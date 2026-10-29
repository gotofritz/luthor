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
  `Tests/LuthorStoreTests/Fixtures/golden-log.jsonl`. A PR that adds an event
  type adds lines to that fixture; the tests fail if a type has none
- A build skips an event type it does not know and leaves its line in the
  log, so an older build can open a newer log. An event that is broken in
  other ways is reported with its file and line number and left out of the
  state, not fatal; the app offers Repair Log, which moves this device's bad
  lines into `<file>.rejected` (never another device's file). Appends start on
  a fresh line if the file lacks a final newline, and are `fsync`ed (not
  `F_FULLFSYNC`; a power cut may still lose the last write on a drive that lies)
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
                             TaskDelegated/Reclaimed, TaskDropped, TaskDueSet, DayHoursSet (the start and end of one day),
                             TaskStartSet (the minute a planned task starts at),
                             DayBlockSet, DayBlockRemoved (BlockEvents.swift: untracked time on a day, such as lunch),
                             TaskSessionSet, TaskSessionRemoved (SessionEvents.swift: a stretch of a planned task's day set apart)
    CalendarDate.swift       pure year-month-day type (weekday, adding days, ISO text); the domain
                             never reads a clock, callers pass today in
    ReviewEvents.swift       TaskTimeLogged, UnplannedTimeLogged, DayReviewed
    TagEvents.swift          TagCreated, TaskTagged, TaskUntagged, TagDeleted
    RepeatRule.swift         RepeatRule (every n days/weeks/months/years, weekdays, from due date or from completion) and
                             its pure nextDue(after:completedOn:today:)
    RepeatEvents.swift       TaskRepeatSet, TaskRecurred (next task copied from the previous one; its ID is
                             TaskID.recurring(after:), so two devices make the same one)
    ProjectReviewEvents.swift  ReviewInterval (off or every n days; n on the wire, 0 for off), ReviewDefaultSet,
                             ReviewIntervalSet, ReviewDateSet (a chosen next
                             review), TaskReviewed
    Identifiers.swift        EventID, DeviceID, TaskID (one ID for tasks and projects; derived IDs for the next
                             of a repeat and for copies in a copied subtree), TagID, ViewID (+ ViewID.default)
    Commands.swift           command → new events; IDGenerator protocol, CommandError; `after(_:lamport:)` binds
                             the held state, so a command is given only the events since and replays nothing
    Commands+Planning.swift  schedule, order, capacity, delegate, reclaim, drop, send to someday
    Commands+Completion.swift  reopen a completed or dropped task or project
    Commands+Blocks.swift    add, change and remove a block of untracked time on a day
    Commands+Sessions.swift  set apart, change and remove a session of a planned task
    Commands+Due.swift       set or clear a task's due date (hard deadline or target date)
    Commands+Repeat.swift    set or stop a task's repeat, skip an occurrence, and the next task made by complete
    Commands+Tags.swift      create and delete a tag, tag and untag a task, tag by name (creating the tag), set a task's tags
    Commands+Review.swift    log time on a task or unplanned, review a day
    Commands+ProjectReview.swift  weekly project review: default and per-project interval, choose the next review,
                             review a project, drop it
    ItemDefaults.swift       ItemDefaults (priority and estimate) and what a new task (its parent's, from the nearest
                             project above that has them) or a new top-level project (the settings') starts with
    Commands+Defaults.swift  the events that give a new item those defaults
    Undo.swift               UndoStep (the events of a command and the events that take them back) and
                             LibraryState.undoStep(for:), which reads the state before the command; nil if any event cannot be undone
    Commands+Undo.swift      append(_:log:): writes the events of an undo or redo as new events
    Commands+Cards.swift     rename, notes and project kind, as edited on a card; add a note to and delete a note
                             from an item's notes
    NoteBullets.swift        notes seen as bullet points, one for each non-blank line (the text stays one string)
    BulkEdit.swift           BulkEdit (what a bulk edit sets: each field `keep` or `set`), BulkSummary (what several tasks hold in common
                             in each field, `Common` being `same` or `mixed`, and the tags all or only some carry), and the
                             commands that apply an edit, drop or delete to many tasks, one after the other
    LibraryExport.swift      LibraryExport (views, tags, items as plain Codable data) and LibraryState.export()
    Commands+Import.swift    importLibrary: the events that add what an export holds and the library lacks
    StructureEvents.swift    TaskDuplicated, TaskDeleted (takes the subtree), ChildrenOrdered (the order of the items filed in a project)
    Commands+Order.swift     move an item of a project one place up or down (ChildrenOrdered)
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
    LibraryState+Capacity.swift  capacity(in:on:planning:): a day's own capacity, else its weekday's
    LibraryState+Due.swift   DueDate (date + hard or target), applying TaskDueSet, dueDate(of:) and
                             effectiveDueDate(of:) (own, else the nearest ancestor's)
    LibraryState+Calendar.swift  pure functions calendar(for:from:days:) → CalendarDay (planned and due
                             counts per day, the item that carries a date being the one marked) and calendarEntries(for:on:today:) →
                             CalendarEntry (a day's tasks and projects)
    LibraryState+History.swift  EventPayload.isBeyondExport (plan and review events an export cannot hold, carried
                             over by Compact Log) and the check that a rewritten log kept them
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
    DayPlan.swift            the plan's types: Delegation, PlanEntry, DayCapacity, DayPlan (slots on the day's hours),
                             PlanSlot, WaitingItem
    LibraryState+Planning.swift  planning reducers and pure functions: plan(for:on:today:matching:) →
                             DayPlan (ordered entries with reasons, candidates, DayCapacity; effective hard
                             deadlines rank after priority; only tasks, never projects; DayPlan.slots(notBefore:) lays the entries on the day's
                             hours, set starts first; DayPlan.layout(...) lays tasks, blocks and sessions so none overlaps, the one moved winning), hours(in:on:), waitingFor(in:today:)
    Settings.swift           SettingKey, ThemeAccent (the eight accent names; the app colours them), Weekday,
                             Settings (typed planning numbers, DayHours per weekday, the view's accent and the priority and estimate of a new top-level project); SettingChanged
                             event lives in Events.swift; resolves Settings from LibraryState's raw
                             values (global, then per-view override, then built-in default) and the
                             default view, as an extension (split out for file_length, not access)
  LuthorStore/               event log on disk, config, real ID generator
    EventLog.swift           EventLog protocol
    JSONLinesEventLog.swift  canonical log: one JSON event per line (EventLine codec); damaged lines reported as
                             LogProblem and quarantined to .rejected on repair (also a Lamport counter above 2^53, a file over 512 MB is refused, and in
                             a device file a line of another device); lines of an unknown event
                             type are skipped on read and stay in the file
    JSONLinesEventLog+Increment.swift  LogCursor (how far a reading got: bytes and lines per file, and a checksum of the
                             last bytes) and the scan that reads a file whole or from a cursor; `readIncrement(since:)` of the
                             logs gives only what was appended, `nil` if a file shrank, went or was replaced
    LibraryText.swift        a LibraryExport (tasks and projects, no history) as YAML text and back (uses Yams)
    LogCompactor.swift       Settings → This Mac → Compact Log: backs up the log files and a YAML copy, rebuilds
                             the log from the library (export, then import) and carries over the plan and review events, checks it, refuses
                             a log with events of a newer build or a file that changed meanwhile, swaps it in
    CompactionHandshake.swift  request/answer/done files in the shared folder so every Mac stops writing before a
                             compaction (ids checked, unreadable or far-off times expire); PausableEventLog refuses appends while this Mac has stopped
    DeviceFilesEventLog.swift  shared-folder log (slice 10): appends to events-<device>.jsonl only,
                             reads the merge of every device's file
    LogStorage.swift         the place the user chose for the log (Dropbox folder or Home Folder),
                             per device; prepares it (creates folders, copies the Home Folder log in); `folderStatus()` says if the folder
                             is inside a real Dropbox, outside one, or missing
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
                             delegation actions and the day's layout, worked out once for each present, in LibraryViewModel+Today.swift, the calendar's days,
                             the day picked and due dates in LibraryViewModel+Calendar.swift, logging time and
                             reviewing a day in LibraryViewModel+Review.swift, starting and stopping a task now and giving it times in LibraryViewModel+Running.swift, a task's sessions in LibraryViewModel+Sessions.swift, splitting a task in two (its times, deferring the part cut off) in LibraryViewModel+Split.swift, the weekly project review (due list, mark
                             reviewed, intervals, drop) in LibraryViewModel+ProjectReview.swift, the Tags place, tagging and the
                             candidate filter in LibraryViewModel+Tags.swift, repeating tasks (set, stop,
                             skip) in LibraryViewModel+Repeat.swift, duplicating, deleting for good and
                             Add Tasks in LibraryViewModel+Structure.swift, a new item started from a column's plus button (a draft in
                             `newItem`, kept by OK) in LibraryViewModel+NewItem.swift, the priorities place's lists (`priorityGroups`, a task added from the bottom of one) in LibraryViewModel+PriorityLists.swift, notes
                             on a card, deselecting a column, the project card that replaces a list (`projectCardOpen`, `toggleProjectCard`) and the card the last column shows (`cardTarget`) in LibraryViewModel+Columns.swift, and the card's repeat summary in RepeatSummary.swift,
                             reading the log and
                             filling the published state (columns, lists, completed items) and text export/import in
                             LibraryViewModel+Presenting.swift (split for file_length)
    ListSort.swift           ListSortKey, ListSort: how a list is sorted from the header above it (title, created, due,
                             duration, priority; a way of showing the list, never written to the log)
    LibraryViewModel+ListSort.swift  the sort of each list and the click on a header cell (`sortBy`), applied when presenting
    LibraryViewModel+Bulk.swift  several tasks selected together (`setSelection`, `selectedIDs`), the bulk card (`bulkCard`),
                             and tagging, editing, dropping and deleting them as one step to undo
    LibraryViewModel+Undo.swift  undo and redo of this session's commands (stacks kept in the view model, unlimited,
                             not persisted); `perform` records each command that can be taken back
    LogCatchUp.swift         LogSnapshot (state, held events, log cursor, damaged lines) and LogCatchUp.run, which brings a snapshot
                             up to the log; no actor, so `reloadInBackground()` (LibraryViewModel+Reload.swift, with `reload()`) runs
                             it off the main actor and swaps the result in
    ClockText.swift          clockText(_:), minutes after midnight as 09:00
    StorageController.swift  where the log lives: first-start choice and Settings → This Mac, its folder warning, and its Compact Log button
    EstimateScale.swift      the estimate slider's logarithmic scale, 5 minutes to a week, and estimate labels
    NoteLinks.swift          finds web addresses in plain-text notes, so cards can link them
App/                         Xcode project for the SwiftUI Mac app (`make app`)
  Luthor/                    LuthorApp (wiring, menus, ⌘,) + thin views (LibraryView: window, top bar
                             with search and view switcher, capture; NavigationRailView: icon
                             rail, Settings pinned to the bottom; PriorityColumns: the priorities place's picker and its list for each priority, with an add button; ColumnBrowserView: the columns of
                             the place picked and the card at their end; ProjectColumnsView: a project's column, ended by a plus button and, while an item is being added, a box with its title; NewItemViews: the card
                             of an item being added, in edit mode; CardViews: the task card column, the project card in the
                             last column while the pencil on the project's row is pressed, replacing its list (the fields of an open item are CardLiveFields, changed by clicking and kept at once, with no edit mode; CardProjectPicker: the project tree pulldown at the top of a card; CardFieldsForm is the form of a new item's card); NotesViews: notes
                             as deletable bullets with clickable links and a field that adds one; LinkedText: a note as an AppKit text view, so
                             the pointer is a hand over a link; SettingsColumnsView: Global/Views/This Mac setting families (Views: the list of views, then the settings of the one picked),
                             then the individual settings of the one picked; WeekdaySettingsViews: the Global rows that open a
                             column of their own, the weekday capacity fields and the quarter-hour grid for day start and end; TodayView: the candidates with a
                             Waiting for toggle, leftovers, the day header, capacity meter, Plan / Review toggle, delegate dialog;
                             SessionViews: a session's block and the sheet that asks for start and end; DayBlockViews: a block of untracked time on the grid; EstimateSlider: the slider that sets an estimate; BlockSizing: how tall a block is on the grid and the compact look of short ones; DoneViews: a done task locked in its place on the grid; DayDropDelegate: a drag over the hour grid;
                             DayCalendarView: the day as an hour grid with zoom, drag and drop (DayHoursFields: its start and end fields and a Now button),
                             set start times;
                             CalendarView: the list of days and the tasks of the one picked;
                             ReviewView: the day looked back on, time fields, deciding, closing the review;
                             BulkCardViews: the card of several tasks selected together (fields greyed where they differ);
                             TagsView: the Tags place's tag column;
                             RepeatViews: the card's Repeat field and line and the Repeat context menu;
                             TaskRowCells: the cells of a task row; ListSortHeader: the sticky table header above a list, a cell for each column;
                             WeeklyReviewView: the weekly review's due list, project card with its
                             buttons, and the project review menu items;
                             StorageSetupView: the first-start modal and the This Mac settings;
                             Theme: the accent of the view shown as `@Environment(\.theme)`, type styles and the mountain
                             mark; AppearanceSettingsViews: the accent swatches of Settings → Global and Views;
                             Assets.xcassets: the app icon)
Tests/
  LuthorTestSupport/         shared fixtures: event builders, InMemoryEventLog,
                             SequentialIDs, TemporaryDirectory, syntheticLog(years:) (years of heavy use)
  LuthorPerformanceTests/    launch and action timings on synthetic logs (`make bench`); loose budgets, numbers printed
  Luthor<Module>Tests/       unit tests, one target per module; LuthorStoreTests holds the golden log
                             (Fixtures/golden-log.jsonl): a line for every event type, must always replay
  LuthorAcceptanceTests/     end-to-end flows via the view models (`make test-acceptance`);
                             AppHarness.swift launches the app's view model on a real log
docs/brand/                  source SVG and PNG of the app icon (the README masthead)
scripts/                     commit-message, coverage and architecture checks (check-architecture.sh: domain imports and
                             purity, layer boundaries, this code map), next-version.sh (release tag
                             from Conventional Commits, app-version.sh: the version About Luthor shows, check-version-tag.sh: a release tag is vX.Y.Z),
                             with their shell tests
.githooks/  infra/ (Terraform for the GitHub repo settings)
.github/workflows/           CI (make check-ci), PR title check, release (on main pushes, and v* tags: a read-only build job, then a publish job
                             with the checksum, provenance attestation and a draft made public last)
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
- Remote agent sessions may have no Swift toolchain. Install one before writing
  code; never ask the user about it and never push unbuilt code to see what CI
  says. On Linux (CI uses `swift:6.2`):

  ```bash
  mkdir -p /opt/swift-dl /opt/swift && cd /opt/swift-dl
  curl -sSfL -o swift.tgz https://download.swift.org/swift-6.2-release/ubuntu2404/swift-6.2-RELEASE/swift-6.2-RELEASE-ubuntu24.04.tar.gz
  tar xzf swift.tgz -C /opt/swift --strip-components=2
  export PATH=/opt/swift/bin:$PATH
  ```

  (adjust `ubuntu2404` and the file name to the OS and architecture), then
  `make tools` and run `make lint` and `make test`. Only if the download is
  refused write the tests first, push, and use CI as the build: the fast
  `linux` job (`make test-linux`, package only) reports in minutes, the macOS
  job (`make check-ci`) is the full check, fixing what it reports. The Mac app
  (`make app`) needs Xcode, so only CI builds it. Delete the `Package.resolved`
  that `swift build` leaves (it is not tracked)

### Commands

The `Makefile` is the single entry point, locally and in CI:

```bash
make tools      # once: install the pinned SwiftLint into .tools/
make hooks      # once: point git at .githooks/
make format     # apply swift-format
make lint       # swift-format lint --strict + SwiftLint
make test       # swift test + script tests
make architecture  # scripts/check-architecture.sh: domain purity, layer boundaries, code map (part of make lint)
make coverage   # make test with coverage; fails under 90% line coverage of Sources/
make test-unit  # unit tests only (skips LuthorAcceptanceTests and LuthorPerformanceTests)
make test-acceptance  # end-to-end acceptance tests only
make bench      # launch and action timings on synthetic 1, 3 and 5 year logs (LuthorPerformanceTests)
make test-linux # swift build + swift test of the package; the Linux CI job, no Xcode needed
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

**IMPORTANT: always cut a new branch from the latest `origin/main`, never
from a local `main`, which may be stale.** Run `git fetch origin main` first,
then `git checkout -b <branch> origin/main`.

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
- `scripts/check-architecture.sh` (`make architecture`, part of `make lint` and the Linux job) fails on a domain
  import, a clock, UUID or randomness in the domain, SwiftUI/AppKit outside `App/`, GRDB or Dropbox code in the domain
  or view models, and a source file missing from the code map (or a map entry with no file)
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
