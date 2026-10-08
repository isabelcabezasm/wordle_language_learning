# Requirements — Wordle for Vocabulary Learning

Status: Draft v0.1

Items marked **[OQ-n]** are decisions pending in [Open questions](#10-open-questions). Until answered, the stated *default* is used.

## 1. Vision, goals, users

**Vision.** A Wordle-style web game (NYT Wordle rules) where players learn vocabulary in a new language by guessing words of 5–8 letters, progressing through levels.

**Goals**
- G1: Fun, familiar mechanics that make word-learning a daily habit.
- G2: Progressive difficulty via word levels.
- G3: Reinforce learning: show meaning/translation after each game.
- G4: Easy to maintain and extend word lists (new words, levels, languages).

**Target users:** language learners (beginner to intermediate), on mobile and desktop, who may not know the target word's spelling conventions (accents, etc.).

**Success measures (indicative):** completion rate per level, return rate, average attempts per level.

## 2. Game rules

| Rule | Requirement |
|---|---|
| Word length | 5–8 letters; each game's length is that of the secret word. Board columns = word length. |
| Attempts | Number of attempts = word length + 1 (5 letters → 6 attempts, 6 → 7, 7 → 8, 8 → 9). **(OQ-1 resolved).** |
| Feedback | Per letter: **green/correct** (right letter, right place), **yellow/present** (in word, wrong place), **gray/absent**. |
| Duplicates | Standard two-pass algorithm: (1) mark exact matches; (2) for remaining letters left→right, mark *present* only while unmatched copies of that letter remain in the answer; otherwise *absent*. E.g. answer `ABBEY`, guess `BABES` → B(present) A(present) B(correct) E(correct) S(absent). |
| Win | Guess equals the answer. Lose: all attempts used without a match; the answer is then revealed. |
| Guess length | A guess must be exactly the answer length; shorter submissions are rejected with a message (no attempt consumed). |
| Valid words | Guesses must be in the language's accepted-guess list (answers ∪ extra dictionary), as in Wordle; invalid → "Not in word list", no attempt consumed. Default: accepted list = full word list of that language **[OQ-2]**. |
| Case | Input is case-insensitive; normalised to a canonical case server-side. |
| Accents/diacritics | **Decided (OQ-3 resolved).** Matching is accent-insensitive: the player types base letters (`a` is correct for `à`/`á`). Once a tile is accepted as **green**, it is re-rendered with the real letter including its accent (e.g. typed `a` → tile shows `á`). The server returns the display letter for each correct tile (never for absent/present tiles, and never before the tile is green). Normalisation = Unicode NFD, strip combining marks, except language-specific letters configured as distinct (e.g. `ñ` in Spanish). |
| German `ß` | **Decided.** In German, `ß` is written and matched as `ss` (two letters/tiles). Word length (5–8) and attempts (length + 1) are counted on the normalised form, so `Straße` = `STRASSE` = 7 tiles, 8 attempts. Player types `ss`; the real `ß` is shown in the end-of-game panel (and on green tiles, see **[OQ-13]**). |
| Hard mode | Not in MVP. |
| Repeat guesses | Allowed to submit a previously used guess? Default: rejected, no attempt consumed. |

## 3. Levels and word list

### 3.1 Data model

| Field | Type | Req. | Notes |
|---|---|---|---|
| `id` | string/int | yes | Stable identifier |
| `word` | string | yes | Display form, with diacritics; 5–8 chars after normalisation |
| `normalized` | string | derived | Uppercase, accent-folded form used for matching (`ß` → `SS`); its length (5–8) defines tiles and attempts |
| `language` | ISO 639-1 code | yes | Language of the word |
| `level` | integer ≥ 1 | yes | 1 = easiest |
| `translation` | string | optional | In the learner's UI language (see [OQ-4]) |
| `hint` | string | optional | Definition/example sentence, shown after game (optionally as in-game hint, post-MVP) |
| `part_of_speech`, `tags` | string | optional | Future filtering |
| `valid_guess_only` | bool | optional | If true, word is accepted as a guess but never selected as an answer |

Storage for MVP: **JSON files** (decided), versioned in the repo, one file per language (e.g. `data/words/<lang>.json`), UTF-8 NFC, validated against a JSON Schema and loaded by the backend; no DB required. Game state storage remains **[OQ-5]**.

### 3.2 Levels and progression
- Levels are integers; number of levels is data-driven (default proposal: 5). Level is *not* tied to word length; each level may mix lengths 5–8 **[OQ-6]**.
- Player picks a language and a level. Level 1 is unlocked at start; level N+1 unlocks after completing a threshold of games in level N (default: 5 wins) **[OQ-7]**.
- Word selection: random from the level's words not yet *won/seen* by the player; when exhausted, repeat allowed (prefer least recently played). Optional daily-word mode is post-MVP **[OQ-8]**.
- Selection is server-side only.

### 3.3 Validation rules (enforced by a loader/CI check)
- Length 5–8 after normalisation; letters only (no spaces, digits, hyphens) unless configured.
- Valid language code and level ≥ 1; no duplicate (`language`, `normalized`) entries.
- Every level has a minimum number of words (default 20).
- Only characters of the language's alphabet; UTF-8, NFC-stored.
- Invalid data fails CI and server start-up.

### 3.4 Maintenance
For word data, changes go via pull request, validated by the CI check. Source/licensing of word lists must be documented (only use lists we may redistribute). A short contributor guide describes the file format and level criteria (frequency, difficulty, CEFR mapping **[OQ-6]**).

## 4. Functional requirements

### 4.1 Frontend (Angularl)
- FR-F1: Board renders rows × columns matching the secret word's length and attempts; re-renders per game.
- FR-F2: On-screen keyboard (layout per language, includes Enter/Backspace) and physical keyboard input; both stay in sync.
- FR-F3: Keyboard keys reflect best-known state (correct > present > absent).
- FR-F4: Tile reveal animation (respecting `prefers-reduced-motion`); shake + message on invalid guess.
- FR-F5: Language and level selector; show locked/unlocked levels and the word length of the upcoming game.
- FR-F6: End-of-game panel: win/lose message, the answer with diacritics (incl. `ß`), translation/hint, "Next word" and "Change level".
- FR-F6b: Green tiles display the real accented letter from the server response (typed `a` → `á`/`à`); non-green tiles keep the typed base letter. Accessible name of the tile includes the real letter.
- FR-F7: Stats and progress (local): games played, win %, streak, guess distribution, per level/language progress.
- FR-F8: Resume an in-progress game after reload.
- FR-F9: Settings: colour-blind palette, high contrast/dark mode, UI language.
- FR-F10: "How to play" dialog explaining the rules and colours.
- FR-F11: Error handling for network failure (retry, no attempt lost).

### 4.2 Backend (Python)
Framework to be selected (FastAPI proposed). Python version and tooling to be pinned in the repo.

- FR-B1: **Answer never leaves the server** while a game is active. Responses contain only per-letter results; the answer is returned only when the game ends.
- FR-B2: Server-side guess evaluation, validation and attempt counting.
- FR-B3: Word selection per language/level, per the rules in §3.2.
- FR-B4: Game state held server-side (in memory/Redis/DB **[OQ-5]**), keyed by an opaque game id.
- FR-B5: Stats may be client-side (MVP) or server-side with accounts (post-MVP) **[OQ-9]**.

**API sketch** (JSON, versioned `/api/v1`; documented via OpenAPI):

| Method & path | Purpose | Request | Response |
|---|---|---|---|
| `GET /languages` | Available languages and levels | – | `[{code, name, levels:[{level, wordCount}]}]` |
| `POST /games` | Start a game | `{language, level}` | `{gameId, length, maxAttempts}` |
| `POST /games/{id}/guesses` | Submit guess | `{guess}` | `{result:[{state: correct\|present\|absent, letter?}…], status: in_progress\|won\|lost, attemptsUsed}` (`letter` = real accented letter, only for `correct` tiles); on end also `{answer, translation, hint}` |
| `GET /games/{id}` | Resume | – | `{length, maxAttempts, guesses:[{guess,result}], status}` |
| `GET /health` | Liveness | – | `{status}` |

Errors: `400` wrong length/invalid chars, `404` unknown game, `409` game already finished, `422` word not in list (distinct error code, no attempt consumed), `429` rate-limited. Consistent error body `{code, message}`.

## 5. Non-functional requirements

### 5.1 Accessibility (WCAG 2.1 AA target)
- Feedback never colour-only: add icons/patterns/letters-state text; ARIA labels on tiles (e.g. "A, correct"), live region announcing results.
- Colour-blind palette option and high-contrast theme; contrast ≥ 4.5:1.
- Full keyboard operability, visible focus, screen-reader friendly dialogs, reduced-motion support.

### 5.2 Responsiveness
Mobile-first; usable from 320 px width; board for 8 columns fits without horizontal scroll; touch targets ≥ 44 px.

### 5.3 Performance
- First contentful paint < 2 s on mid-range mobile over 4G; guess API p95 < 200 ms.
- Initial bundle budget to be set (proposal: < 250 kB gzipped).
- Word list loaded once at server start, held in memory.

### 5.4 i18n
- UI strings externalised (Angular i18n or equivalent) from day one; the UI language is independent of the target (learned) language.
- Per-language config: alphabet, keyboard layout, diacritics policy, normalisation.
- MVP UI language(s) **[OQ-4]**.

### 5.5 Security
- Answer never in responses, logs, or error messages while active; no answer in client bundles.
- Input validation (length, charset) server-side; strict request size limits.
- Rate limiting per IP/game; CORS restricted to the frontend origin; security headers/CSP.
- Game ids unguessable (random ≥ 128 bits); no PII collected in MVP; dependency vulnerability scanning.
- Note: client-side-only checking is unacceptable, as it exposes answers.

### 5.6 Testing
- Backend: pytest unit tests for evaluator (duplicate-letter cases, accents, case), word-list validation, and API tests for all endpoints, including "answer not leaked" assertions. Coverage target ≥ 90 % on game logic.
- Frontend: unit tests (Jasmine/Karma or Jest) for board/keyboard/state; component tests for accessibility attributes.
- E2E (e.g. Playwright): win, lose, invalid word, level switch, mobile viewport, 5- and 8-letter games.
- Property/regression table of evaluator cases shared as fixtures.

### 5.7 CI/CD
- GitHub Actions: lint, type-check, tests, word-list validation, build, dependency/security scan on each PR; main branch protected.
- Containerised builds; deployed to Azure, resource group `wordle` (North Europe) **[OQ-10 resolved]**.
- Preview/staging environment desirable; versioned releases.

### 5.8 Code conventions
- **Python:** follow `.github/instructions/python-coding-conventions.instructions.md`: PEP 8, 79-column limit, type hints (`typing`), PEP 257 docstrings, small functions, comments on design decisions, explicit edge-case handling, unit tests with docstrings. Linting: flake8/ruff and mypy in CI.
- **Angular/TypeScript:** official style guide, strict TS, ESLint + Prettier, standalone components, accessibility lint rules.
- Conventional commits; code review approval required to merge.

## 6. Out of scope for MVP
- User accounts, cross-device sync, leaderboards, social sharing.
- Hard mode, timed mode, daily-word mode, multiplayer.
- Spaced repetition / review of missed words.
- In-game hints before game end, audio pronunciation, images.
- Admin UI for editing words; DB-backed word management.
- Native mobile apps, offline/PWA support.
- Right-to-left and non-alphabetic scripts.

## 7. Assumptions
- Single target language in MVP is acceptable, but the model supports many **[OQ-11]**.
- Word list is small enough (≤ tens of thousands) to hold in memory.
- Players are anonymous; progress stored in browser local storage.
- Latin-script languages only.
- Standard Wordle rules, except attempts = word length + 1; no hard mode.

## 8. Milestones (MVP)

| # | Milestone | Content |
|---|---|---|
| M0 | Foundations | Confirm open questions, API contract (OpenAPI), repo layout, word-list schema, threat model |
| M1 | Word data | Seed list for ≥ 1 language, ≥ 3 levels, loader + validation rules, sources/licensing |
| M2 | Backend core | Evaluator, game/session endpoints, word selection, error model, evaluator tests |
| M3 | Frontend core | Board, keyboards, level selector, feedback, end-of-game panel |
| M4 | Integration | Connect FE↔BE, resume, stats/progress, translations |
| M5 | Quality | Accessibility pass, colour-blind mode, E2E, security review (rate limit, CORS, no leak) |
| M6 | Delivery | CI/CD pipelines, deployment, monitoring |
| Continuous | Review & gatekeeping | Code review for every PR; final sign-off |

CI scaffolding starts in parallel with M1.

## 9. Acceptance (MVP)
A player can pick a level, play a 5–8 letter word with correct Wordle feedback (including duplicates), win or lose, see the answer with translation, resume after reload, and play with colour-blind mode on mobile; the answer is provably absent from all responses during an active game; CI is green.

## 10. Open questions
1. **[OQ-1] RESOLVED** — Attempts = word length + 1.
2. **[OQ-2]** Should guesses be restricted to our word list, or a broader dictionary of valid words per language? Where does it come from?
3. **[OQ-3] RESOLVED** — Accent-insensitive typing; green tiles show the real accented letter; German `ß` = `ss`.
4. **[OQ-4]** Which language(s) are being learned first, and in which language is the UI/translation shown (native language of the learners)?
5. **[OQ-5]** Word list storage: **RESOLVED — JSON files in the repo.** Still open: persistence for game state (memory vs Redis/DB)?
6. **[OQ-6]** How are levels defined (frequency, CEFR A1–C2, custom)? How many levels? Is word length tied to level?
7. **[OQ-7]** Level unlock rule: all levels open, or progressive unlocking (and with what threshold)?
8. **[OQ-8]** Random word on demand, or a daily word per level (or both)? Repeats allowed?
9. **[OQ-9]** Are accounts/server-side progress needed, or is browser-local progress enough for MVP?
10. **[OQ-10] RESOLVED** — Azure, resource group `wordle`. Still open: budget/SKU tier.
11. **[OQ-11]** Is the first release one language only, or multi-language from day one? Will the word list be supplied externally or created in-project?
12. **[OQ-13]** German `ß`: when the two `S` tiles turn green, should they stay as two `S` tiles (default) or visually merge into one `ß`? (Note: the real `ß` is always shown in the end-of-game panel.)
12. Branding/name, and any licensing constraints on the word data?
