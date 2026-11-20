-- Vika baseline schema, rebuilt 2026-11-16 from the repository alone.
--
-- The previous Supabase project is not accessible, so nothing here was copied
-- from a live database. Sources, in priority order:
--   1. Client code under lib/ (every .from(), .storage and functions.invoke).
--   2. The three earlier migrations in this folder (their effect is included
--      here; they must not be applied alongside this file).
--   3. docs/reference/supabase-schema/supabase_schema_reference_v4_4.md.
--
-- Conventions:
--   * Every user-owned table has user_id -> auth.users(id) ON DELETE CASCADE,
--     so the delete-account edge function (auth.admin.deleteUser) removes the
--     whole user subtree. The old project pointed user_id at profiles(id);
--     auth.users is used here so a write can never fail only because the
--     profiles row has not been upserted yet (the client creates that row
--     itself; there is no signup trigger).
--   * RLS is on for every table. Policies target the `authenticated` role and
--     compare against auth.uid(). Table privileges are granted explicitly so
--     the file does not depend on the project's default grants.
--   * The client never issues DELETE, so no DELETE policy or grant exists.
--   * Lines marked GUESS have no proof in the repo; see the rebuild report.
--
-- The file is re-runnable: IF NOT EXISTS / DROP ... IF EXISTS throughout.

-- ════════════════════════════════════════════════════════════════════════
-- 1. profiles
-- ════════════════════════════════════════════════════════════════════════
-- Created by the client with upsert(onConflict: 'id'), often with only a
-- few keys, so every column is nullable or has a default.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  avatar_url text,
  fitness_level text
    check (fitness_level in ('beginner', 'intermediate', 'advanced')),
  goals text[],
  onboarding_complete boolean not null default false,
  subscription_status text not null default 'free'
    check (subscription_status in ('free', 'pro', 'cancelled')),
  subscription_expires_at timestamptz,
  -- The old project stored these two as text. timestamptz is returned by
  -- the API as an ISO-8601 string, which is what the client parses.
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  streak bigint not null default 0 check (streak >= 0),
  last_workout_at timestamptz,
  is_staff boolean not null default false,
  -- The client writes four values (s11_body_info.dart, profile_screen.dart);
  -- the old schema doc listed only male/female.
  gender text
    check (gender in ('male', 'female', 'other', 'prefer_not_to_say')),
  height_cm numeric check (height_cm between 100 and 250),
  weight_kg numeric check (weight_kg between 25 and 250),
  age integer check (age between 16 and 100),
  training_duration text,
  fork text check (fork in ('home', 'yoga')),
  schedule_sessions text[],
  -- Nullable on purpose: onboarding upserts an explicit NULL when empty.
  problem_resonance text[] default '{}'
);

-- Effect of 20260616_profiles_training_duration_v5_buckets.sql: the v5
-- onboarding buckets plus the three legacy values.
alter table public.profiles
  drop constraint if exists profiles_training_duration_check;
alter table public.profiles
  add constraint profiles_training_duration_check
  check (
    training_duration = any (
      array['<6m', '6m-2y', '2y+', '<3m', '3-11m', '1y+']
    )
  );

alter table public.profiles enable row level security;

drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
  on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Column-level write privileges: RLS limits WHICH row a user may write, not
-- which columns. Without this a signed-in user could set is_staff (unlocks
-- the in-app developer menu) or subscription_status on their own row. The
-- list below is exactly the set of columns the client writes. If a future
-- client version writes a new profiles column, add it here.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant
  insert (
    id, display_name, avatar_url, updated_at, gender, height_cm, weight_kg,
    age, goals, onboarding_complete, problem_resonance, training_duration,
    fork, fitness_level, schedule_sessions
  ),
  update (
    id, display_name, avatar_url, updated_at, gender, height_cm, weight_kg,
    age, goals, onboarding_complete, problem_resonance, training_duration,
    fork, fitness_level, schedule_sessions
  )
  on public.profiles to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- 2. exercise_catalog  (reference data, read-only for app users)
-- ════════════════════════════════════════════════════════════════════════
-- Shape follows ExerciseCatalogEntry.fromSupabase. The NOT NULL columns are
-- the ones that Dart code casts without a null check; a NULL there would
-- throw while the plan is being generated.

create table if not exists public.exercise_catalog (
  id text primary key,
  vietnamese_name text not null,
  english_name text not null,
  fork text not null check (fork in ('home', 'yoga', 'both')),
  body_regions text[] not null default '{}',
  muscle_groups text[] not null default '{}',
  difficulty_tier integer not null check (difficulty_tier between 1 and 3),
  goal_fit jsonb not null default '{}',
  pain_safe text[] not null default '{}',
  pain_contraindicated text[] not null default '{}',
  is_form_checked boolean not null default false,
  is_corrective boolean not null default false,
  corrective_for text[] not null default '{}',
  class_key text,
  video_url text,
  -- Read by tool/generate_exercise_catalog.dart, which rejects values < 1.
  base_sets integer not null default 3 check (base_sets >= 1),
  base_reps integer check (base_reps >= 1),
  base_seconds integer check (base_seconds >= 1),
  progression_from text references public.exercise_catalog (id),
  progression_to text references public.exercise_catalog (id),
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  max_reps_beginner integer,
  max_reps_intermediate integer,
  max_reps_advanced integer,
  max_seconds_beginner integer,
  max_seconds_intermediate integer,
  max_seconds_advanced integer,
  -- prescribeVolume() throws when a row has neither target.
  constraint exercise_catalog_has_volume_target
    check (base_reps is not null or base_seconds is not null)
);

alter table public.exercise_catalog enable row level security;

-- anon is included because tool/generate_exercise_catalog.dart reads this
-- table with the anon key and no user session.
drop policy if exists "Anyone can read the exercise catalog"
  on public.exercise_catalog;
create policy "Anyone can read the exercise catalog"
  on public.exercise_catalog for select to anon, authenticated
  using (true);

revoke all on public.exercise_catalog from anon, authenticated;
grant select on public.exercise_catalog to anon, authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- 3. recommendations_log  (one row per generated plan)
-- ════════════════════════════════════════════════════════════════════════
-- Includes the effect of 20260518_recommendation_v44.sql and
-- 202605181630_recommendations_log_client_generation_policy.sql (lifecycle
-- columns, active-plan index, own-row select/insert/update).

create table if not exists public.recommendations_log (
  -- The client generates the uuid itself; the default only covers other
  -- writers.
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  generated_at timestamptz not null default now(),
  "trigger" text not null
    check ("trigger" in ('onboarding', 'reassessment', 'profile_change')),
  template_key text not null,
  plan_structure jsonb not null,
  algorithm_version text not null,
  rng_seed text,
  parameters jsonb not null default '{}',
  user_snapshot jsonb not null default '{}',
  superseded_at timestamptz,
  plan_started_at timestamptz,
  plan_completed_at timestamptz
);

create index if not exists idx_reco_log_user_active
  on public.recommendations_log (user_id, plan_completed_at)
  where plan_completed_at is null;
create index if not exists idx_reco_log_user_generated
  on public.recommendations_log (user_id, generated_at desc);

alter table public.recommendations_log enable row level security;

drop policy if exists "Users can read own recommendations"
  on public.recommendations_log;
create policy "Users can read own recommendations"
  on public.recommendations_log for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own recommendations"
  on public.recommendations_log;
create policy "Users can insert own recommendations"
  on public.recommendations_log for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own recommendation lifecycle"
  on public.recommendations_log;
create policy "Users can update own recommendation lifecycle"
  on public.recommendations_log for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on public.recommendations_log from anon, authenticated;
grant select, insert, update on public.recommendations_log to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- 4. workout_sessions  (one row per planned session that was started)
-- ════════════════════════════════════════════════════════════════════════
-- Not in the schema doc and not in any earlier migration. Columns come from
-- SessionPersistence; every type here is inferred from the Dart value that
-- is written or read. completed_at must stay NULL until the summary is
-- frozen: the client treats "completed_at is not null" as "session done".

create table if not exists public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  recommendation_id uuid
    references public.recommendations_log (id) on delete set null,
  week_number integer,
  session_index integer,
  started_at timestamptz not null default now(), -- GUESS: never read or written by the client
  completed_at timestamptz,
  raw_form_score integer,
  session_form_score integer,
  total_reps integer,
  total_good_reps integer,
  total_calories integer,
  total_duration_seconds integer,
  coach_note jsonb,
  summary_version text
);

create index if not exists idx_workout_sessions_user_completed
  on public.workout_sessions (user_id, completed_at desc);
create index if not exists idx_workout_sessions_user_plan_week
  on public.workout_sessions (user_id, recommendation_id, week_number);

alter table public.workout_sessions enable row level security;

drop policy if exists "Users can read own workout sessions"
  on public.workout_sessions;
create policy "Users can read own workout sessions"
  on public.workout_sessions for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own workout sessions"
  on public.workout_sessions;
create policy "Users can insert own workout sessions"
  on public.workout_sessions for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own workout sessions"
  on public.workout_sessions;
create policy "Users can update own workout sessions"
  on public.workout_sessions for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on public.workout_sessions from anon, authenticated;
grant select, insert, update on public.workout_sessions to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- 5. exercise_sessions  (one row per exercise performed)
-- ════════════════════════════════════════════════════════════════════════
-- exercise_id is deliberately NOT a foreign key to exercise_catalog: the
-- old schema had none, and the id written is whatever the launch path
-- carries, which is not guaranteed to be a catalog id.

create table if not exists public.exercise_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  exercise_id text not null,
  started_at timestamptz not null default now(),
  -- The client never writes completed_at; it relies on this default and
  -- then sorts and filters on the column.
  completed_at timestamptz not null default now(),
  form_score integer,
  total_reps integer,
  total_good_reps integer,
  total_sets integer,
  calories integer,
  fault_counts jsonb not null default '{}',
  difficulty_ratings text[],
  set_data jsonb,
  created_at timestamptz not null default now(),
  issue_shown text,
  issue_response text,
  interpreter_output jsonb,
  device_fps smallint,
  app_version text,
  overall_difficulty text
    check (overall_difficulty in ('light', 'medium', 'heavy')),
  recommendation_id uuid
    references public.recommendations_log (id) on delete set null,
  slot_name text,
  workout_session_id uuid
    references public.workout_sessions (id) on delete set null
);

create index if not exists idx_exercise_sessions_user_exercise_completed
  on public.exercise_sessions (user_id, exercise_id, completed_at desc);
create index if not exists idx_exercise_sessions_user_completed
  on public.exercise_sessions (user_id, completed_at desc);
create index if not exists idx_exercise_sessions_user_plan
  on public.exercise_sessions (user_id, recommendation_id);
create index if not exists idx_exercise_sessions_workout
  on public.exercise_sessions (workout_session_id);

alter table public.exercise_sessions enable row level security;

drop policy if exists "Users can read own exercise sessions"
  on public.exercise_sessions;
create policy "Users can read own exercise sessions"
  on public.exercise_sessions for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own exercise sessions"
  on public.exercise_sessions;
create policy "Users can insert own exercise sessions"
  on public.exercise_sessions for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own exercise sessions"
  on public.exercise_sessions;
create policy "Users can update own exercise sessions"
  on public.exercise_sessions for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on public.exercise_sessions from anon, authenticated;
grant select, insert, update on public.exercise_sessions to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- 6. user_pain_areas
-- ════════════════════════════════════════════════════════════════════════
-- body_region uses the vocabulary in lib/models/pain_regions.dart:
-- shoulder_neck, back, lower_back, hip, wrist, knee, ankle, other. The same
-- strings are matched against exercise_catalog.pain_contraindicated when a
-- plan is generated, so the two vocabularies must stay identical.

create table if not exists public.user_pain_areas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  body_region text not null,
  source text not null default 'self_reported'
    check (source in ('self_reported', 'confirmed')),
  status text not null default 'active'
    check (status in ('active', 'resolved', 'escalated')),
  intensity integer check (intensity between 1 and 5),
  first_flagged_at timestamptz not null default now(),
  last_reaffirmed_at timestamptz not null default now(),
  resolved_at timestamptz,
  escalated_at timestamptz,
  improvement_signal_count integer not null default 0,
  reask_count integer not null default 0,
  notes text,
  flag_count integer not null default 1
);

-- GUESS: at most one active row per user and region. The client assumes it
-- (it reads the active row with maybeSingle(), which errors on two rows).
create unique index if not exists uq_user_pain_areas_active_region
  on public.user_pain_areas (user_id, body_region)
  where status = 'active';
create index if not exists idx_user_pain_areas_user_status
  on public.user_pain_areas (user_id, status);

alter table public.user_pain_areas enable row level security;

drop policy if exists "Users can read own pain areas"
  on public.user_pain_areas;
create policy "Users can read own pain areas"
  on public.user_pain_areas for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own pain areas"
  on public.user_pain_areas;
create policy "Users can insert own pain areas"
  on public.user_pain_areas for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own pain areas"
  on public.user_pain_areas;
create policy "Users can update own pain areas"
  on public.user_pain_areas for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on public.user_pain_areas from anon, authenticated;
grant select, insert, update on public.user_pain_areas to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- 7. user_detected_issues  (camera-detection log)
-- ════════════════════════════════════════════════════════════════════════

create table if not exists public.user_detected_issues (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  session_id uuid references public.exercise_sessions (id) on delete set null,
  exercise_id text,
  issue_id text,
  body_region text not null,
  source text not null default 'camera'
    check (source in ('self_reported', 'camera')),
  confidence double precision,
  priority integer not null default 99,
  trigger_reason text,
  trigger_rep_numbers integer[],
  trigger_metric_values jsonb,
  trigger_thresholds jsonb,
  cofire_context jsonb,
  interpreter_version text,
  app_version text,
  detected_at timestamptz not null default now(),
  asked_at timestamptz,
  expires_at timestamptz,
  response text check (response in ('yes', 'no')),
  reported_severity integer check (reported_severity between 1 and 5),
  aggravated_by_exercise boolean,
  status text not null default 'queued'
    check (status in ('queued', 'asked', 'confirmed', 'declined', 'expired'))
);

create index if not exists idx_user_detected_issues_user_status
  on public.user_detected_issues (user_id, status);

alter table public.user_detected_issues enable row level security;

drop policy if exists "Users can read own detected issues"
  on public.user_detected_issues;
create policy "Users can read own detected issues"
  on public.user_detected_issues for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own detected issues"
  on public.user_detected_issues;
create policy "Users can insert own detected issues"
  on public.user_detected_issues for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own detected issues"
  on public.user_detected_issues;
create policy "Users can update own detected issues"
  on public.user_detected_issues for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on public.user_detected_issues from anon, authenticated;
grant select, insert, update on public.user_detected_issues to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- 8. user_exercise_capacity  (from 20260518_recommendation_v44.sql)
-- ════════════════════════════════════════════════════════════════════════
-- The composite primary key is required by
-- upsert(onConflict: 'user_id,exercise_id').

create table if not exists public.user_exercise_capacity (
  user_id uuid not null references auth.users (id) on delete cascade,
  exercise_id text not null references public.exercise_catalog (id),
  target_hit_streak integer not null default 0 check (target_hit_streak >= 0),
  unlocked_next_id text references public.exercise_catalog (id),
  last_final_reps integer,
  last_final_rest_seconds integer,
  last_avg_difficulty text
    check (last_avg_difficulty in ('easy', 'hard', 'mixed')),
  last_was_deload boolean not null default false,
  last_session_at timestamptz,
  primary key (user_id, exercise_id)
);

alter table public.user_exercise_capacity enable row level security;

drop policy if exists "Users can read own exercise capacity"
  on public.user_exercise_capacity;
create policy "Users can read own exercise capacity"
  on public.user_exercise_capacity for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own exercise capacity"
  on public.user_exercise_capacity;
create policy "Users can insert own exercise capacity"
  on public.user_exercise_capacity for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own exercise capacity"
  on public.user_exercise_capacity;
create policy "Users can update own exercise capacity"
  on public.user_exercise_capacity for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on public.user_exercise_capacity from anon, authenticated;
grant select, insert, update on public.user_exercise_capacity to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- 9. weekly_checkins  (from 20260518_recommendation_v44.sql)
-- ════════════════════════════════════════════════════════════════════════
-- The unique constraint is required by
-- upsert(onConflict: 'user_id,recommendation_id,week_number').

create table if not exists public.weekly_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  recommendation_id uuid not null
    references public.recommendations_log (id) on delete cascade,
  week_number integer not null check (week_number between 1 and 7),
  phase_number integer not null check (phase_number between 1 and 3),
  responses jsonb not null,
  energy_score integer check (energy_score between 1 and 5),
  pain_flag boolean not null default false,
  difficulty_avg numeric,
  notes text,
  created_at timestamptz not null default now(),
  unique (user_id, recommendation_id, week_number)
);

alter table public.weekly_checkins enable row level security;

drop policy if exists "Users can read own weekly checkins"
  on public.weekly_checkins;
create policy "Users can read own weekly checkins"
  on public.weekly_checkins for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own weekly checkins"
  on public.weekly_checkins;
create policy "Users can insert own weekly checkins"
  on public.weekly_checkins for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own weekly checkins"
  on public.weekly_checkins;
create policy "Users can update own weekly checkins"
  on public.weekly_checkins for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on public.weekly_checkins from anon, authenticated;
grant select, insert, update on public.weekly_checkins to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- 10. fitness_retests  (from 20260518_recommendation_v44.sql)
-- ════════════════════════════════════════════════════════════════════════

create table if not exists public.fitness_retests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  recommendation_id uuid
    references public.recommendations_log (id) on delete set null,
  squat_reps integer check (squat_reps >= 0),
  wall_pushup_reps integer check (wall_pushup_reps >= 0),
  squat_form_score integer check (squat_form_score between 0 and 100),
  pushup_form_score integer check (pushup_form_score between 0 and 100),
  previous_level text
    check (previous_level in ('beginner', 'intermediate', 'advanced')),
  suggested_level text
    check (suggested_level in ('beginner', 'intermediate', 'advanced')),
  accepted_level text
    check (accepted_level in ('beginner', 'intermediate', 'advanced')),
  user_action text
    check (user_action in ('accepted', 'declined', 'no_change')),
  scoring_version text not null default 'v1',
  raw_scoring_input jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_fitness_retests_user_plan
  on public.fitness_retests (user_id, recommendation_id);

alter table public.fitness_retests enable row level security;

drop policy if exists "Users can read own fitness retests"
  on public.fitness_retests;
create policy "Users can read own fitness retests"
  on public.fitness_retests for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own fitness retests"
  on public.fitness_retests;
create policy "Users can insert own fitness retests"
  on public.fitness_retests for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own fitness retests"
  on public.fitness_retests;
create policy "Users can update own fitness retests"
  on public.fitness_retests for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on public.fitness_retests from anon, authenticated;
grant select, insert, update on public.fitness_retests to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- 11. fork_decisions  (onboarding audit row, insert-only from the client)
-- ════════════════════════════════════════════════════════════════════════
-- "override" is generated; the client does not send it for this table.

create table if not exists public.fork_decisions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  fork_recommended text not null check (fork_recommended in ('yoga', 'home')),
  raw_score numeric,
  confidence numeric,
  dominant_signal text,
  reason_text text,
  fork_chosen text not null check (fork_chosen in ('yoga', 'home')),
  "override" boolean generated always as (fork_chosen <> fork_recommended) stored,
  contribution_goal numeric,
  contribution_pain numeric,
  contribution_why numeric,
  contribution_duration numeric,
  algorithm_version text not null default 'v1.0'
);

create index if not exists idx_fork_decisions_user
  on public.fork_decisions (user_id);

alter table public.fork_decisions enable row level security;

drop policy if exists "Users can read own fork decisions"
  on public.fork_decisions;
create policy "Users can read own fork decisions"
  on public.fork_decisions for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own fork decisions"
  on public.fork_decisions;
create policy "Users can insert own fork decisions"
  on public.fork_decisions for insert to authenticated
  with check ((select auth.uid()) = user_id);

revoke all on public.fork_decisions from anon, authenticated;
grant select, insert on public.fork_decisions to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- 12. level_assessments  (onboarding audit row, insert-only from the client)
-- ════════════════════════════════════════════════════════════════════════
-- Not in the schema doc and not in any earlier migration. Columns come from
-- OnboardingPersistence._writeLevelAssessment; every type is inferred from
-- the Dart value. Here "override" is a plain column: the client sends it.

create table if not exists public.level_assessments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  fork text,
  training_duration text,
  duration_band text,
  recommended_level text,
  final_level text,
  "override" boolean,
  degraded boolean,
  degrade_threshold numeric,
  assessment_a_exercise text,
  assessment_a_clean_ratio numeric,
  assessment_a_good numeric,
  assessment_a_total numeric,
  assessment_b_exercise text,
  assessment_b_clean_ratio numeric,
  assessment_b_good numeric,
  assessment_b_total numeric,
  algorithm_version text
);

create index if not exists idx_level_assessments_user
  on public.level_assessments (user_id);

alter table public.level_assessments enable row level security;

drop policy if exists "Users can read own level assessments"
  on public.level_assessments;
create policy "Users can read own level assessments"
  on public.level_assessments for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own level assessments"
  on public.level_assessments;
create policy "Users can insert own level assessments"
  on public.level_assessments for insert to authenticated
  with check ((select auth.uid()) = user_id);

revoke all on public.level_assessments from anon, authenticated;
grant select, insert on public.level_assessments to authenticated;

-- ════════════════════════════════════════════════════════════════════════
-- 13. Storage: avatars bucket
-- ════════════════════════════════════════════════════════════════════════
-- UserProfileService uploads to '<user id>/avatar_<millis>.<ext>' with
-- upsert: true and then stores getPublicUrl(), so the bucket is public and
-- the owner needs insert + select + update on their own folder. Public URLs
-- do not go through RLS. The delete-account function removes the folder
-- with the service role.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  true,
  5242880, -- GUESS: 5 MB. The picker caps width at 1200 px, quality 88.
  array['image/jpeg', 'image/png', 'image/webp'] -- the three types the client sends
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users can read own avatar objects" on storage.objects;
create policy "Users can read own avatar objects"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users can upload own avatar objects" on storage.objects;
create policy "Users can upload own avatar objects"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users can replace own avatar objects" on storage.objects;
create policy "Users can replace own avatar objects"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Nothing else is needed by the client: it calls no RPC, subscribes to no
-- realtime channel, and expects no trigger (profiles rows are created by
-- the app, see isOnboardingComplete() in lib/main.dart).
