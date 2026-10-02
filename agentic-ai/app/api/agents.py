from fastapi import APIRouter, Depends

from app.agents.orchestrator import Orchestrator
from app.api.deps import get_medicine_knowledge_retriever, get_node_client, require_internal_api_key
from app.config import Settings, get_settings
from app.llm.provider import get_llm_provider
from app.rag.retriever import MedicineKnowledgeRetriever
from app.schemas.agents import AgentRequest, AgentResponse
from app.tools.node_client import NodeApiClient

router = APIRouter(tags=["agents"], dependencies=[Depends(require_internal_api_key)])


def get_orchestrator(
    node_client: NodeApiClient = Depends(get_node_client),
    settings: Settings = Depends(get_settings),
    retriever: MedicineKnowledgeRetriever = Depends(get_medicine_knowledge_retriever),
) -> Orchestrator:
    return Orchestrator(node_client, get_llm_provider(settings), retriever)


@router.post("/agents/respond", response_model=AgentResponse)
async def respond(request: AgentRequest, orchestrator: Orchestrator = Depends(get_orchestrator)) -> AgentResponse:
    return await orchestrator.handle(request)
