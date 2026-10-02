from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "development"
    log_level: str = "INFO"
    host: str = "0.0.0.0"
    port: int = 8000
    internal_api_key: str = ""

    llm_provider: str = "mock"
    llm_api_key: str = ""
    embedding_provider: str = "mock"
    embedding_api_key: str = ""
    vector_db_url: str = ""

    # Node is the only source of truth for application data; Python holds no DB credentials
    # and reaches it only through these scoped, internal-key-protected endpoints.
    node_api_base_url: str = "http://localhost:4000"
    node_api_timeout_seconds: float = 5.0


@lru_cache
def get_settings() -> Settings:
    return Settings()
