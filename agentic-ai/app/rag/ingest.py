import json
import logging
from dataclasses import dataclass
from pathlib import Path

from app.rag.chunking import entries_to_documents, medicine_id, split_documents
from app.rag.vector_store import KnowledgeVectorStore

logger = logging.getLogger(__name__)

DATA_PATH = Path(__file__).resolve().parent.parent.parent / "data" / "medicines" / "knowledge_base.json"


@dataclass(frozen=True)
class IngestionReport:
    added: int
    updated: int
    unchanged: int
    removed: int

    @property
    def embedded(self) -> int:
        """How many chunks needed a Gemini embedding call this run."""
        return self.added + self.updated


def load_medicine_entries(path: Path = DATA_PATH) -> list[dict]:
    if not path.exists():
        return []
    return json.loads(path.read_text(encoding="utf-8"))


def build_name_lookup(entries: list[dict]) -> dict[str, str]:
    """lowercased name/alias -> canonical display name, so "glucophage" resolves to "Metformin"."""
    lookup: dict[str, str] = {}
    for entry in entries:
        for alias in (entry["name"], *entry.get("aliases", [])):
            lookup[alias.lower()] = entry["name"]
    return lookup


def ingest_knowledge_base(store: KnowledgeVectorStore, entries: list[dict], embedding_model: str) -> IngestionReport:
    """Idempotent sync of the knowledge base into the vector store:
    new chunk -> embedded and inserted; changed chunk (text or embedding model) -> re-embedded and
    updated; unchanged chunk -> left alone with no embedding call; chunk no longer in the JSON ->
    deleted. Safe to run on every process start: when nothing changed it makes zero Gemini calls."""
    chunks = split_documents(entries_to_documents(entries), embedding_model)
    desired = {c.id: c for c in chunks}
    stored = store.stored_hashes()

    to_write = [c for c in chunks if stored.get(c.id) != c.metadata["content_hash"]]
    stale = [chunk_id for chunk_id in stored if chunk_id not in desired]

    store.upsert(to_write)
    store.delete(stale)

    report = IngestionReport(
        added=sum(1 for c in to_write if c.id not in stored),
        updated=sum(1 for c in to_write if c.id in stored),
        unchanged=len(chunks) - len(to_write),
        removed=len(stale),
    )
    logger.info(
        "Knowledge base ingestion: %d added, %d updated, %d unchanged, %d removed",
        report.added, report.updated, report.unchanged, report.removed,
    )
    return report


__all__ = ["DATA_PATH", "IngestionReport", "build_name_lookup", "ingest_knowledge_base", "load_medicine_entries", "medicine_id"]
