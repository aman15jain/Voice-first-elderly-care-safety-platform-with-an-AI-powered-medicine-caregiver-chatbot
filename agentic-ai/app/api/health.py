from fastapi import APIRouter

from app import __version__
from app.api.deps import knowledge_base_status
from app.schemas.health import HealthResponse

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok", service="agentic-ai", version=__version__, knowledge_base=knowledge_base_status())
