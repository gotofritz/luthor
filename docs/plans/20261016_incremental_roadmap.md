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
  measurably slow; no Dropbox API until iOS needs it (see `20261018_ios_app.md`)
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

### CI-Linux. Fast Linux job for the package ✅

A `linux` job (`swift:6.0` container, `make test-linux`: `swift build` and
`swift test`, no Xcode, lint or coverage gate) runs next to the macOS job, so
agent sessions without a toolchain get quick feedback. The macOS job stays
the full check. Issue #85.

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

### CD-2. ~~iOS~~ (moved)

Moved 2026-10-18 to `20261018_ios_app.md`. The number stays so the CI/CD
numbering holds.

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
project path, dropped subtrees, review intervals.

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
read-only (creation day and notes) until the pencil opens them for
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

Review is a place (⇧⌘N), looking back on the day Today shows; slice 14 folded it into Today as a Plan / Review toggle.
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

### 11. Due dates and the calendar ✅

`TaskDueSet(task, date?, isHard)` gives an open task a due date, a hard
deadline or a target date, and clears it when the date is missing; it is set
on the task card and never plans the task by itself. A hard deadline that is
due on the day Today shows, or overdue, ranks after priority and ahead of the
priority's peers, in the plan and the candidates, and the entry says so; an
unclarified task with such a deadline is a candidate too. A target date only
shows. Calendar is a new place on the rail (⇧⌘C): its first Miller column is
a scrolling list of days, one row across the column each, from 60 days back
to a year ahead, Sundays tinted, with one mark for tasks planned for a day
and another for tasks due on it; picking a day lists its tasks (planned ones
in plan order, then those only due) in the next column, and a task opens its
card in the one after. Per view and read-only: planning stays in Today and
Review. Which days have tasks, and which tasks a day has, are pure functions
of the state (`calendar(for:from:days:)`, `calendarEntries(for:on:today:)`).

Dropped from this slice (see Decisions, slice 11): defer dates and the
availability rule, Upcoming, Forecast.

Usable: deadlines feed the plan without taking it over, and any day's
tasks are one click away.

### 12. Tags ✅

`TagCreated(tag, name, view)`, `TaskTagged(task, tag)` and `TaskUntagged(task,
tag)` give a task any number of tags, labels such as `@calls`. A tag belongs
to one view, so `@calls` at work and at home are different tags, and taking a
task to another view leaves its tags behind. Tags are put on in the Tags field
of a task's card (comma-separated names; a new name creates the tag) or
toggled from a task's context menu. Tags is a new place on the rail (tag icon,
after Prios): its first Miller column lists the view's tags with how many open
tasks carry each, picking one lists those tasks in the next column, and a task
opens its card in the one after. Filtering is a pure `TaskFilter` (tags, all
of which a task needs; priority; project, sub-projects included; due by a
day), applied by `tasks(in:matching:)` and by `plan(for:on:today:matching:)`
to Today's candidates, which get a Filter button.

Usable: contexts (`@home`, `@calls`, `@deep-work`).

### 13. ~~Capture without the app: iPhone and Alfred~~ (dropped)

Dropped 2026-10-17: the Shortcut inbox file and the Alfred workflow are not
needed. The number stays so later slices keep theirs. The CLI is removed
with it (see Decisions 2026-10-17, slice 13 dropped).

### 14. Weekly project review ✅

`ReviewDefaultSet` sets how often projects are reviewed (a number of days, or
off; weekly until set), `ProjectReviewIntervalSet` overrides it for one
project (its own value, off, or none to fall back), and `ProjectReviewed(project,
date)` marks a review. A project's next review is its last review day, or the day
it was created, plus the effective interval: a pure function of the events, and
`projectsDueForReview(in:today:)` lists the projects of a view whose review is
today or overdue, the longest overdue first. `ProjectDropped`
gives a project a status; a dropped project hands out no next actions, so
none of its tasks is a Today candidate, and it is not reviewed. The weekly review is a new place on the rail, after
Calendar, with a glasses icon (`eyeglasses`, "Reviews"): the projects due, the one
picked with its card and the buttons to mark it reviewed or drop it, and its tasks, listed and edited like any list (new tasks are captured into
the picked project). Mark Project Reviewed (⇧⌘R) moves to the next project. The
default interval is in Settings → Global, a project's own in the review and in its
context menu. Afterwards a project's card gained the interval and an editable next
review day, so projects made together can be staggered: `ReviewDateSet(project, date)`
replaces the computed day until the project is next reviewed.

Usable: the weekly review.

### 14a. Repeating tasks ✅

A task can repeat, and completing it creates the next one. A `RepeatRule` is
every N days, weeks, months or years; a weekly rule can pick weekdays
(Monday and Thursday); monthly keeps the day number and a 31st falls on the
last day of a shorter month. It never ends. Fixed (the default) makes the next
due date the first date of the rule after the previous due date and after
today, so a week of missed days does not pile up; after completion makes it
the completion day plus the interval. `TaskRepeatSet(task, rule?)` sets or
clears the rule, and a repeating task needs a due date, whose kind (hard
deadline or target date) the next tasks keep: setting a repeat on a task with
none gives it the day Today shows, as a target date. Completing a repeating
task writes `TaskCompleted` and `TaskRecurred(previous, next, due)` in one
command; the reducer makes `next` a copy of `previous` as it is at that point
in the replay (title, notes, project, priority, estimate, tags, rule, kind of
due date; not the day planned, a delegation or logged time). The ID of `next`
is a hash of the ID of `previous`, so two Macs completing the same task write
the same next task and the reducer keeps the first. Skip This One drops the
task and makes the next; Stop Repeating clears the rule; Drop Task and Send to
Someday end the series. The Repeat field is in the card editor, a Repeat
submenu in the task context menu and Skip This One in the Task menu and the
decisions on Today.

Known cost: there is no start date, so the next task is in the lists at once,
a week early for a weekly task, though it only counts as a candidate under the
due-date rules. A start date would be its own feature.

Usable: the routines stop being retyped.

### 14b. Duplicate, delete, and tasks that become projects ✅

From issues #49, #50 and #51. `TaskDuplicated(source, copy, createdOn?)` makes
an open task out of another, with its title, notes, priority, estimate, due
date, tags and repeat, in the same project and planned for no day; it shares
its copying with `TaskRecurred`. `TaskDeleted` and `ProjectDeleted` remove a
task, or a project with its sub-projects and every task in them, open or
completed, for good; the events stay in the log as tombstones, the reducer
forgets everything about the target. `TaskPromotedToProject(task, project)`
turns an open task into a parallel project with its title, notes, view and
creation day, at the task's place in the project it was filed in. The app has
Duplicate (⇧⌘D, context menu), Add Tasks (card, context menu) and Delete
Permanently… (context menu, after a confirmation).

Usable: test and wrong items can be removed, and a task that grows can become
a project.

### 14c. One kind of item ✅

From issue #50, designed in
[`20261018_unify_tasks_projects.md`](../archive/20261018_unify_tasks_projects.md).
A project is a task with children, so the two models are one: one `TaskID`
(`ProjectID` is gone), and `TaskCaptured` takes an optional parent and kind.
`TaskMoved`, `TaskKindChanged`, `ReviewIntervalSet` and `TaskReviewed` serve
both, and completing, dropping, renaming, noting and deleting an item take its
subtree where it has one. A project card edits priority, estimate, due date,
repeat and tags like a task's, any item can be filed under any other, and
Duplicate and a repeat copy the whole subtree. Planning follows: only tasks
are actionable, a due date ranks the tasks under it, the calendar marks the
item that carries it, and a project's estimate rolls up from its open tasks.
The event format changed with no migration: the log is started afresh.

Usable: "plan the trip, due in spring" is one item.

### 14d. Look and feel: a view's accent ✅

The app has a face of its own, so its window can be told from Finder's and
the rest at a glance, and each view has its own colour. `SettingKey.themeAccent`
(per view, with a global fallback) names one of eight accents from the logo
palette; the app turns the name into colour. The rail takes the accent as
its fill and carries the logo's mountain, the window opens with the view's name
and the place shown in large heavy type over a rule in the accent, and the
planning views (capacity meter, calendar) use it too. Settings → Global sets the
accent every view falls back to and Settings → Views lists every view, each
with its own accent and overrides (Edit View… in the view switcher opens it on
the view shown; this replaces the Local family, which only reached the view
shown). The app has an icon (from the logo concepts; source in `docs/brand`).
No new event: it is a `SettingChanged` with a new key, which older builds ignore.

Usable: Work is blue, Private is plum, and the window says which at a glance.

### Stress test the desktop app (before 15)

Not a build slice: time spent using the Mac app hard before the format is
frozen and before iOS starts. Real tasks every day, two Macs at once, and a
big synthetic log, where launch replay time and capture latency are measured
(the first item of slice 16). It ends with a list of issues. Whatever it
finds in the event format is fixed in the audit step of slice 15, while the
format is still soft.

### 15. Freeze the event format ✅

The event format is frozen; the `AGENTS.md` event rules apply in full. Replay
skips an event type it does not know and leaves its line in the log, so an
older build opens a newer log (before, the decoder threw `unreadableLine`). A
synthetic golden log (`Tests/LuthorStoreTests/Fixtures/golden-log.jsonl`) holds a
line for every event type and every optional field; tests check that it
decodes, round-trips and replays to the same state reversed and with
duplicates, and fail when a type has no line. The audit found no wart worth a
migration, so the log is untouched. Any later breaking change needs a
migration script, a tested backup and a `!` commit, so the release version
moves with it.

### 15b. The log survives a bad line ✅

A damaged or half-written line no longer stops the app: it is reported (file, line), left out of the state and left in the file. `append` starts on a fresh line and `fsync`s. Repair Log quarantines this device's bad lines into `.rejected`. Compact still refuses a damaged log. Decisions: skip and report rather than a hard stop; plain `fsync`, not `F_FULLFSYNC`.

### 15a. Export and import as text ✅

File → Export to Text… writes the views, tags, tasks and projects as one YAML
file (`format: 1`; per item the title, notes, priority, estimate, kind,
parent, status, planned day, due date, repeat, delegation, tags). Import from
Text… adds what the library lacks, by ID, as ordinary events, so importing
twice changes nothing and a file from another Mac merges. It is the state,
not the history: time logged, reviews and settings are not in it. The one new
dependency is Yams (the YAML codec).

### 16. Speed pass

- Measure launch replay time and capture latency on the real log
- Only if needed: GRDB projections, snapshotting
- The global capture hotkey (#34) and the command palette (#35) were cut on
  2026-10-18: not core, so they wait in issues, to be done if at all later

### 17. ~~Dropbox API sync~~ (moved)

Moved 2026-10-18 to `20261018_ios_app.md`: only iOS needs it, as a Mac reads
the Dropbox folder directly (slice 10). The number stays so later slices
keep theirs.

### 18. ~~iOS app~~ (moved)

Moved 2026-10-18 to `20261018_ios_app.md`, together with the iOS CI/CD item.
This roadmap now ends at the desktop app.

### Later

Nothing is listed here any more. What is not scheduled lives in GitHub
issues, each worked out when it was taken off this list on 2026-10-18.

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
6. **A hard deadline outranks only within its priority.** An A task without a
   deadline still comes before a B task whose deadline is due: priority is
   importance and stays the first key. A deadline counts from the day the
   plan shows, so looking at tomorrow's plan ranks what falls due by then.
   A manual order still wins over all of it
7. **A due deadline reaches the candidates unclarified.** A due date does not
   clarify a task (slice 6, decision 1), but a hard deadline that is due
   makes the task a candidate even in the Inbox, so it cannot be missed.
   Someday tasks stay out, whatever their deadline
8. **The calendar lists a fixed window.** 60 days before today to 365 after,
   re-read on every refresh, so it follows the clock without a setting.
   Earlier days than that are reached through Today and Review
9. **Due dates survive completion.** Completing a task keeps its due date, so
   reopening it brings the deadline back; the calendar lists open tasks only
10. **The read-only card shows the due date too.** It was the day created and
    the notes only (issue #24); a deadline is something to see without
    opening the editor, so it joins them, in red once the day has passed.
    The editor has a Due date switch, a day and hard or target

## Decisions (2026-10-17, slice 12)

1. **A tag is made by naming it on a task.** There is no tag editor: the
   Tags field of the card, or the `tag(taskID:named:)` command, finds the
   view's tag of that name (ignoring case and a leading `@`) or creates it.
   `@` is how tags are shown, never part of the name. Renaming and deleting a
   tag are not in this slice (no `TagRenamed` or `TagDeleted` event); an
   unused tag stays in the list with a count of zero
2. **Names are unique per view in the command, not in the reducer.** Two
   Macs can create `@calls` at the same time, and the replay keeps both
   rather than dropping a tag a task was already put on. The commands never
   create a second one
3. **Tags belong to the task's view.** Tagging a task with a tag of another
   view is ignored by the reducer and refused by the command. Taking a task
   (or a project, with its tasks) to another view takes its tags off
4. **Completing keeps the tags**, as it keeps the due date, so reopening
   brings them back. The Tags place lists open tasks only
5. **Filtering is a domain value, the UI offers it in Today.** `TaskFilter`
   covers tag, priority, project and deadline for any list that wants it. The
   Today candidates take it through `plan(for:on:today:matching:)`; the plan
   itself is never filtered, so a planned task cannot be hidden. The Tags
   place is the tag filter of every other list. The filter lives in the
   window and is dropped when the view changes or the app relaunches; saved
   filters are the perspectives in Later
6. **Several tags narrow, they do not widen.** A task has to carry every
   picked tag. A deadline filter means due on or before the day, hard or
   target
7. **The Tags place sits after Prios**, above Settings, with the `tag` icon,
   as the navigation decisions ask of every new place

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
   `editingCard`; the card shows the creation day and the notes,
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
4. **The read-only card shows only the day and the notes**, as the issue
   asks. The title is left out because the column before the card already
   shows it. Priority, estimate, project, kind and the estimate history are
   in the editor, with the title field

## Decisions (2026-10-18, slice 14)

1. **The next review is worked out, not stored.** `ProjectReviewed` records
   the day; the next review is that day plus the interval in force now, so
   shortening an interval brings the review forward at once. A project never
   reviewed counts from the day it was created; one created before the day
   was kept counts from 1970-01-01, so it is due at once
2. **An interval is a number of days on the wire, 0 for off.** `ReviewInterval`
   is `off` or `every(days:)`; no days or fewer is off. A project's own
   interval can be off while the default is on, or on while the default is
   off, and `nil` clears it. The default is global; per-view defaults are not
   needed yet
3. **A review is due on its day.** The list holds the projects whose next
   review is today or earlier, so a project reviewed on Monday is due again
   the Monday after. Sub-projects are reviewed as projects in their own right
4. **Status is a property of the project.** `Project.status` is active or
   dropped, and `ViewState.nextActions` hands out nothing for a dropped
   project, nor for the sub-projects in it. Its tasks stay open and show
   dimmed; ones already planned for a day stay in that day's plan. A dropped
   project is not reviewed: `ProjectReviewed` for it is refused by the
   command and ignored by the reducer. The app has no way back from a drop
   (the events are never deleted). A pause (on hold) status, with Resume, was
   built and then taken out to keep the app simple
5. **The weekly review is "Reviews" on the rail**, with the glasses icon. The
   day's review lost its rail icon: it is Today's other face, flipped with a
   Plan / Review toggle in the header of both (`NavigationSection.review`
   stays, with ⇧⌘N, and Today stays picked on the rail while it is shown).
   The status button reads Drop Project. Its first
   column lists the projects due, the next the picked project's card with
   Mark Reviewed, the interval picker and Drop Project, the third its
   tasks. The first project is picked on arrival, and marking one reviewed
   picks the one that takes its place, or none when the list is empty
6. **`Project` moved to its own file** (`Project.swift`) with its new status,
   to keep `LibraryState.swift` under SwiftLint's file length

## Decisions (2026-10-18, slice 14a)

1. **The next occurrence appears at once, with no start date.** Not confirmed
   with the owner yet: the alternative is a start (availability) date, which
   would be its own feature
2. **Drop Task and Send to Someday end the series; Skip passes over one
   occurrence.** Not confirmed with the owner yet. Send to Someday clears the
   rule (`TaskRepeatSet` with none), Drop Task writes only `TaskDropped`
3. **A repeat on a task with no due date gives it the day Today shows**, as a
   target date. Not confirmed with the owner yet. The card editor turns the
   Due date switch on and locks it while Repeat is on
4. **Weekdays apply to a weekly rule counted from the due date.** Every
   second week counts weeks from the one the previous due date is in. Counted
   from completion, the weekdays are dropped
5. **The completion day is the injected clock.** `Commands.complete` takes
   `today`; without it the task counts as done on its due date, and a
   repeating task with no due date counts from `today`. The domain never reads
   a clock
6. **The rule is kept on completed and dropped tasks** (as the due date is), so
   `TaskRecurred` can copy it from a completed `previous`. A `TaskRecurred`
   whose `next` exists already is ignored, so completing a reopened task
   again does not make a second next task; the command does not write it
7. **A month keeps the day number of the previous due date.** A 31st that fell
   on the 28th stays on the 28th afterwards: the rule has no memory of the
   31st. Accepted for now
8. **Completing a project completes its open repeating tasks without making
   new ones**, as it takes everything open along
9. **The next task has no creation day** (`createdOn` is `nil`): `TaskRecurred`
   carries no day, as the roadmap listed it

## Decisions (2026-10-18, slice 15)

1. **Slice 15 is cut down.** No separate "every event type and field as v1"
   document: the golden fixture and the `EventType` enum are the spec, as
   the only reader is the owner. Added instead: an audit and fix pass while
   the format is still soft, and skipping unknown events on replay, so an
   older build survives a newer log
2. **Not deferred to slice 17.** The guard is cheap, protects the log now
   that two Macs share it, and slice 14 lands first so its events are in v1

## Decisions (2026-10-18, issues #49 to #51)

1. **Tasks and projects stay two models for now** (issue #50). Merging them
   (a project is a task with children, with target dates and every other task
   field) touches the reducer, planning, calendar, review and the columns, and
   needs the log started afresh (test data only). It is the right direction, and cheapest before the
   format freezes in slice 15, so it is its own slice (14c, designed in
   `20261018_unify_tasks_projects.md`, now in `docs/archive/`). Until then Add Tasks
   promotes a task to a project: priority, estimate, due date, tags, repeat,
   the day planned and a delegation are let go, as a project holds none of
   them. Not confirmed with the owner yet
2. **Delete is a tombstone event, not an edit of the log.** `TaskDeleted` and
   `ProjectDeleted` keep the append-only rule; the reducer forgets the task
   or project and its data, but keeps the task's place in the capture order
   so capturing it again or reopening it brings nothing back
3. **Deleting a project deletes everything under it**, sub-projects and tasks,
   completed ones too, including a sub-project completed on its own. The app
   asks first; there is no undo
4. **A copy is planned for no day and has no delegation**, as the next task of
   a repeat is. It does keep the repeat rule, so duplicating a repeating task
   starts a second series. Projects cannot be duplicated yet
5. **The copy is a new task with the same title.** No "copy of" suffix

## Decisions (2026-10-18, slice 14c)

The five open questions of the plan took its recommended option; say if one
should change.

1. **Dropped items are hidden like completed ones**, listed under "Completed
   and dropped", reopenable, and dropping takes the subtree. A skipped
   occurrence of a repeating task is dropped too, so it is listed there
2. **Repeat on a project copies its subtree**, so a task that gets a child
   keeps its repeat. The copy's tasks carry no due dates
3. **A project's priority does not flow down** to its tasks
4. **A project's tags do not flow down**
5. **The inbox lists unclarified tasks with no parent**; a project with no
   parent is in Projects
6. **Add Tasks makes the item a parallel project at once** (`TaskKindChanged`)
   instead of waiting for its first child, so the columns have somewhere to
   open; it keeps every field. There is no promote event
7. **A project is never itself actionable.** A project whose tasks are all
   done is still open until it is completed by hand
8. **A project's estimate is its own, else the sum of its open tasks'**, shown
   and never planned; its due date ranks the tasks under it and is marked on
   the calendar once, on the project
9. **A copy of a project holds copies of everything in it that was not given
   up**, completed ones included, as open tasks with IDs worked out from the
   copy's, so two devices make the same ones

## Decisions (2026-10-18, issue #55)

Miller column rework. No new event: the notes stay one plain text.

1. **Notes are bullets by line.** A note is a non-blank line of the notes
   text; adding one appends a line, deleting one removes its line. Existing
   notes that already have several lines become several bullets. Appending or
   deleting rewrites the notes with each line trimmed and blank lines dropped.
   The editor still shows the whole text, one bullet to a line
2. **The plus button replaces the New project field and, in Projects, the
   capture field.** Each column ends with a plus that opens a field with a
   choice of task, parallel project or sequential project. The first column
   lists top-level projects, so it offers only the two projects. The Inbox and
   the weekly review keep their capture field
3. **A project's column starts with the project's name**, which picks its
   card. The card of the project shown sits in the last column, where a task's
   card goes, and a task picked takes its place
4. **Clicking the project that is already open deselects what is picked
   beyond it.** The list reports changes of selection only, so a click now
   also goes through the view model (`open`), which clears the task picked
5. **Clicking a column scrolls it to the left edge**, as Finder does, as far
   as the columns after it leave room. This also shows a column that was half
   out of view in full
6. **Clicking the empty part of a column closes what lies beyond it**, the
   same as picking nothing there. In the first column that leaves no project
   shown; in a later one the column's project is shown with no task picked

## Decisions (2026-10-18, issue #60)

Editing improvements to the plus button. No new event: the item is made in one
write when OK is pressed.

1. **The plus button starts a draft, not a field.** It closes the columns
   after its own, shows a read-only box with the title above the button, and
   puts the new item's card in edit mode in the next column. The box follows
   the title as it is typed. The draft lives in the view model (`newItem`) and
   writes nothing until OK; Cancel, Escape or going anywhere else drops it
2. **New tasks start with priority optional (C) and an estimate of 5
   minutes**; new projects start with neither. Switching the kind on the card
   swaps the defaults, unless that field was set by hand (setting it to what it
   holds is not an edit; clearing it is). Quick capture and the inbox are
   unchanged: a task there has what the capture syntax gives it
3. **Add Tasks starts the first task at once.** Promoting a task to a project
   now also starts a new task in it, so one press does both
4. **Pressing the plus of the column whose item is being edited keeps what
   was typed**; the plus of another column starts a fresh item
5. **After OK a task is selected and a project is opened**, so its card or
   column is shown, rather than the field staying open for another item
6. **An empty project can be turned back into a task.** `TaskKindChanged` now
   takes an optional kind; none means a task. Only an item with no open task
   or sub-project in it qualifies (`projectHasChildren` otherwise), and what
   was set on it stays. Old logs still replay, as every kind written so far is
   there. The context menu offers it on a project with nothing in it

## Decisions (2026-10-19, look and feel)

1. **The accent is a setting in the log**, not a per-Mac preference: a view's
   colour belongs to the view, so it follows it to every Mac. A build that
   does not know the key ignores it, and a value it does not know falls back to
   navy
2. **The domain names the accent, the app colours it.** `ThemeAccent` is eight
   names; their RGB, the light and dark variants, the type and the mountain
   mark live in `App/Luthor/Theme.swift`. Views read `@Environment(\.theme)`
   instead of `Color.accentColor`, so a view's colour is one read away
3. **Flat and Swiss.** One grotesque (the system face) in three weights,
   square swatches, a rule instead of a box, the accent used as a block (the
   rail) and as a line (under the title) rather than sprinkled around. Red stays
   for overdue and overloaded, orange for a follow-up that is due; no accent
   is red or orange so they never mean two things
4. **The icon is the abstract alpine peak** of the logo concepts, rendered from
   `docs/brand/luthor-icon.svg` into `App/Luthor/Assets.xcassets`
5. **Views replaces Local in Settings.** A list of views with the settings of
   the one picked, instead of overrides for the view shown, so another view's
   colour can be set without switching to it. The view model's settings
   calls take a view; the `ForCurrentView` ones remain and use the view shown
6. **The rail's mountain is the icon's, in three tones**: white for the lit
   top, translucent white for the faces in light, a dark shade for the one in
   shadow, on a clear sky, so it takes on each view's accent. The app also
   sets its icon explicitly at start, as ⌘-Tab can keep showing a generic one
   that Launch Services cached

## Decisions (2026-10-19, slice 15)

1. **Do it now, as a safety net, with strict rules.** The owner runs two Macs
   with real data, so the format is frozen as is: no audit migration, because
   nothing found is worth the risk. Breaking changes stay possible only with
   a migration script, a tested backup and a `!` commit
2. **Text export is YAML, not OPML.** OPML is what OmniFocus exports, but it
   is an outline of text plus free attributes: it can carry the tree and
   notes, yet priority, estimates, repeat rules, delegation and the schedule
   would be invented attributes that no other tool reads, and it has no
   typed values. YAML is readable, diffable, typed and lossless for this
   data. The file holds tasks and projects, not events, so it stays
   readable and does not change when events are added. OPML export is an optional extra for interop, not the backup format
3. **No automatic retention; a Compact Log button instead.** Events are
   append-only and about 200 bytes each, so a year of heavy use is a few
   megabytes, and slice 16 measures replay time before anything more is built.
   When the log should shrink, Settings → This Mac → Compact Log backs up the
   old files and a YAML copy, rebuilds the log from the library (export, then
   import), verifies it holds the same library and swaps it in. With several
   Macs it first runs a handshake of small files in the shared folder (each
   file has one writer): the asker requests, every other Mac answers and stops
   writing, the asker waits until their last events have arrived, then
   compacts; a Mac that stays away can be skipped by force, and the new events
   outrank the old ones. History (time
   logged, reviewed days) is dropped; tasks, projects, settings and project
   reviews stay. Events are never deleted in place

## Decisions (2026-10-23, editing a project in the columns)

A project's column no longer starts with the project repeated at its head.
The pencil on the project's own row (shown on the projects the columns lead
through) swaps the list of its children for its card, in the column right
after the row; pressed again it brings the list back. Opening a project shows
its list with no card until a task is picked or the pencil is pressed. State
is `projectCardOpen` in the view model, closed by picking a task, opening
another project, starting a new item or leaving the Projects place. No event
changes.

## Decisions (2026-10-24, Today as a day calendar)

Today's order is by urgency: the priority's weight (A 0 days, B 10, C 20,
none 30) plus the days to the due date, hard or target (none counts as 30,
more than 90 days off as 90, overdue below zero), so a critical task due in
months no longer tops the list. The day is laid out as a calendar: the
planned tasks end to end from the day's start, as tall as their estimates;
`DayHoursSet(view, date, start?, end?)`, a new optional-field event with a
golden-log line, sets one day's hours, over the per-weekday
`dayStart…`/`dayEnd…` settings (09:00 to 17:00 built in). Waiting for is a
toggle on the candidates column, the candidate Filter button is gone until
app-wide search and filtering, and the capture field shows in the Inbox only.

One due date, one scheduled date, repeat: the hard/target choice is gone from
the app. `TaskDueSet` keeps its `isHard` field (the format is frozen) but nothing
reads it. A due date only ranks: urgency is the priority's weight plus the days
to it (equal to the priority's own on the due day, none counting as 30, far-off
capped at 90). The scheduled date is the day a task is in the plan; on any other
day it ranks after all the other candidates. The card always shows the Due and
Scheduled rows.

Untracked time: `DayBlockSet(block, view, date, title, start, end)` and
`DayBlockRemoved(block)` put a block such as lunch on a day; tasks flow round it
and it is not counted in the capacity. The Default button for a day's hours is gone.

A planned task can stand at a time of its own: `TaskStartSet(task, date,
minute?)` (another optional-field event with a golden-log line), valid only
while the task stays planned for that date. The others follow in plan order
from the day's start, or from now on today, round the fixed ones. Candidates
and blocks drag onto the grid and back; the grid zooms.
