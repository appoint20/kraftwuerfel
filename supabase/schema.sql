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
  is_admin boolean not null default false,
  is_premium boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "read own profile" on public.profiles;
create policy "read own profile" on public.profiles
  for select using (auth.uid() = id);

-- Profil automatisch bei der Registrierung anlegen (frei, nicht Admin)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
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

-- Nach erfolgreicher Zahlung / Upgrade (z. B. Apple Pay)
create or replace function public.upgrade_to_pro()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set is_premium = true
  where id = auth.uid();
end;
$$;

grant execute on function public.upgrade_to_pro() to authenticated;

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
-- Konto freischalten (im SQL-Editor ausführen, ersetze die E-Mail):
--
--   update public.profiles set is_premium = true where email = 'name@example.com';
--   update public.profiles set is_admin   = true where email = 'name@example.com';
-- ---------------------------------------------------------------------------
