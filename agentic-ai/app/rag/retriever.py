import logging
import threading
from dataclasses import dataclass
from typing import Callable

from langchain_core.documents import Document
from langchain_core.language_models import BaseChatModel

from app.rag.chain import build_rag_chain
from app.rag.chunking import medicine_id
from app.rag.vector_store import KnowledgeVectorStore

logger = logging.getLogger(__name__)


class RagUnavailableError(RuntimeError):
    """Embedding, vector search or ingestion failed. Raised instead of degrading to a different
    retrieval method, so a failure is visible and incompatible vectors are never mixed. The message
    never includes credentials or connection strings."""


@dataclass(frozen=True)
class RetrievedChunk:
    id: str
    medicine_name: str
    section: str
    text: str


@dataclass(frozen=True)
class MedicineAnswer:
    text: str
    chunks: list[RetrievedChunk]


def _to_chunk(doc: Document) -> RetrievedChunk:
    meta = doc.metadata
    return RetrievedChunk(
        id=meta.get("chunk_id") or doc.id or "",
        medicine_name=meta.get("medicine_name", ""),
        section=meta.get("section", ""),
        text=doc.page_content,
    )


class MedicineKnowledgeRetriever:
    """The grounding source for general (not personal) medicine questions — docs/ai-architecture.md
    rule 1: the medicine agent never states a fact about a drug that isn't in a retrieved chunk.

    The vector store (Gemini embeddings + Supabase pgvector) is connected and synced lazily on the
    first general-medicine question, so the personal-data paths never depend on it."""

    def __init__(
        self,
        name_lookup: dict[str, str],
        store_factory: Callable[[], KnowledgeVectorStore],
        chat_model: BaseChatModel | None = None,
    ):
        self._name_lookup = name_lookup
        self._store_factory = store_factory
        self._chat_model = chat_model
        self._store: KnowledgeVectorStore | None = None
        # Warm-up and a user's first question can race; only one may connect and sync.
        self._init_lock = threading.Lock()
        self._last_init_failed = False

    def find_mentioned_medicine(self, query: str) -> str | None:
        lowered = query.lower()
        for alias, canonical in self._name_lookup.items():
            if alias in lowered:
                return canonical
        return None

    def retrieve(self, query: str, medicine_name: str, top_k: int = 2) -> list[RetrievedChunk]:
        """Top-K chunks for the named medicine: LangChain retriever -> Gemini query embedding ->
        pgvector cosine search."""
        try:
            return [_to_chunk(d) for d in self._retriever(medicine_name, top_k).invoke(query)]
        except RagUnavailableError:
            raise
        except Exception as exc:
            raise self._unavailable("retrieval", exc) from exc

    def answer(self, query: str, medicine_name: str, top_k: int = 2) -> MedicineAnswer:
        """Full RAG chain: retrieve, then have the Gemini chat model word an answer from only
        those chunks (extractive fallback if the chat model fails)."""
        try:
            retriever = self._retriever(medicine_name, top_k)
            result = build_rag_chain(retriever, self._chat_model).invoke(query)
        except RagUnavailableError:
            raise
        except Exception as exc:
            raise self._unavailable("retrieval", exc) from exc
        return MedicineAnswer(text=result["answer"], chunks=[_to_chunk(d) for d in result["docs"]])

    @property
    def status(self) -> str:
        """"ready" once connected and synced, "failed" if the last attempt failed (the next
        question retries), otherwise "pending"."""
        if self._store is not None:
            return "ready"
        return "failed" if self._last_init_failed else "pending"

    def warm_up(self) -> None:
        """Connect to the vector store and sync the knowledge base now instead of on the first
        question. Safe to call repeatedly and concurrently; raises RagUnavailableError on failure."""
        self._ensure_store()

    def _ensure_store(self) -> KnowledgeVectorStore:
        if self._store is not None:
            return self._store
        with self._init_lock:
            if self._store is None:
                try:
                    self._store = self._store_factory()
                except Exception as exc:
                    self._last_init_failed = True
                    raise self._unavailable("startup/ingestion", exc) from exc
                self._last_init_failed = False
            return self._store

    def _retriever(self, medicine_name: str, top_k: int):
        return self._ensure_store().as_retriever(medicine_id(medicine_name), top_k)

    @staticmethod
    def _unavailable(stage: str, exc: Exception) -> RagUnavailableError:
        logger.error("RAG %s failed: %s", stage, type(exc).__name__)
        return RagUnavailableError(f"Medicine knowledge base unavailable ({stage} failed: {type(exc).__name__})")
