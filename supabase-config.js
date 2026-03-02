// ============================================================
// SUPABASE CONFIGURATION — Ekonomikas Meistars
// ============================================================
//
// SETUP REQUIRED: Replace the two TODO values below with your
// real Supabase project credentials before using this file.
//
// WHERE TO FIND THEM:
//   1. Go to https://supabase.com → open your project
//   2. Sidebar → Settings → API
//   3. Copy "Project URL" and the "anon / public" key
//
// Full instructions: see README_SUPABASE.md
//
// ============================================================
//
// IMPORTANT — load order in index.html must be:
//   1. <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
//   2. <script src="supabase-config.js"></script>
//   3. (your existing app scripts)
//
// ============================================================

const SUPABASE_URL = 'TODO_REPLACE_WITH_YOUR_PROJECT_URL';
// Example: 'https://abcdefghijklmnop.supabase.co'

const SUPABASE_ANON_KEY = 'TODO_REPLACE_WITH_YOUR_ANON_KEY';
// Example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6...'

// ============================================================
// CLIENT INITIALIZATION
// ============================================================
// The global `supabase` object is injected by the CDN script above.
// If credentials are still placeholders, the client is set to null
// and all helper functions below will return a safe no-op error.

const _credentialsSet =
  SUPABASE_URL !== 'TODO_REPLACE_WITH_YOUR_PROJECT_URL' &&
  SUPABASE_ANON_KEY !== 'TODO_REPLACE_WITH_YOUR_ANON_KEY';

let supabaseClient = null;

if (!window.supabase) {
  console.warn(
    '[Supabase] CDN library not found. ' +
    'Add the CDN <script> tag to index.html before supabase-config.js.'
  );
} else if (!_credentialsSet) {
  console.warn(
    '[Supabase] Credentials are still TODO placeholders. ' +
    'Edit SUPABASE_URL and SUPABASE_ANON_KEY in supabase-config.js.'
  );
} else {
  supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  console.log('[Supabase] Client initialized successfully.');
}

// ============================================================
// HELPER: internal safe-call wrapper
// Returns {data: null, error: string} when the client is not ready,
// so callers never have to null-check supabaseClient themselves.
// ============================================================
function _notReady() {
  return { data: null, error: 'Supabase client not initialized — check credentials and CDN script.' };
}

// ============================================================
// TABLE: student_sessions
// One row per quiz attempt. Created at the start of a quiz,
// updated with the final score when the student finishes.
// ============================================================

/**
 * Create a new session row when a student starts the quiz.
 *
 * @param {object} params
 * @param {string} params.student_name     - First name
 * @param {string} params.student_surname  - Last name
 * @param {string} params.class_name       - e.g. "12.a"
 * @returns {Promise<{data: object|null, error: string|null}>}
 */
async function createStudentSession({ student_name, student_surname, class_name }) {
  if (!supabaseClient) return _notReady();

  return supabaseClient
    .from('student_sessions')
    .insert([{
      student_name,
      student_surname,
      class_name,
      started_at: new Date().toISOString()
    }])
    .select()
    .single();
}

/**
 * Close a session and persist the final result when the quiz ends.
 *
 * @param {string} sessionId        - UUID returned by createStudentSession
 * @param {object} params
 * @param {number} params.score         - Raw point total (0–420)
 * @param {number} params.total_xp      - XP equivalent (can equal score)
 * @param {number} params.level_reached - Highest level completed (1–3)
 * @returns {Promise<{data: object|null, error: string|null}>}
 */
async function completeStudentSession(sessionId, { score, total_xp, level_reached }) {
  if (!supabaseClient) return _notReady();

  return supabaseClient
    .from('student_sessions')
    .update({
      completed_at: new Date().toISOString(),
      score,
      total_xp,
      level_reached
    })
    .eq('id', sessionId)
    .select()
    .single();
}

// ============================================================
// TABLE: student_answers
// One row per question answered, linked to a session.
// ============================================================

/**
 * Persist a single question answer immediately after the student responds.
 *
 * @param {object} params
 * @param {string}  params.session_id    - UUID from createStudentSession
 * @param {string}  params.question_id   - e.g. "level1_q0", "level2_q3"
 * @param {string}  params.answer_given  - Stringified answer (index, "true"/"false", etc.)
 * @param {boolean} params.is_correct    - Whether the answer was correct
 * @param {number}  params.time_taken_ms - Milliseconds from question display to submission
 * @returns {Promise<{data: object|null, error: string|null}>}
 */
async function saveStudentAnswer({ session_id, question_id, answer_given, is_correct, time_taken_ms }) {
  if (!supabaseClient) return _notReady();

  return supabaseClient
    .from('student_answers')
    .insert([{
      session_id,
      question_id,
      answer_given: String(answer_given),
      is_correct,
      time_taken_ms,
      timestamp: new Date().toISOString()
    }]);
}

// ============================================================
// TABLE: leaderboard
// One row per unique student (name + surname + class).
// Updated on each completion — only best_score is promoted.
// ============================================================

/**
 * Insert or update a student's leaderboard entry.
 * Uses an upsert so the best score is preserved across multiple attempts.
 *
 * @param {object} params
 * @param {string}   params.student_name     - First name
 * @param {string}   params.student_surname  - Last name
 * @param {string}   params.class_name       - e.g. "12.a"
 * @param {number}   params.best_score       - Score from this attempt
 * @param {number}   params.total_xp         - XP from this attempt
 * @param {string}   params.badge_earned     - e.g. "Meistars", "Eksperts"
 * @returns {Promise<{data: object|null, error: string|null}>}
 */
async function upsertLeaderboard({ student_name, student_surname, class_name, best_score, total_xp, badge_earned }) {
  if (!supabaseClient) return _notReady();

  return supabaseClient
    .from('leaderboard')
    .upsert(
      [{
        student_name,
        student_surname,
        class_name,
        best_score,
        total_xp,
        badges_earned: [badge_earned],
        last_played: new Date().toISOString()
      }],
      // Conflict target must match the UNIQUE constraint in supabase_schema.sql
      { onConflict: 'student_name,student_surname,class_name' }
    );
}

/**
 * Fetch the top N leaderboard entries, sorted by best_score descending.
 *
 * @param {number} [limit=50]
 * @returns {Promise<{data: object[]|null, error: string|null}>}
 */
async function fetchLeaderboard(limit = 50) {
  if (!supabaseClient) return { data: [], error: null }; // Fail silently for read

  return supabaseClient
    .from('leaderboard')
    .select('student_name, student_surname, class_name, best_score, total_xp, badges_earned, last_played')
    .order('best_score', { ascending: false })
    .limit(limit);
}

// ============================================================
// TABLE: flashcard_progress
// Tracks how well each student knows each theory card.
// mastery_level: 0 = unseen, 1–2 = learning, 3–4 = familiar, 5 = mastered
// ============================================================

/**
 * Save or update a student's mastery level for a single flashcard.
 *
 * @param {object} params
 * @param {string} params.student_name     - First name
 * @param {string} params.student_surname  - Last name
 * @param {string} params.card_id          - e.g. "card_1", "card_2"
 * @param {string} params.deck_id          - e.g. "theory_naudas_faktori"
 * @param {number} params.mastery_level    - 0–5
 * @param {number} params.times_seen       - Cumulative open count
 * @returns {Promise<{data: object|null, error: string|null}>}
 */
async function upsertFlashcardProgress({ student_name, student_surname, card_id, deck_id, mastery_level, times_seen }) {
  if (!supabaseClient) return _notReady();

  return supabaseClient
    .from('flashcard_progress')
    .upsert(
      [{
        student_name,
        student_surname,
        card_id,
        deck_id,
        mastery_level,
        times_seen,
        last_seen: new Date().toISOString()
      }],
      { onConflict: 'student_name,student_surname,card_id,deck_id' }
    );
}

/**
 * Retrieve all flashcard progress records for a student.
 *
 * @param {string} student_name
 * @param {string} student_surname
 * @returns {Promise<{data: object[]|null, error: string|null}>}
 */
async function fetchFlashcardProgress(student_name, student_surname) {
  if (!supabaseClient) return { data: [], error: null }; // Fail silently for read

  return supabaseClient
    .from('flashcard_progress')
    .select('*')
    .eq('student_name', student_name)
    .eq('student_surname', student_surname);
}
