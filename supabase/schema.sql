-- KRAFTWÜRFEL — Supabase schema
-- Run once in the Supabase SQL editor (Dashboard -> SQL Editor -> New query).
-- Re-running is safe: every statement is idempotent.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Rollen
-- Ein Profil pro Konto. Nutzer dürfen ihr Profil lesen, aber nicht ändern —
-- sonst könnte sich jeder selbst zum Premium- oder Admin-Konto machen.
-- Freischalten passiert im SQL-Editor (siehe README).
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  email text,
  name text,
  is_admin boolean not null default false,
  is_premium boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "read own profile" on public.profiles;
create policy "read own profile" on public.profiles
  for select using (auth.uid() = id);

-- Nutzer dürfen ihren Namen ändern — sonst nichts. RLS regelt nur, WELCHE Zeile
-- jemand anfassen darf, nicht welche Spalten; dafür sind Spalten-Grants da.
-- Ohne diese Einschränkung setzt sich jeder mit zwei Zeilen in der Konsole
-- selbst auf is_premium/is_admin.
drop policy if exists "update own profile" on public.profiles;
create policy "update own name" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

revoke update on public.profiles from authenticated, anon;
grant update (name) on public.profiles to authenticated;

-- Zweite Sicherung, falls jemand später versehentlich wieder "grant all" schreibt:
-- Rollenspalten dürfen nur von der Service-Role (Edge Function) geändert werden.
create or replace function public.guard_profile_roles()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if current_setting('request.jwt.claims', true)::jsonb->>'role' is distinct from 'service_role' then
    if new.is_premium is distinct from old.is_premium
       or new.is_admin is distinct from old.is_admin then
      raise exception 'is_premium/is_admin kann nur serverseitig gesetzt werden';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_profile_roles on public.profiles;
create trigger guard_profile_roles
  before update on public.profiles
  for each row execute function public.guard_profile_roles();

-- Profil automatisch bei der Registrierung anlegen (inkl. Name)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1))
  )
  on conflict (id) do update set
    name = coalesce(excluded.name, public.profiles.name);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Admins gelten immer auch als Premium.
create or replace function public.is_premium(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select is_premium or is_admin from public.profiles where id = uid), false);
$$;

-- Es gibt bewusst KEINE Funktion, mit der ein Konto sich selbst freischaltet.
-- Wer Pro vergibt, ist entweder die Edge Function sync-entitlement (Testliste)
-- oder du im SQL-Editor:
--
--   update public.profiles set is_premium = true where email = 'name@example.com';
--
-- Eine frühere Version hatte hier upgrade_to_pro() — die konnte jeder
-- angemeldete Nutzer direkt aufrufen und war damit kein Bezahlschritt.
drop function if exists public.upgrade_to_pro();

-- ---------------------------------------------------------------------------
-- Daten
-- ---------------------------------------------------------------------------

-- Gespeicherte Einzelpläne (Generator -> "Plan speichern")
create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  name text not null,
  method text not null default 'standard',
  items jsonb not null,
  saved_at timestamptz not null default now()
);
create index if not exists plans_user_saved_at_idx on public.plans (user_id, saved_at desc);

-- Aktiver Mehrwochen-Trainingsplan: genau eine Zeile pro Nutzer
create table if not exists public.active_plans (
  user_id uuid primary key references auth.users on delete cascade,
  start_date timestamptz not null,
  duration int not null,
  days text[] not null,
  split text not null,
  method text not null,
  exercise_count int not null,
  rest_time int not null,
  day_plans jsonb not null,
  updated_at timestamptz not null default now()
);

-- Favorisierte Tagespläne (Trainingsplan-Tab -> Herz)
create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  day text not null,
  split text,
  method text,
  cycles jsonb not null,
  favorited_at timestamptz not null default now()
);
create index if not exists favorites_user_favorited_at_idx on public.favorites (user_id, favorited_at desc);

-- Protokoll der KI-Aufrufe. Jeder Aufruf kostet Geld, deshalb zählt die Edge
-- Function hierüber das Tageslimit pro Konto — und man sieht, was genutzt wird.
create table if not exists public.ai_generations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  model text not null,
  goal text,
  days int,
  created_at timestamptz not null default now()
);
create index if not exists ai_generations_user_created_idx on public.ai_generations (user_id, created_at desc);

alter table public.plans enable row level security;
alter table public.active_plans enable row level security;
alter table public.favorites enable row level security;
alter table public.ai_generations enable row level security;

drop policy if exists "read own generations" on public.ai_generations;
create policy "read own generations" on public.ai_generations
  for select using (auth.uid() = user_id);
drop policy if exists "premium logs generations" on public.ai_generations;
create policy "premium logs generations" on public.ai_generations
  for insert with check (auth.uid() = user_id and public.is_premium(auth.uid()));

-- Lesen und Löschen darf jeder für die eigenen Zeilen — wer Premium verliert,
-- kommt weiterhin an Gespeichertes heran und kann aufräumen.
-- Neu anlegen und ändern darf nur, wer Premium (oder Admin) ist.

drop policy if exists "own plans" on public.plans;
drop policy if exists "read own plans" on public.plans;
drop policy if exists "delete own plans" on public.plans;
drop policy if exists "premium writes plans" on public.plans;
drop policy if exists "premium updates plans" on public.plans;
create policy "read own plans" on public.plans
  for select using (auth.uid() = user_id);
create policy "delete own plans" on public.plans
  for delete using (auth.uid() = user_id);
create policy "premium writes plans" on public.plans
  for insert with check (auth.uid() = user_id and public.is_premium(auth.uid()));
create policy "premium updates plans" on public.plans
  for update using (auth.uid() = user_id) with check (public.is_premium(auth.uid()));

drop policy if exists "own active plan" on public.active_plans;
drop policy if exists "read own active plan" on public.active_plans;
drop policy if exists "delete own active plan" on public.active_plans;
drop policy if exists "premium writes active plan" on public.active_plans;
drop policy if exists "premium updates active plan" on public.active_plans;
create policy "read own active plan" on public.active_plans
  for select using (auth.uid() = user_id);
create policy "delete own active plan" on public.active_plans
  for delete using (auth.uid() = user_id);
create policy "premium writes active plan" on public.active_plans
  for insert with check (auth.uid() = user_id and public.is_premium(auth.uid()));
create policy "premium updates active plan" on public.active_plans
  for update using (auth.uid() = user_id) with check (public.is_premium(auth.uid()));

drop policy if exists "own favorites" on public.favorites;
drop policy if exists "read own favorites" on public.favorites;
drop policy if exists "delete own favorites" on public.favorites;
drop policy if exists "premium writes favorites" on public.favorites;
create policy "read own favorites" on public.favorites
  for select using (auth.uid() = user_id);
create policy "delete own favorites" on public.favorites
  for delete using (auth.uid() = user_id);
create policy "premium writes favorites" on public.favorites
  for insert with check (auth.uid() = user_id and public.is_premium(auth.uid()));

-- ---------------------------------------------------------------------------
-- Bestehende Konten nachtragen, die sich vor dem profiles-Trigger registriert
-- haben. Rollen bleiben dabei unangetastet — wer schon Pro hat, behält es,
-- alle anderen bleiben frei.
--
-- Eine frühere Version dieser Datei setzte hier is_premium und is_admin für
-- ALLE Konten auf true, bei jedem Lauf. Das hat die Bezahlschranke jedes Mal
-- aufgehoben, wenn jemand das Schema erneut ausgeführt hat.
-- ---------------------------------------------------------------------------
insert into public.profiles (id, email, name)
select
  id,
  email,
  coalesce(raw_user_meta_data->>'name', split_part(email, '@', 1))
from auth.users
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Ein Konto freischalten (im SQL-Editor, E-Mail ersetzen):
--
--   update public.profiles set is_premium = true where email = 'name@example.com';
--
-- Testkonten laufen bequemer über die Edge Function sync-entitlement:
--   supabase secrets set PRO_TEST_EMAILS="du@example.com,tester@example.com"
-- ---------------------------------------------------------------------------
