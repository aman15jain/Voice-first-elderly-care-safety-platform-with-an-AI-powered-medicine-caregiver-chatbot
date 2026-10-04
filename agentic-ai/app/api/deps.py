from fastapi import Depends, Header, HTTPException

from app.config import Settings, get_settings
from app.embeddings.provider import get_embeddings
from app.rag.chain import create_chat_model
from app.rag.ingest import build_name_lookup, ingest_knowledge_base, load_medicine_entries
from app.rag.retriever import MedicineKnowledgeRetriever
from app.rag.vector_store import KnowledgeVectorStore, create_pgvector_store
from app.tools.node_client import NodeApiClient

_node_client: NodeApiClient | None = None
_medicine_knowledge_retriever: MedicineKnowledgeRetriever | None = None


def get_node_client(settings: Settings = Depends(get_settings)) -> NodeApiClient:
    """A single shared client for the process lifetime; httpx.AsyncClient is safe to reuse
    across requests and this avoids opening a new connection pool per call."""
    global _node_client
    if _node_client is None:
        _node_client = NodeApiClient(
            base_url=settings.node_api_base_url,
            internal_api_key=settings.internal_api_key,
            timeout_seconds=settings.node_api_timeout_seconds,
        )
    return _node_client


def get_medicine_knowledge_retriever(settings: Settings = Depends(get_settings)) -> MedicineKnowledgeRetriever:
    """One retriever per process. Constructing it is cheap and touches no network: the Supabase
    connection and the idempotent sync of `data/medicines/knowledge_base.json` happen in the startup
    warm-up (`app/main.py`) or, failing that, on the first general-medicine question. After a
    restart the vectors are already persisted, so that sync re-embeds nothing unless the knowledge
    base changed."""
    global _medicine_knowledge_retriever
    if _medicine_knowledge_retriever is None:
        entries = load_medicine_entries()

        def store_factory() -> KnowledgeVectorStore:
            store = KnowledgeVectorStore(create_pgvector_store(settings, get_embeddings(settings)))
            ingest_knowledge_base(store, entries, settings.embedding_model)
            return store

        _medicine_knowledge_retriever = MedicineKnowledgeRetriever(
            name_lookup=build_name_lookup(entries),
            store_factory=store_factory,
            chat_model=create_chat_model(settings),
        )
    return _medicine_knowledge_retriever


def knowledge_base_status() -> str:
    """"ready" / "pending" / "failed", or "not_initialised" before the retriever exists."""
    return _medicine_knowledge_retriever.status if _medicine_knowledge_retriever else "not_initialised"


def require_internal_api_key(
    x_internal_api_key: str | None = Header(default=None),
    settings: Settings = Depends(get_settings),
) -> None:
    # An empty key disables the check — local development only, documented in .env.example.
    if not settings.internal_api_key:
        return
    if x_internal_api_key != settings.internal_api_key:
        raise HTTPException(status_code=401, detail="Invalid internal API key")
