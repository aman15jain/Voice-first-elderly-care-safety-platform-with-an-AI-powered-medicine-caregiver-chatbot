from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from langchain_core.documents import Document
from langchain_core.embeddings import Embeddings
from langchain_core.retrievers import BaseRetriever
from langchain_core.vectorstores import InMemoryVectorStore, VectorStore
from langchain_postgres import PGVector
from sqlalchemy import select

from app.config import Settings


class VectorStoreConfigError(ValueError):
    """The vector database connection isn't configured."""


def _to_psycopg_url(url: str) -> str:
    """SQLAlchemy needs the `postgresql+psycopg` driver prefix, and the `pgbouncer=true` flag is a
    Prisma-only URL option that psycopg would reject. Everything else (host, credentials) is the
    same Supabase connection the Node backend uses."""
    parts = urlsplit(url)
    scheme = "postgresql+psycopg" if parts.scheme in ("postgresql", "postgres") else parts.scheme
    query = urlencode([(k, v) for k, v in parse_qsl(parts.query) if k != "pgbouncer"])
    return urlunsplit((scheme, parts.netloc, parts.path, query, parts.fragment))


def create_pgvector_store(settings: Settings, embeddings: Embeddings) -> VectorStore:
    """Supabase PostgreSQL + pgvector via LangChain. Vectors live in LangChain's own
    `langchain_pg_collection` / `langchain_pg_embedding` tables, never in Prisma-managed
    application tables. Similarity (cosine distance) is computed by pgvector inside the database."""
    if not settings.vector_db_url:
        raise VectorStoreConfigError("VECTOR_DB_URL must point at the Supabase Postgres database")
    return PGVector(
        embeddings=embeddings,
        connection=_to_psycopg_url(settings.vector_db_url),
        collection_name=settings.rag_collection_name,
        use_jsonb=True,
    )


class KnowledgeVectorStore:
    """The narrow surface the ingestion and retrieval code uses, so no database or backend-specific
    detail leaks out of this module. Wraps any LangChain `VectorStore`: `PGVector` in production,
    LangChain's `InMemoryVectorStore` in unit tests."""

    def __init__(self, store: VectorStore):
        self._store = store

    def stored_hashes(self) -> dict[str, str]:
        """chunk id -> content hash for everything currently persisted in this collection."""
        ids = self._list_ids()
        if not ids:
            return {}
        return {d.id: (d.metadata or {}).get("content_hash", "") for d in self._store.get_by_ids(ids) if d.id}

    def upsert(self, chunks: list[Document]) -> None:
        """Embeds (via the store's embedding model) and writes; an existing id is overwritten."""
        if chunks:
            self._store.add_documents(chunks, ids=[c.id for c in chunks])

    def delete(self, ids: list[str]) -> None:
        if ids:
            self._store.delete(ids=ids)

    def as_retriever(self, medicine_id: str | None, k: int) -> BaseRetriever:
        search_kwargs: dict = {"k": k}
        if medicine_id is not None:
            if isinstance(self._store, InMemoryVectorStore):
                search_kwargs["filter"] = lambda doc: doc.metadata.get("medicine_id") == medicine_id
            else:
                search_kwargs["filter"] = {"medicine_id": {"$eq": medicine_id}}
        return self._store.as_retriever(search_type="similarity", search_kwargs=search_kwargs)

    def _list_ids(self) -> list[str]:
        if isinstance(self._store, InMemoryVectorStore):
            return list(self._store.store)
        embedding_store = self._store.EmbeddingStore  # type: ignore[attr-defined]
        with self._store._make_sync_session() as session:  # type: ignore[attr-defined]
            collection = self._store.get_collection(session)  # type: ignore[attr-defined]
            stmt = select(embedding_store.id).where(embedding_store.collection_id == collection.uuid)
            return list(session.execute(stmt).scalars().all())
