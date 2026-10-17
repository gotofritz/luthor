# Incremental Roadmap

Status: agreed 2026-10-16

Turns the broad phases of `20260512_initial_plan.md` and the ALPEN product
spec in `20261015_alpen.md` into small slices. Each
slice ends with something I can use every day, even if it is ugly or gets
thrown away later. The architecture (event log as truth, pure reducers,
sync of event files) stays; the order and the amount of machinery change.

## Principles

- **Usable after every slice.** If a slice does not change how I work this
  week, it is too big or in the wrong order
- **Throwaway is fine.** A cheap hack that gives a feature now beats the
  "proper" version in three months. Mark hacks as `// THROWAWAY:` so they are
  easy to find
- **Defer machinery until it hurts.** No SQLite until in-memory replay is
  measurably slow; no Dropbox API until a Dropbox folder stops being enough
- **TDD throughout** (see `AGENTS.md`). The domain is where the tests go;
  hacks at the edges get thin tests
- **Documented as built.** `docs/guide.md` is the user guide. It describes
  shipped behaviour only, and the PR that ships a slice adds or updates its
  section, so the guide is never ahead of the app or behind it
- **Pre-1.0 event format is soft.** While I am the only user, an event format
  change may be handled by a one-off migration script over the log, or by
  starting a new log. The immutability rules in `AGENTS.md` apply in full from
  the slice that freezes the format (slice 15)

## CI/CD track

Runs alongside the slices. Code quality comes first; building and shipping
the app comes once there is an app to ship. Every check CI runs can also be
run locally with the same command, so CI never surprises me.

### CI-1. Code quality, local and CI (slice 1) ✅

`make check-ci` runs format check, SwiftLint, build and tests, locally and on
a macOS runner for every PR and push to `main`; tool versions pinned in the
repo. Git hooks (`make hooks`) check format, lint and Conventional Commit
messages; one script decides what a Conventional Commit is for hooks and the
PR title check. Branch protection on `main` via Terraform in `infra/`. CI also
fails under 90% line coverage of `Sources/` (`make coverage`).

### CI-2. Build the Mac app (slice 2) ✅

`make app` builds the Mac app in `make check-ci`; view model tests run with the
package tests.

### CD-1. Ship the Mac app and CLI (slice 3) ✅

A version tag (`v0.x.y`) runs `make dist` on CI: the `.app` and the universal
`luthor` CLI, ad-hoc signed, zipped and attached to a GitHub Release. PRs that
change the release build run it without publishing. `make install` puts both
in `/Applications` and `~/.local/bin` between releases. Not notarised: the
first launch needs right-click → Open.

### CI-3. Event format guard (slice 15)

- Golden-file replay tests are part of `make check-ci`; a change that breaks
  an old log fails CI

### CD-2. iOS (slice 18)

- `xcodebuild` the iOS target in CI
- Distribution decided with slice 18: free 7-day provisioning from Xcode, or
  TestFlight with the Developer Program

## Slices

### 1. Walking skeleton: CLI capture ✅

`luthor add`, `list` and `done <id-prefix>` over a JSON-Lines log
(`TaskCaptured`, `TaskCompleted`), path from an env var. Proves domain, log and
replay end to end with no UI.

### 2. Mac app: Inbox ✅

SwiftUI inbox on the same log: always-focused add field, complete by click or
key, full replay on launch, file watching keeps CLI and app in step.

### 3. Projects ✅

`ProjectCreated`, `TaskMovedToProject`, `ProjectCompleted` (which takes its
open tasks with it). Parallel and sequential projects; next actions are a pure
function of the project. The app gains a sidebar of Inbox and projects: drag a
task onto a project or press ⌥⌘1–9 to file it, capture straight into the
project shown, complete a project from the toolbar.

### 4. Views: work and private kept apart ✅

Every task and project belongs to exactly one view (Work, Private…), each
with its own Inbox. `ViewCreated`, `ViewRenamed`, `TaskMovedToView` and
`ProjectMovedToView`; `TaskCaptured` and `ProjectCreated` carry a `viewID`,
and events without one belong to the default view replay always creates.
Isolation is a domain rule: tasks and projects are reachable only through
`LibraryState.view(_:)`, filing a task into a project of another view is a
`CommandError`, and a no-leak test per list checks both directions. The app
shows one view at a time (switcher in the sidebar header, ⌃⌘1–9, last view
remembered per device); `luthor add|list|done` work in `--view` or
`LUTHOR_VIEW`, else the default view.

### 5. Nested projects ✅

A project contains tasks and other projects, to any depth. `ProjectCreated`
gains an optional `parentID` and `ProjectMovedToProject(project, parent?)`
nests or un-nests; old logs replay as top-level projects. Nesting across views
or under the project's own subtree is a `CommandError`, and replay ignores
such an event, so two devices nesting projects under each other converge.
Next actions are a recursive pure function of the tree
(`ViewState.nextActions(of:)`): a sequential project's first open child, task
or sub-project, is active; a task is a next action only if every ancestor
lets it be. Completing or moving a project to a view takes its subtree. The
app shows projects in Miller columns instead of a sidebar tree; drag a
project onto another or onto a column to nest it, and the new project field
creates inside the project shown. Later slices read the tree: Today's
project path, on hold and dropped subtrees, review intervals.

### 5a. Navigation rail ✅

The sidebar becomes a narrow rail of icons with their names underneath, which
never expands: Inbox, Projects, Prios (a new place gets a new case in
`NavigationSection` and an icon). The main area has a bar with a search box
(disabled until the Search slice) and the view switcher, which has no
shortcuts so it cannot be triggered by mistake. The first Miller column
depends on the place: Inbox is its list of tasks, Projects the top-level
projects, Prios the four priorities, which add up when clicked, followed by
the tasks that have one of them. For Prios to have anything to list,
`TaskPrioritized(task, priority?)` landed here, ahead of slice 6, with
`Priority` (A, B, C, someday) and a priority menu on tasks; nothing else of
slice 6 did.

### 6. Priority and estimates (ALPEN: A, L) ✅

`TaskEstimated` (minutes, clearable) joins `TaskPrioritized` from 5a.
Clarifying a task means giving it a priority, an estimate or a project;
`ViewState.inbox` now lists only unclarified tasks, and a someday task
(`Priority.someday`) is excluded from `ViewState.nextActions(of:)` until
given another priority. `QuickCapture.parse`, a pure function in
`LuthorDomain`, strips `!a`/`!b`/`!c`/`!someday` and `<n>m` tags out of
captured text; `Commands.capture` calls it, so the CLI and the app share the
syntax with no code of their own. The app's Estimate menu (context menu and
Task menu) offers 5/15/30/60-minute presets and None, next to Priority.

Usable: triage the inbox into A/B/C with estimates, at capture speed.

### 7. Settings ✅

A rail icon pinned to the bottom (or ⌘,) opens Settings: two Miller columns,
the families Global and Local in the first, the individual settings of the
one picked in the second. `SettingChanged(key, value, viewID?)` is the one
event for all of them; `LibraryState` resolves a setting from its per-view
override, then the global value, then the built-in default. `key` is a raw
string rather than a closed enum, so a key this build does not recognise is
ignored on replay instead of failing the line, the forward-compatibility the
plan called for. Global sets the default estimate for an unestimated task
(5 minutes), the buffer percentage (40%) and the capacity per weekday (8
hours on weekdays, none at the weekend), plus the default view `luthor add`
and imports use when none is named. Local overrides the buffer and the
capacity for the view shown, each a toggle between following the global
value and its own. Per-device preferences (last view shown, window state)
stay out of the log, in `UserDefaults`. View management (create, rename)
stays where it already was, in the view switcher, rather than duplicating
it here; only choosing the default view belongs in Settings. Each later
slice adds its own settings to the panel in the same PR; the panel is never
a catch-all added at the end.

Usable: the numbers Today will plan with are already set, globally and per
view.

### 8. Today: plan the day (ALPEN: P, E)

- `TaskScheduled(date)`, `TaskUnscheduled`, `DayPlanOrdered(date, taskIDs)`.
  Rescheduling keeps the task's identity; nothing is ever duplicated
- Day capacity per view: `DayCapacitySet(date, minutes)` overrides the
  weekday default from Settings (slice 7); the buffer percentage is a setting
  too, default 40%
- A task without an estimate is never refused: it counts at the default
  estimate from Settings (5 minutes) and is flagged "unestimated", in the
  plan and in the totals
- Capacity is a pure function of events and the injected clock: buffer,
  usable, planned and remaining minutes, and an overloaded flag when planned
  exceeds usable. The buffer is protected capacity, never a task
- Suggested order is deterministic and explained: A before B before C, then
  hard deadlines, then project sequence. A manual order always wins and is
  kept
- Today view: capacity meter with the buffer shown, the ordered plan,
  candidates to pull in, and an overload warning that informs rather than
  blocks. Defer, delegate, drop or send to someday from the plan in one key
- Delegating: `TaskDelegated(to, followUpDate?)` and `TaskReclaimed`. A
  delegated task leaves Today's candidates and the capacity totals, and
  shows in a Waiting for list in the current view with who and since when.
  On its follow-up date (or when reclaimed) it returns to the candidates, so
  nothing delegated is forgotten. Delegating never completes or drops it
- One plan per view and day: the work day and the evening are planned apart

Usable: the ALPEN morning plan, with capacity and buffer always in sight.

### 9. Daily review and carry-over (ALPEN: N)

- Review of the day in the current view: done and not done, estimated
  against actual minutes, unplanned minutes
- `TaskTimeLogged(minutes)` entered by hand; `UnplannedTimeLogged(date,
  minutes)`; `DayReviewed(date, note)` with a one-line note (long reflection
  belongs in Joplin)
- Each unfinished task gets a decision: tomorrow, another day, back to the
  list, delegate, someday, or dropped (`TaskDropped`). No per-task carry-over policy:
  the review decides, and an unreviewed day's leftovers show at the top of
  the next Today until decided
- Estimate history per task and project is shown, never applied: the user's
  estimate is never changed silently

Usable: the ALPEN loop is closed, and estimates improve with feedback.

### 10. Mac ↔ Mac sync via a Dropbox folder (THROWAWAY candidate)

- Log lives in the Dropbox folder, synced by the Dropbox desktop app
- One file per device (`events-<deviceID>.jsonl`), so two machines never
  write the same file and Dropbox never makes conflict copies
- Read = merge all device files, order by `(lamport, deviceID, eventID)`,
  replay. Shuffled-order and duplicate-event tests land here
- Optional: split acceptance testing out of the TDD skill into its own
  `acceptance` skill, linked from the TDD skill. Likely needed here, because
  two-device flows need a shared harness (several simulated devices, an
  injected clock from slice 8, fixture logs) and a way to turn a slice's
  promises into scenarios. Do it only if that guidance outgrows a section of
  the TDD skill

Usable: same tasks on every Mac, with almost no sync code. If this proves
reliable, the "proper" Dropbox API sync can come much later or never for Mac.

### 11. Defer and due, Upcoming and Forecast

- `TaskDeferred` (available from), `TaskDueSet` (hard deadline or target
  date), and clearing both
- Availability rule (deferred, blocked by sequence, completed, dropped) in
  the domain. Scheduling before a task is available is a `CommandError`; a
  due date never schedules a task by itself
- Due and overdue hard deadlines surface in Today's candidates, ahead of
  their priority peers
- Upcoming (days ahead and their plans) and Forecast (deadlines and planned
  minutes per day, overloaded days flagged)

Usable: deadlines feed the plan without taking it over.

### 12. Tags

- `TagCreated`, `TaskTagged`, `TaskUntagged`
- Filter any list, Today's candidates included, by tag; also by priority,
  project and deadline
- Tags belong to a view, so `@calls` at work and at home are different tags

Usable: contexts (`@home`, `@calls`, `@deep-work`).

### 13. Capture without the app: iPhone (THROWAWAY) and Alfred

- An iOS Shortcut appends a line to `Dropbox/Luthor/inbox.txt`
- The Mac app imports new lines as `TaskCaptured` events and truncates the
  file once imported (idempotent by line hash); lines use the quick-capture
  syntax of slice 6
- One inbox file per view (`inbox-<view>.txt`), one Shortcut per view
- The CLI becomes a capture tool for Alfred and nothing else: `luthor add`
  stays, `list` and `done` go, and an Alfred workflow (keyword, then the
  task title) calls it. Acceptance tests that relied on `luthor list` move
  to the view models

Usable: capture from the phone, lock screen and Siri included, months before
an iOS app exists, and from Alfred on the Mac without switching to the app.

### 14. Weekly project review

The daily review (slice 9) looks at the day; this one keeps projects from
going stale.

- On by default, weekly, and the user can change both. `ReviewDefaultSet`
  sets the default interval (a number of days, or off) for all projects;
  `ProjectReviewIntervalSet` overrides it for one project, with its own
  value or off, and clearing the override falls back to the default.
  Turning review off everywhere is `ReviewDefaultSet(off)`
- `ProjectReviewed` sets the next review date to the review date plus the
  effective interval. Next review date is a pure function of events and the
  injected clock; a project with review off has none and never appears in
  the review list
- Project status: `ProjectPutOnHold`, `ProjectResumed`, `ProjectDropped`.
  On-hold and dropped projects yield no next actions or plan candidates, and
  dropped ones skip review
- Review list in the current view: projects whose next review date has
  passed, oldest first. Mark reviewed (⌘⇧R) moves to the next one; the
  project's tasks are shown and editable in place

Usable: the weekly review.

### 15. Freeze the event format

- Write down every event type and field as v1
- Golden-file tests: a checked-in fixture log must always replay to the same
  state
- From here, `AGENTS.md` event rules are strict

### 16. Speed pass

- Measure launch replay time and capture latency on the real log
- Only if needed: GRDB projections, snapshotting, global capture hotkey,
  command palette

### 17. Dropbox API sync

- OAuth, token in Keychain, sync of the same per-device files over the API
- Sync behind a `Transport` protocol; in-memory fake for tests; two-device
  convergence tests
- Required for iOS, which has no Dropbox folder to watch

### 18. iOS app

- Same package; capture, Inbox and Today first, then the daily review
- Without the Apple Developer Program, a free provisioning profile expires
  every 7 days; decide then whether to pay

### Later

- Search: make the search box in the top bar work, over titles in the
  current view only
- Full keyboard navigation: reach the rail, every column, the top bar and
  the view switcher without the mouse (the view switcher still gets no
  shortcut)
- Repeating tasks
- Timer for actual minutes, and an in-progress state with it
- Estimate suggestions from history, offered and never applied silently
- Calendar integration: fixed commitments reduce a day's capacity
- Perspectives as saved queries, scoped to a view
- Per-device view lists: a work Mac that never shows (or never syncs)
  private views, if logical isolation turns out not to be enough
- Notes field kept minimal (notes live in Joplin)
- CloudKit transport, if ever

## Decisions (2026-10-16)

1. **Soft event format until slice 15.** `AGENTS.md` event rules updated to
   match: format changes before the freeze ship with a migration script or a
   fresh log
2. **CLI first** in slice 1
3. **Dropbox folder sync** in slice 10, possibly as the permanent Mac solution
4. **Ordering key**: Lamport counter plus device ID (then event ID as the
   tiebreak). Hybrid logical clocks only if timestamps matter for display
5. **No SQLite until slice 16**, and only if replay is measurably slow

## Decisions (2026-10-17)

1. **CLI is capture only.** The app does everything the CLI does; the CLI
   gains no project, defer or tag commands, and shrinks to `luthor add` for
   Alfred in slice 13
2. **Views are logical, in one log.** Work and private live in the same
   event log and sync together; isolation is enforced by the domain (every
   query names a view), not by separate files. Separate logs per view stay
   an option under Later if a work machine must not hold private data
3. **Views come next** (slice 4), because without them I cannot use
   Luthor at work
4. **Luthor is an ALPEN app**, with OmniFocus as a reference rather than
   the goal. `20261015_alpen.md` is the product spec; this roadmap puts it
   in order (slices 6, 8 and 9 are A-L-P-E-N, with Settings in between) and
   records where it deviates
5. **State is derived, not stored.** The spec's `status`, `planned_minutes`,
   `updated_at` and the like are computed by the reducer from events; only
   decisions are events
6. **No per-task carry-over policy.** The daily review decides what happens
   to each unfinished task
7. **Day plans are per view.** The work day and the evening have their own
   capacity, buffer and plan
8. **Planning numbers are settings, in the log.** Default estimate, buffer
   and weekday capacity are events with a per-view override, so they sync;
   per-device preferences stay local. The panel is its own slice (7), ahead
   of Today
9. **A comprehensive user guide, kept current.** `docs/guide.md` starts with
   what is shipped (slices 1 to 3) and grows with every slice, checked in the
   docs check of `AGENTS.md`
10. **Unestimated tasks are planned, not refused.** They count at a
    configurable default (5 minutes) and are flagged
11. **A default capacity per weekday and view**, adjusted for a single day in
    the morning plan
12. **Project review stays**, weekly by default; the interval is a setting and
    review can be turned off for all projects or one
13. **Sync (slice 10) before defer and due (slice 11)**, because two Macs
    matter more than deadlines
14. **Delegating is a real state**, not a tag: a delegated task leaves the
    plan and the capacity totals, sits in a Waiting for list with who and
    since when, and returns on its follow-up date
15. **Projects nest, to any depth, before the planning slices** (slice 5).
    Next actions become a recursive pure function, so the rule is settled
    before Today, review and delegation build on it

## Decisions (2026-10-17, slice 4)

1. **Two move events.** `TaskMovedToView` takes one task across, into the
   other view's Inbox (out of its project); `ProjectMovedToView` takes a
   project and its open tasks. Two plain events read better in the log than
   one event with an optional task or project
2. **The default view is called "Default"** and can be renamed like any
   other; it cannot be removed, so every log has at least one view
3. **The CLI works in one view for every command.** Not only `add`: `list`
   and `done` also take `--view` or `LUTHOR_VIEW`, so `luthor list` at work
   never prints a private task. View names match ignoring case and must be
   unique

## Decisions (2026-10-17, slice 5)

1. **Miller columns, not a collapsible tree.** Each project opened adds a
   column of its sub-projects and tasks, so the path to the project shown is
   always on screen. Sub-projects are entries in their parent's column, not
   groups in its task list
2. **New projects go inside the project shown.** The new project field
   creates a sub-project while a project is shown, and a top-level project
   from the Inbox, as capture does for tasks
3. **An empty sub-project holds back a sequential parent.** It is still an
   open child, so the parent's later children wait until it is completed or
   given tasks
4. **A sub-project moved to another view alone is top-level there.** Its old
   parent stays behind without it

## Decisions (2026-10-17, navigation)

1. **Navigation is a rail, not a sidebar.** A fixed-width strip of icon and
   name, never expanded. Places: Inbox, Projects, Prios. Later slices add
   theirs (Tags in slice 12)
2. **The view switcher has no keyboard shortcut.** Switching view by mistake
   shows a different world; the ⌃⌘1–9 commands are gone
3. **Prios are additive.** Clicking a priority adds it to the picked ones
   instead of replacing them; with none picked the list is empty
4. **`TaskPrioritized` ships before slice 6.** It is the minimal priority
   model: `Priority` (A critical, B important, C optional, someday, shown as
   "One day") and a clearable event, with no UI for it beyond a menu. The
   event format is still soft
5. **Search and keyboard navigation are deferred** to their own slices (see
   Later)

## Decisions (2026-10-17, slice 6)

1. **Clarified leaves the Inbox, for good until cleared.** A task is
   clarified by a priority, an estimate or a project (any one, not all
   three); `ViewState.inbox` filters on that, so giving a task a priority
   from the Inbox removes it from the list immediately, same as filing it.
   Clearing every clarifying field returns it
2. **Someday is excluded inside `nextActions(of:)`, not by a separate
   list.** It already had a "list" via Prios → One day (slice 5a); slice 6
   only had to keep it out of the recursive next-actions function, so a
   someday task never blocks a sequential project or counts as workable
3. **The quick-capture syntax lives inside `Commands.capture`, not in the
   CLI or the view model.** Both already call `Commands.capture` with the
   raw typed text, so parsing it there is what "the CLI and the app share
   it" means in practice: neither needs its own parsing code
4. **Minutes only, no hours shorthand.** `<n>m` is the one estimate tag;
   `1h30m` or similar is left for a later slice if it turns out to be
   wanted

## Decisions (2026-10-17, slice 7)

1. **One event for every setting**, `SettingChanged(key, value, viewID?)`,
   rather than one event type per setting. A setting is a key/value pair the
   domain resolves, not a distinct kind of thing that happened
2. **`key` is a raw string on the wire, not a closed enum.** Decoding never
   fails on a key this build does not recognise; `LibraryState.apply`
   ignores it instead, so an old build survives a log a newer one wrote.
   `Commands` and the view model still use the typed `SettingKey` enum, so
   callers cannot typo a key
3. **Two families in the settings place, Global and Local**, as suggested:
   Global is what every view falls back to; Local is the current view's
   overrides, each a toggle between following the global value and its own
4. **Capacity per weekday is seven keys, not one key holding seven values.**
   A flat `SettingKey` case per weekday keeps the event format simple (no
   nested value) and lets a weekday be overridden on its own
5. **The default view is a global setting, not a new kind of event.** It is
   `SettingKey.defaultViewID`, always global: a view cannot override which
   view is the default
6. **Settings does not duplicate view management.** Create and rename
   already work from the view switcher; Settings only adds choosing the
   default view, which is new here
