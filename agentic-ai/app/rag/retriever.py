from dataclasses import dataclass

from app.rag.chunking import Chunk
from app.rag.ingest import MedicineKnowledgeBase


@dataclass(frozen=True)
class RetrievedChunk:
    id: str
    medicine_name: str
    section: str
    text: str


def _to_retrieved(chunk: Chunk) -> RetrievedChunk:
    return RetrievedChunk(id=chunk.id, medicine_name=chunk.medicine_name, section=chunk.section, text=chunk.text)


class MedicineKnowledgeRetriever:
    """The grounding source for general (not personal) medicine questions — docs/ai-architecture.md
    rule 1: the medicine agent never states a fact about a drug that isn't in one of these chunks."""

    def __init__(self, knowledge_base: MedicineKnowledgeBase):
        self._kb = knowledge_base

    def find_mentioned_medicine(self, query: str) -> str | None:
        lowered = query.lower()
        for alias, canonical in self._kb.name_lookup.items():
            if alias in lowered:
                return canonical
        return None

    def retrieve(self, query: str, medicine_name: str, top_k: int = 2) -> list[RetrievedChunk]:
        query_embedding = self._kb.provider.embed(query)
        scored = self._kb.store.search(query_embedding, top_k=top_k, medicine_name=medicine_name)
        matched = [_to_retrieved(s.chunk) for s in scored if s.score > 0]
        if matched:
            return matched
        # The query named the medicine but didn't use words matching any section (e.g. just
        # "tell me about metformin") — fall back to its general "uses" chunk as the most useful default.
        fallback = [c for c in self._kb.store.chunks_for_medicine(medicine_name) if c.section == "uses"]
        return [_to_retrieved(c) for c in fallback[:1]]
