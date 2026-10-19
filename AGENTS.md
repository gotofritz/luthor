# AGENTS.md

## What This Is

Luthor is a personal task system built around the ALPEN daily-planning
method, with OmniFocus as a reference: a **local-first,
event-sourced** Swift app for Mac (iOS later) that syncs an append-only event
log through the Dropbox API. One user, built to last.

> Events are the source of truth, not the database.

## Read First

- `README.md` — project overview
- `docs/plans/20260512_initial_plan.md` — architecture, stack and phases
- `docs/guide.md` — user guide, describes shipped behaviour
- `docs/plans/20261015_alpen.md` — product spec: the ALPEN method
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
- The event format is frozen (slice 15 of
  `docs/plans/20261016_incremental_roadmap.md`). Events are a public,
  persisted format on every device: never rename a field or change its
  meaning; add a new event type or a new optional field instead. Old logs
  must always replay, checked by the golden log in
  `Tests/LuthorStoreTests/GoldenLogFixture.swift`. A PR that adds an event
  type adds lines to that fixture; the tests fail if a type has none
- A build skips an event type it does not know and leaves its line in the
  log, so an older build can open a newer log. An event that is broken in
  other ways is still an error
- A breaking change to the format (one that cannot be done additively) is
  allowed only with a one-off migration script that rewrites the log, a
  tested backup of the log before it runs, and a breaking (`!`) Conventional
  Commit, so the release version moves to the next major (minor while
  below 1.0) and says the log needs migrating. Note it in the PR body
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
    Events.swift             event payloads + EventEnvelope (id, device, lamport), replay order;
                             TaskCaptured carries the optional day created (`createdOn`), parent and kind (a
                             project is an item with a kind); TaskMoved, TaskKindChanged;
                             Priority (A, B, C, someday), TaskPrioritized and TaskEstimated
    PlanningEvents.swift     TaskScheduled/Unscheduled, DayPlanOrdered, DayCapacitySet,
                             TaskDelegated/Reclaimed, TaskDropped, TaskDueSet
    CalendarDate.swift       pure year-month-day type (weekday, adding days, ISO text); the domain
                             never reads a clock, callers pass today in
    ReviewEvents.swift       TaskTimeLogged, UnplannedTimeLogged, DayReviewed
    TagEvents.swift          TagCreated, TaskTagged, TaskUntagged
    RepeatRule.swift         RepeatRule (every n days/weeks/months/years, weekdays, from due date or from completion) and
                             its pure nextDue(after:completedOn:today:)
    RepeatEvents.swift       TaskRepeatSet, TaskRecurred (next task copied from the previous one; its ID is
                             TaskID.recurring(after:), so two devices make the same one)
    ProjectReviewEvents.swift  ReviewInterval (off or every n days; n on the wire, 0 for off), ReviewDefaultSet,
                             ReviewIntervalSet, ReviewDateSet (a chosen next
                             review), TaskReviewed
    Identifiers.swift        EventID, DeviceID, TaskID (one ID for tasks and projects; derived IDs for the next
                             of a repeat and for copies in a copied subtree), TagID, ViewID (+ ViewID.default)
    Commands.swift           command → new events; IDGenerator protocol, CommandError
    Commands+Planning.swift  schedule, order, capacity, delegate, reclaim, drop, send to someday
    Commands+Completion.swift  reopen a completed or dropped task or project
    Commands+Due.swift       set or clear a task's due date (hard deadline or target date)
    Commands+Repeat.swift    set or stop a task's repeat, skip an occurrence, and the next task made by complete
    Commands+Tags.swift      create a tag, tag and untag a task, tag by name (creating the tag), set a task's tags
    Commands+Review.swift    log time on a task or unplanned, review a day
    Commands+ProjectReview.swift  weekly project review: default and per-project interval, choose the next review,
                             review a project, drop it
    Commands+Cards.swift     rename, notes and project kind, as edited on a card; add a note to and delete a note
                             from an item's notes
    NoteBullets.swift        notes seen as bullet points, one for each non-blank line (the text stays one string)
    LibraryExport.swift      LibraryExport (views, tags, items as plain Codable data) and LibraryState.export()
    Commands+Import.swift    importLibrary: the events that add what an export holds and the library lacks
    StructureEvents.swift    TaskDuplicated, TaskDeleted (takes the subtree)
    Commands+Structure.swift duplicate an item (with its subtree), delete an item for good, make a task a project and an empty project a task
    QuickCapture.swift       pure parser for the `!a`/`!b`/`!c`/`!someday` + `<n>m` capture syntax,
                             used by Commands.capture
    LibraryState.swift       reducer: LibraryState.replay(events) → views; one item store (a task and a project
                             are the same TaskItem; a kind makes it a project), tasks and projects
                             only via view(id); holds the raw global/per-view setting values, the
                             day each task is scheduled for, due dates, delegations, plan orders and
                             day capacities
    LibraryState+Items.swift capturing, filing and moving items; the lists of open and finished tasks and
                             projects derived from the store; subtree(of:), descendants(of:),
                             rolledUpEstimate(of:)
    Project.swift            Project (an item with a kind: own priority and estimate, children) and ProjectChild
    LibraryState+Completion.swift  Completed<Item> (completed or dropped); finishing an item with its subtree,
                             and reopening it
    LibraryState+Due.swift   DueDate (date + hard or target), applying TaskDueSet, dueDate(of:) and
                             effectiveDueDate(of:) (own, else the nearest ancestor's)
    LibraryState+Calendar.swift  pure functions calendar(for:from:days:) → CalendarDay (planned and due
                             counts per day, the item that carries a date being the one marked) and calendarEntries(for:on:today:) →
                             CalendarEntry (a day's tasks and projects)
    LibraryState+Review.swift  daily review: logged time, reviewed days; pure functions dayReview(for:on:today:) →
                             DayReview (done, not done, minutes), carryOver(in:today:) (leftovers of earlier
                             days), estimateHistory(ofTask:/ofProject:)
    LibraryState+ProjectReview.swift  weekly project review: applying its events, effective interval,
                             nextReviewDate(of:) (a chosen day, else an interval after the last review), projectsDueForReview(in:today:) → ProjectReviewItem
    LibraryState+Repeat.swift  applying TaskRepeatSet and TaskRecurred, repeatRule(of:)
    LibraryState+Structure.swift  applying the structure events; copyTask (with the subtree), shared by
                             TaskRecurred and TaskDuplicated; hasProject
    LibraryState+Tags.swift  TagItem, applying the tag events, tags(in:/of:), tasks(tagged:), taskCounts; TaskFilter
                             (tags, priority, project, deadline) and tasks(in:matching:)
    LibraryState+Cards.swift  applying rename, notes and kind events
    ViewState.swift          one view's open tasks, completed tasks and projects, inbox of
                             unclarified tasks, project tree, recursive next actions excluding
                             someday; tasks by priority
    LibraryState+Planning.swift  planning reducers and pure functions: plan(for:on:today:matching:) →
                             DayPlan (ordered entries with reasons, candidates, DayCapacity; effective hard
                             deadlines rank after priority; only tasks, never projects), waitingFor(in:today:)
    Settings.swift           SettingKey, ThemeAccent (the six accent names; the app colours them), Weekday,
                             Settings (typed planning numbers and the view's accent); SettingChanged
                             event lives in Events.swift; resolves Settings from LibraryState's raw
                             values (global, then per-view override, then built-in default) and the
                             default view, as an extension (split out for file_length, not access)
  LuthorStore/               event log on disk, config, real ID generator
    EventLog.swift           EventLog protocol
    JSONLinesEventLog.swift  canonical log: one JSON event per line (EventLine codec); lines of an unknown event
                             type are skipped on read and stay in the file
    LibraryText.swift        a LibraryExport (tasks and projects, no history) as YAML text and back (uses Yams)
    DeviceFilesEventLog.swift  shared-folder log (slice 10): appends to events-<device>.jsonl only,
                             reads the merge of every device's file
    LogStorage.swift         the place the user chose for the log (Dropbox folder or Home Folder),
                             per device; prepares it (creates folders, copies the Home Folder log in)
    MachineID.swift          this Mac's own ID, made once and kept by the app, so devices that share a
                             host name stay apart
    LuthorConfiguration.swift log path (LUTHOR_LOG, default ~/.luthor/events.jsonl) or shared folder
                             (LUTHOR_SYNC_DIR) or the chosen LogStorage, device ID; makes the log
                             and its change monitor
    FileChangeMonitor.swift  polls the log file, or the device files of the shared folder, so the app
                             sees outside writes
    UUIDGenerator.swift      production IDGenerator
  LuthorViewModels/          @Observable view models, no SwiftUI
    LibraryViewModel.swift   LibraryViewModel: current view, navigation section, picked priorities,
                             project columns, list, drops, injected clock; the card being edited
                             (`editingCard`), with edit, cancel and save (a task's and a project's card share one draft) and
                             a project's rolled-up estimate in LibraryViewModel+Cards.swift; SidebarItem/NavigationSection/
                             ColumnEntry/ProjectColumn/TaskCardDraft types live in LibraryViewModel+Types.swift, settings
                             methods in LibraryViewModel+Settings.swift, the day shown, plan and
                             delegation actions in LibraryViewModel+Today.swift, the calendar's days,
                             the day picked and due dates in LibraryViewModel+Calendar.swift, logging time and
                             reviewing a day in LibraryViewModel+Review.swift, the weekly project review (due list, mark
                             reviewed, intervals, drop) in LibraryViewModel+ProjectReview.swift, the Tags place, tagging and the
                             candidate filter in LibraryViewModel+Tags.swift, repeating tasks (set, stop,
                             skip) in LibraryViewModel+Repeat.swift, duplicating, deleting for good and
                             Add Tasks in LibraryViewModel+Structure.swift, a new item started from a column's plus button (a draft in
                             `newItem`, kept by OK) in LibraryViewModel+NewItem.swift, notes
                             on a card, deselecting a column and the card the last column shows (`cardTarget`) in LibraryViewModel+Columns.swift, and the card's repeat summary in RepeatSummary.swift,
                             reading the log and
                             filling the published state (columns, lists, completed items) and text export/import in
                             LibraryViewModel+Presenting.swift (split for file_length)
    StorageController.swift  where the log lives: first-start choice and Settings → This Mac
    NoteLinks.swift          finds web addresses in plain-text notes, so cards can link them
App/                         Xcode project for the SwiftUI Mac app (`make app`)
  Luthor/                    LuthorApp (wiring, menus, ⌘,) + thin views (LibraryView: window, top bar
                             with search and view switcher, capture; NavigationRailView: icon
                             rail, Settings pinned to the bottom; ColumnBrowserView: the columns of
                             the place picked and the card at their end; ProjectColumnsView: a project's column, headed by its name and
                             ended by a plus button and, while an item is being added, a box with its title; NewItemViews: the card
                             of an item being added, in edit mode; CardViews: the task card column, the project card in the
                             last column when no task is picked (read-only, a pencil opens the editor with OK and Cancel; both edit
                             priority, estimate, due date, repeat and tags through the shared form in CardFieldsForm); NotesViews: notes
                             as deletable bullets with clickable links and a field that adds one; LinkedText: a note as an AppKit text view, so
                             the pointer is a hand over a link; SettingsColumnsView: Global/Views/This Mac setting families (Views: the list of views, then the settings of the one picked),
                             then the individual settings of the one picked; TodayView: the day's plan
                             and the Plan / Review toggle, capacity meter, leftovers, candidates, Waiting for, delegate dialog;
                             CalendarView: the list of days and the tasks of the one picked;
                             ReviewView: the day looked back on, time fields, deciding, closing the review;
                             TagsView: the Tags place's tag column and Today's candidate filter menu;
                             RepeatViews: the card's Repeat field and line and the Repeat context menu;
                             WeeklyReviewView: the weekly review's due list, project card with its
                             buttons, and the project review menu items;
                             StorageSetupView: the first-start modal and the This Mac settings;
                             Theme: the accent of the view shown as `@Environment(\.theme)`, type styles and the mountain
                             mark; AppearanceSettingsViews: the accent swatches of Settings → Global and Views;
                             Assets.xcassets: the app icon)
Tests/
  LuthorTestSupport/         shared fixtures: event builders, InMemoryEventLog,
                             SequentialIDs, TemporaryDirectory
  Luthor<Module>Tests/       unit tests, one target per module; LuthorStoreTests holds the golden log
                             (GoldenLogFixture.swift): a line for every event type, must always replay
  LuthorAcceptanceTests/     end-to-end flows via the view models (`make test-acceptance`);
                             AppHarness.swift launches the app's view model on a real log
docs/brand/                  source SVG and PNG of the app icon (the README masthead)
scripts/                     commit-message and coverage checks, and next-version.sh (release tag
                             from Conventional Commits), with their shell tests
.githooks/  infra/ (Terraform for the GitHub repo settings)
.github/workflows/           CI (make check-ci), PR title check, release (on main pushes, and v* tags)
```

Dependencies point inwards: `LuthorStore` and `LuthorViewModels` depend on
`LuthorDomain`; nothing depends on the app.
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
  through the view models against a real log in a temporary
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
- Remote agent sessions may have no Swift toolchain. Never ask the user
  about installing one. If a route works without asking, install it and run
  `make check-ci` locally; otherwise write the tests first, push, and use CI
  (`make check-ci`) as the build, fixing what it reports

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
make install    # build and install the app (/Applications)
make dist       # zip the app into .build/dist, as a release does
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

- `README.md` describes what the app and every `make` target do now:
  new features, changed shortcuts, install paths, setup steps
- `docs/guide.md` (the user guide) covers every user-visible feature and
  shortcut this PR adds or changes, and nothing that is not shipped yet
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
- A merge to `main` with a `feat`, `fix`, `perf` or breaking (`!`) commit since
  the last tag runs `make dist` on CI and publishes a GitHub Release at the
  version `scripts/next-version.sh` works out from the Conventional Commit
  titles (this is why PR titles must be exact). A hand-pushed version tag
  (`v0.x.y`) publishes that version instead; PRs that change the `Makefile`,
  that script or that workflow run the same build without publishing
- Git hooks for local development, installed with `make hooks`:
  `pre-commit` runs format check and lint, `commit-msg` checks the message
  is a Conventional Commit. Do not bypass them with `--no-verify`
- All checks must pass before merge
