# Voice-First Elderly Care & Safety Platform

A voice-first, accessibility-focused app for elderly users and their caregivers: spoken medicine reminders,
an AI medicine assistant, caregiver insights, cognitive games, emergency SOS and voice calling.

**Status: Phase 12 (production-readiness; all 12 planned phases complete).** Auth/roles/family
linking (Phase 2), medicines/schedules/adherence/reminders
(Phase 3), a full elderly-friendly Flutter UI (Phase 4), and four real on-device cognitive games
with deterministic difficulty suggestions plus non-invasive activity tracking (Phase 5). Phase 6
added Emergency SOS: an idempotent, deterministic SOS trigger, caregiver notification and
acknowledge/resolve, and emergency contacts the elder's device can call directly — the backend
never calls a number itself, only notifies registered caregivers. Phase 7 added the voice layer:
on-device speech-to-text/text-to-speech, deterministic (non-LLM) intent matching in English and a
starter Hindi pack, and a voice assistant screen that can answer medicine/activity questions, call
an emergency contact, or open (never auto-fire) the SOS confirm screen. Phase 8 brought the Python
`agentic-ai` service to life: a real orchestrator routes to a medicine agent and a caregiver-insight
agent, each grounded only in structured data fetched from Node over an internal-key-protected API.
Phase 9 adds RAG: the medicine agent can now also answer general medicine questions — what a drug
is for, its side effects, warnings — grounded in a small curated knowledge base (chunking, a
lexical embedding provider, and a swappable in-memory vector store), separate from and never
blended with an elder's personal data. Python still holds no database credentials and can trigger
no real-world action, only answer questions and summarize. Phase 10 adds the real caregiver
dashboard: one call (`GET /api/family/dashboard`) returns adherence/activity/emergency status for
every linked elder, a per-elder adherence trend chart, a Notifications tab for missed-dose alerts,
and a per-caregiver mute toggle for them — all deterministic aggregation of data earlier phases
already compute, no new AI involved. Phase 11 is a hardening/testing pass, not new features: an
audit of every endpoint's authorization (plus new regression tests for the gaps it found — a
stricter login/register rate limit, and missing elder-vs-elder negative tests), prompt/tool-abuse
regression tests for the agentic-ai service, and the Flutter app's first offline/weak-network
support (connectivity detection, a cached today's-schedule fallback, a small safe-to-retry sync
queue, and an emergency screen that fails loud rather than quiet when it can't reach the server).
Phase 12 is deployment preparation, not new features or architecture changes: a standalone
production Docker Compose file (`docker-compose.prod.yml` — no dev defaults, no exposed internal
ports, `restart: unless-stopped`), a CI pipeline (`.github/workflows/ci.yml`) that runs all three
test suites and fails on any failure, `.dockerignore` files for both containers, backend request
timeouts, a Flutter release build that now fails loudly instead of silently defaulting to a
development API URL, and a documented (not automated) PostgreSQL backup procedure. See
[docs/architecture.md](docs/architecture.md), [docs/ai-architecture.md](docs/ai-architecture.md)
and [docs/setup.md](docs/setup.md#production-deployment-phase-12) for the full production checklist.

| Part | Tech | Role |
|---|---|---|
| [frontend/elderly_care_app](frontend/elderly_care_app) | Flutter, Riverpod, go_router | User experience |
| [backend](backend) | Node.js, TypeScript, Express, Prisma | Application backend, business logic, all DB access |
| [agentic-ai](agentic-ai) | Python, FastAPI | Agents, tools, RAG, LLM (called only by Node) |
| PostgreSQL | via Docker | Application data |

## Quick start

```bash
cp .env.example .env
docker compose up --build        # postgres + backend (:4000) + agentic-ai (:8000)
curl localhost:4000/health/dependencies
```

Without Docker, per-service instructions, and **production deployment**:
[docs/setup.md](docs/setup.md#production-deployment-phase-12) (`docker compose -f docker-compose.prod.yml up -d --build`).

## Docs

[Architecture](docs/architecture.md) · [Setup](docs/setup.md) · [API](docs/api.md) · [Database](docs/database.md) · [AI architecture](docs/ai-architecture.md)
