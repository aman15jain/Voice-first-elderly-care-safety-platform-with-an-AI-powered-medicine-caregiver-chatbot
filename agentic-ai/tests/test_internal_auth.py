from fastapi.testclient import TestClient

from app.api.deps import get_node_client
from app.config import Settings, get_settings
from app.main import app

client = TestClient(app)


class FakeNodeApiClient:
    async def get_medicine_context(self, elder_id: str) -> dict:
        return {"medicines": [], "adherence": {"taken": 0, "totalDue": 0, "takenRate": None}}

    async def get_caregiver_insight_context(self, elder_id: str) -> dict:
        return {"adherence": {}, "activity": {}, "activeEmergency": False}


def _settings_with_key() -> Settings:
    return Settings(internal_api_key="shared-secret")


def setup_function() -> None:
    app.dependency_overrides[get_node_client] = lambda: FakeNodeApiClient()
    app.dependency_overrides[get_settings] = _settings_with_key


def teardown_function() -> None:
    app.dependency_overrides.clear()


def test_missing_internal_api_key_is_rejected() -> None:
    res = client.post("/agents/respond", json={"elder_id": "e1", "mode": "caregiver_insight"})
    assert res.status_code == 401


def test_wrong_internal_api_key_is_rejected() -> None:
    res = client.post(
        "/agents/respond",
        json={"elder_id": "e1", "mode": "caregiver_insight"},
        headers={"x-internal-api-key": "wrong"},
    )
    assert res.status_code == 401


def test_correct_internal_api_key_is_accepted() -> None:
    res = client.post(
        "/agents/respond",
        json={"elder_id": "e1", "mode": "caregiver_insight"},
        headers={"x-internal-api-key": "shared-secret"},
    )
    assert res.status_code == 200
