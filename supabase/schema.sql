-- =============================================================================
-- Database schema for the Major Project app.
--
-- Run this once in the Supabase dashboard: SQL Editor -> New query -> paste ->
-- Run. It is safe to run again; existing tables and data are left alone and
-- the policies, function and trigger are recreated.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- users: one profile row per auth account.
-- -----------------------------------------------------------------------------
create table if not exists public.users (
  id            uuid primary key references auth.users (id) on delete cascade,
  name          text not null,
  role          text not null check (role in ('elderly', 'caregiver')),
  phone         text,
  language_pref text not null default 'en',
  -- timestamptz rather than plain timestamp: it stores an absolute moment, so
  -- the value means the same thing regardless of server or client time zone.
  created_at    timestamptz not null default now()
);

alter table public.users enable row level security;

-- Each user can see and change only their own row. `(select auth.uid())` is
-- written as a subquery so Postgres evaluates it once per query, not per row.
drop policy if exists "users: read own row" on public.users;
create policy "users: read own row"
  on public.users for select
  to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "users: insert own row" on public.users;
create policy "users: insert own row"
  on public.users for insert
  to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists "users: update own row" on public.users;
create policy "users: update own row"
  on public.users for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- There is deliberately no delete policy: rows are removed only when the auth
-- account is deleted (on delete cascade above).


-- -----------------------------------------------------------------------------
-- Create the users row automatically when someone signs up.
--
-- The app sends `name` and `role` as sign-up metadata. Creating the row here,
-- inside the same transaction as the auth account, means it works even when
-- "Confirm email" is on (in which case the app has no session yet, so it could
-- not insert the row itself past RLS). If `role` is missing or invalid the
-- insert fails and so does the sign-up, rather than creating a half-set-up
-- account.
-- -----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.users (id, name, role, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    new.raw_user_meta_data ->> 'role',
    new.raw_user_meta_data ->> 'phone'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- -----------------------------------------------------------------------------
-- family_links: connects an elderly user to a caregiver.
-- -----------------------------------------------------------------------------
create table if not exists public.family_links (
  id           uuid primary key default gen_random_uuid(),
  elderly_id   uuid not null references public.users (id) on delete cascade,
  caregiver_id uuid not null references public.users (id) on delete cascade,
  created_at   timestamptz not null default now(),
  constraint family_links_no_self_link check (elderly_id <> caregiver_id),
  constraint family_links_unique_pair unique (elderly_id, caregiver_id)
);

-- The unique constraint already indexes (elderly_id, ...); this covers lookups
-- by caregiver.
create index if not exists family_links_caregiver_id_idx
  on public.family_links (caregiver_id);

alter table public.family_links enable row level security;

-- Either person in a link can see it.
drop policy if exists "family_links: read own links" on public.family_links;
create policy "family_links: read own links"
  on public.family_links for select
  to authenticated
  using (
    (select auth.uid()) = elderly_id
    or (select auth.uid()) = caregiver_id
  );

-- Only the elderly user can create a link, naming the caregiver. That way
-- nobody can attach themselves to someone else as their caregiver. If you'd
-- rather have caregivers send link requests, change this policy (an approval
-- step would then be needed before a link grants any access).
drop policy if exists "family_links: elderly user creates link" on public.family_links;
create policy "family_links: elderly user creates link"
  on public.family_links for insert
  to authenticated
  with check ((select auth.uid()) = elderly_id);

-- Either person can end a link. Links are not edited, so there is no update
-- policy.
drop policy if exists "family_links: either side removes link" on public.family_links;
create policy "family_links: either side removes link"
  on public.family_links for delete
  to authenticated
  using (
    (select auth.uid()) = elderly_id
    or (select auth.uid()) = caregiver_id
  );
