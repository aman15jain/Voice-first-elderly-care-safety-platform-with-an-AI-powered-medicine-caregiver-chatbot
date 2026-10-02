import httpx


class ToolError(Exception):
    """Raised when Node's internal API can't be reached or returns an error. Agents catch this
    and produce an honest "I couldn't retrieve that" response rather than guessing."""


class NodeApiClient:
    """The *only* way any agent or tool reaches application data. Python never holds a database
    credential (docs/ai-architecture.md rule 4) — every fact an agent grounds its answer in came
    from here, and Node already authorized the caller before ever invoking Python."""

    def __init__(self, base_url: str, internal_api_key: str, timeout_seconds: float):
        self._base_url = base_url.rstrip("/")
        self._headers = {"x-internal-api-key": internal_api_key} if internal_api_key else {}
        self._timeout_seconds = timeout_seconds

    async def _get(self, path: str) -> dict:
        try:
            async with httpx.AsyncClient(base_url=self._base_url, timeout=self._timeout_seconds) as client:
                res = await client.get(path, headers=self._headers)
        except httpx.HTTPError as exc:
            raise ToolError(f"Could not reach the backend: {exc}") from exc
        if res.status_code != 200:
            raise ToolError(f"Backend returned {res.status_code} for {path}")
        return res.json()

    async def get_medicine_context(self, elder_id: str) -> dict:
        return await self._get(f"/internal/elders/{elder_id}/medicine-context")

    async def get_caregiver_insight_context(self, elder_id: str) -> dict:
        return await self._get(f"/internal/elders/{elder_id}/caregiver-insight-context")
