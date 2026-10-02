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
- `rag/chunking.py`: one chunk per section (`uses`/`side_effects`/`warnings`) rather than per
  medicine, so retrieval can tell "what is it for" apart from "what are the side effects" instead
  of always returning the whole entry.
- `embeddings/provider.py`: `EmbeddingProvider` abstraction; `TfEmbeddingProvider` (the real
  default, `EMBEDDING_PROVIDER=mock`) is deterministic, stopword-filtered term-frequency vectors
  over the corpus vocabulary — labelled as a lexical retriever, not dressed up as a trained
  semantic model, the same honesty `MockLlmProvider` already follows. For disambiguating which
  section of a short entry answers a question, keyword overlap is the right tool, not a limitation.
- `rag/vector_store.py`: `VectorStore` abstraction; `InMemoryVectorStore` does cosine-similarity
  search over the (small, static) chunk set. A production-scale deployment could swap in a real
  vector database (`settings.vector_db_url`, still unused) behind the same interface.
- `rag/ingest.py` / `rag/retriever.py`: ingestion (load -> chunk -> embed -> index) runs once per
  process (`api/deps.py`), not per-request. `MedicineKnowledgeRetriever.find_mentioned_medicine`
  matches a name or alias in the query; `.retrieve()` then searches only that medicine's chunks and
  falls back to its `uses` chunk if nothing scores above zero (e.g. "tell me about metformin" with
  no section-specific words).
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
