create table if not exists public.nutrition_kv (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  key text not null check (key like 'nutri\_%' and length(key) <= 80),
  value jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);

alter table public.nutrition_kv enable row level security;

drop policy if exists "Users read own nutrition" on public.nutrition_kv;
create policy "Users read own nutrition"
  on public.nutrition_kv for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users insert own nutrition" on public.nutrition_kv;
create policy "Users insert own nutrition"
  on public.nutrition_kv for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users update own nutrition" on public.nutrition_kv;
create policy "Users update own nutrition"
  on public.nutrition_kv for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users delete own nutrition" on public.nutrition_kv;
create policy "Users delete own nutrition"
  on public.nutrition_kv for delete to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.nutrition_kv from anon, authenticated;
grant select, insert, update, delete on public.nutrition_kv to authenticated;
