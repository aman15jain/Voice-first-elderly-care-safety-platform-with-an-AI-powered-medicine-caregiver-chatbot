# API

Base URL: `http://localhost:4000` in development; your real backend origin behind HTTPS in
production (see [docs/setup.md](setup.md#production-deployment-phase-12)). Errors use
`{ "success": false, "error": { "code", "message", "details?" }, "requestId" }`.
Every response carries an `x-request-id` header.

`CORS_ORIGINS` must be your real frontend origin(s) in production — never empty (which blocks
all cross-origin requests, the safe default), never `*`, never a `localhost` entry left over
from development.

## Backend (Phase 1)

### GET /health
Liveness only; does not touch dependencies.
```json
{ "status": "ok", "service": "backend", "uptimeSeconds": 12 }
```

### GET /health/dependencies
200 when all up, 503 when degraded.
```json
{
  "status": "ok",
  "service": "backend",
  "dependencies": {
    "database":  { "status": "up", "latencyMs": 4 },
    "aiService": { "status": "up", "latencyMs": 9 }
  }
}
```

## Auth

Passwords: 8-72 chars, at least one letter and one number. `role` is `ELDER` or `CAREGIVER` only —
admins are provisioned directly in the database, not through registration. **`/register` and
`/login` are rate-limited to 10 requests per 15 minutes per client** (Phase 11,
`common/middleware/authRateLimit.ts`) — on top of the app-wide 300/min limiter — specifically to
bound password-guessing; a 429 returns `{ success:false, error:{ code: "TOO_MANY_REQUESTS", ... } }`.

### POST /api/auth/register
Body: `{ email, password, role, fullName, preferredLanguage? }`. Creates the user and their
ELDER/CAREGIVER profile in one transaction, and returns a session (201).

### POST /api/auth/login
Body: `{ email, password }` → 200 with a session. Wrong password and unknown email return the
same 401 message, so a login attempt can't be used to discover which emails have accounts.

### POST /api/auth/refresh
Body: `{ refreshToken }` → 200 with a **new** access + refresh token pair. The refresh token used
in the request is revoked immediately (rotation) — reusing it returns 401.

### POST /api/auth/logout
Body: `{ refreshToken }` → 204. Revokes that refresh token; safe to call twice.

Session response shape:
```json
{ "success": true, "accessToken": "...", "refreshToken": "...", "expiresIn": 900,
  "user": { "id": "...", "email": "...", "role": "ELDER", "preferredLanguage": "en" } }
```

## Users

### GET /api/users/me
Requires `Authorization: Bearer <accessToken>`. Returns `{ id, email, role, preferredLanguage, fullName, notifyOnMissedDose? }`.
`notifyOnMissedDose` is present (default `true`) only for a `CAREGIVER` account.

### PATCH /api/users/me/notification-preferences
**CAREGIVER-only** (Phase 10). Body `{ notifyOnMissedDose: boolean }` → `{ success: true, notifyOnMissedDose }`.
Muting only skips the `Notification` row `MissedDoseService` would have created for that caregiver
— it never affects the caregiver's own data access or the dashboard below.

## Family links

All routes require `Authorization: Bearer <accessToken>`. A caregiver only ever sees an elder's
data elsewhere in the API once a link's status is `ACCEPTED` — see `FamilyService.assertCaregiverCanAccessElder`.

- **GET /api/family/links** — every link involving the caller (any status). Each link also carries
  `elderName`/`elderEmail`/`caregiverName`/`caregiverEmail` (the counterpart's own name/email are
  never included — every link a user sees already involves them) so the UI can render who it's
  with without a separate lookup.
- **POST /api/family/links** — `{ email }` of the other party. ELDER/CAREGIVER only (not ADMIN).
  Either side can invite the other; the target's role must be the opposite one. Re-inviting a
  `REVOKED`/`DECLINED` pair reuses the row and sets it back to `PENDING`.
- **PATCH /api/family/links/:id/accept** / **.../decline** — only the invited party (not the
  inviter) may respond, and only while `PENDING`.
- **DELETE /api/family/links/:id** — either party revokes an active link at any time.

### GET /api/family/dashboard (Phase 10)
**CAREGIVER-only.** One call for every ACCEPTED-linked elder — no `elderId` param, no N+1 requests
from Flutter:
```json
{ "success": true, "elders": [
  { "elderId": "...", "elderName": "Grandma Rose", "elderEmail": "...",
    "adherence": { "...": "30-day AdherenceSummary, same shape as /api/adherence/summary" },
    "activity": { "daysInRange": 7, "activeDays": 5, "medicineInteractionDays": 5, "gameSessionDays": 2 },
    "activeEmergency": false } ] }
```
Reuses the exact same per-elder facts `/internal/elders/:elderId/caregiver-insight-context`
(Phase 8) already computes for agentic-ai — one computation, two consumers.

## Elder-data scoping (medicines, doses, adherence)

Every endpoint below requires `Authorization: Bearer <accessToken>` and resolves *which elder's*
data the request touches via one shared rule (`resolveElderScope`):
- **ELDER**: always their own data. Passing someone else's `elderId` is rejected (403), not ignored.
- **CAREGIVER**: must pass `?elderId=`, and needs an `ACCEPTED` family link to it (403 otherwise).
- **ADMIN**: none of these endpoints are open to admins yet.

Mutations (create/edit/delete a medicine or schedule, mark a dose taken/skipped) are **ELDER-only**
and always act on the caller's own data — not even a linked caregiver can do them.

## Medicines

- **GET /api/medicines** `?elderId=&includeInactive=` — soft-deleted medicines are hidden unless `includeInactive=true`.
- **POST /api/medicines** — `{ name, dosage, instructions? }` → 201.
- **PATCH /api/medicines/:id** — any subset of the same fields.
- **DELETE /api/medicines/:id** — **soft delete**: sets `isActive=false` on the medicine and all its
  schedules. Past doses (and their adherence history) are never removed.

## Medicine schedules

- **GET /api/medicine-schedules** `?elderId=&medicineId=`
- **POST /api/medicine-schedules** — `{ medicineId, timesOfDay: ["08:00","20:00"], daysOfWeek?: [0-6], startDate, endDate? }`.
  `timesOfDay` are 24h `HH:mm` **in UTC** — per-elder timezones aren't implemented yet (see docs/architecture.md).
  `daysOfWeek` empty/omitted means every day. Creating a schedule immediately generates its upcoming doses.
- **PATCH /api/medicine-schedules/:id** — editing it deletes not-yet-due `SCHEDULED` doses and regenerates
  them from the new schedule; doses already reminded/taken/skipped/missed are untouched history.

## Doses (`GET /api/doses` is the reminder engine's read side)

- **GET /api/doses** `?elderId=` — no `from`/`to` → today (UTC). With both, inclusive range, max 90 days.
- **POST /api/doses/:id/reminded** — elder marks a reminder as delivered (`SCHEDULED` → `REMINDED`). 409 if not `SCHEDULED`.

Doses are generated and swept for missed status automatically by a background job — see
[docs/architecture.md](architecture.md#reminder-engine-phase-3).

## Adherence

- **POST /api/adherence/:doseId/taken** / **.../skipped** — from `SCHEDULED`/`REMINDED`/`MISSED` only
  (409 if already `TAKEN`/`SKIPPED`). Deterministic — no LLM involved.
- **GET /api/adherence/summary** `?elderId=&from=&to=` — both `from`/`to` or neither (defaults to the
  last 30 days), max 90-day range.
  ```json
  { "success": true, "summary": { "from": "2026-01-01", "to": "2026-01-30",
    "scheduled": 2, "reminded": 1, "taken": 40, "skipped": 3, "missed": 2, "totalDue": 45, "takenRate": 89 } }
  ```
  `totalDue` = taken + skipped + missed (settled doses only); `takenRate` is null until something is due.
- **GET /api/adherence/trend** `?elderId=&from=&to=` (Phase 10) — same scoping/range rules as
  `/summary`, but defaults to the last **14** days and returns one row per calendar day instead
  of one aggregate:
  ```json
  { "success": true, "days": [
    { "date": "2026-01-01", "taken": 1, "totalDue": 1, "takenRate": 100 },
    { "date": "2026-01-02", "taken": 0, "totalDue": 0, "takenRate": null } ] }
  ```
  Powers the caregiver dashboard's per-elder trend sparkline; a day with nothing due yet still
  gets a row (`totalDue: 0`, `takenRate: null`) rather than a gap.

## Notifications

In-app only — there's no push/SMS provider configured. A caregiver's missed-dose alerts land here,
unless that caregiver has muted them (`PATCH /api/users/me/notification-preferences`, Phase 10) —
muting skips creating the row entirely, so a muted caregiver's unread count never includes them.

- **GET /api/notifications** `?unreadOnly=true`
- **PATCH /api/notifications/:id/read**

## Cognitive games

Same elder-data scoping as above. Gameplay itself runs entirely on-device (Flutter); the backend
only records the outcome and suggests the next difficulty — it never picks up mid-game state.

- **GET /api/games** `?elderId=` — the four built-in games, each with a deterministic
  `suggestedDifficulty` (1-3) computed from that elder's last two sessions on it (see
  `gameDifficulty.ts`; never an LLM call). A new elder gets 1 for everything.
- **POST /api/games/:id/session** — **ELDER-only**. `{ difficulty: 1-3, score, mistakes, durationSeconds, completed }`,
  all bounded (`durationSeconds` max 3600). 404 for an unknown/inactive game id.
- **GET /api/games/sessions** `?elderId=&gameId=&from=&to=` — history; same from/to rules as doses
  (both or neither, max 90 days, defaults to the last 30 days).

## Activity

- **POST /api/activity/app-opened** — **ELDER-only**, no body. Idempotent per UTC day: opening the
  app five times today still records one event. This is the *only* generic tracking call in the
  app — everything else in the summary below is derived from medicine/game actions already
  recorded for their own purposes (see docs/architecture.md on why this isn't a bigger event log).
- **GET /api/activity/summary** `?elderId=&from=&to=` — defaults to the last 7 days (max 90).
  One row per calendar day, even empty ones:
  ```json
  { "success": true, "days": [
    { "date": "2026-01-01", "medicineInteractions": 3, "gameSessions": 1, "active": true },
    { "date": "2026-01-02", "medicineInteractions": 0, "gameSessions": 0, "active": false }
  ] }
  ```

## Emergency SOS

Deterministic backend logic throughout — no LLM is ever involved in triggering, notifying or
resolving an emergency (spec section 15). Same elder-data scoping as above for reads.

An **emergency contact** is a name + phone number, not necessarily an app account — it's separate
from a linked caregiver. The backend can only notify caregivers (they're registered users);
calling a contact's number is a real, on-device action Flutter performs with the phone dialer,
which is why `POST /api/emergency/sos` hands back the contact list in the same response.

- **GET /api/emergency/contacts** `?elderId=`
- **POST /api/emergency/contacts** — **ELDER-only**. `{ name, phone, relationship?, priority? }`.
  `priority` defaults to "added last" (lower calls first); omit it to just append.
- **PATCH /api/emergency/contacts/:id** / **DELETE /api/emergency/contacts/:id** — ELDER-only, own contacts only.

- **POST /api/emergency/sos** — **ELDER-only**. Body `{ latitude?, longitude? }` (both or neither).
  Creates an `ACTIVE` event and notifies every linked caregiver in-app. **Idempotent**: pressing SOS
  again while one is already `ACTIVE`/`ACKNOWLEDGED` returns that same event instead of creating a
  duplicate or re-notifying. Response includes the elder's contact list:
  ```json
  { "success": true,
    "event": { "id": "...", "status": "ACTIVE", "latitude": 12.97, "longitude": 77.59, "triggeredAt": "..." },
    "contacts": [ { "id": "...", "name": "Daughter Jane", "phone": "+1 555-123-4567", "priority": 1 } ] }
  ```
- **GET /api/emergency/events** `?elderId=&from=&to=` — defaults to the last 30 days (max 90).
- **PATCH /api/emergency/events/:id/acknowledge** — **CAREGIVER-only** (must be linked): `ACTIVE` → `ACKNOWLEDGED`.
- **PATCH /api/emergency/events/:id/resolve** — the elder themself or a linked caregiver:
  `ACTIVE`/`ACKNOWLEDGED` → `RESOLVED`. 409 if already resolved/acknowledged as applicable.

## Voice

Deterministic keyword/pattern matching throughout — no LLM is involved in Phase 7 (spec sections
13/26). The response shape is intentionally the AI response contract from spec section 26, so
Phase 8's real agent can later sit behind it without any Flutter-side change.

- **POST /api/voice/process** — **ELDER-only**. Body `{ transcript, language? }` (`language`
  defaults to `"en"`; unsupported codes fall back to English). Always records the interaction
  (transcript + matched intent, never audio) and returns:
  ```json
  { "success": true,
    "type": "information" | "action",
    "response": "You've taken 1 out of 1 medicines today. Well done!",
    "language": "en",
    "action": null }
  ```
  `action` is `null` for `type: "information"`. For `type: "action"` it is one of exactly two
  shapes, and Flutter executes nothing else:
  - `{ "type": "CALL_CONTACT", "contactId": "...", "contactName": "Jane", "phone": "+1 555-123-4567" }`
  - `{ "type": "TRIGGER_SOS" }` — Flutter navigates to the existing `/emergency` confirm screen; it
    never calls `POST /api/emergency/sos` directly from a voice command, so a human always
    explicitly confirms before the real SOS fires.
- **GET /api/voice/interactions** `?elderId=&from=&to=` — defaults to the last 30 days (max 90).
  Same elder-data scoping as every other module.

## AI assistant (Phases 8-9)

Same response contract as Voice (spec section 26) and backed by a real orchestrator/agent pair in
`agentic-ai`, but **read-only**: `action` is always `null`.

- **POST /api/ai/ask** — **ELDER-only**. Body `{ query, language? }`. The medicine agent answers
  two kinds of question, both grounded, never guessed:
  - the caller's own medicines/adherence (Phase 8, from Node's 30-day adherence summary) — says
    so plainly if there's nothing to report;
  - general medicine questions — what a drug is for, its side effects, warnings (Phase 9, from a
    curated knowledge base) — says so plainly for a medicine it doesn't have information on.
  ```json
  { "success": true, "type": "information",
    "response": "You take 1 medicine(s): Metformin (500mg).",
    "language": "en", "sources": ["medicines"], "action": null }
  ```
- **GET /api/ai/caregiver-insight** `?elderId=&language=` — same elder-data scoping as every other
  module. The caregiver-insight agent summarizes 30-day adherence and 7-day activity, and leads
  with a plain-language notice if there's an active emergency right now.

## AI service (internal, Node -> Python only)

### GET /health
```json
{ "status": "ok", "service": "agentic-ai", "version": "0.1.0" }
```

### POST /agents/respond
Requires `x-internal-api-key`. Body `{ elder_id, mode: "medicine_query"|"caregiver_insight", query?, language? }`.
This is what `/api/ai/ask` and `/api/ai/caregiver-insight` call internally; never reachable from Flutter.

## Internal context (Node, callable only by agentic-ai)

Both require `x-internal-api-key` (the same shared secret used in the other direction) — never a
user access token, and not reachable from Flutter. Node has already authorized the original
caller (elder or linked caregiver) before agentic-ai ever makes these calls; nothing here does
its own authorization.

- **GET /internal/elders/:elderId/medicine-context** — `{ medicines: [{name, dosage, instructions}], adherence }` (30-day window).
- **GET /internal/elders/:elderId/caregiver-insight-context** — `{ adherence, activity: {daysInRange, activeDays, medicineInteractionDays, gameSessionDays}, activeEmergency }` (30-day adherence, 7-day activity).
