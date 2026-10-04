from app.llm.provider import LlmProvider, with_general_info_disclaimer
from app.rag.retriever import MedicineKnowledgeRetriever, RagUnavailableError
from app.schemas.agents import AgentResponse
from app.tools.medicine_tool import MedicineContextTool
from app.tools.node_client import ToolError

_ADHERENCE_KEYWORDS = ("taken", "took", "adherence", "missed", "skip")
_GENERAL_INFO_KEYWORDS = (
    "what is", "what's", "side effect", "used for", "purpose of", "why do i take", "what does", "tell me about",
    "cause",
)
_ADHERENCE_WINDOW_DAYS = 30


class MedicineAgent:
    """Answers an elder's own medicine/adherence questions (grounded in `MedicineContextTool`,
    which Node already authorized), and general medicine questions — what a drug is for, its
    side effects, warnings — grounded in the curated knowledge base (`MedicineKnowledgeRetriever`,
    Phase 9). Every fact it states came from one of those two sources; it never names a medicine
    or a number that wasn't in them (docs/ai-architecture.md rule 1), and says so plainly when
    there's nothing to report."""

    def __init__(self, tool: MedicineContextTool, llm: LlmProvider, retriever: MedicineKnowledgeRetriever):
        self._tool = tool
        self._llm = llm
        self._retriever = retriever

    async def answer(self, elder_id: str, query: str, language: str) -> AgentResponse:
        general_info_answer = self._try_general_info(query, language)
        if general_info_answer is not None:
            return general_info_answer

        try:
            context = await self._tool.run(elder_id)
        except ToolError:
            return AgentResponse(
                response="I couldn't retrieve your medicine information right now. Please try again shortly.",
                language=language,
                sources=[],
            )

        medicines = context.get("medicines", [])
        adherence = context.get("adherence", {})

        if _mentions_adherence(query):
            total_due = adherence.get("totalDue", 0)
            if total_due == 0:
                text = self._llm.compose("medicine_adherence_none", days=_ADHERENCE_WINDOW_DAYS)
            else:
                text = self._llm.compose(
                    "medicine_adherence",
                    days=_ADHERENCE_WINDOW_DAYS,
                    taken=adherence.get("taken", 0),
                    total_due=total_due,
                    taken_rate=adherence.get("takenRate"),
                )
            return AgentResponse(response=text, language=language, sources=["adherence_summary"])

        if not medicines:
            text = self._llm.compose("medicine_none")
            return AgentResponse(response=text, language=language, sources=[])

        medicines_list = ", ".join(f"{m['name']} ({m['dosage']})" for m in medicines)
        text = self._llm.compose("medicine_list", count=len(medicines), medicines_list=medicines_list)
        return AgentResponse(response=text, language=language, sources=["medicines"])

    def _try_general_info(self, query: str, language: str) -> AgentResponse | None:
        """Returns a RAG-grounded answer if the query both looks like a general-info question and
        names a medicine the knowledge base covers; otherwise None, so `answer()` falls through to
        the personal-data path."""
        if not _mentions_general_info(query):
            return None
        medicine_name = self._retriever.find_mentioned_medicine(query)
        if medicine_name is None:
            text = self._llm.compose("medicine_general_info_not_found")
            return AgentResponse(response=text, language=language, sources=[])

        try:
            result = self._retriever.answer(query, medicine_name=medicine_name)
        except RagUnavailableError:
            return AgentResponse(
                response="I couldn't look up medicine information right now. Please try again shortly.",
                language=language,
                sources=[],
            )
        if not result.chunks:
            text = self._llm.compose("medicine_general_info_unknown", medicine_name=medicine_name)
            return AgentResponse(response=text, language=language, sources=[])

        # The RAG chain already worded the answer from the retrieved chunks only; the disclaimer is
        # appended deterministically rather than left to a model.
        text = with_general_info_disclaimer(result.text)
        sources = [f"knowledge_base:{c.id}" for c in result.chunks]
        return AgentResponse(response=text, language=language, sources=sources)


def _mentions_adherence(query: str) -> bool:
    lowered = query.lower()
    return any(keyword in lowered for keyword in _ADHERENCE_KEYWORDS)


def _mentions_general_info(query: str) -> bool:
    lowered = query.lower()
    return any(keyword in lowered for keyword in _GENERAL_INFO_KEYWORDS)
