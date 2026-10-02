from abc import ABC, abstractmethod

from app.config import Settings


class LlmProvider(ABC):
    """Composes natural-language text from already-retrieved, structured facts. A provider never
    decides *what* facts are true — agents fetch those from Node first (docs/ai-architecture.md
    rule 1) — it only turns them into a sentence a person can read."""

    @abstractmethod
    def compose(self, template_key: str, **values: object) -> str: ...


class MockLlmProvider(LlmProvider):
    """Deterministic string templating — no network call, no hallucination risk, nothing to mock
    out in tests. This is the real default (`LLM_PROVIDER=mock`), not a placeholder: every Phase 8
    response is produced by this provider. A real model-backed provider can be added later behind
    the same `compose` interface without touching any agent."""

    def compose(self, template_key: str, **values: object) -> str:
        template = _TEMPLATES[template_key]
        return template.format(**values)


_TEMPLATES = {
    "medicine_list": "You take {count} medicine(s): {medicines_list}.",
    "medicine_none": "You don't have any medicines set up yet. Ask a family member to help you add one.",
    "medicine_adherence": "Over the last {days} days you've taken {taken} out of {total_due} doses that were due ({taken_rate}%).",
    "medicine_adherence_none": "You don't have any doses due yet over the last {days} days, so there's nothing to report.",
    "caregiver_insight_summary": (
        "Over the last {adherence_days} days, adherence was {taken_rate}, with {taken} of {total_due} doses "
        "taken. In the last {activity_days} days there were {active_days} active day(s)."
    ),
    "caregiver_insight_emergency": "There is an active emergency alert for this elder right now — please check on them.",
    "medicine_general_info": "{body} This is general information, not medical advice — talk to your doctor or pharmacist with any concerns.",
    "medicine_general_info_unknown": "I don't have general information about {medicine_name} yet. Please ask your doctor or pharmacist.",
    "medicine_general_info_not_found": "I don't have general information about that medicine yet. Please ask your doctor or pharmacist.",
}


def get_llm_provider(settings: Settings) -> LlmProvider:
    if settings.llm_provider == "mock":
        return MockLlmProvider()
    # A real provider (OpenAI/Anthropic/etc.) would be wired in here. Not implemented yet —
    # failing loudly is more honest than silently falling back to the mock.
    raise NotImplementedError(f"LLM provider '{settings.llm_provider}' is not implemented yet")
