# CLAUDE.md — Naudas-faktori (Ekonomikas Meistars)

## Project Overview

**Ekonomikas Meistars** ("Economics Master") is a gamified educational quiz platform for Latvian 12th-grade economics students. The application teaches money value, inflation/deflation, payment methods, and current global economic events through a structured theory + quiz progression.

- **Language:** All user-facing content is written in **Latvian**
- **Architecture:** Single-file web application — the entire app lives in `index.html`
- **No build tools:** No npm, bundler, or compilation step — serve the HTML directly

---

## Repository Structure

```
Naudas-faktori/
└── index.html    # Complete application (HTML + CSS + JavaScript, ~1350 lines)
```

There are no other source files, configuration files, or directories beyond `.git/`.

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Markup | HTML5 |
| Styling | CSS3 (custom) + Tailwind CSS 3.4.17 (CDN) |
| Logic | Vanilla JavaScript (ES6+) |
| Font | Space Grotesk via Google Fonts |
| Theming | Element SDK (`/_sdk/element_sdk.js`) |
| Data | Data SDK (`/_sdk/data_sdk.js`) for leaderboard persistence |

Both SDKs are served from `/_sdk/` and are injected at runtime — they are **not** included in the repository. Do not attempt to inline them or replace them.

---

## index.html Structure

The single file is divided into three logical sections:

1. **Head (lines ~1–268)** — meta tags, Tailwind CDN, SDK includes, all custom CSS (animations, component styles, color variables)
2. **Body (lines ~269–510)** — four screens, each controlled with `display: none` / `display: block` toggling:
   - `screen-registration` — player info entry
   - `screen-theory` — 4 collapsible theory cards
   - `screen-quiz` — 21-question quiz UI
   - `screen-results` — score breakdown + leaderboard
3. **JavaScript (lines ~512–1354)** — game state, question database, rendering functions, event handlers

---

## Game State

All runtime state is held in a single `gameState` object:

```javascript
let gameState = {
  currentScreen: 'registration',
  player: { name, surname, className },
  cardsRead: Set(),          // tracks which theory cards are read (0–4)
  currentLevel: 1,           // 1 = Beginner, 2 = Analyst, 3 = Expert
  currentQuestion: 0,        // index within current level (0–6)
  scores: { level1, level2, level3 },
  totalScore: 0,
  allResults: []             // leaderboard data from Data SDK
};
```

---

## Question Database

Questions are in a `const questions` object with three arrays:

```javascript
const questions = {
  level1: [ /* 7 questions, 10 pts each */ ],
  level2: [ /* 7 questions, 20 pts each */ ],
  level3: [ /* 7 questions, 30 pts each */ ]
};
```

**Five question types** are supported, each with a dedicated rendering function:

| Type | Renderer | Description |
|------|----------|-------------|
| `"single"` | `renderSingleChoice()` | One correct answer from options |
| `"multi"` | `renderMultiChoice()` | Multiple correct answers |
| `"truefalse"` | `renderTrueFalse()` | True / False selection |
| `"match"` | `renderMatch()` | Match pairs (left ↔ right) |
| `"order"` | `renderOrder()` | Drag-and-drop sequence ordering |

**When adding or editing questions**, preserve the existing structure for each type. Every question object must include `question`, `type`, `correctAnswer` (or `correctOrder` / `pairs`), and `explanation`.

---

## Scoring & Progression

| Level | Latvian name | Points per correct question | Max |
|-------|-------------|----------------------------|-----|
| 1 | Iesācējs (Beginner) | 10 | 70 |
| 2 | Analītiķis (Analyst) | 20 | 140 |
| 3 | Eksperts (Expert) | 30 | 210 |
| — | **Total** | — | **420** |

**Achievement badges** (displayed on results screen):

| Badge | Score range |
|-------|------------|
| 🥉 Iesācējs | 0–100 |
| 🥈 Analītiķis | 101–210 |
| 🥇 Eksperts | 211–330 |
| 💎 Ekonomists-Meistars | 331–420 |

---

## Theming / Configuration

The app supports runtime theming via Element SDK. Default values are defined in:

```javascript
const defaultConfig = {
  game_title: "Ekonomikas Meistars",
  primary_color: "#00D4FF",      // cyan
  secondary_color: "#FFD700",    // gold
  background_color: "#0A0E27",   // dark blue
  text_color: "#FFFFFF",
  surface_color: "#1a1f3a"
};
```

When the Element SDK loads it may override these values. Do not hard-code colours in new elements — reference CSS custom properties (`var(--primary-color)` etc.) or apply Tailwind classes that map to the theme.

---

## Data SDK & Leaderboard

The Data SDK provides backend persistence. Saved record shape:

```javascript
{
  name: string,
  surname: string,
  class_name: string,
  level1_points: number,   // 0–70
  level2_points: number,   // 0–140
  level3_points: number,   // 0–210
  total_points: number,    // 0–420
  badge: string,
  completion_date: string  // ISO 8601
}
```

The leaderboard is sorted descending by `total_points`. The Data SDK is limited to 999 stored results. Do not implement alternative storage (localStorage, cookies) without explicit instruction.

---

## Naming Conventions

| Context | Convention | Example |
|---------|-----------|---------|
| JS variables / functions | camelCase | `gameState`, `renderSingleChoice` |
| HTML element IDs | kebab-case | `btn-start`, `screen-quiz` |
| Backend data fields | snake_case | `total_points`, `class_name` |
| CSS custom classes | kebab-case | `.theory-card`, `.option-btn` |

---

## CSS Architecture

- **Tailwind utility classes** are the primary styling mechanism
- **Custom CSS** handles complex components: `.theory-card`, `.option-btn`, `.progress-bar`, `.match-item`, `.order-item`, etc.
- **Animations defined in `<style>`:** `float` (3 s), `pulseGlow` (2 s), `slideIn` (0.5 s), `shake` (0.4 s)
- **Responsive breakpoints:** `md:` prefix used for tablet/desktop variants

---

## Development Workflow

### Running the app

Open `index.html` directly in a modern browser. No server or build step is needed for basic development. To use the SDKs (theming, leaderboard), the file must be served from a host that provides `/_sdk/element_sdk.js` and `/_sdk/data_sdk.js`.

### Making changes

1. Edit `index.html` directly.
2. Hard-refresh the browser (`Ctrl+Shift+R`) to see changes.
3. There is no hot-reload or watch mode.

### No tests

There are no test files or test runners. When modifying game logic (scoring, question rendering, navigation), manually verify the full user flow:
- Registration → Theory (read all 4 cards) → Quiz (all 21 questions) → Results

---

## Git Workflow

- Active development branch: `claude/claude-md-mm8wmszh65jpsj09-GcYwN`
- Remote: `origin`
- Commit messages should be descriptive and in English
- Push with: `git push -u origin <branch-name>`

---

## Content Conventions

- All UI text is in **Latvian**
- Economic data references (ECB rates, inflation figures, tariff policies) are current as of **early 2026**
- When updating theory card content or question explanations, maintain consistency with other references within the file (e.g., if ECB deposit rate changes, update all mentions)
- Latvian decimal separator is a comma (`,`), but JavaScript computations use a period (`.`) — be mindful when displaying localised numbers

---

## Key Things to Avoid

- Do **not** introduce npm, a bundler, or a build step — the app must remain a single deployable HTML file
- Do **not** replace CDN references with local copies unless specifically asked
- Do **not** add a new screen without adding the corresponding `display:none` default in CSS and the navigation logic in JS
- Do **not** modify `/_sdk/` paths — they are resolved by the hosting platform
- Do **not** add question types without also adding a rendering function and a scoring handler for that type
