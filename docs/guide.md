# Luthor user guide

How to use Luthor as it is today. This describes shipped behaviour only: what
is planned lives in `docs/plans/`. Every PR that changes what the app or the
CLI does updates this guide in the same PR (see the docs check in
`AGENTS.md`).

## Concepts

- **View**: a separate space, such as Work or Private. Every task and project
  belongs to exactly one view, and the app shows one view at a time: nothing
  from another view ever shows up in it. A log starts with one view, Default
- **Task**: one thing to do. Captured in the Inbox, optionally filed into a
  project, completed when done
- **Inbox**: tasks of the current view not yet clarified. Clarifying means
  giving a task a priority, an estimate or a project; once you do, it leaves
  the Inbox
- **Priority**: how much a task matters: Critical (A), Important (B),
  Optional (C) or One day (someday). It says nothing about order or deadline.
  A task has none until you give it one
- **Estimate**: how many minutes a task is expected to take. A task has none
  until you give it one
- **Someday**: a task given the One day priority. It is kept out of next
  actions until promoted to another priority
- **Project**: a group of tasks and other projects, its sub-projects, to any
  depth ("Home" contains "Kitchen", which contains "Replace tap"). Its
  children are in the order they were added. *Parallel*: every child is
  active. *Sequential*: only the first open child is; the others are dimmed
- **Next action**: a task you can do now. A task is one only if every project
  above it lets it be, and it is not someday: an active sub-project hands out
  its own next actions, one held back by a sequential parent hands out none

## Finding your way around

A narrow rail on the left lists the places, an icon with its name underneath.
It does not expand. Click a place to look at it:

- **Inbox**: your inbox tasks, as a list
- **Projects**: the top-level projects, as Miller columns (see Projects)
- **Prios**: the priorities, then the tasks that have one of them (see
  Priorities)
- **Settings**, pinned to the bottom of the rail (or ⌘,): the planning
  numbers (see Settings)

Above the main area is a bar with a search box and the view switcher. Search
does not work yet. Navigating by keyboard alone is not possible yet either.

## Views

- The view you are in is shown in the bar at the top of the window. Click it
  to switch to another view. It has no keyboard shortcut, so you cannot
  trigger it by mistake
- Create a view with New View… in the same menu; the window switches to it.
  Rename the current view with Rename View…. Names are unique, ignoring case
- The app opens on the view you used last on this Mac
- A task can only be filed into a project of its own view. To take a task to
  another view, select it and use Task → Move to View: it lands in that
  view's Inbox. To take a whole project with its sub-projects and tasks, use
  Move to View in the project's context menu. A sub-project moved alone is
  top-level in the other view

## Capturing a task

Type in the capture field and press Return. The field is always focused, so
capture needs no click. With a project shown, the task goes straight into
that project; otherwise it goes to the Inbox of the current view.

Add `!a`, `!b`, `!c` or `!someday` for a priority and `<n>m` for an estimate
in minutes, anywhere in what you type: `call bank !a 15m` captures "call
bank" with priority Critical and a 15-minute estimate, already clarified.
The `luthor add` command understands the same syntax.

## Completing a task

Select a task with ↑ and ↓ and press ⌘Return, or click its circle.

## Projects

Projects show in Miller columns. The first column lists the top-level
projects. Click a project to open it: a column of its sub-projects and tasks
appears to its right, and so on down the tree.

- Create a project with the field at the bottom of Projects, choosing
  parallel or sequential. It goes inside the project shown, or is top-level
  when none is open
- Nest a project by dragging it onto another, or onto a column to move it
  into that column's project. Drag it onto the first column, or use Move to
  Top Level in its context menu, to make it top-level again. A project cannot
  go inside itself or one of its own sub-projects
- File a task by dragging it onto a project, or select it and press ⌥⌘1 to
  ⌥⌘9 for the first nine projects (Task → Move to Project)
- Complete a project from the toolbar or its context menu. Its sub-projects
  and their open tasks are completed with it, all the way down

## Priorities and estimates

Give a task a priority from its context menu (Priority) or, with the task
selected, from Task → Priority; an estimate the same way, from Estimate (5,
15, 30 or 60 minutes). None clears either. Giving a task a priority or an
estimate clarifies it: it leaves the Inbox, same as filing it into a
project. A task keeps its priority and estimate when filed into a project or
taken to another view.

Prios lists Critical, Important, Optional and One day. Click one to list its
tasks. Click another to add it: the picked priorities add up, and the list
shows the tasks of all of them, the most urgent first. Click a picked
priority again to drop it. With none picked, the list is empty. You can
complete a task from the list like anywhere else.

A task given One day (someday) is kept out of next actions, wherever it is
filed, until you give it another priority.

## Settings

Settings shows two families in its first column: Global and Local.

- **Global** sets the numbers every view falls back to: the default estimate
  for a task given no estimate (5 minutes), the buffer percentage held back
  from each day's capacity (40%), and the capacity of each weekday in
  minutes (8 hours on weekdays, none at the weekend). It also picks the
  default view: the one `luthor add` and imports use when none is named
- **Local** overrides the buffer and the weekday capacity for the view
  currently shown. Each is a toggle: off, it follows the global value
  (shown greyed with "(global)"); on, it shows its own value to change.
  Switching it off returns to following the global value

These numbers do not yet change anything else in the app; Today (a later
slice) plans the day with them.

## The luthor command

A quick way to capture from a terminal. It knows tasks only, not projects,
and works in one view: the one named with `--view`, else `LUTHOR_VIEW`, else
the view chosen in Settings. View names ignore case.

```bash
luthor add "buy milk"
luthor add "call bank !a 15m"   # priority Critical, 15-minute estimate
luthor add --view Work "write the report"
luthor list              # every open task of the view, filed or not
luthor done 9afc         # any unique prefix of a task ID in the view
```

Set `LUTHOR_VIEW=Work` on the work Mac, and `luthor` never shows or touches a
private task there.

It shrinks to `luthor add` later, for launchers such as Alfred (see the
roadmap).

## Where your data lives

Everything is one append-only event log, `~/.luthor/events.jsonl` by default.
Set `LUTHOR_LOG` to use another file and `LUTHOR_DEVICE_ID` to name the device.
The app and the command share the log and see each other's changes. Back it
up by copying the file.

## Installing

See the README: `make install`, or a release from GitHub. The app is not
notarised, so the first launch of a copied app needs right-click → Open.
