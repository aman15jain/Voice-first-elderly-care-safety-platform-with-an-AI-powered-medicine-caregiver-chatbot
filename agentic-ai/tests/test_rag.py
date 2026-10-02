from app.config import Settings
from app.rag.chunking import chunk_all, chunk_medicine
from app.rag.ingest import build_knowledge_base, load_medicine_entries
from app.rag.retriever import MedicineKnowledgeRetriever

_ENTRIES = [
    {
        "name": "Metformin",
        "aliases": ["glucophage"],
        "uses": "Metformin helps control blood sugar in type 2 diabetes.",
        "side_effects": "Common side effects include nausea and stomach upset.",
        "warnings": "Take with food.",
    },
    {
        "name": "Aspirin",
        "aliases": [],
        "uses": "Low-dose aspirin helps prevent heart attacks and strokes.",
        "side_effects": "Can cause stomach upset and bruising.",
        "warnings": "Tell your doctor before surgery.",
    },
]


def test_chunk_medicine_produces_one_chunk_per_section() -> None:
    chunks = chunk_medicine(_ENTRIES[0])
    assert [c.section for c in chunks] == ["uses", "side_effects", "warnings"]
    assert all(c.medicine_name == "Metformin" for c in chunks)
    assert chunks[0].id == "metformin:uses"


def test_chunk_all_covers_every_entry() -> None:
    chunks = chunk_all(_ENTRIES)
    assert len(chunks) == 6


def test_real_knowledge_base_file_loads_and_is_nonempty() -> None:
    entries = load_medicine_entries()
    assert len(entries) >= 5
    assert any(e["name"] == "Metformin" for e in entries)


def test_retriever_finds_mentioned_medicine_by_name_and_alias() -> None:
    kb = build_knowledge_base(Settings(embedding_provider="mock"), entries=_ENTRIES)
    retriever = MedicineKnowledgeRetriever(kb)
    assert retriever.find_mentioned_medicine("what are the side effects of metformin") == "Metformin"
    assert retriever.find_mentioned_medicine("why do i take glucophage") == "Metformin"
    assert retriever.find_mentioned_medicine("what about ibuprofen") is None


def test_retriever_returns_the_section_matching_the_question() -> None:
    kb = build_knowledge_base(Settings(embedding_provider="mock"), entries=_ENTRIES)
    retriever = MedicineKnowledgeRetriever(kb)

    side_effects = retriever.retrieve("what are the side effects of metformin", medicine_name="Metformin")
    assert side_effects[0].section == "side_effects"

    uses = retriever.retrieve("what is metformin used for", medicine_name="Metformin")
    assert uses[0].section == "uses"


def test_retriever_falls_back_to_uses_when_nothing_matches_lexically() -> None:
    kb = build_knowledge_base(Settings(embedding_provider="mock"), entries=_ENTRIES)
    retriever = MedicineKnowledgeRetriever(kb)

    result = retriever.retrieve("tell me about metformin", medicine_name="Metformin")
    assert len(result) == 1
    assert result[0].section == "uses"


def test_retrieval_is_scoped_to_the_named_medicine_only() -> None:
    kb = build_knowledge_base(Settings(embedding_provider="mock"), entries=_ENTRIES)
    retriever = MedicineKnowledgeRetriever(kb)

    result = retriever.retrieve("what are the side effects of aspirin", medicine_name="Aspirin")
    assert all(c.medicine_name == "Aspirin" for c in result)
