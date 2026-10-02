import math
import re
from abc import ABC, abstractmethod
from collections import Counter

from app.config import Settings

_TOKEN_RE = re.compile(r"[a-z0-9]+")

# Filtered out so lexical overlap reflects meaning, not grammar: without this, "what is the X
# for" and "what are the side effects of X" look similar purely because they share "the"/"of".
_STOPWORDS = frozenset(
    {
        "a", "about", "an", "and", "are", "as", "at", "be", "by", "do", "does", "for", "from",
        "has", "have", "i", "in", "is", "it", "me", "my", "of", "on", "or", "take", "tell", "that",
        "the", "this", "to", "used", "what", "when", "why", "with", "you",
    }
)


def _tokenize(text: str) -> list[str]:
    return [t for t in _TOKEN_RE.findall(text.lower()) if t not in _STOPWORDS]


class EmbeddingProvider(ABC):
    """Turns text into a sparse vector (term -> weight) for similarity search. Swappable later
    for a real semantic model without changing anything in `rag/`."""

    @abstractmethod
    def fit(self, corpus: list[str]) -> None:
        """Learn a vocabulary from the knowledge base corpus before embedding anything."""

    @abstractmethod
    def embed(self, text: str) -> dict[str, float]: ...


class TfEmbeddingProvider(EmbeddingProvider):
    """The real default (`EMBEDDING_PROVIDER=mock`, or no `EMBEDDING_API_KEY`): deterministic,
    normalized term-frequency vectors over the corpus vocabulary. This is honestly a lexical
    retriever, not a semantic one — it is named and documented as such rather than dressed up as
    a trained embedding model, matching how `MockLlmProvider` is labelled. For this knowledge
    base's purpose (picking which section of a short medicine entry answers a question) keyword
    overlap is the right tool, not a limitation to hide."""

    def __init__(self):
        self._vocabulary: set[str] = set()

    def fit(self, corpus: list[str]) -> None:
        for text in corpus:
            self._vocabulary.update(_tokenize(text))

    def embed(self, text: str) -> dict[str, float]:
        tokens = [t for t in _tokenize(text) if not self._vocabulary or t in self._vocabulary]
        counts = Counter(tokens)
        if not counts:
            return {}
        norm = math.sqrt(sum(v * v for v in counts.values()))
        return {term: count / norm for term, count in counts.items()}


def cosine_similarity(a: dict[str, float], b: dict[str, float]) -> float:
    if not a or not b:
        return 0.0
    common = set(a) & set(b)
    return sum(a[t] * b[t] for t in common)


def get_embedding_provider(settings: Settings) -> EmbeddingProvider:
    if settings.embedding_provider == "mock" or not settings.embedding_api_key:
        return TfEmbeddingProvider()
    # A real embedding API would be wired in here. Not implemented yet — failing loudly is more
    # honest than silently falling back to the lexical provider.
    raise NotImplementedError(f"Embedding provider '{settings.embedding_provider}' is not implemented yet")
