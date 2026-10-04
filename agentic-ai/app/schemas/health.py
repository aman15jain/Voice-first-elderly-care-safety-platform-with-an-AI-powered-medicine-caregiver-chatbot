from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str
    # RAG knowledge-base readiness: ready / pending / failed / not_initialised. Informational only:
    # `status` stays "ok" so a slow or failed warm-up never takes the service out of rotation.
    knowledge_base: str = "not_initialised"
