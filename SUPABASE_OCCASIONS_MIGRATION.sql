-- Manual Supabase migration for The Highlight meal/occasion grouping.
-- Run this in the Supabase SQL editor before using occasion features in the app.

create table if not exists public.occasions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    title text null,
    date date null,
    restaurant_name text null,
    formatted_address text null,
    latitude double precision null,
    longitude double precision null,
    created_at timestamptz not null default now()
);

alter table public.highlights
add column if not exists occasion_id uuid null references public.occasions(id) on delete set null;

create index if not exists occasions_user_created_at_idx
on public.occasions (user_id, created_at desc);

create index if not exists highlights_occasion_id_idx
on public.highlights (occasion_id);

alter table public.occasions enable row level security;

drop policy if exists "Occasions are selectable by owner" on public.occasions;
create policy "Occasions are selectable by owner"
on public.occasions
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Occasions are insertable by owner" on public.occasions;
create policy "Occasions are insertable by owner"
on public.occasions
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Occasions are updatable by owner" on public.occasions;
create policy "Occasions are updatable by owner"
on public.occasions
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Occasions are deletable by owner" on public.occasions;
create policy "Occasions are deletable by owner"
on public.occasions
for delete
to authenticated
using (auth.uid() = user_id);

-- Defense in depth: highlights should only point to occasions owned by the
-- same user. Existing highlight RLS policies remain responsible for deciding
-- who may insert or update highlight rows.
create or replace function public.ensure_highlight_occasion_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.occasion_id is not null and not exists (
        select 1
        from public.occasions
        where occasions.id = new.occasion_id
          and occasions.user_id = new.user_id
    ) then
        raise exception 'Highlight occasion must belong to the same user';
    end if;

    return new;
end;
$$;

drop trigger if exists ensure_highlight_occasion_owner_trigger on public.highlights;
create trigger ensure_highlight_occasion_owner_trigger
before insert or update of occasion_id, user_id
on public.highlights
for each row
execute function public.ensure_highlight_occasion_owner();
