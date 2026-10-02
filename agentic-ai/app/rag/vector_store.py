from abc import ABC, abstractmethod
from dataclasses import dataclass

from app.embeddings.provider import cosine_similarity
from app.rag.chunking import Chunk


@dataclass(frozen=True)
class ScoredChunk:
    chunk: Chunk
    score: float


class VectorStore(ABC):
    """Swappable store for (chunk, embedding) pairs. `InMemoryVectorStore` is the real
    implementation for this knowledge base's size; a production-scale deployment could swap in
    a real vector database (`settings.vector_db_url`, currently unused) behind this same interface."""

    @abstractmethod
    def add(self, chunk: Chunk, embedding: dict[str, float]) -> None: ...

    @abstractmethod
    def search(self, query_embedding: dict[str, float], top_k: int, medicine_name: str | None = None) -> list[ScoredChunk]: ...

    @abstractmethod
    def chunks_for_medicine(self, medicine_name: str) -> list[Chunk]: ...


class InMemoryVectorStore(VectorStore):
    def __init__(self):
        self._entries: list[tuple[Chunk, dict[str, float]]] = []

    def add(self, chunk: Chunk, embedding: dict[str, float]) -> None:
        self._entries.append((chunk, embedding))

    def search(self, query_embedding: dict[str, float], top_k: int, medicine_name: str | None = None) -> list[ScoredChunk]:
        candidates = self._entries
        if medicine_name is not None:
            candidates = [(c, e) for c, e in candidates if c.medicine_name.lower() == medicine_name.lower()]
        scored = [ScoredChunk(chunk=c, score=cosine_similarity(query_embedding, e)) for c, e in candidates]
        scored.sort(key=lambda s: s.score, reverse=True)
        return scored[:top_k]

    def chunks_for_medicine(self, medicine_name: str) -> list[Chunk]:
        return [c for c, _ in self._entries if c.medicine_name.lower() == medicine_name.lower()]
