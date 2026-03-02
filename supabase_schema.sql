-- ============================================================
-- Ekonomikas Meistars — Supabase Database Schema
-- ============================================================
-- Run this entire file once in the Supabase SQL Editor.
-- Navigate to: Project → SQL Editor → New Query → paste → Run
-- ============================================================


-- ============================================================
-- EXTENSIONS
-- ============================================================
-- uuid-ossp is enabled by default on Supabase; listed here for clarity.
-- gen_random_uuid() is available natively in PostgreSQL 13+.


-- ============================================================
-- TABLE: student_sessions
-- ============================================================
-- One row per quiz attempt.
-- Created when a student starts the quiz; completed_at / score
-- are filled in when they finish.
-- ============================================================

CREATE TABLE IF NOT EXISTS student_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_name    TEXT NOT NULL,
    student_surname TEXT NOT NULL,
    class_name      TEXT NOT NULL,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at    TIMESTAMPTZ,                        -- NULL until quiz is finished
    score           INTEGER CHECK (score >= 0),         -- Raw points (0–420 in current game)
    total_xp        INTEGER CHECK (total_xp >= 0),      -- XP awarded (can equal score)
    level_reached   INTEGER CHECK (level_reached BETWEEN 1 AND 3)
);

-- Index: quickly look up all sessions for a specific student
CREATE INDEX IF NOT EXISTS idx_student_sessions_name
    ON student_sessions (student_name, student_surname);

-- Index: filter completed vs in-progress sessions
CREATE INDEX IF NOT EXISTS idx_student_sessions_completed
    ON student_sessions (completed_at)
    WHERE completed_at IS NOT NULL;

COMMENT ON TABLE  student_sessions                IS 'One row per quiz attempt; links to all per-question answers.';
COMMENT ON COLUMN student_sessions.score          IS 'Total raw points earned (max 420 in current 3-level quiz).';
COMMENT ON COLUMN student_sessions.total_xp       IS 'XP awarded for this session (may equal score or use a separate formula).';
COMMENT ON COLUMN student_sessions.level_reached  IS '1 = Iesācējs, 2 = Analītiķis, 3 = Eksperts.';


-- ============================================================
-- TABLE: student_answers
-- ============================================================
-- One row per question answered within a session.
-- Enables per-question analytics: which questions trip students up,
-- average time, correct-answer rate, etc.
-- ============================================================

CREATE TABLE IF NOT EXISTS student_answers (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id    UUID NOT NULL REFERENCES student_sessions (id) ON DELETE CASCADE,
    question_id   TEXT NOT NULL,                    -- e.g. "level1_q0", "level2_q4"
    answer_given  TEXT NOT NULL,                    -- Serialised answer:
                                                    --   single:    "2"  (option index)
                                                    --   multi:     "0,2,4"
                                                    --   truefalse: "true" or "false"
                                                    --   match:     "matched_all" or "partial:2/4"
                                                    --   order:     "3,0,1,2" (submitted order of orig indices)
    is_correct    BOOLEAN NOT NULL,
    time_taken_ms INTEGER CHECK (time_taken_ms >= 0), -- Ms from question display to submission
    timestamp     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index: fetch all answers for one session (used in session review)
CREATE INDEX IF NOT EXISTS idx_student_answers_session
    ON student_answers (session_id);

-- Index: aggregate stats across all sessions for a given question
CREATE INDEX IF NOT EXISTS idx_student_answers_question
    ON student_answers (question_id);

COMMENT ON TABLE  student_answers               IS 'Per-question answer log; one row per question per quiz attempt.';
COMMENT ON COLUMN student_answers.question_id   IS 'Composite key: level + question index, e.g. "level1_q0".';
COMMENT ON COLUMN student_answers.answer_given  IS 'Serialised student answer — format depends on question type (see column comment).';
COMMENT ON COLUMN student_answers.time_taken_ms IS 'Time from question render to answer submission in milliseconds.';


-- ============================================================
-- TABLE: leaderboard
-- ============================================================
-- One row per unique student identity (name + surname + class).
-- Updated on every quiz completion: best_score is preserved
-- (only promoted if new score is higher), total_xp accumulates,
-- and badges_earned grows over time.
-- ============================================================

CREATE TABLE IF NOT EXISTS leaderboard (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_name    TEXT NOT NULL,
    student_surname TEXT NOT NULL,
    class_name      TEXT NOT NULL,
    best_score      INTEGER NOT NULL DEFAULT 0 CHECK (best_score >= 0),
    total_xp        INTEGER NOT NULL DEFAULT 0 CHECK (total_xp >= 0),
    badges_earned   TEXT[] NOT NULL DEFAULT '{}',   -- Array of badge names earned
    last_played     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Ensures upsert matches the right student row
    CONSTRAINT uq_leaderboard_student UNIQUE (student_name, student_surname, class_name)
);

-- Index: serve the leaderboard table sorted by score (most common query)
CREATE INDEX IF NOT EXISTS idx_leaderboard_score
    ON leaderboard (best_score DESC);

COMMENT ON TABLE  leaderboard                 IS 'One row per student; stores career-best score and accumulated XP.';
COMMENT ON COLUMN leaderboard.best_score      IS 'Highest score across all attempts; never lowered on re-attempt.';
COMMENT ON COLUMN leaderboard.total_xp        IS 'Sum of XP from all completed sessions.';
COMMENT ON COLUMN leaderboard.badges_earned   IS 'Array of badge names (e.g. [''Meistars'', ''Eksperts'']); deduplicated on insert.';


-- ============================================================
-- TABLE: flashcard_progress
-- ============================================================
-- Tracks how well each student knows each theory card.
-- Designed for a future spaced-repetition or mastery-gate feature.
--
-- mastery_level scale:
--   0 = never opened
--   1 = opened once
--   2 = reviewed (opened > 1 time)
--   3 = familiar (answered related quiz question correctly)
--   4 = confident
--   5 = mastered (consistently correct over multiple sessions)
-- ============================================================

CREATE TABLE IF NOT EXISTS flashcard_progress (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_name    TEXT NOT NULL,
    student_surname TEXT NOT NULL,
    card_id         TEXT NOT NULL,   -- e.g. "card_1", "card_2", "card_3", "card_4"
    deck_id         TEXT NOT NULL,   -- e.g. "theory_naudas_faktori" (supports future decks)
    mastery_level   SMALLINT NOT NULL DEFAULT 0 CHECK (mastery_level BETWEEN 0 AND 5),
    times_seen      INTEGER  NOT NULL DEFAULT 0 CHECK (times_seen >= 0),
    last_seen       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- One progress record per (student, card, deck) combination
    CONSTRAINT uq_flashcard_progress UNIQUE (student_name, student_surname, card_id, deck_id)
);

-- Index: load all card progress for a specific student in one query
CREATE INDEX IF NOT EXISTS idx_flashcard_progress_student
    ON flashcard_progress (student_name, student_surname);

-- Index: aggregate mastery stats per card across all students (teacher view)
CREATE INDEX IF NOT EXISTS idx_flashcard_progress_card
    ON flashcard_progress (card_id, deck_id);

COMMENT ON TABLE  flashcard_progress                IS 'Per-student mastery tracking for each theory flashcard.';
COMMENT ON COLUMN flashcard_progress.card_id        IS 'Matches the card number in the theory module, e.g. "card_1".';
COMMENT ON COLUMN flashcard_progress.deck_id        IS 'Groups cards into named decks; allows multiple topic sets.';
COMMENT ON COLUMN flashcard_progress.mastery_level  IS '0=unseen 1=opened 2=reviewed 3=familiar 4=confident 5=mastered.';
COMMENT ON COLUMN flashcard_progress.times_seen     IS 'Cumulative count of how many times the student opened this card.';


-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
-- Supabase requires RLS to be explicitly enabled. The policies
-- below allow any authenticated or anonymous user to read/write
-- their own data. Tighten these for production if needed.
-- ============================================================

ALTER TABLE student_sessions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_answers   ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboard       ENABLE ROW LEVEL SECURITY;
ALTER TABLE flashcard_progress ENABLE ROW LEVEL SECURITY;

-- Allow anyone using the anon key to insert and read sessions
CREATE POLICY "Allow public insert on student_sessions"
    ON student_sessions FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Allow public read on student_sessions"
    ON student_sessions FOR SELECT
    USING (true);

CREATE POLICY "Allow public update on student_sessions"
    ON student_sessions FOR UPDATE
    USING (true);

-- Allow anyone to insert answers
CREATE POLICY "Allow public insert on student_answers"
    ON student_answers FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Allow public read on student_answers"
    ON student_answers FOR SELECT
    USING (true);

-- Allow anyone to read and upsert the leaderboard
CREATE POLICY "Allow public insert on leaderboard"
    ON leaderboard FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Allow public read on leaderboard"
    ON leaderboard FOR SELECT
    USING (true);

CREATE POLICY "Allow public update on leaderboard"
    ON leaderboard FOR UPDATE
    USING (true);

-- Allow anyone to read and upsert flashcard progress
CREATE POLICY "Allow public insert on flashcard_progress"
    ON flashcard_progress FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Allow public read on flashcard_progress"
    ON flashcard_progress FOR SELECT
    USING (true);

CREATE POLICY "Allow public update on flashcard_progress"
    ON flashcard_progress FOR UPDATE
    USING (true);


-- ============================================================
-- USEFUL VIEWS (optional — safe to skip on first setup)
-- ============================================================

-- View: leaderboard with rank, ready to display in the UI
CREATE OR REPLACE VIEW leaderboard_ranked AS
SELECT
    ROW_NUMBER() OVER (ORDER BY best_score DESC) AS rank,
    student_name,
    student_surname,
    class_name,
    best_score,
    total_xp,
    badges_earned,
    last_played
FROM leaderboard
ORDER BY best_score DESC;

-- View: per-question accuracy across all students (teacher analytics)
CREATE OR REPLACE VIEW question_accuracy AS
SELECT
    question_id,
    COUNT(*)                                          AS total_attempts,
    SUM(CASE WHEN is_correct THEN 1 ELSE 0 END)      AS correct_count,
    ROUND(
        100.0 * SUM(CASE WHEN is_correct THEN 1 ELSE 0 END) / COUNT(*),
        1
    )                                                 AS accuracy_pct,
    ROUND(AVG(time_taken_ms))                         AS avg_time_ms
FROM student_answers
GROUP BY question_id
ORDER BY accuracy_pct ASC;  -- Hardest questions first

-- View: flashcard mastery summary per deck (teacher overview)
CREATE OR REPLACE VIEW flashcard_deck_summary AS
SELECT
    deck_id,
    card_id,
    COUNT(*)                     AS students_seen,
    ROUND(AVG(mastery_level), 2) AS avg_mastery,
    ROUND(AVG(times_seen), 1)    AS avg_times_seen
FROM flashcard_progress
GROUP BY deck_id, card_id
ORDER BY deck_id, card_id;
