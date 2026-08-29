-- Oaks Finance 7.0 — Supabase setup
-- Run once in Supabase SQL Editor.

create table if not exists public.oaks_finance_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  client_modified_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.oaks_finance_state enable row level security;

-- Least privilege. Anonymous visitors cannot read financial data.
revoke all on table public.oaks_finance_state from anon;
grant select, insert, update on table public.oaks_finance_state to authenticated;

-- Recreate policies safely.
drop policy if exists "Users can read own Oaks Finance state" on public.oaks_finance_state;
drop policy if exists "Users can insert own Oaks Finance state" on public.oaks_finance_state;
drop policy if exists "Users can update own Oaks Finance state" on public.oaks_finance_state;

create policy "Users can read own Oaks Finance state"
on public.oaks_finance_state
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can insert own Oaks Finance state"
on public.oaks_finance_state
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update own Oaks Finance state"
on public.oaks_finance_state
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- Server timestamp for every insert/update.
create or replace function public.set_oaks_finance_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_oaks_finance_updated_at on public.oaks_finance_state;
create trigger trg_oaks_finance_updated_at
before insert or update on public.oaks_finance_state
for each row execute function public.set_oaks_finance_updated_at();

-- Enable Realtime for cross-device updates, only if not already added.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'oaks_finance_state'
  ) then
    alter publication supabase_realtime add table public.oaks_finance_state;
  end if;
end $$;
