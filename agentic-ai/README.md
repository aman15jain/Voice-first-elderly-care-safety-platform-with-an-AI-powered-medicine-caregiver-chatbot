# agentic-ai

Python/FastAPI service for agents, tools, RAG and LLM access. Called only by the Node backend.

## Run standalone

```bash
python -m venv .venv
.venv\Scripts\activate          # Windows  (source .venv/bin/activate on macOS/Linux)
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --port 8000
```

Check: `GET http://localhost:8000/health` and `http://localhost:8000/docs`.

## RAG setup (LangChain + Gemini + Supabase pgvector)

General medicine questions use RAG over `data/medicines/knowledge_base.json`:

```
knowledge_base.json -> LangChain Documents -> text splitter -> Gemini embeddings -> Supabase pgvector
question -> Gemini query embedding -> pgvector cosine search -> top-K Documents -> Gemini chat model -> answer
```

- LangChain orchestrates; Gemini makes the vectors and the final answer; Supabase PostgreSQL +
  pgvector stores and searches them. One Gemini key can serve both embeddings and the LLM.
- The vectors live in the **same Supabase project** as the Node/Prisma application data, but in
  separate tables (`langchain_pg_collection`, `langchain_pg_embedding`). Python never reads
  application tables.

Environment (`.env`, never committed):

```
LLM_PROVIDER=gemini
LLM_API_KEY=<gemini key>
LLM_MODEL=gemini-flash-lite-latest
EMBEDDING_PROVIDER=gemini
EMBEDDING_API_KEY=<gemini key>
EMBEDDING_MODEL=gemini-embedding-001
VECTOR_DB_URL=postgresql+psycopg://<user>:<password>@<host>:5432/postgres   # same as backend DIRECT_URL
```

`VECTOR_DB_URL` must be the unpooled / session-mode Supabase connection (the backend's
`DIRECT_URL`), not the pgbouncer transaction pooler.

Ingest (idempotent; also happens automatically on the first general-medicine question):

```bash
python -m app.rag      # unchanged chunks are not re-embedded
```

## Test

```bash
pytest        # hermetic: fake embeddings + in-memory store, no Gemini/Supabase needed
```

## Layout

`app/agents`, `app/tools`, `app/llm`, `app/rag`, `app/embeddings` and `app/api/agents.py` are all
real: an orchestrator routes to a medicine agent and a caregiver-insight agent. The medicine agent
answers both an elder's own medicine/adherence questions (Phase 8, grounded in data fetched from
Node via `app/tools/node_client.py`) and general medicine questions (Phase 9, grounded in RAG over
`data/medicines/knowledge_base.json`) — see [docs/ai-architecture.md](../docs/ai-architecture.md).
`app/voice`, `app/services` remain empty placeholders — no further phases plan to use them.
