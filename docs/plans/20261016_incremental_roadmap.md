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

### CD-1. Ship the Mac app (slice 3) ✅

A merge to `main` that carries a release runs `make dist` on CI (see Decisions,
automatic releases): the `.app`, ad-hoc signed, zipped and attached to a
GitHub Release. A version tag pushed by hand (`v0.x.y`) still does the same.
PRs that change the release build run it without publishing. `make install` puts it in `/Applications` between
releases. Not notarised: the first launch needs right-click → Open. The
universal `luthor` CLI shipped alongside until it was removed (see Decisions
2026-10-17, slice 13 dropped).

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
replay end to end with no UI. The CLI was removed on 2026-10-17; the app
is the only front end.

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
projects, Prios the four priorities and no priority, picked like the rows of any
list, followed by the tasks that have one of them. For Prios to have anything to list,
`TaskPrioritized(task, priority?)` landed here, ahead of slice 6, with
`Priority` (A, B, C, someday) and a priority menu on tasks; nothing else of
slice 6 did.

### 5b. Cards and completed items ✅

From issue #16. Completed tasks and projects are kept by the reducer (it used
to throw them away) and listed behind a Completed toggle in the top bar,
dimmed and struck through; `TaskReopened` and `ProjectReopened` bring them
back. Clicking a task opens a card in the next column and a project's column
starts with its card; both edit the title (`TaskRenamed`, `ProjectRenamed`)
and plain-text notes (`TaskNoted`, `ProjectNoted`, links made clickable by
`NoteLinks`), and a project's card switches it between sequential and
parallel (`ProjectKindChanged`, also in its context menu). All events are
additive, so old logs replay unchanged. From issue #24 the cards are
read-only (title, creation day, notes) until the pencil opens them for
editing, closed by OK or Cancel; see the Decisions at the end.

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

### 8. Today: plan the day (ALPEN: P, E) ✅

Today is a place on the rail, one plan per view and day. `TaskScheduled(task,
date)` and `TaskUnscheduled` plan a task for a day (scheduling it again moves
it: the task keeps its identity, nothing is duplicated), `DayPlanOrdered(view,
date, tasks)` keeps the order the user chose, and `DayCapacitySet(view, date,
minutes?)` overrides the weekday capacity from Settings for one day. Days are a
pure `CalendarDate` in the domain (no time zone, no system calendar); the view
model's injected clock says which day it is. Capacity is a pure function of
events and that date: buffer percentage of the day's capacity, usable, planned
and remaining minutes, and an overloaded flag that warns and never refuses. A
task without an estimate counts at the default estimate and is flagged in the
plan and the totals. The suggested order is deterministic and explained under
each task: A before B before C, then the order of the tasks in their projects,
then capture order; a manual order always wins and tasks added later follow
it. Candidates are the clarified open tasks that could be pulled in (no
someday task, none held back by a sequential project, no delegated task before
its follow-up date). Defer (to tomorrow), delegate, drop and send to someday
are one chord each from the plan or the candidates. `TaskDelegated(task, to,
since, followUpDate?)` and `TaskReclaimed` make delegating a real state: the
task leaves Today and the totals, waits in Waiting for with who and since
when, and returns to the candidates on its follow-up date. `TaskDropped` ships
here, ahead of slice 9, because dropping from the plan needs it.

Usable: the ALPEN morning plan, with capacity and buffer always in sight.

### 9. Daily review and carry-over (ALPEN: N) ✅

Review is a place on the rail (⇧⌘N), looking back on the day Today shows.
`TaskTimeLogged(task, date, minutes?)` sets the minutes a task took on a day,
by hand; `UnplannedTimeLogged(view, date, minutes?)` the minutes of work
outside the plan; `DayReviewed(view, date, note?)` closes the review with a
one-line note. Each sets rather than adds, so typing again replaces what the
day had and clearing it is the same event with no minutes. The review lists
the tasks planned for the day that were completed (done) and the ones still
planned for it (not done), each with its planned minutes (the estimate, or the
default estimate), the minutes logged, and its estimate history; its totals are
planned, logged and unplanned minutes. Deciding on a task not done reuses the
Today chords: tomorrow, another day, back to the list (`TaskUnscheduled`),
delegate, someday and `TaskDropped`. There is no carry-over policy: an open
task planned for a day before today is a leftover, listed at the top of Today
(and no longer among its candidates) until decided, reviewed or not. The
estimate history, a task's estimate against its logged minutes and the same
added up for a project, is shown in the review and on the cards, never applied.

Usable: the ALPEN loop is closed, and estimates improve with feedback.

### 10. Mac ↔ Mac sync via a Dropbox folder (THROWAWAY candidate) ✅

The log lives in a folder the Dropbox desktop app syncs, chosen in a
first-start modal and later in Settings → This Mac (`LUTHOR_SYNC_DIR` does the
same from a shell).
`DeviceFilesEventLog` appends only to `events-<device>.jsonl`, so two Macs
never write the same file and Dropbox never makes a conflict copy, and reads
the merge of every `events-*.jsonl`; replay already orders by `(lamport,
deviceID, eventID)` and applies each event once, so any arrival order gives
the same state (a conflict copy is harmless for the same reason). A last line
of another device's file that is still half synced is skipped until the rest
arrives; any other unreadable line is still an error. `FileChangeMonitor`
also watches the folder, so the app reloads when Dropbox delivers. Without
`LUTHOR_DEVICE_ID` a shared folder names the device after the Mac's host
name. Acceptance flows simulate two Macs on one folder. The optional
`acceptance` skill was not needed: the two-device harness is a small
`launchApp(sharing:as:)` helper.

Usable: same tasks on every Mac, with almost no sync code. If this proves
reliable, the "proper" Dropbox API sync can come much later or never for Mac.

### 11. Due dates and the calendar

- `TaskDueSet(task, date?, hard)` sets a due date, a hard deadline or a
  target date, and clears it when the date is missing. A due date never
  schedules a task by itself
- Due and overdue hard deadlines surface in Today's candidates, ahead of
  their priority peers
- Due date field on the task card, next to priority and estimate
- Calendar, a new place on the rail (new case in `NavigationSection`, calendar
  icon). Its first Miller column is a scrolling list of days, one row per day
  across the whole column, starting at today with earlier days reachable by
  scrolling up. Sundays have a different background, today is marked, and a
  mark on a row shows the day has tasks: one for tasks planned for it
  (`TaskScheduled`), another for tasks due on it, so a deadline looks
  different from a plan. Picking a day lists all its tasks in the next
  column, planned and due; picking a task opens its card in the column after
  that, as everywhere else. Per view, like Today. Read-only: planning,
  rescheduling and deciding stay in Today and Review
- The day-to-tasks lookup is a pure function in `LibraryState`, taking the
  range of days and today as parameters like `plan(for:on:today:)`

Dropped from this slice (see Decisions, slice 11): defer dates and the
availability rule, Upcoming, Forecast.

Usable: deadlines feed the plan without taking it over, and any day's
tasks are one click away.

### 12. Tags

- `TagCreated`, `TaskTagged`, `TaskUntagged`
- Filter any list, Today's candidates included, by tag; also by priority,
  project and deadline
- Tags belong to a view, so `@calls` at work and at home are different tags

Usable: contexts (`@home`, `@calls`, `@deep-work`).

### 13. ~~Capture without the app: iPhone and Alfred~~ (dropped)

Dropped 2026-10-17: the Shortcut inbox file and the Alfred workflow are not
needed. The number stays so later slices keep theirs. The CLI is removed
with it (see Decisions 2026-10-17, slice 13 dropped).

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
- Richer notes (markdown, attachments): notes are plain text with clickable
  links, and longer writing lives in Joplin
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
   gains no project, defer or tag commands. (Superseded: slice 13 is dropped
   and the CLI is removed altogether)
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
3. **Prios are picked like any list.** ~~Clicking a priority adds it to the
   picked ones~~ Superseded (issue #17): a click picks one, shift-click a
   range, command-click adds or drops one; with none picked the list is empty
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

## Decisions (2026-10-17, slice 8)

1. **Dates are a domain type, today is an input.** `CalendarDate` is plain
   arithmetic over year, month and day, written to the log as `2026-10-19`. The
   domain never reads a clock: `LibraryState.plan(for:on:today:)` and
   `waitingFor(in:today:)` take today as a parameter, the view model owns the
   injected clock (the system's by default), and a command that needs "since
   when" gets the date from its caller
2. **Plans and capacity overrides carry a `viewID`.** The roadmap sketch of
   `DayPlanOrdered` and `DayCapacitySet` had only a date; decision 7 of
   2026-10-17 (plans are per view) needs the view in both. A task's own day
   needs none: the task knows its view. A plan is the tasks of the view
   scheduled for the date, so a task scheduled in one view never shows in
   another
3. **The plan is derived, only decisions are events.** Membership is "scheduled
   for this date"; `DayPlanOrdered` stores only the user's order. Tasks it
   names that are no longer scheduled that day are skipped, and tasks added
   afterwards follow it in suggested order. A manual order is kept per view and
   day and is never rewritten by the suggestion
4. **No deadline step in the suggestion yet.** The ordering rule is priority,
   then project order, then capture order; "hard deadlines" slot in after
   priority in slice 11, when tasks have them. The doc comment of `plan(for:)`
   says so
5. **Clarified tasks only are candidates.** A task still in the Inbox has to
   be clarified (a priority, an estimate or a project) before it can be pulled
   in; planning is for clarified work. A task in a project is a candidate only
   if it is a next action. The scheduling command does not enforce this (that
   is slice 11's availability rule); Today just does not offer such tasks
6. **Delegating clears the day; scheduling a delegated task reclaims it.** A
   delegated task cannot also be planned, so `TaskDelegated` removes its day on
   replay, and the schedule command writes `TaskReclaimed` before
   `TaskScheduled` when the task is delegated, so the reducer stays a plain
   state machine. A delegated task never completes or drops by itself
7. **Someday cannot be scheduled.** `Commands.schedule` throws
   `CommandError.someday` until the task is promoted; "send to someday" writes
   `TaskUnscheduled` and `TaskPrioritized(someday)`. Nothing in the reducer
   enforces it, so a log that disagrees still replays
8. **`TaskDropped` arrives in slice 8.** The slice promises dropping from the
   plan in one key; slice 9's review reuses the same event rather than adding
   another
9. **The event field is `to`, the code's is `person`.** The log keeps the
   roadmap's `to`; the Swift property is `person`, to keep clear of a
   two-letter identifier (SwiftLint `identifier_name`)
10. **No new settings this slice.** The default estimate, buffer percentage and
    weekday capacity from slice 7 are everything Today reads, so the settings
    panel is unchanged. Capacity for a single day is set from Today itself

## Decisions (2026-10-17, cards and completed items)

1. **Completed items are kept in the reducer, not recomputed.** `LibraryState`
   holds completed tasks and projects beside the open ones; `ViewState`
   exposes them per view. Dropped tasks are still gone for good
2. **Reopen is an event, and only for what was completed itself.** A project's
   completion takes its sub-projects and open tasks along; those come back
   only with the project (`Completed.completedWith` says which), so reopening
   never half-restores a tree. A reopened task returns to its project if that
   is active, else it is loose; a reopened sub-project returns to its former
   parent if that is active, else it is top-level
3. **Notes are plain text, with clickable links.** The AGENTS rule against
   note-taking features stands: no markdown, no attachments, one text field
   per task or project. `NoteLinks` finds `http(s)://` and `www.` addresses
   without Foundation's data detector, so it runs on Linux too
4. **Task and project share one card style, not one type.** The domain keeps
   `TaskItem` and `Project`; merging them is a larger change for a later slice
5. **Edits apply to open tasks and active projects only.** Rename, notes and
   kind events on something completed are ignored on replay, like every other
   edit; the card of a completed item is read-only until it is reopened
6. **Blank notes clear them; the same text writes nothing.** Commands trim
   the text and compare, so tabbing through a card writes no events

## Decisions (2026-10-17, priority picking, issue #17)

1. **Prios use the platform's list selection.** The additive "sticky" clicks
   were a mistake: a click picks one, shift-click a range, command-click adds
   or drops one, all from the list itself. The view model only holds the set
   (`selectPriorities`); `togglePriority` stays as the command-click
2. **No priority is `nil` in the picked set.** `Set<Priority?>`, listed after
   One day, covers open tasks with no priority wherever they are filed; no
   new event or type

## Decisions (2026-10-17, slice 13 dropped)

1. **Slice 13 is dropped.** Phone capture through a Dropbox inbox file and
   the Alfred workflow are not needed. Slice numbers are not renumbered
2. **The CLI is removed.** `LuthorCLI`, the `luthor` executable, its tests,
   `make cli` and the CLI zip in releases go; `Commands.complete(idPrefix:)`
   and `CommandError.ambiguousPrefix` existed only for it and go too, as does
   `LUTHOR_VIEW`. `LUTHOR_LOG` and `LUTHOR_DEVICE_ID` stay, for the app. The
   app and the view models do everything it did
3. **The default-view setting is now unused.** Only the CLI read it (the
   view `luthor add` captured into); the app reopens on the view last used.
   It stays in Settings for now

## Decisions (2026-10-17, slice 9)

1. **Time is set, not added.** `TaskTimeLogged` and `UnplannedTimeLogged`
   carry the minutes the day has; logging again replaces them and `nil` (or
   zero) clears them, like `DayCapacitySet`. A task done over several days has
   one entry for each. The roadmap's `TaskTimeLogged(minutes)` gained the
   task and the day, and `UnplannedTimeLogged` and `DayReviewed` the view,
   because the review is per view and day
2. **No completion date in the log.** A completed task counts as done on the
   day it was planned for, which the reducer remembers when it completes the
   task (`plannedDays`). A task completed without a day is in no review, and
   its time goes under unplanned. Completing early or late is still done on
   its planned day; a `TaskCompleted` with a date would be a later change
3. **Deciding clears the day.** A task deferred, delegated, sent to someday or
   dropped leaves the day it was planned for, so the review of an old day
   lists what was done and what is still undecided. The decisions themselves
   are not kept as a history; the plan is, in the events
4. **Leftovers are a pure function.** `LibraryState.carryOver(in:today:)`: open
   tasks of the view planned for a day before today, oldest day first, then the
   suggested order (a manual order for that day is honoured). Nothing writes an
   event to carry a task over. Candidates no longer include them, so a task is
   never in two places of Today
5. **Reviewing is optional and recorded.** `DayReviewed` does not gate
   anything; leftovers wait whether or not the day was reviewed. The note is
   one line (the command folds line breaks and runs of spaces to one space)
   and reviewing again replaces it
6. **History is shown, never applied.** `EstimateHistory` adds the estimates
   and the logged minutes of the tasks that have both; for a project, its
   tasks and sub-projects' tasks, open or completed. No command or reducer
   reads it to change an estimate
7. **⇧⌘N for Show Review.** N for Nachkontrolle, the ALPEN step. ⇧⌘R stays free
   for slice 14's project review

## Decisions (2026-10-17, automatic releases)

1. **CI cuts the release, from the Conventional Commits.** Every push to
   `main` since the last tag is read by `scripts/next-version.sh`: `feat` bumps
   the minor version, `fix` and `perf` the patch, `!` any type a breaking
   change. The other types release nothing, so docs and chore merges stay quiet.
   The first release is `v0.1.0`
2. **No automatic 1.0.0.** While the major version is 0, a breaking change
   bumps the minor one; going to 1.0.0 is a hand-pushed tag
3. **The release workflow makes the tag.** `gh release create --target <sha>`
   creates it, so no second workflow is needed (a tag pushed with the workflow
   token would not start one). A build that fails after a merge makes no
   release; the next merge works from the same last tag and tries again

## Decisions (2026-10-17, slice 10)

1. **Where the log lives is a per-device choice, not an event.** The log has
   to be found before it can be read, so the choice sits in `UserDefaults`
   next to the last view shown. A first-start modal asks (radio buttons
   Dropbox, defaulting to `~/Dropbox/backups/Luthor`, and Home Folder,
   `~/.luthor/events.jsonl`); Settings → This Mac changes it, live
2. **Moving to Dropbox copies, never moves.** The Home Folder log is copied in
   as this Mac's device file the first time, if that file does not exist; the
   original stays. Moving back copies nothing
3. **The environment still wins.** `LUTHOR_LOG` or `LUTHOR_SYNC_DIR` decide
   the place, with no modal and a read-only note in Settings. Without
   `LUTHOR_DEVICE_ID` a shared folder names the device after the host name
4. **Distribution stays ad-hoc signed.** A release zip is fetched with
   `gh release download`, which sets no quarantine flag, so Gatekeeper does
   not block it; notarising (Developer ID, $99 a year) is not set up

## Decisions (2026-10-17, slice 11)

1. **Slice 11 shrinks to due dates.** Due dates fit ALPEN: a deadline is an
   input to the morning plan, and decision 4 of slice 8 already leaves a slot
   for it in the ordering. Defer dates, Upcoming and Forecast are OmniFocus
   ideas, and ALPEN plans one day at a time. Dropped, not postponed
2. **No defer dates, so no availability rule.** "Defer to tomorrow" from
   slice 8 covers the need: it schedules the task for tomorrow. Scheduling
   still does not enforce availability (slice 8, decision 5) and no
   `CommandError` is added for it. Sequential projects keep holding tasks
   back through next actions, as before
3. **The calendar is a rail place, not a Forecast.** It shows where tasks
   are, with no totals and no overload flags: capacity stays a Today concern
4. **Calendar layout: a list of days, not month grids.** One row per day
   fills the first Miller column, as every other first column is a list, so
   picking works like any list (click, then the day's tasks in the next
   column). The column is narrow and a seven-column month grid is cramped in
   it; a row also has room for two kinds of mark and a weekday name, and the
   Sunday background marks the week boundary. Alternative, kept for later if
   the list proves hard to place a date in: month calendars, one grid per
   month, scrolling, with the same marks as dots under the day number and the
   same next column for the tasks of the picked day
5. **Two marks, planned and due.** A day with tasks scheduled for it and a day
   with a task due on it look different. Both read from existing and new
   events only; the calendar stores nothing of its own

## Decisions (2026-10-17, device IDs)

1. **A random machine ID, not the MAC address.** Two Macs can share a host
   name, and the shared folder named each Mac's file after it, so they would
   write the same file. macOS randomises Wi-Fi MAC addresses per network and a
   Mac has several, so `MachineID` makes a UUID on first start and keeps it in
   the app's defaults on that Mac (never in the log or the folder)
2. **The device is `<host name>-<first 8 characters of the ID>`** in a shared
   folder; `LUTHOR_DEVICE_ID` still wins, and without a shared folder it is
   `local`. Files written under the old host-name-only device stay in the
   folder and are still read; the Mac simply writes a new file from now on.
   If the defaults are wiped the Mac becomes a new device, which is harmless
   because events merge by ID

## Decisions (2026-10-17, read-only cards, issue #24)

1. **A card is read-only until the pencil.** The view model holds
   `editingCard`; the card shows the title, the creation day and the notes,
   and the pencil (no text) turns it into the editor. Showing another task,
   project, place or view leaves edit mode. A completed item has no pencil
2. **Nothing is written until OK.** The editor keeps its own draft of the
   fields; OK hands them to `saveCard` which writes the events that differ
   (the commands already write nothing for unchanged values), Cancel drops
   the draft. Priority and estimate used to be written on each pick, so
   they are drafts now too. A blank title writes nothing and keeps the card
   open
3. **The creation day is an optional field on the creating events.**
   `TaskCaptured` and `ProjectCreated` gain `createdOn` (a `CalendarDate`,
   ISO text in the log), set from the view model's clock. Optional and
   absent in old logs, so they replay unchanged and their cards show no day.
   No wall-clock time: the domain stays free of `Date()`
4. **The read-only card shows only title, day and notes**, as the issue
   asks. Priority, estimate, project, kind and the estimate history are in
   the editor
