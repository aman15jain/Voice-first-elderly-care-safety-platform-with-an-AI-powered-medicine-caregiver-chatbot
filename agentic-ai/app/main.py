import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app import __version__
from app.api import agents, health
from app.api.deps import get_medicine_knowledge_retriever
from app.config import get_settings
from app.rag.warmup import warm_up_knowledge_base


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    warm_up_task = None
    if settings.warm_up_on_startup:
        # Background task: the server accepts requests immediately while the vector store connects
        # and syncs. A failure is logged and the same initialisation is retried on first use.
        retriever = get_medicine_knowledge_retriever(settings)
        warm_up_task = asyncio.create_task(warm_up_knowledge_base(retriever, settings.warm_up_timeout_seconds))
    yield
    if warm_up_task is not None and not warm_up_task.done():
        warm_up_task.cancel()


def create_app() -> FastAPI:
    settings = get_settings()
    logging.basicConfig(level=settings.log_level.upper(), format="%(asctime)s %(levelname)s %(name)s %(message)s")

    app = FastAPI(title="Elderly Care Agentic AI", version=__version__, lifespan=lifespan)
    # /health stays open for container health checks; every other router requires
    # the shared internal API key (see docs/ai-architecture.md).
    app.include_router(health.router)
    app.include_router(agents.router)
    return app


app = create_app()
