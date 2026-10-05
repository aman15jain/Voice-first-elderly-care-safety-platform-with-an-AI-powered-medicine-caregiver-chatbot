from typing import Literal

from pydantic import BaseModel, Field


class AgentRequest(BaseModel):
    elder_id: str
    mode: Literal["medicine_query", "caregiver_insight", "general_question"]
    query: str | None = None
    language: str = "en"


class AgentResponse(BaseModel):
    success: bool = True
    type: Literal["information", "action"] = "information"
    response: str
    language: str
    sources: list[str] = Field(default_factory=list)
    # Phase 8 agents are read-only: they never produce an action for Flutter to execute.
    action: None = None
