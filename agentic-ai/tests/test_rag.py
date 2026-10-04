import re
from pathlib import Path

import pytest
from langchain_core.language_models.fake_chat_models import FakeListChatModel
from langchain_core.vectorstores import InMemoryVectorStore
from langchain_google_genai import GoogleGenerativeAIEmbeddings

from app.config import Settings
from app.embeddings.provider import EmbeddingConfigError, get_embeddings
from app.rag.chain import create_chat_model
from app.rag.chunking import SOURCE, entries_to_documents, medicine_id, split_documents
from app.rag.ingest import build_name_lookup, ingest_knowledge_base, load_medicine_entries
from app.rag.retriever import MedicineKnowledgeRetriever, RagUnavailableError
from app.rag.vector_store import _to_psycopg_url
from tests.fakes import ENTRIES, KeywordFakeEmbeddings, make_store

MODEL = "gemini-embedding-001"


def _settings(**overrides) -> Settings:
    return Settings(_env_file=None, **overrides)


def _retriever(store=None, chat_model=None) -> MedicineKnowledgeRetriever:
    store = store or make_store()
    ingest_knowledge_base(store, ENTRIES, MODEL)
    return MedicineKnowledgeRetriever(build_name_lookup(ENTRIES), lambda: store, chat_model)


# --- knowledge base -> LangChain Documents -> chunks ----------------------------------------


def test_real_knowledge_base_file_loads_and_is_nonempty() -> None:
    entries = load_medicine_entries()
    assert len(entries) >= 5
    assert any(e["name"] == "Metformin" for e in entries)


def test_entries_become_langchain_documents_with_metadata() -> None:
    docs = entries_to_documents(ENTRIES)
    assert len(docs) == 6  # 2 medicines x 3 sections
    first = docs[0]
    assert first.metadata == {"medicine_id": "metformin", "medicine_name": "Metformin", "section": "uses", "source": SOURCE}
    assert "blood sugar" in first.page_content


def test_split_documents_preserves_metadata_and_assigns_stable_ids() -> None:
    chunks = split_documents(entries_to_documents(ENTRIES), MODEL)
    assert len(chunks) == 6  # short sections are not split further
    chunk = chunks[0]
    assert chunk.id == "metformin:uses:0"
    assert chunk.metadata["medicine_name"] == "Metformin" and chunk.metadata["chunk_index"] == 0
    assert len(chunk.metadata["content_hash"]) == 64
    # Deterministic: the same input gives the same ids and hashes.
    assert [c.id for c in chunks] == [c.id for c in split_documents(entries_to_documents(ENTRIES), MODEL)]


def test_long_sections_are_split_and_every_piece_keeps_the_medicine_metadata() -> None:
    long_entry = {"name": "Long Med", "uses": " ".join(["Sentence about this medicine."] * 80)}
    chunks = split_documents(entries_to_documents([long_entry]), MODEL)
    assert len(chunks) > 1
    assert [c.metadata["chunk_index"] for c in chunks] == list(range(len(chunks)))
    assert all(c.metadata["medicine_id"] == "long-med" and c.metadata["section"] == "uses" for c in chunks)
    assert len({c.id for c in chunks}) == len(chunks)


def test_content_hash_depends_on_the_embedding_model() -> None:
    a = split_documents(entries_to_documents(ENTRIES), "model-a")[0].metadata["content_hash"]
    b = split_documents(entries_to_documents(ENTRIES), "model-b")[0].metadata["content_hash"]
    assert a != b


def test_medicine_id_is_a_knowledge_base_slug() -> None:
    assert medicine_id("Vitamin D3 (Cholecalciferol)") == "vitamin-d3-cholecalciferol"


# --- ingestion: persistence + idempotency ---------------------------------------------------


def test_first_ingestion_embeds_every_chunk_as_a_document() -> None:
    embeddings = KeywordFakeEmbeddings()
    report = ingest_knowledge_base(make_store(embeddings), ENTRIES, MODEL)
    assert (report.added, report.updated, report.unchanged, report.removed) == (6, 0, 0, 0)
    assert len(embeddings.document_calls) == 6
    assert embeddings.query_calls == []  # ingestion embeds documents only


def test_repeated_ingestion_does_not_duplicate_or_re_embed() -> None:
    embeddings = KeywordFakeEmbeddings()
    backend = InMemoryVectorStore(embeddings)
    store = make_store(backend=backend)
    ingest_knowledge_base(store, ENTRIES, MODEL)
    calls_after_first = len(embeddings.document_calls)

    report = ingest_knowledge_base(store, ENTRIES, MODEL)
    assert (report.added, report.updated, report.unchanged) == (0, 0, 6)
    assert len(embeddings.document_calls) == calls_after_first
    assert len(backend.store) == 6


def test_restart_reuses_persisted_vectors_without_re_embedding() -> None:
    embeddings = KeywordFakeEmbeddings()
    backend = InMemoryVectorStore(embeddings)  # stands in for the persistent Supabase table
    ingest_knowledge_base(make_store(backend=backend), ENTRIES, MODEL)
    embeddings.document_calls.clear()

    # "Restart": a brand-new process wraps the same persisted store.
    report = ingest_knowledge_base(make_store(backend=backend), ENTRIES, MODEL)
    assert report.embedded == 0 and embeddings.document_calls == []
    # ...and queries work immediately against the persisted vectors.
    retriever = MedicineKnowledgeRetriever(build_name_lookup(ENTRIES), lambda: make_store(backend=backend))
    assert retriever.retrieve("side effects of metformin", "Metformin", top_k=1)[0].section == "side_effects"


def test_changed_chunk_is_re_embedded_and_removed_chunk_is_deleted() -> None:
    embeddings = KeywordFakeEmbeddings()
    backend = InMemoryVectorStore(embeddings)
    store = make_store(backend=backend)
    ingest_knowledge_base(store, ENTRIES, MODEL)
    embeddings.document_calls.clear()

    aspirin_without_warnings = {k: v for k, v in ENTRIES[1].items() if k != "warnings"}
    edited = [dict(ENTRIES[0], uses="Metformin lowers blood sugar."), aspirin_without_warnings]
    report = ingest_knowledge_base(store, edited, MODEL)
    assert (report.added, report.updated, report.unchanged, report.removed) == (0, 1, 4, 1)
    assert embeddings.document_calls == ["Metformin lowers blood sugar."]
    assert "aspirin:warnings:0" not in backend.store


def test_changing_the_embedding_model_re_embeds_everything() -> None:
    store = make_store(KeywordFakeEmbeddings())
    ingest_knowledge_base(store, ENTRIES, "model-a")
    report = ingest_knowledge_base(store, ENTRIES, "model-b")
    assert report.updated == 6


# --- retrieval ------------------------------------------------------------------------------


def test_retriever_finds_mentioned_medicine_by_name_and_alias() -> None:
    retriever = _retriever()
    assert retriever.find_mentioned_medicine("what are the side effects of metformin") == "Metformin"
    assert retriever.find_mentioned_medicine("why do i take glucophage") == "Metformin"
    assert retriever.find_mentioned_medicine("what about ibuprofen") is None


def test_retrieval_ranks_by_vector_similarity_and_respects_top_k() -> None:
    retriever = _retriever()
    side_effects = retriever.retrieve("what are the side effects of metformin", "Metformin", top_k=1)
    assert [c.section for c in side_effects] == ["side_effects"]

    uses = retriever.retrieve("which medicine controls blood sugar in diabetes", "Metformin", top_k=1)
    assert [c.section for c in uses] == ["uses"]

    assert len(retriever.retrieve("anything", "Metformin", top_k=3)) == 3


def test_retrieval_is_scoped_to_the_named_medicine_only() -> None:
    result = _retriever().retrieve("bruising from aspirin", "Aspirin", top_k=3)
    assert len(result) == 3 and all(c.medicine_name == "Aspirin" for c in result)


def test_query_is_embedded_with_the_same_embedding_object_as_documents() -> None:
    embeddings = KeywordFakeEmbeddings()
    retriever = _retriever(make_store(embeddings))
    retriever.retrieve("side effects of metformin", "Metformin")
    assert embeddings.query_calls == ["side effects of metformin"]
    assert len(embeddings.document_calls) == 6


# --- RAG chain: retrieved context -> chat model -> answer -----------------------------------


class _RecordingChatModel(FakeListChatModel):
    seen: list = []

    def _call(self, messages, *args, **kwargs):
        self.seen.append(messages)
        return super()._call(messages, *args, **kwargs)


def test_chain_passes_retrieved_context_to_the_chat_model_and_returns_its_answer() -> None:
    chat = _RecordingChatModel(responses=["It can upset your stomach."], seen=[])
    answer = _retriever(chat_model=chat).answer("what are the side effects of metformin", "Metformin", top_k=1)

    assert answer.text == "It can upset your stomach."
    assert [c.id for c in answer.chunks] == ["metformin:side_effects:0"]
    prompt_text = " ".join(m.content for m in chat.seen[0])
    assert "nausea, diarrhea and stomach upset" in prompt_text  # the retrieved chunk
    assert "side effects of metformin" in prompt_text  # the question
    assert "blood sugar in type 2 diabetes" not in prompt_text  # chunks that weren't retrieved are not sent


def test_chain_falls_back_to_the_retrieved_text_when_the_chat_model_fails() -> None:
    class _Broken(FakeListChatModel):
        def _call(self, *args, **kwargs):
            raise RuntimeError("llm down")

    answer = _retriever(chat_model=_Broken(responses=["x"])).answer("side effects of metformin", "Metformin", top_k=1)
    assert answer.text == "Common side effects include nausea, diarrhea and stomach upset."


def test_without_a_chat_model_the_answer_is_the_retrieved_text() -> None:
    answer = _retriever(chat_model=None).answer("does aspirin cause bruising", "Aspirin", top_k=1)
    assert answer.text == "Can cause stomach upset and bruising."


# --- failures are explicit ------------------------------------------------------------------


def test_store_startup_failure_raises_without_leaking_secrets() -> None:
    def factory():
        raise RuntimeError("connection to postgresql://user:SUPERSECRET@host failed")

    retriever = MedicineKnowledgeRetriever(build_name_lookup(ENTRIES), factory)
    with pytest.raises(RagUnavailableError) as info:
        retriever.retrieve("side effects", "Metformin")
    assert "SUPERSECRET" not in str(info.value)


def test_embedding_failure_during_retrieval_raises_and_does_not_fall_back() -> None:
    class _FailingQueries(KeywordFakeEmbeddings):
        def embed_query(self, text):
            raise RuntimeError("quota exceeded")

    store = make_store(_FailingQueries())
    ingest_knowledge_base(store, ENTRIES, MODEL)
    retriever = MedicineKnowledgeRetriever(build_name_lookup(ENTRIES), lambda: store)
    with pytest.raises(RagUnavailableError):
        retriever.retrieve("side effects", "Metformin")
    with pytest.raises(RagUnavailableError):
        retriever.answer("side effects", "Metformin")


# --- configuration: Gemini only, no local embeddings ----------------------------------------


def test_embeddings_are_gemini_with_the_configured_model() -> None:
    embeddings = get_embeddings(_settings(embedding_provider="gemini", embedding_api_key="k", embedding_model=MODEL))
    assert isinstance(embeddings, GoogleGenerativeAIEmbeddings)
    assert embeddings.model.endswith(MODEL)


def test_missing_key_or_non_gemini_provider_fails_clearly() -> None:
    with pytest.raises(EmbeddingConfigError):
        get_embeddings(_settings(embedding_provider="gemini", embedding_api_key=""))
    for provider in ("mock", "sentence-transformers", "tfidf"):
        with pytest.raises(EmbeddingConfigError):
            get_embeddings(_settings(embedding_provider=provider, embedding_api_key="k"))


def test_chat_model_selection() -> None:
    assert create_chat_model(_settings(llm_provider="mock")) is None
    assert create_chat_model(_settings(llm_provider="gemini", llm_api_key="k", llm_model="some-model")).model.endswith("some-model")
    with pytest.raises(ValueError):
        create_chat_model(_settings(llm_provider="gemini", llm_api_key=""))


def test_connection_url_is_converted_for_the_psycopg_driver() -> None:
    url = _to_psycopg_url("postgresql://u:p@host:6543/postgres?pgbouncer=true&sslmode=require")
    assert url == "postgresql+psycopg://u:p@host:6543/postgres?sslmode=require"
    assert _to_psycopg_url("postgresql+psycopg://u:p@h/db") == "postgresql+psycopg://u:p@h/db"


def test_rag_code_has_no_local_embedding_model_and_touches_no_application_table() -> None:
    app_dir = Path(__file__).resolve().parent.parent / "app"
    source = "\n".join(p.read_text(encoding="utf-8") for sub in ("rag", "embeddings") for p in (app_dir / sub).glob("*.py"))
    assert not re.search(r"sentence_transformers|SentenceTransformer|TfidfVectorizer|TfEmbedding|MiniLM|faiss|chroma", source, re.I)
    prisma_tables = (
        "medicine_doses", "medicine_schedules", "elder_profiles", "caregiver_profiles", "emergency_events",
        "family_links", "refresh_tokens", "activity_events", "voice_interactions", "game_sessions",
    )
    assert not [t for t in prisma_tables if t in source]
