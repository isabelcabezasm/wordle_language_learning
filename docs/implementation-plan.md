# Implementation Plan — Wordle for Vocabulary Learning

Status: Draft v0.1
Source: [requirements.md](requirements.md).

## 0. Timeline & ordering overview

| Phase | Name | Depends on | Est. | Milestone |
|---|---|---|---|---|
| P0 | Decisions, contract, threat model | – | 3 d | M0 |
| P1 | Repo scaffolding & tooling | P0 | 3 d | M0 |
| P2 | CI foundation (GitHub Actions) | P1 | 3 d | M0 |
| P3 | Word data & levels | P0, P1 (P2 for CI job) | 5 d | M1 |
| P4 | Backend game logic & API | P0, P3 | 8 d | M2 |
| P5 | Frontend board/keyboard/levels | P0, P1 (mock API; parallel to P3/P4) | 8 d | M3 |
| P6 | Integration, resume, stats, e2e | P4, P5 | 6 d | M4 |
| P7 | Accessibility & polish | P6 | 4 d | M5 |
| P8 | Security hardening | P4 (start), P6 (finish) | 4 d | M5 |
| P9 | Release & deploy (CD) | P2, P6, P8 (P7 for sign-off) | 4 d | M6 |

Ordering: P0 → P1 → P2 → {P3 ∥ P5} → P4 (needs P3) → P6 → {P7 ∥ P8} → P9. Every PR is code-reviewed throughout, with final sign-off at P9. CI (P2) is extended by each later phase (each phase lists its CI additions).

### Defaults used for open questions (from requirements §10)

| OQ | Default assumed | Plan items depending on it |
|---|---|---|
| OQ-1 | RESOLVED: attempts = word length + 1 (5→6 … 8→9) | P4-T3, P5-T2, tests with `maxAttempts` |
| OQ-2 | Accepted guesses = full word list of that language | P3-T3, P4-T4 (guess validation) |
| OQ-3 | RESOLVED: accent-insensitive typing; green tiles reveal the real accented letter (`letter` in API result); German `ß` = `ss` (length/attempts on normalised form) | P3-T2, P4-T1/T2, P5-T2/T3 (board, keyboard) |
| OQ-13 | `ß` green tiles stay as two `S` tiles (default); merge into `ß` is an option | P5-T2 |
| OQ-4 | One target language (Spanish proposed), UI/translation in English | P3-T1, P5-T8 (i18n), P6-T4 |
| OQ-5 | RESOLVED: word list in versioned JSON in repo; game state in memory (single instance, default) | P3-T1, P4-T5, P9 (no sticky/scale-out) |
| OQ-6 | 5 levels, data-driven, mixed lengths 5–8, CEFR-ish mapping | P3-T1/T5 |
| OQ-7 | Progressive unlock: 5 wins per level | P5-T4, P6-T3 |
| OQ-8 | Random word, repeats allowed once exhausted; no daily mode | P4-T3 |
| OQ-9 | Progress/stats in browser localStorage, no accounts | P6-T3 |
| OQ-10 | RESOLVED: deploy to **Azure**, resource group `wordle` (North Europe), using the logged-in subscription. Containers (Docker) → Azure Container Registry/GHCR; backend on Azure Container Apps; static frontend via Azure Static Web Apps or nginx container. | P9 entirely; P8-T6 (CORS origins/CSP) |
| OQ-11 | One language in first release; data model multi-language | P3, P4 |

Re-plan trigger: any OQ answer that differs from the default is raised for a decision; affected tasks above get re-estimated.

## 1. Proposed repo structure

```
.
├── backend/                 # Python (FastAPI proposed), src layout
│   ├── src/wordle_api/      # api/, game/ (evaluator, service), words/ (loader), config.py
│   ├── tests/               # unit/, api/, fixtures/ (shared evaluator cases)
│   └── pyproject.toml       # ruff/flake8, mypy, pytest, coverage config
├── frontend/                # Angular (standalone components, strict TS)
│   ├── src/app/             # core/ (api, state), features/ (board, keyboard, levels, stats, settings), shared/
│   ├── src/locale/          # UI string catalogs
│   └── e2e/                 # Playwright
├── data/
│   ├── words/<lang>.json    # versioned word lists (NFC UTF-8)
│   ├── languages/<lang>.json# alphabet, keyboard layout, diacritics policy
│   ├── schema/              # JSON Schema
│   └── SOURCES.md           # provenance & licences
├── docs/                    # requirements, implementation-plan, openapi.yaml, threat-model, contributor guide
├── .github/
│   ├── workflows/           # ci-backend, ci-frontend, ci-words, security, e2e, cd
│   ├── dependabot.yml, CODEOWNERS, pull_request_template.md
│   └── instructions/
├── docker/ (or Dockerfiles in backend/ and frontend/), docker-compose.yml
└── .squad/
```

## 2. Branching, PR & commit conventions

- Trunk-based: `main` protected; short-lived branches `feat/<id>-slug`, `fix/…`, `chore/…`, `docs/…` (id = task ID e.g. `p4-t3`).
- Conventional Commits; squash-merge; PR title follows the convention.
- PR template: linked task IDs, tests added, screenshots (UI), security/a11y checklist, OQ dependency noted.
- Every PR: CI green + **code review approval** (CODEOWNERS) + no unresolved conversations. Word-data PRs additionally require a data review; security-sensitive paths require a security review.
- Python: PEP 8, 79 cols, type hints, PEP 257 docstrings, test docstrings (per `.github/instructions/python-coding-conventions.instructions.md`). TS: official style guide, ESLint + Prettier.
- Versioning: SemVer tags `vX.Y.Z` on `main` drive releases.

---

## 3. Phases

### P0 — Decisions, API contract & threat model (M0)
**Goal:** Lock scope and contracts so teams can work in parallel.
**Dependencies:** none.

- [ ] P0-T1 Send OQ list for answers; record answers or confirm defaults in `.squad/decisions.md`.
- [ ] P0-T2 Write `docs/openapi.yaml` for `/api/v1` (languages, games, guesses, resume, health) incl. error model `{code, message}` and codes 400/404/409/422/429.
- [ ] P0-T3 Choose framework (FastAPI), Python version (3.12), Node/Angular LTS versions; pin them.
- [ ] P0-T4 Threat model: answer leakage (responses, logs, errors, bundle), enumeration of game ids, brute force of guesses, DoS.
- [ ] P0-T5 Word-list JSON schema + language config schema (§3.1/§3.3 of requirements).
- [ ] P0-T6 Test strategy & shared evaluator fixture format (table of answer/guess/expected).
- [ ] P0-T7 Review gate: contract and schemas approved.

**Tests:** P0-T6 defines fixture cases (ABBEY/BABES, triple letters, accents, 5 and 8 letters) before implementation (test-first).
**DoD:** OpenAPI lint-clean; decisions logged; schemas merged; review approved.

### P1 — Repo scaffolding & tooling (M0)
**Goal:** Empty but runnable skeletons with lint/test commands working locally.
**Dependencies:** P0.

- [ ] P1-T1 Repo layout (§1), `.editorconfig`, `.gitignore`, CODEOWNERS, PR template, issue templates, `README` quickstart.
- [ ] P1-T2 `backend/` skeleton: pyproject, ruff/flake8, mypy (strict), pytest + pytest-cov, `/health` endpoint.
- [ ] P1-T3 `frontend/` Angular skeleton: strict TS, standalone, ESLint (+ angular-eslint a11y rules), Prettier, test runner (Jest or Karma — decide), i18n set up, bundle budget in `angular.json` (<250 kB gz).
- [ ] P1-T4 Dockerfiles (multi-stage, non-root) and `docker-compose.yml` for local dev; pre-commit hooks.
- [ ] P1-T5 **Tests:** pytest smoke test for `/health`; Angular smoke test for `AppComponent`; coverage thresholds configured (fail-under) and wired in config.
- [ ] P1-T6 Review.

**Coverage targets:** thresholds configured now (backend ≥ 90 % game logic, ≥ 80 % overall; frontend ≥ 80 % lines), enforced from the phase that introduces the code.
**DoD:** `pytest`, `ruff`, `mypy`, `ng lint`, `ng test`, `ng build`, `docker compose up` all work from a clean clone.

### P2 — CI foundation with GitHub Actions (introduced right after scaffolding)
**Goal:** Automated gates on every PR before real code lands; extended by later phases.
**Dependencies:** P1. Extended in P3, P4, P5, P6, P8, P9.

Workflows (`.github/workflows/`), all triggered on `pull_request` and `push` to `main`, with `concurrency` cancel-in-progress and least-privilege `permissions: contents: read`; path filters per area (jobs still always report a status via a lightweight aggregator so required checks don't hang):

| Workflow | Jobs / steps | Matrix | Cache | Artifacts |
|---|---|---|---|---|
| `ci-backend.yml` | ruff/flake8 → mypy → `pytest --cov --cov-fail-under` | Python 3.11, 3.12 (3.12 canonical) | pip (`setup-python` cache) | `coverage.xml`, HTML report, junit XML |
| `ci-frontend.yml` | ESLint + Prettier check → unit tests w/ coverage → `ng build` (prod, budgets) | Node 20, 22 LTS | npm (`setup-node` cache) | coverage report, `dist/` build |
| `ci-words.yml` | Run word-list validator (schema, length 5–8, charset, duplicates, min 20/level, NFC) + validator unit tests | – | pip | validation report (JSON/markdown summary) |
| `security.yml` | `pip-audit`, `npm audit --omit=dev`, CodeQL (Python + JS/TS), secret scanning/gitleaks, Docker image scan (Trivy); weekly schedule too | – | – | SARIF uploads |
| `e2e.yml` (P6) | Build both, start via compose, Playwright | Chromium, WebKit (mobile + desktop viewports) | npm + Playwright browsers | traces, screenshots, videos on failure, HTML report |
| `cd.yml` (P9) | See P9 | – | Docker layer cache (buildx gha) | image digest, SBOM |
| `pr-gate.yml` | Aggregator job `ci-success` that `needs:` all required jobs; checks PR title (conventional commits) | – | – | – |

- [ ] P2-T1 `ci-backend.yml` and `ci-frontend.yml` (lint, type-check, test, build, caching, matrix, artifacts).
- [ ] P2-T2 `pr-gate.yml` aggregator + conventional-commit title check.
- [ ] P2-T3 `dependabot.yml` (pip, npm, github-actions, docker; weekly, grouped).
- [ ] P2-T4 `security.yml` baseline: CodeQL, dependency audit, secret scanning + push protection enabled in repo settings.
- [ ] P2-T5 Branch protection on `main`: required checks (`ci-success`), ≥1 approving review from a CODEOWNER, dismiss stale approvals, linear history, no force-push, conversation resolution.
- [ ] P2-T6 **Tests:** verify gates by opening a deliberately failing PR (lint error, failing test, coverage drop) and confirm it blocks; document in README.
- [ ] P2-T7 Review; confirm gate is enforced.

**DoD:** A PR to `main` cannot merge without green required checks and a code review approval; cache hit visible on second run; artifacts downloadable; Dependabot PRs appear.

### P3 — Word data & levels (M1)
**Goal:** Validated, licensed seed data and a loader.
**Dependencies:** P0 (schemas), P1; CI job needs P2. Depends on OQ-4/5/6/11.

- [ ] P3-T1 Seed list: 1 language (default Spanish), 5 levels (≥ 3 required for MVP), ≥ 20 words/level, lengths 5–8 mixed, with translation (EN) and hint; `data/words/es.json`.
- [ ] P3-T2 Language config `data/languages/<lang>.json` (es, de): alphabet, keyboard layout, accent policy (`ñ` distinct; vowels folded), `ß` → `ss` expansion, normalisation rules, per-position display-letter mapping. *(OQ-3)*
- [ ] P3-T3 Extra accepted-guess words (`valid_guess_only`) or confirm accepted list = word list. *(OQ-2)*
- [ ] P3-T4 Loader + validator module and CLI (`python -m wordle_api.words.validate`) enforcing §3.3; server start-up fails on invalid data.
- [ ] P3-T5 `data/SOURCES.md` (provenance/licences) and contributor guide (format, level criteria).
- [ ] P3-T6 **Tests (pytest):** valid fixture passes; each rule has a failing fixture (length 4/9, digits, hyphen, duplicate normalized, bad language code, level 0, level under minimum, non-NFC, char outside alphabet); normalisation tests (`é`→`E`, `ñ` preserved, case-insensitive, NFC vs NFD input); loader start-up failure test; real-data test that shipped lists pass.
- [ ] P3-T7 Wire `ci-words.yml` to run validator on every PR touching `data/`.
- [ ] P3-T8 Review (incl. licence check).

**Coverage:** loader/validator ≥ 95 %.
**CI added:** `ci-words.yml` required check.
**DoD:** Shipped data passes validation in CI; licences documented; data review sign-off.

### P4 — Backend game logic & API (M2)
**Goal:** Correct, secure server-side game per OpenAPI.
**Dependencies:** P0, P3. Depends on OQ-1/2/3/5/8.

- [ ] P4-T1 Normaliser: NFD fold, `ß` → `ss`, language exceptions, case-insensitive; length/attempts computed on the normalised form. Evaluator returns the real (accented) letter only for `correct` tiles. *(OQ-3)*
- [ ] P4-T1t **Tests (pytest):** `à`/`á`/`é`/`ñ` typed as base letter is accepted; green tile returns the real letter, present/absent tiles never leak it; `Straße` typed `strasse` → 7 tiles, 8 attempts; `ß` word length bounds (5 and 8 after expansion); validation rejects words whose normalised length is outside 5–8.
- [ ] P4-T2 Evaluator: two-pass algorithm with duplicate-letter handling; pure function, typed, documented.
- [ ] P4-T3 Game service: word selection per language/level (random, avoid seen, least-recent when exhausted), attempts (`maxAttempts = length + 1`), status transitions. *(OQ-1, OQ-8)*
- [ ] P4-T4 Guess validation: length (400), charset (400), not-in-list (422), repeat guess rejected, finished game (409), no attempt consumed on rejection. *(OQ-2)*
- [ ] P4-T5 Game store abstraction (in-memory with TTL/eviction; interface allows Redis later); ids = `secrets.token_urlsafe(32)`. *(OQ-5)*
- [ ] P4-T6 Endpoints `GET /languages`, `POST /games`, `POST /games/{id}/guesses`, `GET /games/{id}`, `GET /health`; consistent error model; OpenAPI served and diffed against `docs/openapi.yaml`.
- [ ] P4-T7 **Evaluator unit tests (pytest, parametrised from shared fixture):** all-correct; all-absent; ABBEY/BABES; guess with more copies than answer; fewer copies; triple letters; duplicates both correct and misplaced; lengths **5 and 8** (and 6, 7); accented answers vs unaccented guesses; `ñ` distinct; mixed case; empty/None/non-letter input handled.
- [ ] P4-T8 **Service tests:** win on attempt 1 and on the last attempt, lose after `length + 1` attempts with answer revealed, `maxAttempts == length + 1` for every length 5–8 (parametrized), invalid guesses don't consume attempts, repeat guess rejected, guess after finish → 409, word selection by level and length, exhaustion fallback, store TTL.
- [ ] P4-T9 **API tests (httpx/TestClient):** every endpoint and error code; **answer-not-leaked** assertions: scan all responses, headers and captured logs of an active game for the answer (and its accented form); answer present only when game ends; unknown id 404; id entropy ≥ 128 bits.
- [ ] P4-T10 Property-based tests (hypothesis): result length == word length; all-correct iff guess == normalised answer; count of non-absent per letter ≤ count in answer.
- [ ] P4-T11 Backend image build in CI; OpenAPI drift check job.
- [ ] P4-T12 Review (evaluator and leak tests scrutinised).

**Coverage:** ≥ 90 % on game logic (evaluator, normaliser, service) — enforced `--cov-fail-under`; ≥ 85 % overall backend.
**CI added:** coverage gate raised, OpenAPI drift check, Docker build.
**DoD:** All endpoints match contract; tests green incl. no-leak; mypy strict clean; line length ≤ 79.

### P5 — Frontend game board, keyboard & levels (M3)
**Goal:** Playable UI against a mock API (parallel with P3/P4).
**Dependencies:** P0 (OpenAPI → generated typed client / mock), P1. Depends on OQ-1/3/4/7.

- [ ] P5-T1 Core: typed API client (generated from OpenAPI), `GameStateService` (signals), error mapping, mock server (MSW/in-memory) for dev & tests.
- [ ] P5-T2 Board component: rows × columns from `length`/`maxAttempts`; fits 8 columns at 320 px; a green tile swaps the typed base letter for the real accented letter returned by the API (typed `a` → `á`). *(OQ-3, OQ-13)*
- [ ] P5-T2t **Tests (Angular):** tile shows base letter until green, then the real letter; present/absent tiles keep typed letter; `ß` word renders as two `S` tiles; aria-label includes real letter.
- [ ] P5-T3 On-screen keyboard (layout per language config) + physical keyboard handler; key state precedence correct > present > absent.
- [ ] P5-T4 Language/level selector with locked/unlocked states and upcoming word length. *(OQ-7)*
- [ ] P5-T5 Tile reveal animation (respect `prefers-reduced-motion`), shake + message on invalid guess.
- [ ] P5-T6 End-of-game panel: result, answer with diacritics, translation/hint, Next word / Change level.
- [ ] P5-T7 "How to play" dialog.
- [ ] P5-T8 UI string externalisation (EN catalog). *(OQ-4)*
- [ ] P5-T9 **Unit tests (Angular):**
  - Services: `GameStateService` (start, submit, win/lose transitions, input buffering limited to word length, backspace, no input after finish), key-state precedence reducer, API client error mapping (400/409/422/429/network), level-unlock logic.
  - Components: Board renders N×M for lengths 5 and 8; tile classes/ARIA labels; Keyboard emits keys, reflects states, syncs with physical keys; Level selector locked/unlocked; End panel shows answer/translation; reduced-motion disables animation.
- [ ] P5-T10 Frontend CI: coverage + bundle-budget enforcement.
- [ ] P5-T11 Review.

**Coverage:** ≥ 80 % lines/statements overall, ≥ 90 % for services/reducers.
**DoD:** Full game playable against the mock; lint/tests/build green; bundle < 250 kB gz.

### P6 — Integration, resume, stats & e2e (M4)
**Goal:** FE ↔ BE working end to end with persistence and e2e coverage.
**Dependencies:** P4, P5. Depends on OQ-7/9.

- [ ] P6-T1 Replace mock with real API; dev proxy; CORS config per environment.
- [ ] P6-T2 Resume in-progress game after reload (store `gameId`, `GET /games/{id}`); handle expired/unknown game gracefully (404 → new game).
- [ ] P6-T3 Local stats and progress: played, win %, streak, guess distribution, per language/level progress and unlock. *(OQ-7, OQ-9)*
- [ ] P6-T4 Translation/hint display wired from end-of-game response. *(OQ-4)*
- [ ] P6-T5 Network failure UX: retry, no attempt lost (idempotent client retry strategy to be agreed; document whether a guess POST is safely retryable).
- [ ] P6-T6 **Integration tests:** backend contract tests (Schemathesis or equivalent against OpenAPI); Angular integration tests with HttpTestingController for full guess flow; stats/progress/unlock calculations incl. localStorage corruption.
- [ ] P6-T7 **E2E (Playwright):** win; lose (answer revealed); invalid word (422, shake, no attempt consumed); wrong length; level switch and unlock; reload-resume; **5- and 8-letter games**; accented answer typed with base letters; duplicate-letter feedback visible; mobile viewport (320/375 px) and desktop; network failure and retry; assert answer never in network responses/bundle during an active game. Needs a deterministic test mode (seeded word selection via env flag, disabled in prod builds, security-reviewed).
- [ ] P6-T8 `e2e.yml`: docker-compose stack, Playwright cache, traces/screenshots/videos as artifacts; flaky-test retry = 1 with report; required check.
- [ ] P6-T9 Review.

**Coverage:** e2e covers all acceptance criteria (§9); combined unit coverage thresholds unchanged.
**CI added:** `e2e.yml` required.
**DoD:** MVP acceptance scenario passes in CI; no known leak; stats persist across reloads.

### P7 — Accessibility & polish (M5)
**Goal:** WCAG 2.1 AA, responsive, themed.
**Dependencies:** P6.

- [ ] P7-T1 Non-colour-only feedback (icons/patterns/text state), ARIA labels on tiles ("A, correct"), live region for results, focus management in dialogs.
- [ ] P7-T2 Colour-blind palette, high-contrast and dark mode; contrast ≥ 4.5:1; settings persisted. UI language selector (if >1 locale).
- [ ] P7-T3 Touch targets ≥ 44 px, 320 px layout checks, visible focus, full keyboard operability.
- [ ] P7-T4 Performance: FCP < 2 s on throttled mobile; lazy-load dialogs/stats.
- [ ] P7-T5 **Tests:** component tests for ARIA attributes and live-region content; settings service tests (persist/restore, theme application); axe-core checks in Playwright (zero serious/critical violations) across themes; keyboard-only e2e; reduced-motion e2e; Lighthouse CI budget (a11y ≥ 95, perf budget) as a non-blocking-then-blocking job.
- [ ] P7-T6 Manual screen-reader pass (NVDA/VoiceOver) with checklist recorded in `docs/`.
- [ ] P7-T7 Review.

**Coverage:** a11y-related components 100 % of ARIA behaviours asserted; overall thresholds hold.
**CI added:** axe in e2e job; Lighthouse CI job.
**DoD:** zero axe serious/critical issues; manual SR checklist done; contrast verified for all palettes.

### P8 — Security hardening (M5)
**Goal:** Mitigate threat-model items; verify no answer leak. Starts after P4 (backend items), completes after P6.
**Dependencies:** P0-T4, P4, P6. Depends on OQ-10 (origins/CSP).

- [ ] P8-T1 Rate limiting per IP and per game (429); request size limits; strict input validation (pydantic).
- [ ] P8-T2 Logging policy: structured logs, no answers, no request bodies of guesses tied to answers; error handlers never echo answer.
- [ ] P8-T3 CORS restricted to configured origin; security headers (CSP, HSTS, X-Content-Type-Options, Referrer-Policy, frame-ancestors) on API and frontend host.
- [ ] P8-T4 Review game-id entropy/expiry, enumeration, guess-brute-force limits (attempt cap enforced server-side), test-mode flag not enabled in prod, bundle scan for word data.
- [ ] P8-T5 Harden CI: pin actions by SHA, minimal permissions, CodeQL required, Trivy fail on high/critical, secrets scanning push protection, Dependabot security updates on.
- [ ] P8-T6 CSP and CORS values for chosen host. *(OQ-10)*
- [ ] P8-T7 **Tests:** rate-limit tests (429 after threshold, reset after window); oversize body → 413/422; malformed JSON; CORS preflight allowed/denied origins; security-header presence tests (API + built frontend served by container); log-capture test asserting answer absent; CI check that `dist/` contains no word-list files or answers; fuzz/negative inputs (unicode, null bytes, very long strings); brute-force test (attempt cap).
- [ ] P8-T8 Security sign-off report in `docs/security-review.md`.
- [ ] P8-T9 Review.

**Coverage:** security middleware ≥ 90 %.
**CI added:** dist-leak check, security-header test, SHA-pinned actions.
**DoD:** all threat-model items mitigated or accepted in writing; scans clean (no high/critical); security sign-off.

### P9 — Release & deploy (M6)
**Goal:** Reproducible, versioned deployment to staging and production.
**Dependencies:** P2, P6, P8 (P7 for final sign-off). **Hosting: Azure, resource group `wordle` (OQ-10 resolved).**

**Target:** Azure subscription already logged in via `az`; all resources go in resource group `wordle` (North Europe). Container images published to GHCR (or Azure Container Registry); staging auto-deployed from `main`, production deployed on `vX.Y.Z` tag with manual approval via GitHub Environments; backend on Azure Container Apps, frontend static files via Azure Static Web Apps or nginx container; single backend instance because game state is in memory (OQ-5). GitHub Actions authenticates to Azure with OIDC federated credentials (`azure/login`), no long-lived secrets stored.

- [ ] P9-T1 `cd.yml`: on `main` merge → build images (buildx, layer cache), run Trivy, generate SBOM, push to GHCR tagged by SHA; deploy to **staging**; smoke test (`/health`, one scripted game).
- [ ] P9-T2 Production job on tag `v*`: GitHub Environment `production` with required reviewer approval, OIDC credentials (no long-lived secrets), post-deploy smoke tests, automatic rollback on failure.
- [ ] P9-T3 `release.yml`: changelog from conventional commits, GitHub Release with artifacts (SBOM, coverage).
- [ ] P9-T4 Preview environments per PR (optional/if hosting permits).
- [ ] P9-T5 Monitoring: health check, basic uptime alert, structured-log aggregation, error alerting; runbook and rollback doc.
- [ ] P9-T6 **Tests:** post-deploy smoke test suite (health, languages, full game via API, headers) reused for staging/prod; Playwright e2e against staging (non-blocking nightly + blocking before prod promotion); rollback drill on staging.
- [ ] P9-T7 Acceptance walkthrough against requirements §9; open OQ review.
- [ ] P9-T8 Final sign-off.

**CI/CD secrets:** environment-scoped; none in repo (gitleaks enforced).
**DoD:** Tagged release deployed to production from CI; smoke tests green; rollback tested; runbook published; MVP acceptance (§9) signed off.

---

## 4. Testing summary by phase

| Phase | Test deliverables | Coverage target |
|---|---|---|
| P0 | Fixture format & cases defined | – |
| P1 | Smoke tests, thresholds configured | – |
| P2 | Gate verification PRs | – |
| P3 | Word-list validation, normalisation, loader tests | ≥ 95 % loader |
| P4 | Evaluator (dupes, 5/8 letters, accents), service, API, no-leak, property tests | ≥ 90 % game logic, ≥ 85 % backend |
| P5 | Angular service + component tests | ≥ 80 % (≥ 90 % services) |
| P6 | Contract, integration, Playwright e2e | all §9 criteria |
| P7 | ARIA component tests, axe, Lighthouse | 0 serious/critical axe |
| P8 | Rate-limit, CORS, headers, log/dist leak tests | ≥ 90 % security code |
| P9 | Smoke, staging e2e, rollback drill | – |

## 5. Risks

| # | Risk | Impact | Mitigation |
|---|---|---|---|
| R1 | Open questions answered differently (attempts, accents, levels) | Rework in evaluator/UI/data | Defaults flagged per task; isolate in config; OQ review at P0 |
| R2 | Answer leakage (responses, logs, bundle, test mode) | Core game broken | Leak tests in P4/P6/P8, dist scan, security review |
| R3 | Duplicate-letter / accent evaluation bugs | Wrong feedback | Shared fixtures, property tests, ≥ 90 % coverage |
| R4 | Word-list licensing/quality | Legal, poor learning value | SOURCES.md, licence review, CEFR criteria |
| R5 | In-memory state lost on restart / no scale-out | Games lost | Store abstraction; TTL; Redis later; single instance; client handles 404 |
| R6 | Azure setup (OIDC, resource provisioning) delays P9 | P9 slip | Container-first CD; provision infra early with IaC (Bicep) in resource group `wordle` |
| R7 | 8-column board on 320 px & a11y | Poor mobile UX | Early layout spike in P5; axe + viewport e2e |
| R8 | Flaky e2e / slow CI | Slower merges | Deterministic seeded mode, retries=1, caching, path filters |
| R9 | Rate limiting behind proxy misidentifies IPs | Over/under-blocking | Configure trusted proxy headers, test in staging |
| R10 | Supply-chain/dependency vulnerabilities | Security | Dependabot, audits, SHA-pinned actions, CodeQL |
| R11 | Review bottleneck | Delays | Small PRs, CODEOWNERS backup reviewer, PR size guideline (<400 LOC) |
| R12 | Scope creep (daily mode, accounts, hard mode) | Delay | Out-of-scope list (requirements §6); scope triage |

## 6. Cross-cutting Definition of Done (every task/PR)
Code and tests merged together; lint/type-check clean; coverage thresholds met; docs/OpenAPI updated; no secrets; code review approved; CI green.
