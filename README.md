# Major Project

A Flutter app for elderly users and their caregivers, backed by Supabase.

This repository is the **base model**: sign-up and login with a chosen role,
password reset by email, persistent sessions, and auth-guarded navigation.
Medicine and contact entry are placeholders to build on next.

**Stack:** Flutter · Supabase (Auth + Postgres) · Riverpod · go_router

## Features

- Email/password sign-up and login (Supabase Auth)
- Choose a role at sign-up: **Elderly User** or **Caregiver**, stored in the `users` table
- Forgot-password email
- Session persistence: reopening the app signs you back in
- Auth-guarded routes: signed-out users are redirected to Login, signed-in users to Home
- Row Level Security so each user can only read and write their own data

## Setup

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- A free [Supabase](https://supabase.com) account

### 1. Create a Supabase project

In the Supabase dashboard, create a new project and wait for it to finish
provisioning.

### 2. Create the database tables

Open **SQL Editor → New query**, paste the contents of
[`supabase/schema.sql`](supabase/schema.sql), and click **Run**.

This creates the `users` and `family_links` tables, turns on Row Level
Security with policies, and adds a trigger that creates a `users` row whenever
someone signs up. It is safe to run more than once.

### 3. Check the email sign-in setting

Under **Authentication → Providers → Email**, the *Confirm email* option
decides what happens after sign-up:

- **On** (Supabase's default): the user must click a link in an email before
  logging in. The app tells them to check their inbox.
- **Off**: the user is signed in immediately. This is the quickest option while
  developing.

### 4. Add your Supabase URL and anon key

**This is the one place credentials go: the `.env` file in the project root.**

1. Copy the example file:

   ```bash
   # macOS / Linux / Git Bash
   cp .env.example .env
   # Windows PowerShell
   copy .env.example .env
   ```

2. In the Supabase dashboard open **Project Settings → API** and copy:
   - **Project URL** → `SUPABASE_URL`
   - **anon / publishable key** → `SUPABASE_ANON_KEY`

3. Edit `.env`:

   ```
   SUPABASE_URL=https://your-project-ref.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   ```

`.env` is git-ignored, so your keys are not committed. Only `.env.example`
(with placeholders) is tracked.

> The `.env` file is bundled into the app as an asset, so the key can be read
> from a built app. That is fine for the anon key, which is designed to be
> public and is protected by Row Level Security. **Never put the `service_role`
> or secret key in this file.**

If you run the app before filling in `.env`, it shows a "Supabase is not
configured" screen instead of crashing.

### 5. Run the app

```bash
flutter pub get
flutter run
```

Pick a device with `flutter run -d chrome` (web) or `flutter run -d windows`.

> **Windows:** building with plugins needs symlink support. If you see
> *"Building with plugins requires symlink support"*, enable Developer Mode
> (`start ms-settings:developers`) and run `flutter pub get` again.

### 6. Forgot-password links (optional)

Reset emails link to your project's **Site URL**
(**Authentication → URL Configuration**). See *Known limitations* below for
what is and isn't wired up.

## Running checks

```bash
flutter analyze
flutter test
```

The tests use an in-memory fake of `SupabaseService`, so they need no Supabase
project or network.

## Folder structure

```
.env.example              Placeholder credentials (copy to .env)
supabase/
  schema.sql              Tables, RLS policies and the sign-up trigger
lib/
  main.dart               Loads .env, initialises Supabase, starts the app
  app.dart                MaterialApp.router and theme
  models/
    app_user.dart         AppUser (a users row) and the UserRole enum
  providers/
    auth_provider.dart    supabaseServiceProvider, authStateProvider, appUserProvider
    onboarding_provider.dart   Flag that sends new users to onboarding
  routes/
    app_routes.dart       Route path constants
    app_router.dart       go_router config and the auth redirect
  screens/
    splash_screen.dart
    login_screen.dart
    signup_screen.dart              Includes role selection
    forgot_password_screen.dart
    home_screen.dart                Placeholder dashboard with a logout button
    onboarding_screen.dart          Placeholder for medicine/contact entry
    setup_required_screen.dart      Shown when .env isn't filled in
  services/
    supabase_service.dart  Every Supabase call: sign up, log in, log out, fetch user
  utils/
    validators.dart        Form validation
    snackbar.dart
test/                      Unit and widget tests (mirrors lib/)
```

## How it works

- **Sign-up and roles.** The app sends the name and chosen role as sign-up
  metadata. A database trigger (`handle_new_user` in `schema.sql`) copies them
  into the `users` table. Doing it in the database means it also works when
  email confirmation is on, when the app has no session yet.
- **Auth state.** `authStateProvider` streams Supabase auth events. Supabase
  stores the session on the device and restores it on launch, which is what
  gives auto-login.
- **Routing.** The router is created once. When the auth state changes, it
  re-runs its `redirect`: signed-out users can only visit Login, Sign up and
  Forgot password; signed-in users are moved off those screens. The splash
  screen shows until Supabase reports the initial session.
- **Onboarding.** After a successful sign-up the user lands on the onboarding
  placeholder; on later logins they go straight to Home.

## Known limitations

- **Finishing a password reset is not built.** The app sends the reset email,
  but there is no "set new password" screen and no deep-link setup (Android
  intent filter, iOS URL scheme) to bring the user back into the app from the
  link. Both are needed to complete the flow.
- **The onboarding flag is in memory only.** If the app is closed during
  onboarding, the user goes to Home next time.
- **`family_links` has no UI yet.** Its policies let only the elderly user
  create a link (naming a caregiver) and let either person read or remove it.
