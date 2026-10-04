# AI architecture

Status: **Phase 11.** `agents/`, `tools/`, `llm/`, `rag/`, `embeddings/` and `api/agents.py` are all
real and tested. An orchestrator routes to a medicine agent and a caregiver-insight agent; the
medicine agent now answers both an elder's own medicine/adherence questions (Phase 8, grounded in
Node) and general medicine questions — what a drug is for, its side effects, warnings — grounded
in a small curated knowledge base (Phase 9, RAG over `data/medicines/knowledge_base.json`). Voice-
command intent routing stays in Node (`backend/src/modules/voice`, Phase 7) — it is deliberately
deterministic and does not call this service. Phase 11 re-verified (and added regression tests
for) every safety guarantee below rather than changing the architecture — see
`agentic-ai/tests/test_prompt_injection.py` and docs/architecture.md's Security section.

## Prompt/tool-abuse resistance (Phase 11)

- A query's free text cannot redirect which elder is looked up — `elder_id` for every tool call
  comes only from the request's validated `elder_id` field, never parsed out of `query`. Tested
  directly: a query containing `"elder_id=some-other-elder-999"` still only ever looks up the
  elder actually authenticated.
- A query cannot talk the agent into emitting an `action` — `AgentResponse.action` is typed `None`
  (not `Optional[Action]`), so there's no code path where it could be anything else, regardless of
  what the query text asks for.
- `caregiver_insight` mode never accepts a `query` field in the first place — supplying one (as an
  injection attempt) is simply ignored.
- A request without the internal API key is rejected by a router-level dependency before any
  agent or tool code runs at all — confirmed by asserting the (fake) data layer is never called.

## Design (Phase 8 — agents, tools, orchestrator)

- `agents/`: `Orchestrator` (routes a request to exactly one agent — no logic of its own),
  `MedicineAgent` (answers an elder's own medicine/adherence questions, plus general medicine
  questions via RAG — see below), `CaregiverInsightAgent` (summarizes an elder's adherence/activity
  for a linked caregiver). Neither agent can call the other, and neither can produce an `action` —
  both are read-only/informational.
- `tools/`: an explicit, fixed set — `MedicineContextTool`, `CaregiverInsightContextTool` — each a
  thin wrapper around `NodeApiClient`, the *only* way any agent reaches application data. Nothing
  in `agents/` makes an HTTP or DB call directly.
- `llm/`: `LlmProvider` abstraction; `MockLlmProvider` (the real default, `LLM_PROVIDER=mock`) composes
  responses by filling named templates with the exact fields a tool or the retriever returned —
  never free-form generation, so grounding is structural, not a prompting convention. A real
  model-backed provider can be added later behind the same `compose()` interface.

## Design (Phase 9 — RAG, embeddings)

- `data/medicines/knowledge_base.json`: a small, curated starter set (8 common medicines) with
  `uses`/`side_effects`/`warnings` text per medicine. This is general public medicine information,
  not personal data — unlike the Phase 8 tools, it isn't scoped to one elder.
- **LangChain** orchestrates the RAG pipeline; **Gemini** provides both the embeddings
  (`gemini-embedding-001`, 3072 dimensions) and the answer model (`LLM_MODEL`); **Supabase
  PostgreSQL + pgvector** stores the vectors and performs the similarity search.
- `rag/chunking.py`: knowledge entries -> LangChain `Document`s, one per section
  (`uses`/`side_effects`/`warnings`) so retrieval can tell "what is it for" apart from "what are the
  side effects", then `RecursiveCharacterTextSplitter`. Every chunk carries `medicine_id`,
  `medicine_name`, `section`, `source`, `chunk_index`, a stable id (`medicine:section:index`) and a
  content hash (text + embedding model).
- `embeddings/provider.py`: `get_embeddings()` returns LangChain's `GoogleGenerativeAIEmbeddings`.
  The same object embeds documents at ingestion and queries at retrieval. There is **no local or
  lexical fallback** — a missing key or non-Gemini provider raises, because two embedding spaces
  must never share an index.
- `rag/vector_store.py`: `PGVector` (`langchain-postgres`) over the **same Supabase database the Node
  backend uses** (`VECTOR_DB_URL`, the unpooled/session-mode connection string). Vectors live in
  LangChain's own `langchain_pg_collection` / `langchain_pg_embedding` tables; Prisma-owned
  application tables are never read or written. `KnowledgeVectorStore` is the narrow wrapper the
  rest of the code uses.
- `rag/ingest.py` (`python -m app.rag`): idempotent sync. New chunk -> embed + insert; changed text
  or changed embedding model -> re-embed + update; unchanged -> skipped (zero Gemini calls); removed
  from the JSON -> deleted. So a restart re-embeds nothing.
- `rag/retriever.py` / `rag/chain.py`: the LangChain retriever (`as_retriever`, cosine similarity,
  filtered to the one medicine named in the question) feeds an LCEL chain
  `retriever -> prompt -> ChatGoogleGenerativeAI -> answer`. The model only words an answer from
  the retrieved chunks. If the chat model fails, the retrieved text itself is returned; if
  embedding/vector search fails, `RagUnavailableError` is raised and the agent says it can't look
  that up right now — it never answers from a different retrieval method. The "not medical advice"
  disclaimer is appended deterministically, not by the model.
- The store connects and syncs lazily on the first general-medicine question, so personal-data
  questions never depend on Gemini or the vector database.
- **The medicine agent only answers from the knowledge base when it both recognizes a general-info
  question (`what is`/`side effect`/`used for`/...) and a medicine name the knowledge base covers.**
  An unrecognized medicine gets an honest "I don't have general information about that medicine
  yet" rather than a guess — rule 1 (grounded in retrieved sources; say so when nothing is found)
  applies here exactly as it does to Phase 8's personal-data answers.

## Rules

1. Medicine answers must be grounded in retrieved sources; say so when nothing is found.
2. Caregiver summaries use only structured data fetched from Node.
3. Missed doses, adherence and SOS are deterministic backend logic, never LLM decisions.
4. Python holds no application DB credentials; it calls scoped internal Node APIs.
5. All internal calls carry `x-internal-api-key`.

## Response contract

```json
{ "success": true, "type": "information|action", "response": "...", "language": "en", "sources": [], "action": null }
```

## Production exposure (Phase 12)

This service must never be reachable from the public internet — only the Node backend, over an
internal network, authenticated by `x-internal-api-key` (rule 5 above). `docker-compose.prod.yml`
enforces this concretely: `agentic-ai` publishes no host port at all, unlike the dev
`docker-compose.yml` which exposes `8000` for local debugging convenience. See
[docs/setup.md](setup.md#production-deployment-phase-12).
