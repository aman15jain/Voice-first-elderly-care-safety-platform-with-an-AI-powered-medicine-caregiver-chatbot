import logging

from fastapi import FastAPI

from app import __version__
from app.api import agents, health
from app.config import get_settings


def create_app() -> FastAPI:
    settings = get_settings()
    logging.basicConfig(level=settings.log_level.upper(), format="%(asctime)s %(levelname)s %(name)s %(message)s")

    app = FastAPI(title="Elderly Care Agentic AI", version=__version__)
    # /health stays open for container health checks; every other router requires
    # the shared internal API key (see docs/ai-architecture.md).
    app.include_router(health.router)
    app.include_router(agents.router)
    return app


app = create_app()
