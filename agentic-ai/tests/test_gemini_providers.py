import httpx
import pytest

from app.config import Settings
from app.llm.provider import GeminiLlmProvider, MockLlmProvider, get_llm_provider

def _settings(**overrides) -> Settings:
    # _env_file=None: never read the developer's real .env.
    return Settings(_env_file=None, **overrides)


class _FakeResponse:
    def __init__(self, payload: dict, status_code: int = 200):
        self._payload = payload
        self.status_code = status_code

    def raise_for_status(self) -> None:
        if self.status_code >= 400:
            raise httpx.HTTPStatusError("error", request=httpx.Request("POST", "http://x"), response=self)  # type: ignore[arg-type]

    def json(self) -> dict:
        return self._payload


# --- LLM provider ---------------------------------------------------------------------------


def test_llm_selection_mock_gemini_and_missing_key() -> None:
    assert isinstance(get_llm_provider(_settings(llm_provider="mock")), MockLlmProvider)
    assert isinstance(get_llm_provider(_settings(llm_provider="gemini", llm_api_key="k")), GeminiLlmProvider)
    with pytest.raises(ValueError):
        get_llm_provider(_settings(llm_provider="gemini", llm_api_key=""))
    with pytest.raises(NotImplementedError):
        get_llm_provider(_settings(llm_provider="other", llm_api_key="k"))


def test_gemini_llm_uses_configured_model_and_header_key(monkeypatch) -> None:
    captured: dict = {}

    def fake_post(url, headers, json, timeout):
        captured.update(url=url, headers=headers, json=json)
        return _FakeResponse({"candidates": [{"content": {"parts": [{"text": " You take 2 medicines. "}]}}]})

    monkeypatch.setattr(httpx, "post", fake_post)
    provider = get_llm_provider(_settings(llm_provider="gemini", llm_api_key="secret", llm_model="my-model"))
    text = provider.compose("medicine_list", count=2, medicines_list="A, B")

    assert text == "You take 2 medicines."
    assert "my-model:generateContent" in captured["url"]
    assert "secret" not in captured["url"]
    assert captured["headers"]["x-goog-api-key"] == "secret"
    # Gemini is only handed the already-grounded sentence.
    assert captured["json"]["contents"][0]["parts"][0]["text"] == "You take 2 medicine(s): A, B."


@pytest.mark.parametrize(
    "outcome",
    [httpx.ConnectTimeout("t"), _FakeResponse({}, status_code=500), _FakeResponse({"candidates": []}), _FakeResponse({"candidates": [{"content": {"parts": [{"text": "  "}]}}]})],
)
def test_gemini_llm_falls_back_to_grounded_template(monkeypatch, outcome) -> None:
    def fake_post(*args, **kwargs):
        if isinstance(outcome, Exception):
            raise outcome
        return outcome

    monkeypatch.setattr(httpx, "post", fake_post)
    text = GeminiLlmProvider("k", "m").compose("medicine_list", count=1, medicines_list="A")
    assert text == "You take 1 medicine(s): A."
