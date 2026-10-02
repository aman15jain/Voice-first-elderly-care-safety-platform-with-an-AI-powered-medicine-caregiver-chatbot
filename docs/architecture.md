# Architecture

```
Flutter app ──REST/HTTPS──▶ Node.js backend ──Prisma──▶ PostgreSQL
                                   │
                                   └──internal HTTP──▶ Python agentic-ai (FastAPI)
                                                          ├─ agents / tools
                                                          ├─ RAG + vector store
                                                          └─ LLM provider
```

## Responsibilities

| Component | Owns | Never does |
|---|---|---|
| Flutter | UI, voice I/O, device actions (calls, location) | Talk to Postgres or the AI service; hold LLM keys; run arbitrary AI output |
| Node.js | Auth, authorization, business rules (adherence, missed doses, SOS), all DB access | Contain Python or model code |
| Python | Intent detection, agents, RAG, LLM calls | Access Postgres credentials directly; touch the phone; decide safety-critical outcomes |
| PostgreSQL | Persistent app data | - |

## Key decisions and why

- **Node owns the data.** One place enforces authorization and audit. Python gets only scoped data through
  internal APIs, so a bug or prompt injection in the AI layer cannot bypass family-permission rules.
- **Flutter never calls Python.** The AI service is an internal dependency; Node authenticates the user first,
  then calls it with a shared internal key (`x-internal-api-key`).
- **Deterministic core, AI at the edges.** Missed-dose detection, SOS and adherence math are plain backend code.
  The LLM only explains, retrieves and picks from a fixed set of tools.
- **Prisma migrations are committed** so PostgreSQL can be deployed and upgraded independently of the app.
- **Health endpoints split liveness from dependencies.** `/health` never touches dependencies (safe for
  container liveness); `/health/dependencies` reports DB and AI status and returns 503 when degraded.

## Layout so far

```
backend/src/{config,common,modules/{health,auth,users,family,medicines,reminders,adherence,notifications,games,activity,emergency,voice,ai,internal,dashboard},routes,services,jobs,prisma}   app.ts / server.ts
agentic-ai/app/{api,agents,tools,llm,rag,embeddings,config,schemas}  main.py
frontend/elderly_care_app/lib/{core,shared,features/{auth,home,medicines,family,profile,games,activity,emergency,voice,health,dashboard,notifications}}
```

`voice/`, `services/` under `agentic-ai/app/` remain empty placeholders — no further phases plan to use them.

## Auth & family linking (Phase 2)

- **Access tokens** are short-lived JWTs (`sub`, `role`; 15 min default). **Refresh tokens** are
  opaque random strings, stored only as `sha256(pepper + token)` — a database leak alone can't be
  replayed. Refresh rotates on every use; the old token is revoked immediately, so a copy an
  attacker captures stops working the moment the real client refreshes.
- **Login is enumeration-resistant**: an unknown email still runs a bcrypt comparison against a
  dummy hash, so the response and its timing look identical to a wrong password.
- **Family links are the only permission grant.** Every module that lets a caregiver see an
  elder's data (medicines, activity, emergency, ...) must call
  `FamilyService.assertCaregiverCanAccessElder` first — there is no other path to that data.
- **Repositories are injected**, not imported: each module defines a repository interface, a
  `Prisma*Repository` implementation for production, and tests use in-memory fakes
  (`backend/tests/fakes/`) built to the same interface. `createApp(deps)` never changes between
  a real server and a test — only what's plugged into it does. This continues the Phase 1 pattern
  used for `pingDatabase`/`ai`.

## Reminder engine (Phase 3)

- **A dose row is the adherence record.** `MedicineDose` carries `status` (`SCHEDULED → REMINDED →
  TAKEN|SKIPPED|MISSED`) plus every transition timestamp. There's no separate adherence table to
  keep in sync — `GET /api/adherence/summary` computes counts live from these rows (a pure function,
  `computeAdherenceSummary`, unit-tested independent of the database).
- **Generation is a pure function plus an idempotent insert.** `buildDoseInputs(schedule, daysAhead,
  now)` has no I/O — given the same inputs it always returns the same dose rows — and
  `createManySkipDuplicates` relies on the `(scheduleId, scheduledFor)` unique constraint, so running
  generation twice is harmless.
- **Missed-dose detection is deterministic, never an LLM call.** `MissedDoseService.sweep()` flags a
  dose `MISSED` once it's `SCHEDULED`/`REMINDED` past `scheduledFor + MISSED_DOSE_GRACE_MINUTES`, then
  notifies every caregiver with an `ACCEPTED` family link to that elder (`FamilyRepository.
  listAcceptedCaregiverIds`) — reusing the Phase 2 permission model rather than a new one.
- **The sweep runs on a real interval** (`jobs/reminderSweep.ts`, `REMINDER_SWEEP_INTERVAL_MINUTES`),
  started from `server.ts`. This is a genuine, working scheduler for one instance — not a stub. A
  multi-instance production deployment should move it to a proper job runner (node-cron/BullMQ) so
  only one instance runs it at a time.
- **Notifications are in-app only.** No push/SMS provider (FCM/APNs/Twilio) is configured, so
  `NotificationsService` writes a polled DB row — the real default, not a placeholder for one.
- **Known simplification:** `timesOfDay` are stored as UTC `HH:mm`. Flutter's time picker converts
  the elder's local-time choice to UTC before sending it (`add_medicine_screen.dart`), so the
  common case is correct; the remaining edge case is a time near local midnight landing on the
  "wrong" UTC calendar day, because the backend has no per-elder timezone (`ElderProfile.timezone`)
  to correct for it.
- **Elder-data authorization is one function.** `resolveElderScope` (`common/access/elderScope.ts`)
  is called by every medicines/reminders/adherence controller — an elder is always scoped to
  themself, a caregiver must pass `elderId` and hold an `ACCEPTED` link. There is exactly one place
  this rule is enforced, matching the Phase 2 family-permission principle.

## Flutter app (Phase 4)

- **Two Dio clients, one job each.** `authDioProvider` is bare — used only for the public
  `/api/auth/{register,login,refresh,logout}` calls, which must never wait on an access token.
  `dioProvider` carries `AuthInterceptor`, which attaches the access token to every other request
  and, on a 401, refreshes once (coalescing concurrent 401s into a single refresh call) and retries.
  If the refresh itself fails, tokens are cleared.
- **`TokenStorage.isAuthenticated` is a plain `ValueNotifier<bool>`, not Riverpod state.** It's the
  one thing both the Dio interceptor (a plain Dart class, outside the widget tree) and go_router's
  `refreshListenable` (which needs a `Listenable`) can share without Riverpod threading a `Ref`
  through non-widget code. `AuthController` (Riverpod `Notifier<AuthState>`) is the actual source of
  truth for *who* is signed in; screens read that, not `TokenStorage` directly.
- **Splash navigates explicitly, not just via router redirect.** `SplashScreen` uses `ref.listen` on
  `AuthController` and calls `context.go(...)` itself once bootstrapping resolves. This mattered in
  practice: bootstrapping into "no stored session" never *changes* `isAuthenticated` (it starts and
  stays `false`), so relying only on `refreshListenable` left the app stuck on the splash screen —
  found and fixed via the widget test suite before it could ship.
- **`AppFailure.fromError`** is the one place a `DioException` becomes user-facing text: the
  backend's own 4xx error message is shown as-is (it's already elder-friendly, per its own rules),
  anything else (network errors, 5xx) becomes a generic "please try again" — never a raw exception
  or stack trace on screen.
- **A caregiver and an elder share the same widgets** (`FamilyScreen`, `ProfileScreen`,
  `SettingsScreen`) behind separate go_router `ShellRoute`s (`/home...` vs `/caregiver...`), since
  the underlying API and permission model are identical (Phase 2) — only the destination paths and
  a couple of labels differ.
- **Repositories are faked the same way the backend fakes them**: each repository (`AuthRepository`,
  `MedicinesRepository`, `FamilyRepository`) is a concrete class; tests `extends` it and overrides
  the network-touching methods, then swap it in via `ProviderScope(overrides: [...])`. No mocking
  framework, same pattern as `backend/tests/fakes/`.
- **Live-verified, not just unit-tested.** Beyond `flutter test`, the full stack was driven through
  a real browser (Flutter web build + Playwright) against the real Node backend and a real
  PostgreSQL: register → land on elder home → add a medicine with a schedule → see it in the list,
  all via actual UI taps, with zero console errors.

## Cognitive games & activity (Phase 5)

- **The backend never plays the game.** Matching cards, recalling a sequence, spotting the odd one
  out — all of it runs client-side in Flutter, deterministically, with no network round-trip mid-game.
  The backend only receives the finished outcome (`POST /api/games/:id/session`) and validates it's
  in-bounds; it has no way to know or care *how* the score was produced, only that it's plausible.
- **The game catalog is fixed, seeded data, not an API-managed resource.** The four games (spec
  section 17) are inserted directly by the `20260923000000_games_activity` migration with hardcoded
  ids — there's no `POST /api/games` to create a fifth one. This matches reality: the games
  themselves are code (Flutter widgets), not data, so the "catalog" is just stable ids for the
  client and backend to agree on.
- **Difficulty suggestion is deterministic**, exactly like adherence and missed-dose detection:
  `suggestNextDifficulty` (pure function, unit-tested) looks at an elder's last two sessions on a
  game and steps up, steps down, or holds — never an LLM call, per spec section 17.
- **Activity tracking is intentionally thin.** `ActivityEvent` has exactly one type, `APP_OPENED`,
  recorded at most once per elder per day. Everything else `GET /api/activity/summary` reports —
  medicine interactions, game sessions — is *derived* from `MedicineDose.responded_at` and
  `GameSession.created_at`, which already exist for their own purposes. This avoids the invasive,
  log-every-screen-visit tracking the spec explicitly warns against (section 18), while still
  answering "was there any meaningful activity on this day."

## Emergency SOS (Phase 6)

- **A contact is not a caregiver.** `EmergencyContact` is just a name and phone number, added by
  the elder — it doesn't need to correspond to any app account. `FamilyLink` (a registered
  caregiver) and `EmergencyContact` (a phone number) are two separate, deliberately unconnected
  concepts, because they can only be acted on in two completely different ways: a caregiver gets
  an in-app notification the backend can send; a contact gets a phone call only the elder's own
  device can place. `POST /api/emergency/sos` hands back the contact list precisely so Flutter can
  make that call immediately, without a second request.
- **SOS is idempotent, not just deterministic.** A panicked elder tapping the button five times
  must not create five events or fire five caregiver notifications — `EmergencyService.triggerSOS`
  returns the existing `ACTIVE`/`ACKNOWLEDGED` event unchanged instead. A new event is only ever
  created after the previous one reaches `RESOLVED`.
- **Location is captured once, not tracked.** `latitude`/`longitude` are set at the moment SOS
  fires and never updated afterwards — there is no background location polling, matching the
  spec's warning against invasive tracking (section 18) and the flow in section 15, which asks for
  "location retrieval" at the moment of the event, not continuous tracking.
- **The state machine is small on purpose:** `ACTIVE → ACKNOWLEDGED → RESOLVED`, with `RESOLVED`
  reachable directly from `ACTIVE` too (the elder can cancel a false alarm before anyone
  acknowledges it). Acknowledging is caregiver-only — it means "a person has seen this and is
  responding" — while resolving is available to either party, since either one might be the one
  who confirms the elder is safe.

## Voice layer (Phase 7)

- **Deterministic intent matching, not an LLM.** `matchIntent` (`modules/voice/voiceLanguagePacks.ts`)
  is plain keyword/regex matching against the on-device speech-to-text transcript — the same
  "deterministic core" rule as adherence and SOS (spec sections 13/26). This keeps emergency and
  medicine-status handling reliable, and lets Phase 8's real agent later sit behind the exact same
  `VoiceService.process()` contract without any Flutter-side change.
- **The response contract mirrors spec section 26 on purpose**: `{ type, response, language, action }`.
  `type: 'action'` only ever carries one of two allow-listed actions — `CALL_CONTACT` (a phone number
  already on the elder's own `EmergencyContact` list) or `TRIGGER_SOS`. Nothing else is ever executed
  client-side from a voice response.
- **Voice-triggered emergency never auto-fires the real SOS.** `TRIGGER_SOS` only tells Flutter to
  navigate to the existing SOS confirmation screen (`/emergency`, Phase 6) — a human still has to
  press the button themselves. This is an explicit extra safety margin beyond the letter of the spec
  (sections 13/15), since letting spoken words alone trigger a real emergency call would be exactly
  the kind of irreversible, agent-driven action the spec warns against.
- **Only the transcript and matched intent are stored**, never audio — `VoiceInteraction` is a text
  row, consistent with the no-invasive-tracking rule (section 18). It doubles as a signal future
  caregiver-insight phases can read, the same way activity summaries reuse dose/game timestamps.
- **Multilingual via a small language-pack registry, not full translation.** `voiceLanguagePacks.ts`
  and `voiceResponses.ts` hold one full English set and a deliberately partial Hindi set (enough
  patterns/responses to prove the abstraction supports more than one language); anything a language
  pack doesn't cover falls back to English rather than erroring, both for intent matching and for
  response text.
- **On-device STT/TTS, same device-capability pattern as Phase 6.** `VoiceInputService`
  (`speech_to_text`) and `VoiceOutputService` (`flutter_tts`) are concrete, injectable classes behind
  Riverpod providers, exactly like `LocationService`/`PhoneService` — tests override them with fakes
  rather than touching the real platform channel.

## Agentic AI (Phase 8)

- **Node still owns authorization; Python never re-checks it.** `/api/ai/ask` and
  `/api/ai/caregiver-insight` resolve and authorize the elder (via `resolveElderScope`, the same
  as every other module) *before* calling the Python orchestrator — the orchestrator and its agents
  trust the `elder_id` they're handed. This is why `/internal/*` (the routes Python calls back into)
  does no authorization of its own either: by the time Python calls it, Node already decided the
  original caller may see that elder's data.
- **Python holds no database credentials.** `NodeApiClient` (`agentic-ai/app/tools/node_client.py`)
  is the only way any agent reaches application data, calling two new Node-only, internal-key-gated
  endpoints (`/internal/elders/:elderId/medicine-context`, `.../caregiver-insight-context`) that
  return facts Node already computed (medicines, a 30-day adherence summary, a 7-day activity
  summary, whether there's an active emergency) — never raw table access.
  `common/middleware/internalAuth.ts` guards them the same way `x-internal-api-key` already guards
  the Node -> Python direction (`services/aiClient.ts`); both directions share one secret
  (`AI_SERVICE_API_KEY` in Node, `INTERNAL_API_KEY` in Python) since the two services are a single
  internal trust boundary.
- **Agents are read-only by construction, not by convention.** `AgentResponse.action` is typed
  `None` in the Python schema — there is no code path in `MedicineAgent` or `CaregiverInsightAgent`
  that could set it to anything else. Neither agent can trigger a real-world action; that stays
  exclusively in Node's deterministic emergency/adherence/voice logic (Phases 3/6/7).
- **"Grounded in retrieved sources" is structural, not a prompt instruction.** `MockLlmProvider`
  (the real default, `LLM_PROVIDER=mock`) only fills named string templates with fields a tool
  already returned from Node — it cannot mention a medicine, a number or an emergency that wasn't
  in that data, because there is no step where it generates free text from a prompt. A real
  model-backed provider could replace it later behind the same `compose()` interface without any
  agent code changing.
- **The orchestrator is a router, not a reasoner.** `Orchestrator.handle()` is a single `if` on
  `mode` (`medicine_query` vs `caregiver_insight`) — Node already knows which one applies from which
  endpoint the user called, so there is no intent-classification step to get wrong. This mirrors
  Phase 7's voice intent matching: the *routing* decision that picks an agent is deterministic;
  only the response text composition uses the (currently mock) LLM layer.
- **Live-verified over real HTTP, not just fakes.** Beyond the backend's/agentic-ai's own fake-based
  test suites, this phase was additionally checked by running the real `uvicorn` process and a
  stub Node-shaped HTTP server, and separately by running Node's real `HttpAiOrchestratorClient`
  against the real `uvicorn` process — confirming the actual wire format on both sides of the
  Node <-> Python boundary, not only the in-memory contracts each side's own tests assume.

## RAG: medicine knowledge base (Phase 9)

- **General medicine knowledge is separate from personal data, on purpose.** Phase 8's
  `MedicineContextTool` answers "what do I take / have I taken it" from Node, scoped to one elder.
  Phase 9 adds a second, independent grounding source — `data/medicines/knowledge_base.json`, a
  small curated set of `uses`/`side_effects`/`warnings` entries — for "what is it for / what are
  the side effects" questions about any medicine the knowledge base covers, not just the elder's
  own. `MedicineAgent` decides which source applies per question; it never blends an unverified
  fact from one into the other.
- **Chunking is per-section, not per-medicine**, so retrieval can tell "what is it for" apart from
  "what are the side effects" instead of always dumping the whole entry back. Retrieval is also
  *scoped* to the one medicine named in the question — a question about aspirin's side effects
  can't accidentally surface lisinopril's warnings.
- **The embedding provider is honestly lexical, not dressed up as semantic.** `TfEmbeddingProvider`
  (the real default) is deterministic, stopword-filtered term-frequency vectors over the corpus
  vocabulary — the same pattern `MockLlmProvider` already follows: a clearly-labelled stand-in,
  not a claim of trained-model understanding it doesn't have. For a handful of short, structured
  entries, picking the best-matching section by keyword overlap is the right tool, not a
  shortcut hiding a gap.
- **A medicine not in the knowledge base gets an honest "I don't have that" answer**, never a
  guess — the same rule (spec/docs rule 1: grounded in retrieved sources, say so when nothing is
  found) Phase 8 already applied to personal medicine data.
- **The vector store is swappable by design**, even though the current `InMemoryVectorStore` is
  the right choice for a handful of entries: a production-scale knowledge base could implement the
  same `VectorStore` interface against a real vector database (`settings.vector_db_url`, still
  unused) without any change to `rag/retriever.py` or the agents above it.

## Caregiver dashboard & notifications (Phase 10)

- **One dashboard call, not N.** `GET /api/family/dashboard` fans out over every elder the
  caregiver has an ACCEPTED link to, but it's the caregiver's *one* request — `CaregiverDashboardService`
  loops server-side, not Flutter. It deliberately reuses `InternalContextService.getCaregiverInsightContext`
  (Phase 8's agentic-ai internal API) rather than writing a second, parallel aggregation: one
  computation of "adherence/activity/emergency for this elder," two consumers.
- **Muting is a caregiver-profile flag, not a family-link change.** `caregiver_profiles.notify_on_missed_dose`
  is completely independent of the `FamilyLink` that grants data access — muting never affects what a
  caregiver can see, only whether `MissedDoseService` creates a `Notification` row for them. `MissedDoseService`
  checks it per caregiver, per missed dose, so one caregiver muting alerts never affects another
  caregiver linked to the same elder.
- **The adherence trend is a day-by-day sibling of the existing summary, not a new concept.**
  `computeAdherenceTrend` (`adherence.trend.ts`) is the same pure, deterministic bucketing as
  `computeAdherenceSummary` and `buildDailySummary` (activity module) — group settled doses by
  calendar day, emit one row per day in range even if empty. No LLM, no new authorization path:
  it's gated by the same `resolveElderScope` as every other adherence endpoint.
- **The dashboard's trend chart is a plain Flutter widget, not a new dependency.** `AdherenceSparkline`
  renders bars with `Container`/`FractionallySizedBox` sized by each day's `takenRate` — enough to
  show a trend at a glance without adding a charting package for eight bars of data.
- **Caught by the first caregiver-login widget test, not by inspection:** `LoginScreen` was
  hardcoding `context.go('/home')` regardless of role (unlike `RegisterScreen`, which already
  branched correctly) — every prior widget test happened to log in as an elder, so this had never
  been exercised. Fixed to read the just-authenticated user's role, the same way `RegisterScreen`
  already did. A second real bug (a `Row` of two dashboard chips overflowing on a narrow phone
  width) was caught the same way and fixed with a `Wrap`.

## Security & authorization (Phase 11)

Phase 11 audited every module against this model rather than redesigning it — the model below
was already in place from Phase 2 onward; what's new is the audit itself, the gaps it found
(brute-force rate limiting; a handful of missing negative tests), and the fixes.

- **Authorization has exactly two enforcement shapes, and every endpoint uses one of them.**
  (1) List/summary-style reads that take an optional `elderId` go through `resolveElderScope`
  (`common/access/elderScope.ts`) — an elder is always scoped to themself, a caregiver must pass
  `elderId` and hold an `ACCEPTED` `FamilyLink`. (2) By-id mutations (medicines, schedules,
  contacts, doses, notifications, family links, game sessions) call a service-level ownership
  check (`getOwnedX(elderId, id)` or an equivalent `record.elderId !== id` guard) before acting,
  returning 404 — not 403 — for someone else's id, so a caregiver probing ids can't even
  distinguish "doesn't exist" from "exists but isn't yours."
- **Role never comes from the client.** `authenticate` (`common/middleware/authenticate.ts`) sets
  `req.auth.role` only from a verified JWT payload; nothing in the codebase reads a role from
  `req.body`/`req.query`. `tests/roleManipulation.routes.test.ts` asserts this directly: claiming
  `role: "CAREGIVER"` in a request body while authenticated as an elder changes nothing, and a
  tampered access token is rejected outright rather than silently treated as a different identity.
- **Brute-force protection is a separate, stricter limiter on just `/api/auth/login` and
  `/register`** (`common/middleware/authRateLimit.ts`, 10 requests/15 min per client) — the global
  limiter (`app.ts`, 300/min) is a DoS guard, not password-guessing protection, so this phase added
  a tighter one specifically there. It's a factory (`createAuthRateLimiter()`), not a module-level
  singleton, because `createApp` runs once per test and a shared limiter would leak its counter
  across unrelated tests.
- **A caregiver's notification-preference endpoint has no "whose preferences" parameter at all** —
  `PATCH /api/users/me/notification-preferences` always acts on `req.auth.userId`. There is no id
  to manipulate, which is a stronger guarantee than checking one would be.
- **Access tokens are not independently revocable** (a deliberate tradeoff, not an oversight):
  logout/refresh-rotation only invalidates the *refresh* token; a captured access token remains
  valid for its 15-minute TTL even after logout. Given the short TTL and that refresh tokens are
  hashed at rest and rotated on every use, this phase did not add a blocklist/jti-revocation
  mechanism — flagged here so the tradeoff is explicit rather than silently assumed.
- **AI safety was re-verified, not re-designed** (docs/ai-architecture.md rules 1-5 were already
  correct from Phase 8): `AgentResponse.action` is typed `None`, not `Optional[Action]`, so no
  agent can produce one regardless of what a query asks for; `/agents/respond` is gated by
  `require_internal_api_key` as a router-level dependency; and no agent/tool file makes an HTTP
  call outside `NodeApiClient`. `agentic-ai/tests/test_prompt_injection.py` adds regression tests
  for this specifically: a query's free text can never change which `elder_id` a tool call uses
  (it only ever uses the validated request field), and asking the agent to "produce an action" in
  the query text has no effect on the response's `action` field.

## Offline & weak-network support (Phase 11)

Built from scratch this phase — nothing existed before (no connectivity detection, no local
cache, no retry logic). Deliberately small, per the "don't over-engineer offline" rule: exactly
two things are cached/queued, nothing else.

- **`ConnectivityService`/`isOnlineProvider`** (`core/services/connectivity_service.dart`) wraps
  `connectivity_plus` behind the same concrete-class-behind-a-Riverpod-provider pattern as
  `LocationService`/`PhoneService` (Phase 6/7), so tests fake it instead of touching a platform
  channel. It reports "does the device have a network interface up," not "is the backend
  reachable" — a global `OfflineBanner` (mounted once in `AppShell`, visible from every tab) shows
  whenever it reports offline.
- **Today's medicine schedule is cached, and only that.** `todayScheduleProvider`
  (`features/medicines/application/medicines_providers.dart`) now catches a *connectivity*
  failure specifically (`AppFailure.isNetworkError` — no response at all, not a real 4xx/5xx) and
  falls back to the last successfully-fetched schedule (`LocalCache`, backed by
  `shared_preferences`), surfaced to the user via a visible "Showing saved schedule from..."
  notice (`TodaysScheduleScreen`) — never silently. A real server-returned error is never
  swallowed this way, only "we couldn't reach the server at all" is.
- **Exactly one thing is queued for later sync: the non-critical "app opened" ping**
  (`core/services/sync_queue_service.dart`). It's queued only because it's both safe to lose (it
  only feeds an activity summary) and safe to retry (idempotent per day server-side, Phase 3).
  Nothing else is queued — **adherence actions (taken/skipped) and SOS always require a live,
  confirmed round trip**, on purpose: a queued-and-silently-retried medical action or emergency
  alert would be actively dangerous (the elder could believe help was called when it wasn't).
- **Emergency fails loud, not quiet.** If `POST /api/emergency/sos` can't be reached at all,
  `SosScreen` shows a modal dialog stating plainly that caregivers were **not** notified and
  routes straight to the emergency contacts list to call manually — not a toast that can be missed
  (`AppFailure.isNetworkError` again distinguishes "never reached the server" from a real error).
- **Retries are scoped to what's actually safe to retry.** `RetryInterceptor`
  (`core/network/retry_interceptor.dart`) retries only `GET` requests that failed for a
  connectivity reason, up to twice with backoff — never `POST`/`PATCH`/`DELETE`, since retrying
  those could duplicate a real action.
- **Known, accepted gap**: no local push notification scheduling (`flutter_local_notifications`)
  for cached doses while offline. Building it correctly (exact-alarm permissions on Android 12+,
  iOS permission prompts, cancel/reschedule bookkeeping) is a meaningfully sized feature on its
  own, disproportionate to this phase's hardening/testing focus — the elder-facing in-app "Due"
  badge already covers the common case of the app being open. Documented here rather than
  partially built and left looking finished.

## Production deployment (Phase 12)

No architecture change — this phase is deployment hardening around the existing design, detailed
in [docs/setup.md](setup.md#production-deployment-phase-12).

- **`docker-compose.prod.yml`** is a standalone production compose file (not an overlay on the
  dev `docker-compose.yml`, to avoid Compose's list-merge ambiguity around `ports`): `restart:
  unless-stopped` everywhere, `NODE_ENV`/`APP_ENV` fixed to `production`, every secret required
  via `${VAR:?message}` instead of defaulted, and — per the diagram at the top of this file —
  only `backend` publishes a host port. Postgres and agentic-ai are reachable only from other
  containers on the compose network, matching "Python never talks to the outside world" from
  day one of this project.
- **`AppConfig.resolveApiBaseUrl`** (Flutter) now throws at startup if a release build has no
  `--dart-define=API_BASE_URL` — previously it would have silently fallen back to a development
  URL (`localhost`/`10.0.2.2`), which is exactly the "release build accidentally pointed at
  nothing real" failure mode this phase's own goals warn about.
- **`server.headersTimeout`/`requestTimeout`** (Node) bound how long a connection may sit open
  without finishing its headers/request — a slow-loris-style connection can no longer hold a
  socket indefinitely. Graceful shutdown (`SIGTERM`/`SIGINT` → stop accepting, drain, disconnect
  Prisma) already existed from Phase 1 and needed no change.
- **`.github/workflows/ci.yml`** runs all three test suites plus a Prisma validation job on every
  push/PR, and fails the pipeline if any of them fail.
- **`.dockerignore`** added for both `backend/` and `agentic-ai/` — neither image's build context
  (and therefore neither final image) includes `.env`, `tests/`, `.git`, or other
  development-only files that were previously only excluded by the Dockerfiles' selective `COPY`
  lines, not by the build context itself.

## Backend conventions

`createApp(deps)` takes its dependencies (DB ping, AI client) as arguments so tests inject fakes and no
test needs a database. Controllers only translate HTTP; logic lives in services. Errors flow to a single
`errorHandler` that returns `{ success:false, error:{code,message} }` and hides internals.
