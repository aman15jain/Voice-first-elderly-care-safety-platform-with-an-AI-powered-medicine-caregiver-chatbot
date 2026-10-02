from fastapi import Depends, Header, HTTPException

from app.config import Settings, get_settings
from app.rag.ingest import build_knowledge_base
from app.rag.retriever import MedicineKnowledgeRetriever
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
    """Ingestion (load -> chunk -> embed -> index) runs once per process, not per-request —
    `data/medicines/knowledge_base.json` is small and static."""
    global _medicine_knowledge_retriever
    if _medicine_knowledge_retriever is None:
        _medicine_knowledge_retriever = MedicineKnowledgeRetriever(build_knowledge_base(settings))
    return _medicine_knowledge_retriever


def require_internal_api_key(
    x_internal_api_key: str | None = Header(default=None),
    settings: Settings = Depends(get_settings),
) -> None:
    # An empty key disables the check — local development only, documented in .env.example.
    if not settings.internal_api_key:
        return
    if x_internal_api_key != settings.internal_api_key:
        raise HTTPException(status_code=401, detail="Invalid internal API key")
