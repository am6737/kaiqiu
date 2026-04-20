# Contributing to 开球 · GameOn

[中文](CONTRIBUTING.md) · **English**

Welcome. This guide is for both **internal team members** and **external contributors**.

Project overview, tech stack, directory layout, and how to run are in [README.en.md](README.en.md). This document only covers *how we collaborate*.

## Core principles

- **Small commits** — one PR solves one thing; easy to review and revert
- **Tests first** — changes to logic layers (`services/` / `repositories/` / `models/`) require new or updated tests
- **Design first** — new features and refactors touching 3+ files need a spec before code
- **Read the RLS** — before changing any database read/write, check the target table's Row Level Security policies

## Workflow

### 1. Sync main

```bash
git checkout main
git pull --rebase
```

### 2. Create a feature branch

Naming: `<type>/<short-description>`

| type | Purpose | Example |
|---|---|---|
| `feat/` | New feature | `feat/pickup-rating` |
| `fix/` | Bug fix | `fix/crash-on-empty-pickup` |
| `refactor/` | Refactor (no behavior change) | `refactor/extract-supabase-client` |
| `docs/` | Documentation | `docs/contributing` |
| `chore/` | Chores (deps, CI) | `chore/bump-flutter-3.42` |
| `test/` | Tests only | `test/rating-repo` |

```bash
git checkout -b feat/pickup-rating
```

### 3. Code + tests

- `flutter analyze` must pass (CI gates on this)
- `flutter test` must pass
- For UI changes, walk through the happy path and edge cases on a simulator/device yourself

### 4. Local pre-push check

Run this locally before pushing — saves CI minutes and review round-trips:

```bash
flutter analyze
flutter test
dart format lib/ test/     # format + eyeball the diff
```

### 5. Commit

**Commit message format** (Conventional Commits):

```
<type>: <short description, imperative, lowercase first letter>

<optional: paragraph explaining the why, not the what>
<optional: related issue / design doc path>
```

**Types**:

| type | Meaning |
|---|---|
| `feat` | New user-facing feature |
| `fix` | Bug fix |
| `refactor` | Refactor (no behavior change) |
| `perf` | Performance improvement |
| `docs` | Documentation only |
| `test` | Tests only |
| `chore` | Dep bumps, CI, tooling |
| `style` | Formatting (rarely used alone) |

**Good**:
```
feat: add Elo-based rating calculation to pickup matches

Uses K-factor = 24 for casual matches. Separate from event matches
(K = 32). Wiring for event matches lands in a follow-up PR.

Design: docs/superpowers/specs/2026-04-20-rating-design.md
```

**Bad**:
```
update code                 # no type, doesn't say what
fixed bug                   # which bug?
WIP                         # don't push WIP to main
```

### 6. Open a PR

```bash
git push -u origin feat/pickup-rating
gh pr create --fill
```

Suggested PR description template:

```markdown
## What
<one sentence: what this PR does>

## Why
<why it needs doing / what problem it solves>

## How
<key implementation notes, 2-3 sentences>

## Test plan
- [ ] flutter analyze passes
- [ ] flutter test passes
- [ ] Manual verification: [main flow / edge cases]
- [ ] (if applicable) Supabase migrations tested against a local project
```

### 7. Code review

- **Authors**: don't force-push after review starts — let reviewers see incremental diffs
- Once approved, you can squash/tidy commits before merging
- Large PRs (>500 lines) should be split; if truly inseparable, explain why in the description

## Code style

We follow standard Flutter/Dart conventions. [`analysis_options.yaml`](analysis_options.yaml) only includes `flutter_lints` with no local overrides.

Conventions (not lint-enforced but called out in review):

- **Single quotes** by default — `'...'` unless you need `$` interpolation or the string contains `'`
- **Trailing commas** on multi-arg constructors — dartfmt wraps cleaner and diffs stay small
- **Prefer `const`** — on widget constructors, on everywhere it compiles
- **One-line file-top comment** — `// foo.dart — short purpose` (not a full docstring)
- **No redundant comments** — don't write `// get user profile` if the function is named `getUserProfile`
- **Avoid premature abstraction** — three similar code paths is still fine; wait for the fourth before introducing a base class / mixin

## Architecture (at a glance)

```
lib/features/<name>/           # one directory per feature
     └── *_screen.dart         # screen widgets
     └── <name>_providers.dart # Riverpod state (if any)

lib/repositories/              # thin Supabase wrappers, return models
lib/services/supabase.dart     # Supabase client singleton + helpers
lib/models/                    # pure data classes (freezed or hand-written)
lib/widgets/                   # components shared across features
lib/data/mock.dart             # offline mock for the scaffold phase
```

**Layering rules**:
- Screens do UI + Riverpod subscriptions only
- Providers orchestrate repository calls and state transformations
- Repositories are thin Supabase SDK wrappers — **never** call `Supabase.instance` from a screen
- Models are pure data, no Flutter imports

## Database migrations

Schema changes go through migrations. **Do not** hand-edit the production database via the Supabase SQL Editor.

### Adding a migration

1. Create a new file in `supabase/migrations/` named `NNNN_short_description.sql` (bump `NNNN` past the current highest)
2. Start the file with a comment explaining motivation, RLS impact, and backward compatibility
3. **Include RLS policies** for any new tables — we enable RLS on all tables by default
4. Test against a local Supabase project before opening the PR
5. After merge + prod deploy, someone runs the SQL manually in the production SQL Editor (not automated yet)

### Seed data

`supabase/seed/` is for demo data — run once on fresh environments only.
Don't add `INSERT`s that conflict on rerun — wrap them with `ON CONFLICT DO NOTHING`.

## Design docs / specs

Any change matching one of the following needs a spec before code:

- A refactor touching 3+ files
- A new feature (even a single screen)
- A change to the data model
- A new external dependency (package or third-party service)

Location: `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`

Format reference: [2026-04-20-rebrand-kaiqiu-gameon-design.md](docs/superpowers/specs/2026-04-20-rebrand-kaiqiu-gameon-design.md) — decision + rationale + change list + preserved items + out-of-scope.

## Secrets and sensitive data

**Never commit**:

- `.env` / `.env.local`
- `lib/config/env.local.dart` (gitignored)
- Android keystore / iOS provisioning profile / Supabase **service_role** key

**Okay to commit**:

- Supabase **anon key** — designed to ship with clients; however, for release builds prefer `--dart-define` instead of baking it into defaults
- Bundle ID, package name, public API URLs (non-secret)

CI secrets live in the repo/org's **Settings → Secrets and variables → Actions**.

## Testing

Current state: only `test/widget_test.dart` (a smoke test). Priorities for adding more:

1. **Repository layer** — integration tests against a local Supabase project or `fake_supabase`
2. **Provider layer** — Riverpod `container.read` + mocked repositories
3. **Widget layer** — only for complex widgets with state/computation; don't test trivial presentation widgets

Run:

```bash
flutter test                        # all
flutter test test/foo_test.dart     # one file
flutter test --coverage             # with coverage
```

## FAQ

### I changed `pubspec.yaml` — do I need to commit `pubspec.lock`?

**Yes**. Unlike libraries, Flutter apps commit `pubspec.lock` to pin versions across CI and contributor machines.

### CI fails but it passes locally?

Common causes:

- Environment drift (Flutter version, Xcode version) — check the version block at the top of the CI log
- Uncommitted local files masking the issue — `git status`
- macOS runner pod cache miss — often fixed by a rerun

Share the CI link + the failing section — it's 10× faster than describing it.

### I want to add a feature but I'm not sure if it should be built?

**Open an issue to discuss first.** Don't code speculatively. Tiny features (under 30 minutes) can go straight to a PR titled with `rfc:`.

## Reporting issues

- Bugs / feature requests: GitHub Issues
- Security (including RLS bypass): **do not** open a public issue — email the owner directly

---

Found this document unclear or out of date? PRs to fix it are welcome.
