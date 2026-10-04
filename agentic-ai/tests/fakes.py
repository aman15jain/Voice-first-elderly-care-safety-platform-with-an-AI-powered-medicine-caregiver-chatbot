"""Test doubles for the RAG pipeline. These exist only under tests/ — production has no local
embedding model; real embeddings are always Gemini."""
import re

from langchain_core.embeddings import Embeddings
from langchain_core.vectorstores import InMemoryVectorStore

from app.rag.vector_store import KnowledgeVectorStore

_VOCAB = [
    "sugar", "diabetes", "nausea", "diarrhea", "stomach", "upset", "bruising", "side", "effects", "heart",
    "attack", "stroke", "food", "surgery", "kidney", "blood", "pressure", "cough", "dizziness", "doctor",
]
_ALIASES = {"effect": "effects"}


class KeywordFakeEmbeddings(Embeddings):
    """Deterministic bag-of-words vectors that record every call, so tests can assert which texts
    were embedded (documents vs queries) and how many Gemini-style calls a run would have made."""

    def __init__(self) -> None:
        self.document_calls: list[str] = []
        self.query_calls: list[str] = []

    @staticmethod
    def _vector(text: str) -> list[float]:
        words = [_ALIASES.get(w, w) for w in re.findall(r"[a-z]+", text.lower())]
        return [float(words.count(term)) for term in _VOCAB] + [0.01]

    def embed_documents(self, texts: list[str]) -> list[list[float]]:
        self.document_calls.extend(texts)
        return [self._vector(t) for t in texts]

    def embed_query(self, text: str) -> list[float]:
        self.query_calls.append(text)
        return self._vector(text)


def make_store(embeddings: Embeddings | None = None, backend: InMemoryVectorStore | None = None) -> KnowledgeVectorStore:
    """`backend` can be shared between two KnowledgeVectorStore instances to simulate a restart
    against the same persisted database."""
    backend = backend or InMemoryVectorStore(embeddings or KeywordFakeEmbeddings())
    return KnowledgeVectorStore(backend)


ENTRIES = [
    {
        "name": "Metformin",
        "aliases": ["glucophage"],
        "uses": "Metformin helps control blood sugar in type 2 diabetes.",
        "side_effects": "Common side effects include nausea, diarrhea and stomach upset.",
        "warnings": "Take with food. Tell your doctor about kidney problems.",
    },
    {
        "name": "Aspirin",
        "aliases": [],
        "uses": "Low-dose aspirin helps prevent a heart attack or stroke.",
        "side_effects": "Can cause stomach upset and bruising.",
        "warnings": "Tell your doctor before surgery.",
    },
]
