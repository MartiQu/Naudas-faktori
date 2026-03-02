-- ============================================================
-- Ekonomikas Meistars — Supabase Schema
-- Run this in your Supabase project → SQL Editor → New Query
-- ============================================================

-- 1. Student sessions (one row per play-through)
create table if not exists public.student_sessions (
  id         uuid primary key default gen_random_uuid(),
  student_name text not null,
  class_name   text,
  started_at   timestamptz not null default now(),
  completed_at timestamptz,
  score        integer default 0,
  total_xp     integer default 0,
  level_reached integer default 1,
  badges_earned jsonb default '[]'::jsonb
);

-- 2. Per-question answers (one row per answer event)
create table if not exists public.student_answers (
  id            uuid primary key default gen_random_uuid(),
  session_id    uuid references public.student_sessions(id) on delete cascade,
  question_id   text not null,          -- e.g. "l1_q0", "fc_deck1_c1_1"
  answer_given  text,                   -- JSON-stringified answer
  is_correct    boolean not null,
  time_taken_ms integer,                -- milliseconds from question shown to answered
  timestamp     timestamptz not null default now()
);

-- 3. Leaderboard (one row per student, upserted on each completion)
create table if not exists public.leaderboard (
  id           uuid primary key default gen_random_uuid(),
  student_name text not null unique,
  class_name   text,
  best_score   integer default 0,
  total_xp     integer default 0,
  badges_earned jsonb default '[]'::jsonb,
  last_played  timestamptz default now()
);

-- ============================================================
-- Indexes for common query patterns
-- ============================================================
create index if not exists idx_student_answers_session
  on public.student_answers(session_id);

create index if not exists idx_leaderboard_best_score
  on public.leaderboard(best_score desc);

create index if not exists idx_leaderboard_total_xp
  on public.leaderboard(total_xp desc);

-- ============================================================
-- Row Level Security (RLS) — allow anonymous inserts/reads
-- Enable this after creating the tables if you want open access
-- for a classroom setting (no auth required).
-- ============================================================
alter table public.student_sessions enable row level security;
alter table public.student_answers   enable row level security;
alter table public.leaderboard       enable row level security;

-- Allow anyone to insert sessions and answers (students play without login)
create policy "anon insert sessions"   on public.student_sessions for insert with check (true);
create policy "anon insert answers"    on public.student_answers   for insert with check (true);
create policy "anon update sessions"   on public.student_sessions for update using (true);

-- Leaderboard: anyone can read and upsert
create policy "anon read leaderboard"  on public.leaderboard for select using (true);
create policy "anon insert leaderboard" on public.leaderboard for insert with check (true);
create policy "anon update leaderboard" on public.leaderboard for update using (true);

-- Admins (authenticated users) can read all session data
create policy "auth read sessions"  on public.student_sessions for select using (auth.role() = 'authenticated');
create policy "auth read answers"   on public.student_answers   for select using (auth.role() = 'authenticated');

-- ============================================================
-- Realtime — enable for live leaderboard updates
-- ============================================================
-- Run in SQL Editor:
--   alter publication supabase_realtime add table public.leaderboard;
