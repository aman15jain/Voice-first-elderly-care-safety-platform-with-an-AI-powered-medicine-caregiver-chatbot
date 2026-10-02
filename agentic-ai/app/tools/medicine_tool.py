from app.tools.node_client import NodeApiClient


class MedicineContextTool:
    """One of the fixed tools an agent may call — never a free-form DB/HTTP call the LLM invents.
    Returns the elder's own medicines and 30-day adherence summary, nothing else."""

    name = "get_medicine_context"

    def __init__(self, node_client: NodeApiClient):
        self._node_client = node_client

    async def run(self, elder_id: str) -> dict:
        return await self._node_client.get_medicine_context(elder_id)
