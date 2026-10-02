import json
from dataclasses import dataclass
from pathlib import Path

from app.config import Settings
from app.embeddings.provider import EmbeddingProvider, get_embedding_provider
from app.rag.chunking import chunk_all
from app.rag.vector_store import InMemoryVectorStore, VectorStore

DATA_PATH = Path(__file__).resolve().parent.parent.parent / "data" / "medicines" / "knowledge_base.json"


@dataclass(frozen=True)
class MedicineKnowledgeBase:
    store: VectorStore
    provider: EmbeddingProvider
    #: lowercased name/alias -> canonical display name, so "glucophage" resolves to "Metformin".
    name_lookup: dict[str, str]


def load_medicine_entries(path: Path = DATA_PATH) -> list[dict]:
    if not path.exists():
        return []
    return json.loads(path.read_text(encoding="utf-8"))


def build_knowledge_base(settings: Settings, entries: list[dict] | None = None) -> MedicineKnowledgeBase:
    """Ingestion: load -> chunk -> embed -> index. Runs once at process startup (see
    `api/deps.py`), not per-request — the knowledge base is small and static."""
    entries = load_medicine_entries() if entries is None else entries
    chunks = chunk_all(entries)

    provider = get_embedding_provider(settings)
    provider.fit([c.text for c in chunks])

    store = InMemoryVectorStore()
    for chunk in chunks:
        store.add(chunk, provider.embed(chunk.text))

    name_lookup: dict[str, str] = {}
    for entry in entries:
        for alias in (entry["name"], *entry.get("aliases", [])):
            name_lookup[alias.lower()] = entry["name"]

    return MedicineKnowledgeBase(store=store, provider=provider, name_lookup=name_lookup)
