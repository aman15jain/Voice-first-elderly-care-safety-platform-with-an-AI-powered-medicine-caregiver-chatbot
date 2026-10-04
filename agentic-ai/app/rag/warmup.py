import asyncio
import logging
import time

from app.rag.retriever import MedicineKnowledgeRetriever

logger = logging.getLogger(__name__)


async def warm_up_knowledge_base(retriever: MedicineKnowledgeRetriever, timeout_seconds: float) -> None:
    """Initialise the vector store off the request path. Never raises and never blocks the caller
    beyond `timeout_seconds`: a failure or timeout is logged (exception type only - messages can
    carry connection details) and the first real question simply retries the same initialisation.

    Only the database connection and the idempotent knowledge-base sync run here; there is no
    chat-model call, and an unchanged knowledge base makes no embedding calls."""
    started = time.monotonic()
    try:
        await asyncio.wait_for(asyncio.to_thread(retriever.warm_up), timeout=timeout_seconds)
    except asyncio.TimeoutError:
        logger.warning("RAG warm-up still running after %.0fs; continuing without waiting", timeout_seconds)
    except Exception as exc:
        logger.warning("RAG warm-up failed (%s); the first medicine question will retry", type(exc).__name__)
    else:
        logger.info("RAG warm-up complete in %.1fs", time.monotonic() - started)
