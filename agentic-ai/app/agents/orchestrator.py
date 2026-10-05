from app.agents.caregiver_insight_agent import CaregiverInsightAgent
from app.agents.general_question_agent import GeneralQuestionAgent
from app.agents.medicine_agent import MedicineAgent
from langchain_core.language_models import BaseChatModel

from app.llm.provider import LlmProvider
from app.rag.retriever import MedicineKnowledgeRetriever
from app.schemas.agents import AgentRequest, AgentResponse
from app.tools.caregiver_insight_tool import CaregiverInsightContextTool
from app.tools.medicine_tool import MedicineContextTool
from app.tools.node_client import NodeApiClient


class Orchestrator:
    """The single entrypoint `/agents/respond` calls. Its only job is routing a request to the one
    agent that handles it — it holds no business logic of its own, and never picks a tool or
    action outside the fixed set each agent is built with."""

    def __init__(
        self,
        node_client: NodeApiClient,
        llm: LlmProvider,
        retriever: MedicineKnowledgeRetriever,
        chat_model: BaseChatModel | None = None,
    ):
        self._medicine_agent = MedicineAgent(MedicineContextTool(node_client), llm, retriever)
        self._general_question_agent = GeneralQuestionAgent(chat_model)
        self._caregiver_insight_agent = CaregiverInsightAgent(CaregiverInsightContextTool(node_client), llm)

    async def handle(self, request: AgentRequest) -> AgentResponse:
        if request.mode == "medicine_query":
            query = request.query or ""
            return await self._medicine_agent.answer(request.elder_id, query, request.language)
        if request.mode == "general_question":
            return await self._general_question_agent.answer(request.query or "", request.language)
        return await self._caregiver_insight_agent.summarize(request.elder_id, request.language)
