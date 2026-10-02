from app.llm.provider import LlmProvider
from app.schemas.agents import AgentResponse
from app.tools.caregiver_insight_tool import CaregiverInsightContextTool
from app.tools.node_client import ToolError

_ADHERENCE_WINDOW_DAYS = 30
_ACTIVITY_WINDOW_DAYS = 7


class CaregiverInsightAgent:
    """Summarizes one elder's recent adherence and activity for a linked caregiver. Grounded only
    in structured data Node already computed (docs/ai-architecture.md rule 2) — never the elder's
    raw messages, and never a suggestion to act, since caregiver summaries must stay informational."""

    def __init__(self, tool: CaregiverInsightContextTool, llm: LlmProvider):
        self._tool = tool
        self._llm = llm

    async def summarize(self, elder_id: str, language: str) -> AgentResponse:
        try:
            context = await self._tool.run(elder_id)
        except ToolError:
            return AgentResponse(
                response="I couldn't retrieve this elder's information right now. Please try again shortly.",
                language=language,
                sources=[],
            )

        adherence = context.get("adherence", {})
        activity = context.get("activity", {})
        taken_rate = adherence.get("takenRate")
        taken_rate_text = "not yet available" if taken_rate is None else f"{taken_rate}%"

        summary = self._llm.compose(
            "caregiver_insight_summary",
            adherence_days=_ADHERENCE_WINDOW_DAYS,
            taken_rate=taken_rate_text,
            taken=adherence.get("taken", 0),
            total_due=adherence.get("totalDue", 0),
            activity_days=_ACTIVITY_WINDOW_DAYS,
            active_days=activity.get("activeDays", 0),
        )

        sources = ["adherence_summary", "activity_summary"]
        if context.get("activeEmergency"):
            emergency_notice = self._llm.compose("caregiver_insight_emergency")
            sources.append("emergency_status")
            return AgentResponse(response=f"{emergency_notice} {summary}", language=language, sources=sources)

        return AgentResponse(response=summary, language=language, sources=sources)
