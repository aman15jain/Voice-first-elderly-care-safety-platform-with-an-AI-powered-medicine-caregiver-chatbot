from langchain_core.embeddings import Embeddings
from langchain_google_genai import GoogleGenerativeAIEmbeddings

from app.config import Settings


class EmbeddingConfigError(ValueError):
    """The configured embedding provider can't be built (unknown provider or missing key)."""


def get_embeddings(settings: Settings) -> Embeddings:
    """The one embedding model for the whole RAG pipeline: LangChain's Gemini integration, used for
    both document vectors (`embed_documents`, at ingestion) and query vectors (`embed_query`, at
    retrieval) so they always live in the same vector space.

    There is deliberately no local/lexical fallback: lexical and semantic vectors (or vectors from
    two different models) must never share one index, so a misconfiguration fails loudly."""
    if settings.embedding_provider != "gemini":
        raise EmbeddingConfigError(
            f"EMBEDDING_PROVIDER must be 'gemini' (got '{settings.embedding_provider}'); no other embedding provider is supported"
        )
    if not settings.embedding_api_key:
        raise EmbeddingConfigError("EMBEDDING_PROVIDER=gemini requires EMBEDDING_API_KEY to be set")
    return GoogleGenerativeAIEmbeddings(model=settings.embedding_model, google_api_key=settings.embedding_api_key)
