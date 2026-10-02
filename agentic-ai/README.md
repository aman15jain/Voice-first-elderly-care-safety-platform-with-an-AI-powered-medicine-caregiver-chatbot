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

## Test

```bash
pytest
```

## Layout

`app/agents`, `app/tools`, `app/llm`, `app/rag`, `app/embeddings` and `app/api/agents.py` are all
real: an orchestrator routes to a medicine agent and a caregiver-insight agent. The medicine agent
answers both an elder's own medicine/adherence questions (Phase 8, grounded in data fetched from
Node via `app/tools/node_client.py`) and general medicine questions (Phase 9, grounded in RAG over
`data/medicines/knowledge_base.json`) — see [docs/ai-architecture.md](../docs/ai-architecture.md).
`app/voice`, `app/services` remain empty placeholders — no further phases plan to use them.
