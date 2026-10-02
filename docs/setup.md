# Setup

Prerequisites: Node 20+, Python 3.11+, Flutter 3.x, PostgreSQL 16 (or Docker).

## Option A: Docker (backend + AI + Postgres)

```bash
cp .env.example .env
docker compose up --build
```

The backend applies Prisma migrations on start. Check `http://localhost:4000/health/dependencies`.

## Option B: run each service locally

**PostgreSQL**: create a database and user, or run only the DB: `docker compose up postgres`.

**AI service**
```bash
cd agentic-ai
python -m venv .venv && .venv\Scripts\activate     # source .venv/bin/activate on macOS/Linux
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --port 8000
pytest
```

**Backend**
```bash
cd backend
cp .env.example .env          # set DATABASE_URL, AI_SERVICE_URL
npm install
npx prisma generate
npx prisma migrate deploy     # or `npm run prisma:migrate` in development
npm run dev                   # http://localhost:4000
npm test
```

**Flutter**
```bash
cd frontend/elderly_care_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<host-ip>:4000
flutter test
```
Defaults: Android emulator `http://10.0.2.2:4000`, others `http://localhost:4000`. A physical phone needs your
computer's LAN IP. Plain HTTP is allowed in **debug builds only**.

The app supports Android, iOS and web targets (`-d chrome` / `-d web-server`) for development —
`CORS_ORIGINS` on the backend must include the web dev server's origin. Auth tokens are stored via
`flutter_secure_storage` (Keystore/Keychain on mobile; also works on web/desktop for development).
Register an elder or caregiver account from the app's own "Create an account" flow — there's no
seed data.

## Environment variables

| Variable | Service | Purpose |
|---|---|---|
| NODE_ENV | backend | `development`/`test`/`production` (default `development`) |
| DATABASE_URL | backend | Postgres connection string |
| PORT, LOG_LEVEL, CORS_ORIGINS | backend | server settings |
| AI_SERVICE_URL, AI_SERVICE_TIMEOUT_MS | backend | where the Python service is |
| AI_SERVICE_API_KEY / INTERNAL_API_KEY | backend / agentic-ai | shared internal secret (same value) |
| JWT_SECRET | backend | signs access tokens |
| JWT_REFRESH_SECRET | backend | pepper mixed into hashed refresh tokens |
| ACCESS_TOKEN_TTL_SECONDS, REFRESH_TOKEN_TTL_DAYS | backend | session lifetimes (defaults: 900s / 30d) |
| DOSE_GENERATION_DAYS_AHEAD | backend | how many days of doses to generate ahead (default 2) |
| MISSED_DOSE_GRACE_MINUTES | backend | grace period before an unconfirmed dose is marked missed (default 60) |
| REMINDER_SWEEP_INTERVAL_MINUTES | backend | how often the reminder engine runs (default 15) |
| LLM_PROVIDER, LLM_API_KEY, EMBEDDING_PROVIDER, EMBEDDING_API_KEY, VECTOR_DB_URL | agentic-ai | used from Phases 8-9 (`*_PROVIDER` default to `mock`, the real default — see docs/ai-architecture.md) |
| NODE_API_BASE_URL, NODE_API_TIMEOUT_SECONDS | agentic-ai | where to reach the Node backend's `/internal/*` endpoints (Phase 8) |
| APP_ENV, LOG_LEVEL, HOST, PORT | agentic-ai | server settings (defaults: `development`, `INFO`, `0.0.0.0`, `8000`) |

Real secrets go in untracked `.env` files only — never commit a filled-in `.env`; only `.env.example` files (with placeholder values) are tracked.

## Security (Phase 11)

- **Auth brute-force protection**: `POST /api/auth/login` and `/register` have their own stricter
  rate limit (10 requests / 15 min per client, on top of the global 300/min limiter) — see
  `common/middleware/authRateLimit.ts`.
- **CORS is closed by default.** Set `CORS_ORIGINS` (comma-separated) to the exact origins allowed
  to call the backend from a browser; an empty value blocks all cross-origin requests.
- **Secrets are environment-only**, validated at startup by `config/env.ts` (zod) — a missing or
  too-short `JWT_SECRET`/`JWT_REFRESH_SECRET` fails fast rather than running insecurely. Nothing
  reads a secret from a committed file or a hardcoded fallback.
- **Logs never contain secrets.** `config/logger.ts` redacts `req.headers.authorization`,
  `req.headers.cookie`, and any `password`/`token`/`refreshToken` field at any depth; every request
  is logged once with `requestId`, `method`, `endpoint`, `status` and `durationMs`
  (`common/middleware/requestContext.ts`) without ever logging the request body.
- See [docs/architecture.md](architecture.md#security--authorization-phase-11) for the full
  authorization model (who can reach what, and how it's enforced/tested).

## Testing

```bash
cd backend && npm test          # 146 tests — unit + HTTP integration, in-memory fakes, no DB needed
cd agentic-ai && pytest         # 23 tests — FastAPI TestClient, fake Node client, no network
cd frontend/elderly_care_app && flutter test   # 62 tests — widget/provider tests, fake repositories
```
All three suites are fully self-contained (no live backend/DB/network required) and are the
baseline that must stay green — see docs/architecture.md for what each new Phase 11 test covers.

## Production Deployment (Phase 12)

This section is deployment *preparation*, not a claim that this project runs on any specific
host today — nothing here assumes a particular cloud provider.

### Prerequisites

- A PostgreSQL 16 server reachable from wherever the backend runs (managed or self-hosted —
  the dev `docker-compose.yml`'s Postgres container is a local convenience, not a production
  database service).
- A place to run two containers (backend, agentic-ai) — any Docker host, or run the two built
  images directly with `node dist/server.js` / `uvicorn app.main:app` behind a process manager.
- A reverse proxy / TLS terminator in front of the backend (nginx, Caddy, a managed load
  balancer, Cloudflare, ...) — **not included in this repo**. The backend itself serves plain
  HTTP; it never terminates TLS itself, the same way it never has in any earlier phase.
- Real values for every secret below — generate with e.g. `openssl rand -hex 32`.

### Environment variables

Same variables as development (see the table above) — production differs only in *values*, not
in which variables exist:

| Variable | Production requirement |
|---|---|
| `NODE_ENV` | `production` |
| `APP_ENV` (agentic-ai) | `production` |
| `JWT_SECRET`, `JWT_REFRESH_SECRET` | long random strings, never the `.env.example` placeholders |
| `AI_SERVICE_API_KEY` / `INTERNAL_API_KEY` | the same long random string in both services |
| `CORS_ORIGINS` | your real frontend origin(s) only — never empty, never `*`, never `localhost` |
| `DATABASE_URL` | your production Postgres connection string |
| `LLM_PROVIDER`, `EMBEDDING_PROVIDER` | stay `mock` unless a real provider is actually implemented — see docs/ai-architecture.md; setting one of these to anything else today fails deterministically (`NotImplementedError`) rather than silently doing nothing |

`docker-compose.prod.yml` (below) enforces the first five with Compose's `${VAR:?message}`
syntax — the stack refuses to start rather than running with an insecure default.

### PostgreSQL setup & migrations

```bash
# Apply migrations (never `migrate dev`, never `migrate reset`, in production):
cd backend
DATABASE_URL=<production-url> npx prisma migrate deploy
```
`migrate deploy` only applies already-committed migrations in order — it cannot generate a new
migration, drop data, or reset the database. There is no seed/demo-data command; the app has no
seed data by design (every account is created through its own register flow).

### Backend deployment

```bash
cd backend
npm ci --omit=dev
npx prisma generate
npm run build
NODE_ENV=production node dist/server.js
```
Or build/run `docker/backend.Dockerfile` directly. The container already runs `prisma migrate
deploy` before starting the server (see the Dockerfile's `CMD`) — this is safe to run on every
deploy since `migrate deploy` is a no-op when nothing's pending.

### Agentic-ai deployment

```bash
cd agentic-ai
pip install -r requirements.txt
APP_ENV=production uvicorn app.main:app --host 0.0.0.0 --port 8000
```
Or build/run `docker/agentic-ai.Dockerfile` directly. **Never expose this service's port to the
public internet** — only the Node backend should ever reach it, over the internal network (a
Docker network, a VPC, etc.), authenticated by the shared `x-internal-api-key`.

### Flutter release builds

```bash
cd frontend/elderly_care_app
flutter build apk --release --dart-define=API_BASE_URL=https://your-production-api.example.com
# or: flutter build ipa / flutter build web, same --dart-define
```
`AppConfig` (`lib/core/config/app_config.dart`) **throws at startup** if a release build has no
`API_BASE_URL` — this is deliberate: without it, a release build would otherwise silently fall
back to a development URL (`localhost`/`10.0.2.2`) and ship pointed at nothing real. Cleartext
HTTP (`usesCleartextTraffic`) is enabled only in the Android **debug** manifest
(`android/app/src/debug/AndroidManifest.xml`); a release build requires HTTPS.

### Docker (recommended for backend + agentic-ai + Postgres)

```bash
cp .env.example .env    # fill in real secrets — see "Environment variables" above
docker compose -f docker-compose.prod.yml up -d --build
```
Differences from the dev `docker-compose.yml`: `restart: unless-stopped` on every service,
`NODE_ENV`/`APP_ENV` fixed to `production`, Postgres and agentic-ai publish **no host port** (only
`backend`'s 4000 is reachable from outside the compose network — put your reverse proxy in front
of that), and every secret is required (`${VAR:?message}`) rather than defaulted.

### Health checks

- `GET /health` (both services) — liveness only, never touches a dependency, safe for a container
  orchestrator's liveness probe.
- `GET /health/dependencies` (backend only) — readiness: pings Postgres and the agentic-ai
  service, returns 503 if either is down. Use this for a readiness probe, not liveness (a
  transient AI-service blip shouldn't restart the backend container).
- Neither endpoint returns configuration, secrets, or internal error detail — just
  `{status, service, ...}`.

### CI/CD

`.github/workflows/ci.yml` runs on every push/PR: backend (install, typecheck, test, build),
agentic-ai (install, test), Flutter (pub get, analyze, test, a debug build to prove it compiles),
and a Prisma schema validation job. The pipeline fails if any test fails — there is no
"continue on error" anywhere in it.

### Backups

No automated backup system exists in this repo — that's an operational responsibility for
wherever Postgres actually runs (a managed Postgres service's built-in backups, or a cron'd
`pg_dump`), not something this application does for you. Recommended practice:

- **What to back up**: the Postgres database only (`pgdata`/`pgdata_prod` volume, or your managed
  instance's own backup mechanism). There is no other persistent store — Flutter has no server-side
  storage, agentic-ai holds no database credentials or state beyond its own small static knowledge
  base file (`data/medicines/knowledge_base.json`, checked into git, not user data).
- **Frequency**: at least daily for a low-write app like this one; more often if write volume
  grows. A point-in-time-recovery-capable managed Postgres service is the simplest way to get
  this without maintaining cron jobs.
- **Manual backup/restore**:
  ```bash
  pg_dump "$DATABASE_URL" -F c -f backup.dump
  pg_restore -d "$DATABASE_URL" --clean backup.dump
  ```
- **Migration precaution**: take a backup immediately before running `prisma migrate deploy`
  against production data, every time — a migration is not reversible by default, and none of
  this project's 6 migrations have been written with a tested down-migration.

### Security considerations (carried over from Phase 11, unchanged)

Re-verified during Phase 12, not re-implemented — see
[docs/architecture.md](architecture.md#security--authorization-phase-11) for the full model.
Nothing here was weakened.

### Known limitations

- **No local push notification scheduling for offline cached doses.** The elder-facing "Due"
  badge only works while the app is open; there is no background alarm for a dose while offline.
- **Access tokens are not independently revocable** before their 15-minute TTL expires, even
  after logout (only the refresh token is revoked).
- **Auth brute-force rate limiting is IP-keyed** (10 requests/15 min) — a shared IP/NAT could be
  over-throttled by one misbehaving client on the same network.

None of these changed in Phase 12 — they're restated here, not newly discovered.
