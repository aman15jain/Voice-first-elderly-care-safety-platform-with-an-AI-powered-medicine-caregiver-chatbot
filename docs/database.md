# Database

PostgreSQL accessed only by the Node backend through Prisma. Schema: [backend/prisma/schema.prisma](../backend/prisma/schema.prisma).
Migrations: `backend/prisma/migrations/` (committed).

## Phase 2: auth, roles, family

| Table | Purpose |
|---|---|
| `users` | One row per account. `role` (`ELDER`\|`CAREGIVER`\|`ADMIN`) is set at registration and only ever read back from a verified access token — never trusted from client input. |
| `elder_profiles` / `caregiver_profiles` | 1:1 with `users`, created in the same transaction as the user. `caregiver_profiles.notify_on_missed_dose` (Phase 10, default `true`) lets a caregiver mute missed-dose `Notification` rows without touching the `family_links` row that grants access. |
| `family_links` | The only place caregiver-to-elder permission is granted. `status`: `PENDING` → `ACCEPTED`/`DECLINED`, either party can move an active link to `REVOKED`. Unique on `(elder_id, caregiver_id)`; a revoked/declined row is reused (revived to `PENDING`) rather than duplicated. |
| `refresh_tokens` | Opaque tokens are never stored raw — only `sha256(pepper + token)`. Rotated on every `/api/auth/refresh` call; reuse of an already-rotated token is rejected. |
| `audit_logs` | Append-only. One row per sensitive action (register, login, login failure, logout, refresh, family link invite/accept/decline/revoke). `actor_id` is nullable (`ON DELETE SET NULL`) so history survives account deletion. |

## Phase 3: medicines, reminders, adherence, notifications

| Table | Purpose |
|---|---|
| `medicines` | One row per medicine an elder takes. `DELETE /api/medicines/:id` is a **soft delete** (`is_active=false`, cascaded to its schedules) — past doses and adherence history are never destroyed. |
| `medicine_schedules` | When a medicine is due: `times_of_day` (`"HH:mm"`, UTC — see architecture.md), `days_of_week` (empty = every day), `start_date`/`end_date`. `elder_id` is denormalized from `medicines.elder_id` so dose queries and authorization checks never need to join through `medicines`. |
| `medicine_doses` | One row per concrete due occurrence, generated from a schedule. This row *is* the adherence record: `status` (`SCHEDULED`→`REMINDED`→`TAKEN`\|`SKIPPED`\|`MISSED`) plus `reminded_at`/`responded_at`/`missed_at`. Unique on `(schedule_id, scheduled_for)` — generation is safe to re-run. There is deliberately no separate "adherence" table; `GET /api/adherence/summary` computes stats live from these rows (small per-elder volume, always consistent, one source of truth). |
| `notifications` | In-app only (no push/SMS provider configured). Currently produced only by the missed-dose sweep. |

## Phase 5: cognitive games, activity

| Table | Purpose |
|---|---|
| `cognitive_games` | The four built-in games (spec section 17), **seeded by the migration itself** with stable, hardcoded ids — not created through the API. |
| `game_sessions` | One row per played round, posted by the client after the fact: `difficulty` (1-3), `score`, `mistakes`, `duration_seconds`, `completed`. The game logic runs entirely on-device; this table only records outcomes. |
| `activity_events` | Deliberately minimal — currently only `APP_OPENED`, one per elder per day. Everything else in `GET /api/activity/summary` is derived from `medicine_doses.responded_at` and `game_sessions.created_at`, which are already recorded for their own purposes; see docs/architecture.md for why this isn't a fuller event log. |

## Phase 6: emergency SOS

| Table | Purpose |
|---|---|
| `emergency_contacts` | Name + phone number, **not** necessarily a registered user — deliberately separate from `family_links`. `priority` orders who to call first; the backend never calls these numbers itself (see docs/architecture.md). |
| `emergency_events` | One row per SOS press. `status`: `ACTIVE` → `ACKNOWLEDGED` (a linked caregiver, via `acknowledged_by`) → `RESOLVED` (the elder or a linked caregiver, via `resolved_by`). Location (`latitude`/`longitude`) is captured once at trigger time, not tracked continuously. A new SOS press while one is already `ACTIVE`/`ACKNOWLEDGED` returns that same row rather than creating a duplicate. |

## Phase 7: voice layer

| Table | Purpose |
|---|---|
| `voice_interactions` | One row per processed voice command: `transcript`, `language`, `intent_type` — never audio (see docs/architecture.md). `intent_type` is the deterministic matcher's output (`MEDICINE_STATUS`, `MEDICINE_INFO`, `ACTIVITY_STATUS`, `CALL_CONTACT`, `EMERGENCY_SOS`, `UNKNOWN`), not an LLM decision. |

Agentic-AI entities (agents, tools, RAG) are added in Phases 8-9.

## Phase 11: security/performance audit — no schema changes

Phase 11 reviewed every table's indexes against its actual query patterns (see
docs/architecture.md) and found existing coverage already adequate for every query the app runs
today — `MedicineDose(elderId, scheduledFor)`, `Notification(recipientId, createdAt)`, etc. all
match how they're actually queried. Two indexes were *considered* but deliberately not added
(`MedicineDose(elderId, status)`, `Notification(recipientId, readAt)`) because no current query
filters by status/readAt alone — adding them now would be speculative, not justified by an actual
access pattern; add them if/when a feature introduces that query.

## Commands

```bash
npx prisma migrate dev --name <change>   # create + apply in development
npx prisma migrate deploy                # apply in CI/production
npx prisma generate                      # regenerate client
```

## Backups (Phase 12)

No automated backup system exists in this repo — see
[docs/setup.md](setup.md#backups) for the full recommendation (frequency, what to back up, and
manual `pg_dump`/`pg_restore` commands) and the migration-precaution rule (always back up before
`prisma migrate deploy` against real data).

## Conventions (from Phase 2)

UUID primary keys, `created_at`/`updated_at`, enums for roles and statuses, foreign keys with indexes,
snake_case table names via `@@map`.
