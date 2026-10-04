import os

import pytest

# Tests must be hermetic: never read the developer's real .env (which points at live Gemini and
# Supabase). Environment variables take precedence over the .env file in pydantic-settings.
for _name, _value in {
    "LLM_PROVIDER": "mock",
    "LLM_API_KEY": "",
    "EMBEDDING_PROVIDER": "gemini",
    "EMBEDDING_API_KEY": "test-key",
    "VECTOR_DB_URL": "",
    "WARM_UP_ON_STARTUP": "false",
    "INTERNAL_API_KEY": "",
}.items():
    os.environ[_name] = _value

from app.api.deps import get_medicine_knowledge_retriever  # noqa: E402
from app.main import app  # noqa: E402
from app.rag.ingest import build_name_lookup, ingest_knowledge_base  # noqa: E402
from app.rag.retriever import MedicineKnowledgeRetriever  # noqa: E402
from tests.fakes import ENTRIES, KeywordFakeEmbeddings, make_store  # noqa: E402


@pytest.fixture(autouse=True)
def fake_knowledge_retriever():
    """API-level tests never touch Gemini or Supabase: the retriever is backed by a LangChain
    in-memory store with deterministic test embeddings."""

    def factory():
        store = make_store(KeywordFakeEmbeddings())
        ingest_knowledge_base(store, ENTRIES, "test-model")
        return store

    retriever = MedicineKnowledgeRetriever(build_name_lookup(ENTRIES), factory)
    app.dependency_overrides[get_medicine_knowledge_retriever] = lambda: retriever
    yield retriever
    app.dependency_overrides.pop(get_medicine_knowledge_retriever, None)
