from app.tools.node_client import NodeApiClient


class CaregiverInsightContextTool:
    """One of the fixed tools an agent may call. Returns adherence, activity and active-emergency
    status for one elder — structured facts only, never free text a caregiver could mistake for
    something the elder said."""

    name = "get_caregiver_insight_context"

    def __init__(self, node_client: NodeApiClient):
        self._node_client = node_client

    async def run(self, elder_id: str) -> dict:
        return await self._node_client.get_caregiver_insight_context(elder_id)
