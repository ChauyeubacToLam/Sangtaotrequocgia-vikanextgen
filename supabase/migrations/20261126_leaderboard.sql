create table if not exists public.leaderboard_members (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  nickname text not null check (char_length(btrim(nickname)) between 2 and 24),
  avatar text not null default 'head' check (avatar ~ '^[a-z_]{1,24}$'),
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.leaderboard_members enable row level security;

drop policy if exists "Users read own leaderboard membership" on public.leaderboard_members;
create policy "Users read own leaderboard membership"
  on public.leaderboard_members for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users join leaderboard" on public.leaderboard_members;
create policy "Users join leaderboard"
  on public.leaderboard_members for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users update own leaderboard membership" on public.leaderboard_members;
create policy "Users update own leaderboard membership"
  on public.leaderboard_members for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users leave leaderboard" on public.leaderboard_members;
create policy "Users leave leaderboard"
  on public.leaderboard_members for delete to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.leaderboard_members from anon, authenticated;
grant select, insert, update, delete on public.leaderboard_members to authenticated;

create or replace function public.leaderboard_week(p_board text, p_limit integer default 50)
returns table (
  rank integer,
  nickname text,
  avatar text,
  value integer,
  sessions integer,
  reps integer,
  is_me boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with bounds as (
    select (date_trunc('week', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh') as week_start
  ),
  rows as (
    select
      s.user_id,
      least(greatest(extract(epoch from (s.completed_at - s.started_at)), 0), 1800) as seconds,
      s.total_reps,
      s.form_score,
      s.exercise_id
    from public.exercise_sessions s
    join public.leaderboard_members m on m.user_id = s.user_id
    cross join bounds b
    where s.completed_at >= b.week_start
      and s.completed_at < b.week_start + interval '7 days'
      and coalesce(s.total_reps, 0) between 1 and 500
  ),
  active as (
    select
      user_id,
      round(sum(seconds) / 60.0)::integer as value,
      count(*)::integer as sessions,
      sum(total_reps)::integer as reps
    from rows
    group by user_id
  ),
  form as (
    select
      user_id,
      round(sum(form_score * total_reps)::numeric / sum(total_reps))::integer as value,
      count(*)::integer as sessions,
      sum(total_reps)::integer as reps
    from rows
    where exercise_id in ('squat', 'push_up', 'glute_bridge', 'plank')
      and form_score between 0 and 100
    group by user_id
    having count(*) >= 3 and sum(total_reps) >= 60
  ),
  picked as (
    select * from active where p_board = 'active'
    union all
    select * from form where p_board = 'form'
  ),
  ranked as (
    select
      (row_number() over (order by p.value desc, p.reps desc, m.joined_at))::integer as rank,
      m.nickname,
      m.avatar,
      p.value,
      p.sessions,
      p.reps,
      p.user_id = (select auth.uid()) as is_me
    from picked p
    join public.leaderboard_members m on m.user_id = p.user_id
  )
  select rank, nickname, avatar, value, sessions, reps, is_me
  from ranked
  where rank <= least(greatest(coalesce(p_limit, 50), 1), 100) or is_me
  order by rank;
$$;

revoke all on function public.leaderboard_week(text, integer) from public, anon;
grant execute on function public.leaderboard_week(text, integer) to authenticated;
