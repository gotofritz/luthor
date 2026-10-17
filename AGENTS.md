# AGENTS.md

## What This Is

Luthor is a personal, OmniFocus-like GTD task system: a **local-first,
event-sourced** Swift app for Mac (iOS later) that syncs an append-only event
log through the Dropbox API. One user, built to last.

> Events are the source of truth, not the database.

## Read First

- `README.md` — project overview
- `docs/plans/20260512_initial_plan.md` — architecture, stack and phases
- `docs/plans/20261016_incremental_roadmap.md` — build order, slice by slice
- `docs/plans/*.md` — other active plans

## Project Rules

- Use `gh` for GitHub operations when available; in environments without it
  (e.g. remote agent sessions), use the GitHub MCP tools instead
- Run commands from project root
- Strictly task execution. Notes and knowledge management live in Joplin;
  do not add note-taking features

## Plans

- Active: `docs/plans/`
- Archive: `docs/archive/`
- Plan filename format: `YYYYMMDD_name_of_plan.md`
  Example: `20260512_initial_plan.md`
- Archive completed plans in the same PR, with `git mv` and the same name.
  Update links from `docs/plans/<name>` to `docs/archive/<name>` in that PR

## Architecture

Layers, from the inside out:

```
Domain       pure Swift: events, entities, GTD rules, reducers
Store        append-only event log (canonical) + projections (in memory; SQLite/GRDB only once replay is slow)
Sync         transport adapter: Dropbox API now, CloudKit maybe later
UI           SwiftUI, Mac first, iOS later
```

Data flow:

```
user action → command → new event(s) → append to log → reduce → projection → UI
remote events → merge into log → deterministic replay → projection → UI
```

### Boundaries

| Concern | Lives in | Never in |
|---------|----------|----------|
| Event definitions | Domain | UI, Sync |
| GTD rules (defer, due, sequential projects, availability) | Domain, pure functions | views, SQL |
| State from events | reducers (pure, deterministic) | views, sync code |
| Fast queries | SQLite projections | — |
| Canonical data | event log | SQLite |
| Network, OAuth, file transfer | Sync adapter behind a protocol | Domain, UI |
| Layout, colour, spacing | SwiftUI views | Domain |

### Event-sourcing rules

- Events are append-only. Code never edits or deletes a written event
- The event format is soft until it is frozen (slice 10 of
  `docs/plans/20261016_incremental_roadmap.md`). Until then a format change
  may break old logs, provided it ships with a one-off migration script that
  rewrites the log, or the change says the log is to be started afresh
- Once frozen, event types are a public, persisted format. Never rename a
  field or change its meaning; add a new event type or a new optional field
  instead. Old logs must always replay, checked by golden-file tests
- Each event carries a unique ID, the originating device ID and an ordering
  key. Replay of the same set of events in any arrival order produces the same
  state
- Reducers are pure: no I/O, no `Date()`, no `UUID()`, no randomness.
  Inject clocks and ID generators
- SQLite is disposable. Any projection must be rebuildable from the event log
  alone; a schema change is handled by dropping and rebuilding the projection,
  not by migrating it
- The domain never imports GRDB, SwiftUI or Dropbox SDK code
- Sync syncs event files, never the SQLite database

Update `docs/plans/20260512_initial_plan.md` (or a successor architecture doc)
before merging changes affecting architecture, boundaries or core patterns.

### Code map

What is where today. Grep for anything finer; this only orients.

```
Package.swift                SwiftPM manifest: every module and test target
Sources/
  LuthorDomain/              pure Swift, imports nothing
    Events.swift             event payloads + EventEnvelope (id, device, lamport), replay order
    Identifiers.swift        EventID, DeviceID, TaskID, ProjectID
    Commands.swift           command → new events; IDGenerator protocol, CommandError
    LibraryState.swift       reducer: LibraryState.replay(events) → open tasks, inbox, projects;
                             Project.nextActions (parallel/sequential rule)
  LuthorStore/               event log on disk, config, real ID generator
    EventLog.swift           EventLog protocol
    JSONLinesEventLog.swift  canonical log: one JSON event per line (EventLine codec)
    LuthorConfiguration.swift log path (LUTHOR_LOG, default ~/.luthor/events.jsonl), device ID
    FileChangeMonitor.swift  polls the log file so the app sees outside writes
    UUIDGenerator.swift      production IDGenerator
  LuthorCLI/CLI.swift        `luthor add|list|done`, testable (returns CLIResult)
  luthor/main.swift          CLI executable: wires real env, home dir, UUIDs
  LuthorViewModels/          @Observable view models (LibraryViewModel: sidebar, list), no SwiftUI
App/                         Xcode project for the SwiftUI Mac app (`make app`)
  Luthor/                    LuthorApp (wiring, menus) + thin views (LibraryView, TaskListView)
Tests/
  LuthorTestSupport/         shared fixtures: event builders, InMemoryEventLog,
                             SequentialIDs, TemporaryDirectory
  Luthor<Module>Tests/       unit tests, one target per module
  LuthorAcceptanceTests/     end-to-end flows via CLI/view models (`make test-acceptance`)
scripts/                     commit-message and coverage checks, with their shell tests
.githooks/  infra/ (Terraform for the GitHub repo settings)
.github/workflows/           CI (make check-ci), PR title check, release on v* tags
```

Dependencies point inwards: `LuthorStore`, `LuthorCLI` and `LuthorViewModels`
depend on `LuthorDomain`; nothing depends on the app or the CLI executable.
There are no projections, SQLite or sync modules yet; the reducer's state is
the only read model. Commands are in [Commands](#commands).

**Keep this map current.** A PR that adds, removes, renames or moves a
module, target or top-level folder, or a file listed above, updates this map
in the same PR.

## Workflow

**MANDATORY TDD — no exceptions.** Every change to behaviour starts with a
failing test. This applies to the domain, reducers, projections, sync and
view models alike.

1. Write a failing test FIRST
2. Run it — confirm it fails for the expected reason (missing behaviour,
   not a compile error or a typo)
3. Write the minimal implementation to make it pass
4. Run the whole suite — all green
5. Refactor with tests green
6. Run the full QA (see below) before opening a PR

**Never write production code before a failing test for it exists.** Code
written before its test is deleted and rewritten test-first. A test that
passes the first time it runs proves nothing; fix the test until you have seen
it fail.

Bug fixes start with a test that reproduces the bug.

**Outside-in.** Work on a plan, or a slice of one, starts with its acceptance
tests: one per user-visible flow the slice promises, in
`Tests/LuthorAcceptanceTests`, named BDD-style from the plan's wording. Watch
them fail, then drive the implementation with unit tests (the loop above)
until they pass. The slice is done when its acceptance tests are green; they
stay red on the branch until then, and are never skipped to get there

Reference: `.claude/skills/tdd/SKILL.md`

### What to test where

- **Domain and reducers**: the bulk of the tests. Given events → expect state.
  Table-style tests with `@Test(arguments:)` are preferred
- **Replay and merge**: same events in shuffled orders produce identical state;
  duplicate events are idempotent; after the freeze, old event formats
  still decode
- **Projections**: GRDB against an in-memory `DatabaseQueue()`; projection
  built from events equals the reducer's state
- **Sync**: against an in-memory fake transport conforming to the sync
  protocol. Two simulated devices writing concurrently converge
- **UI**: keep views thin and test their view models. No snapshot or UI tests
  unless a plan asks for them
- **Acceptance**: end-to-end user flows (capture, list, complete…) driven
  through the CLI or the view models against a real log in a temporary
  directory. They live in `Tests/LuthorAcceptanceTests`, apart from the fast
  unit tests in the per-module targets, and run on their own with
  `make test-acceptance`. Keep them few: one per user-visible flow

## Decision Order

Prioritize:

1. Correctness (and never losing user data)
2. Passing tests
3. Simplicity
4. Existing patterns
5. Minimal diffs

Speed of capture and interaction is a feature: do not regress it.

## Swift

### Tooling

- Swift 6 toolchain, strict concurrency on
- Swift Package Manager. Domain, store and sync live in a Swift package so
  they build and test with `swift test` without Xcode; the SwiftUI app target
  depends on it
- Swift Testing (`import Testing`, `@Test`, `#expect`) for new tests
- `swift-format` for formatting, SwiftLint for linting
- GRDB for SQLite

### Commands

The `Makefile` is the single entry point, locally and in CI:

```bash
make tools      # once: install the pinned SwiftLint into .tools/
make hooks      # once: point git at .githooks/
make format     # apply swift-format
make lint       # swift-format lint --strict + SwiftLint
make test       # swift test + script tests
make coverage   # make test with coverage; fails under 90% line coverage of Sources/
make test-unit  # unit tests only (skips LuthorAcceptanceTests)
make test-acceptance  # end-to-end acceptance tests only
make app        # xcodebuild the Mac app (App/Luthor.xcodeproj)
make cli        # release build of the luthor CLI, universal, ad-hoc signed
make install    # build and install the app (/Applications) and CLI (~/.local/bin)
make dist       # zip the app and CLI into .build/dist, as a release does
make infra      # Terraform: show changes to the GitHub repo settings, apply on yes (needs GITHUB_TOKEN)
make check-ci   # lint + build + coverage + app, exactly what CI runs
swift test --filter <TestName>   # run one test while doing red/green
```

SwiftLint is pinned by `SWIFTLINT_VERSION` in the `Makefile`; swift-format
comes with the Swift toolchain. Run `make check-ci` locally before pushing.
Keep these instructions in sync.

### Rules

- Value types (`struct`, `enum`) for events and domain state
- Events are `Codable`, `Sendable`, `Equatable`
- No force unwraps (`!`) or `try!` outside tests
- No global mutable state, no singletons
- Dependencies (clock, ID generator, store, transport) are injected through
  initialisers or protocols
- Errors are typed and thrown; do not swallow them with `try?` in the store
  or sync layers
- Concise doc comments for public, non-obvious declarations only
- Minimise lint suppressions; document every one

### Testing

- Tests never touch the network, the real Dropbox account or the user's data
- Use in-memory SQLite and in-memory fakes; no mocking frameworks
- Fixed clocks and seeded ID generators for deterministic results
- Shared fixtures (event builders) live in a test support target
- One behaviour per test, named for the behaviour it checks
- Name suites and tests BDD-style, so they read as Given/When/Then specs. The
  suite names the situation, the test names the outcome, and together they
  read as a sentence. Function names stay short camelCase for `--filter`:

  ```swift
  @Suite("When the inbox is empty")
  struct EmptyInboxTests {
    @Test("adding a task shows it in the list")
    func addingATaskShowsIt() { … }
  }
  ```

  Applies to unit and acceptance tests alike, with Swift Testing only (no
  Quick, Nimble or Gherkin). Existing tests are renamed when next touched,
  not en masse

## Data & Secrets

- Never commit a database, an event log or Dropbox tokens
- OAuth tokens go in the Keychain, never in files or `UserDefaults`
- Secrets come from the environment or the Keychain, never from the repo
- Any change that could lose or corrupt the event log needs a test proving
  the log survives it

## Commits & Branches

### Commits

- [Conventional Commits](https://www.conventionalcommits.org):
  `<type>(<scope>): <subject>`, e.g. `feat(domain): add TaskDeferred event`
- Common types: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `build`,
  `ci`, `chore`
- Small, atomic commits
- Imperative present tense
- Subject ≤ 72 chars
- Reference issues when relevant

### Branches

- `feature/<name>`
- `fix/<name>`

Work on the branch the user specifies. If their prompt names one, use it
without asking.

**Before creating a branch**, check for an existing open PR (`gh pr list
--state open`, or the GitHub MCP tools). If an open PR covers the same area,
commit to its branch instead of creating a new one.

**To bring in `main`**, rebase the branch onto it and force-push with
`--force-with-lease`; do not merge `main` into it. Merge only when a rebase is
too messy (many conflicting commits, or a branch others are also pushing to).

## Pull Requests

- Keep PRs focused
- Avoid unrelated refactors
- Include tests for behaviour changes
- Update relevant docs and plans (checklist below)
- Ensure CI passes

### Docs check, before every PR is ready for review

Do this unasked, and again after any later push that changes behaviour,
commands or setup. The user should never have to ask whether docs are current.

- `README.md` describes what the app, the CLI and every `make` target do now:
  new features, changed shortcuts, install paths, setup steps
- The roadmap (`docs/plans/20261016_incremental_roadmap.md`) marks every slice
  and CI/CD item this PR finishes with ✅, condensed to a short paragraph like
  the earlier finished ones; decisions taken in the PR go under Decisions
- A plan finished as a whole is archived (see [Plans](#plans))
- The [Code map](#code-map) and [Commands](#commands) in this file match the
  tree and the `Makefile`
- Say in the PR, or the reply that asks for review, that these were checked

### Title & Body

- Title: Conventional Commits format, same rules and types as commits
  (`<type>(<scope>): <subject>`), ≤ 50 chars. CI fails a PR whose title
  does not match
- Body: concise summary of changes, not implementation details
- Body: reference issues with `Closes #N` when relevant

## Failure Policy

- Never ignore failing tests
- Never disable, skip or delete tests to pass CI
- Never bypass lint/type failures without explanation
- Never merge broken builds
- Surface blockers clearly

## Agent Constraints

- Prefer minimal diffs
- Preserve existing architecture unless intentionally changing it
- Reuse existing patterns
- Avoid unnecessary dependencies; every new package needs a reason in the PR
- Avoid rewriting working code without reason
- Keep changes reviewable

## Enforcement

- CI via GitHub Actions runs `make check-ci`: lint,
  format check, build, `swift test` with a 90% line-coverage gate on
  `Sources/` (`COVERAGE_MIN` in the `Makefile`), Mac app build. The same
  command runs locally
- CI checks that PR titles are Conventional Commits
- A version tag (`v0.x.y`) runs `make dist` on CI and attaches the zips to a
  GitHub Release; PRs that change the `Makefile` or that workflow run the same
  build without publishing
- Git hooks for local development, installed with `make hooks`:
  `pre-commit` runs format check and lint, `commit-msg` checks the message
  is a Conventional Commit. Do not bypass them with `--no-verify`
- All checks must pass before merge
