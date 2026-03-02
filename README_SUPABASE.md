# Supabase Setup Guide — Ekonomikas Meistars

This document walks you through connecting the app to a free Supabase database in four steps.

---

## What you will need

- A web browser
- A free Supabase account (no credit card required)
- About 10 minutes

---

## Step 1 — Create a free Supabase project

1. Open [https://supabase.com](https://supabase.com) and click **Start your project**.
2. Sign in with GitHub, Google, or email.
3. Click **New project**.
4. Fill in the form:
   | Field | What to enter |
   |---|---|
   | **Name** | `ekonomikas-meistars` (or anything you like) |
   | **Database password** | Choose a strong password and save it somewhere safe |
   | **Region** | Pick the closest region to your students (e.g. `eu-central-1` for Latvia) |
5. Click **Create new project** and wait about 60 seconds for provisioning to finish.

---

## Step 2 — Run the SQL schema

1. In your new project, click **SQL Editor** in the left sidebar.
2. Click **New query** (the `+` button).
3. Open the file `supabase_schema.sql` from this project folder and copy its entire contents.
4. Paste the contents into the SQL Editor.
5. Click the green **Run** button (or press `Ctrl+Enter` / `Cmd+Enter`).
6. You should see `Success. No rows returned` in the results panel.

This creates four tables, their indexes, Row Level Security policies, and three optional analytics views:

| Table | Purpose |
|---|---|
| `student_sessions` | One row per quiz attempt; stores start/end times and final score |
| `student_answers` | One row per question; stores what the student answered and whether it was correct |
| `leaderboard` | One row per unique student; preserves their career-best score |
| `flashcard_progress` | Tracks how many times each student has seen each theory card and their mastery level |

To verify the tables were created, click **Table Editor** in the sidebar — you should see all four tables listed.

---

## Step 3 — Copy your API credentials

1. In the left sidebar, click **Settings** (gear icon) → **API**.
2. Locate the two values you need:

   | Value | Where to find it | Looks like |
   |---|---|---|
   | **Project URL** | Under "Project URL" | `https://xxxxxxxxxxxx.supabase.co` |
   | **anon / public key** | Under "Project API keys" → `anon` `public` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` |

   > **Security note:** The `anon` key is safe to include in client-side code — it can only do what your Row Level Security policies allow. Never use the `service_role` key in the browser.

---

## Step 4 — Add credentials to the config file

1. Open `supabase-config.js` in this project folder.
2. Find the two `TODO` lines near the top and replace them:

   ```js
   // BEFORE
   const SUPABASE_URL  = 'TODO_REPLACE_WITH_YOUR_PROJECT_URL';
   const SUPABASE_ANON_KEY = 'TODO_REPLACE_WITH_YOUR_ANON_KEY';

   // AFTER (use your real values)
   const SUPABASE_URL  = 'https://xxxxxxxxxxxx.supabase.co';
   const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
   ```

3. Save the file.

---

## Step 5 — Add the CDN script to index.html

> This step modifies `index.html`. It should be done when you are ready to wire up the database.

Add **two** `<script>` tags inside `<head>`, **before** any existing `<script>` tags:

```html
<!-- Supabase JS client (CDN) -->
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<!-- App database configuration and helpers -->
<script src="supabase-config.js"></script>
```

Once these are in place, the helper functions in `supabase-config.js` are available globally to the rest of the app's JavaScript.

---

## Verifying the connection

After completing Steps 1–5, open the browser console (`F12` → Console tab) and reload the page. You should see:

```
[Supabase] Client initialized successfully.
```

If you see a warning instead, check:
- The two credential values are correct and have no extra spaces or quotes
- The CDN `<script>` tag appears **before** `supabase-config.js`
- Your Supabase project is active (not paused — free projects pause after 7 days of inactivity)

---

## Available helper functions

Once the client is initialised, these functions are available globally from `supabase-config.js`:

| Function | Table | When to call it |
|---|---|---|
| `createStudentSession(params)` | `student_sessions` | When the student clicks "Sākt spēli" |
| `completeStudentSession(id, params)` | `student_sessions` | When `finishGame()` runs |
| `saveStudentAnswer(params)` | `student_answers` | After each question is answered |
| `upsertLeaderboard(params)` | `leaderboard` | At game completion (alongside `completeStudentSession`) |
| `fetchLeaderboard(limit?)` | `leaderboard` | On the results screen to display rankings |
| `upsertFlashcardProgress(params)` | `flashcard_progress` | When a theory card is opened/closed |
| `fetchFlashcardProgress(name, surname)` | `flashcard_progress` | On the theory screen to restore card states |

All functions return `{ data, error }` — the Supabase standard response shape. When the client is not initialised they return a safe error object instead of throwing, so the game continues to work even without a database connection.

---

## Free tier limits

Supabase's free tier (as of 2025) includes:

| Resource | Limit |
|---|---|
| Database size | 500 MB |
| Monthly API requests | 2 million |
| Concurrent connections | 60 |
| Project pause | After 7 days of inactivity |

For a classroom app with a few dozen students these limits are very generous. To prevent pausing, either upgrade to the Pro plan or ping the project periodically.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `[Supabase] CDN library not found` | CDN script tag missing or in wrong order | Add it before `supabase-config.js` in `<head>` |
| `[Supabase] Credentials are still TODO placeholders` | Config file not edited | Replace both `TODO_REPLACE_...` values |
| `Failed to fetch` errors in console | Project is paused | Log in to Supabase and click Resume on the project |
| `violates row-level security policy` | RLS policies missing | Re-run `supabase_schema.sql` fully |
| Data saves but leaderboard upsert silently fails | Unique constraint missing | Check that `CONSTRAINT uq_leaderboard_student` exists in the `leaderboard` table |
