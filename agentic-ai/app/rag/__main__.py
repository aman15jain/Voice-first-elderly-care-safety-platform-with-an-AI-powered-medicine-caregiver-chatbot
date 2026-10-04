"""`python -m app.rag` — sync data/medicines/knowledge_base.json into Supabase pgvector.

Idempotent: unchanged chunks are not re-embedded, so it is safe to run as often as you like."""
from app.config import get_settings
from app.embeddings.provider import get_embeddings
from app.rag.ingest import ingest_knowledge_base, load_medicine_entries
from app.rag.vector_store import KnowledgeVectorStore, create_pgvector_store


def main() -> None:
    settings = get_settings()
    store = KnowledgeVectorStore(create_pgvector_store(settings, get_embeddings(settings)))
    report = ingest_knowledge_base(store, load_medicine_entries(), settings.embedding_model)
    print(
        f"added={report.added} updated={report.updated} unchanged={report.unchanged} "
        f"removed={report.removed} (embedding calls for {report.embedded} chunk(s))"
    )


if __name__ == "__main__":
    main()
