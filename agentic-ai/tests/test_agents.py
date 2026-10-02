from fastapi.testclient import TestClient

from app.api.deps import get_node_client
from app.main import app

client = TestClient(app)


class FakeNodeApiClient:
    """Stands in for the real NodeApiClient — no HTTP call ever leaves the process in these tests."""

    def __init__(self):
        self.medicine_context: dict = {
            "medicines": [{"name": "Metformin", "dosage": "500mg", "instructions": None}],
            "adherence": {"taken": 8, "totalDue": 10, "takenRate": 80},
        }
        self.caregiver_insight_context: dict = {
            "adherence": {"taken": 8, "totalDue": 10, "takenRate": 80},
            "activity": {"daysInRange": 7, "activeDays": 5, "medicineInteractionDays": 5, "gameSessionDays": 2},
            "activeEmergency": False,
        }

    async def get_medicine_context(self, elder_id: str) -> dict:
        return self.medicine_context

    async def get_caregiver_insight_context(self, elder_id: str) -> dict:
        return self.caregiver_insight_context


def _override_node_client(fake: FakeNodeApiClient) -> None:
    app.dependency_overrides[get_node_client] = lambda: fake


def teardown_function() -> None:
    app.dependency_overrides.clear()


def test_medicine_query_lists_medicines() -> None:
    fake = FakeNodeApiClient()
    _override_node_client(fake)

    res = client.post("/agents/respond", json={"elder_id": "e1", "mode": "medicine_query", "query": "what medicine do I take"})
    assert res.status_code == 200
    body = res.json()
    assert body["type"] == "information"
    assert "Metformin" in body["response"]
    assert body["sources"] == ["medicines"]
    assert body["action"] is None


def test_medicine_query_about_adherence_uses_adherence_summary() -> None:
    fake = FakeNodeApiClient()
    _override_node_client(fake)

    res = client.post("/agents/respond", json={"elder_id": "e1", "mode": "medicine_query", "query": "have I taken my medicine today"})
    assert res.status_code == 200
    body = res.json()
    assert "8" in body["response"] and "10" in body["response"]
    assert body["sources"] == ["adherence_summary"]


def test_medicine_query_with_no_medicines_says_so() -> None:
    fake = FakeNodeApiClient()
    fake.medicine_context = {"medicines": [], "adherence": {"taken": 0, "totalDue": 0, "takenRate": None}}
    _override_node_client(fake)

    res = client.post("/agents/respond", json={"elder_id": "e1", "mode": "medicine_query", "query": "what medicine do I take"})
    assert res.status_code == 200
    body = res.json()
    assert "don't have any medicines" in body["response"]
    assert body["sources"] == []


def test_general_medicine_question_is_grounded_in_the_knowledge_base_not_personal_data() -> None:
    # The elder's own medicines don't include aspirin at all — proves this answer came from the
    # Phase 9 knowledge base, not from MedicineContextTool.
    fake = FakeNodeApiClient()
    fake.medicine_context = {"medicines": [{"name": "Metformin", "dosage": "500mg", "instructions": None}], "adherence": {}}
    _override_node_client(fake)

    res = client.post("/agents/respond", json={"elder_id": "e1", "mode": "medicine_query", "query": "what are the side effects of aspirin"})
    assert res.status_code == 200
    body = res.json()
    assert "stomach" in body["response"].lower() or "bruis" in body["response"].lower()
    assert "not medical advice" in body["response"]
    assert body["sources"] == ["knowledge_base:aspirin:side_effects"]


def test_general_medicine_question_about_an_unknown_medicine_says_so() -> None:
    fake = FakeNodeApiClient()
    _override_node_client(fake)

    res = client.post("/agents/respond", json={"elder_id": "e1", "mode": "medicine_query", "query": "what is ibuprofen used for"})
    assert res.status_code == 200
    body = res.json()
    assert "don't have general information" in body["response"]
    assert body["sources"] == []


def test_caregiver_insight_summarizes_adherence_and_activity() -> None:
    fake = FakeNodeApiClient()
    _override_node_client(fake)

    res = client.post("/agents/respond", json={"elder_id": "e1", "mode": "caregiver_insight", "language": "en"})
    assert res.status_code == 200
    body = res.json()
    assert "80%" in body["response"]
    assert "5" in body["response"]
    assert body["sources"] == ["adherence_summary", "activity_summary"]


def test_caregiver_insight_leads_with_active_emergency() -> None:
    fake = FakeNodeApiClient()
    fake.caregiver_insight_context["activeEmergency"] = True
    _override_node_client(fake)

    res = client.post("/agents/respond", json={"elder_id": "e1", "mode": "caregiver_insight"})
    assert res.status_code == 200
    body = res.json()
    assert "active emergency" in body["response"]
    assert "emergency_status" in body["sources"]


def test_tool_error_is_handled_gracefully() -> None:
    class FailingNodeApiClient:
        async def get_medicine_context(self, elder_id: str) -> dict:
            from app.tools.node_client import ToolError

            raise ToolError("backend down")

    _override_node_client(FailingNodeApiClient())

    res = client.post("/agents/respond", json={"elder_id": "e1", "mode": "medicine_query", "query": "what medicine do I take"})
    assert res.status_code == 200
    body = res.json()
    assert "couldn't retrieve" in body["response"]
    assert body["sources"] == []
