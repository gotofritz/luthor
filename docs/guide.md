# Luthor user guide

How to use Luthor as it is today. This describes shipped behaviour only: what
is planned lives in `docs/plans/`. Every PR that changes what the app
does updates this guide in the same PR (see the docs check in
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
- **Plan**: the tasks you decided to do on one day in one view, in order. The
  work day and the evening are planned apart. A task keeps its identity when
  moved from day to day: rescheduling never duplicates it
- **Due date**: when a task is due, set on its card. A *hard deadline* puts
  the task ahead of the other tasks of its priority in Today's candidates
  once it is due; a *target date* is only shown. A due date never plans a
  task for a day by itself
- **Leftover**: an open task planned for a day before today. Nothing moves it
  on by itself: it waits at the top of Today until you decide on it
- **Review**: looking back on one day of a view: what was done, what was not,
  and how long it took against the estimates
- **Capacity**: the minutes a view has on a day. The weekday's capacity from
  Settings applies unless you set one for that day. The **buffer** is a
  percentage of it held back for interruptions; it is protected time, never a
  task. What is left is the **usable** time
- **Delegated**: handed to someone else. A delegated task leaves the plan and
  the totals and waits in Waiting for; it stays open, neither completed nor
  dropped
- **Next action**: a task you can do now. A task is one only if every project
  above it lets it be, and it is not someday: an active sub-project hands out
  its own next actions, one held back by a sequential parent hands out none

## Finding your way around

A narrow rail on the left lists the places, an icon with its name underneath.
It does not expand. Click a place to look at it:

- **Inbox**: your inbox tasks, as a list
- **Today**: the plan of a day, with its capacity (see Today)
- **Calendar**: the days, and the tasks of the one you pick (see Calendar)
- **Review**: the day looked back on (see Review)
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

## Completing a task

Select a task with ↑ and ↓ and press ⌘Return, or click its circle.

A completed task or project disappears from the lists. The Completed toggle
in the bar above the columns, between the search box and the view switcher,
brings them back: they show after the open ones, dimmed and struck through,
in the place they belong (the Inbox, their project's column, or the Prios
that match). The toggle is off when the app opens.

Reopen a completed task by clicking its tick or choosing Reopen in its
context menu. It goes back into its project if that is still open, else it
is loose, in the Inbox or the Prios. Reopen a completed project the same
way: it comes back with the sub-projects and tasks that were completed along
with it, but not tasks you had completed on their own before. What a project
took along cannot be reopened by itself; reopen the project.

## Cards

Click a task and a card opens in the column after the list. Click a project
and the column of its contents starts with the project's card, with its
sub-projects and tasks listed below it.

A card is read-only. It shows the day the task or project was created
("Created 2026-10-19", left out for what was created before the app kept the
day), for a task its due date ("Deadline 2026-10-23" or "Target date
2026-10-23", in red once the day has passed) and the notes ("No notes" if
there are none). It does not repeat the
title, which is in the column before it. Web addresses in notes
(`https://…` or `www.…`) are clickable links.

The pencil button at the top right of the card opens it for editing; nothing
is written until OK:

- A task's card then has the title field, the priority and estimate pickers,
  the Due date switch (a day to pick, and whether it is a hard deadline or a
  target date), its project, the estimate history if there is one, and the
  notes in a text field. A project's card has the title field, the kind (parallel or
  sequential), the estimate history and the notes
- A sequential project dims every child but its first open one, so the next
  actions change at once. The kind can also be switched from Kind in the
  project's context menu
- OK (or Return in the title field) keeps what you changed; Cancel drops it.
  A blank title is not kept: the card stays open so you can fix it. Clearing
  the notes removes them
- Showing another task, project or place closes the card without keeping
  anything
- A completed task or project shows its card too, with no pencil; Reopen is
  on the card

## Today

Today plans one day of the current view. Its first column shows the day
(◀ and ▶, or ⌘[ and ⌘], move to the previous and next day; the Today button or
⇧⌘T in the Plan menu comes back to today), the capacity meter and the plan.
The second column lists candidates, the third what you are waiting for.

**Capacity.** The meter shows the usable time, what is planned and what is
left, with the buffer as its own grey segment. A task with no estimate is
never refused: it counts at the default estimate from Settings and shows
"~5m"; the meter says how many are unestimated. When more is planned than is
usable the meter turns red and says by how much. It informs and never blocks:
the task is still planned. To change one day's capacity, set it for that day
(the weekday capacity from Settings applies otherwise).

**Pulling tasks in.** Candidates are the open tasks of the view that are
clarified (they have a priority, an estimate or a project) or whose hard
deadline is due, so a deadline is not missed in the Inbox; not someday, not
held back by a sequential project, and not delegated until their follow-up
day. A task planned for a later day is a candidate too, so you can pull it
forward. Select one and press ⌘T, or use Add to Plan in its context menu.
Remove from Plan (⌥⌘T) returns it to the candidates.

**Order.** The plan is in a suggested order unless you set your own: A before
B before C, then hard deadlines that are due on the day shown (the earliest
first, overdue ones included), then the order of the tasks in their projects,
then the order they were captured. Each task says why it sits where it does
("A priority, in project Move house, deadline 2026-10-19"). A target date, or a
hard deadline still ahead, changes nothing. Move a task with ⌥⌘↑ and ⌥⌘↓ (Plan menu or its context
menu): from then on the order is yours, tasks you add later follow it, and it
survives a relaunch.

**Deciding.** From the plan, or from the candidates, with the task selected:

- Defer to Tomorrow (⌘D) plans it for the day after the one shown
- Delegate… (⌘L) asks whom, and optionally a follow-up day. It leaves the
  plan and the totals, and shows in Waiting for with who has it and since when
- Send to Someday (⌘Y) takes it off its day and gives it the One day priority
- Drop Task (⇧⌘⌫) gives it up: it leaves every list, without being completed

**Leftovers.** A task planned for a day that has passed, and not completed or
decided on, is not carried over by itself. It waits in a section at the top of
the plan, "Left over from earlier days", saying which day it was planned for,
until you decide on it. Nothing needs a review to have happened first: an
unreviewed day's leftovers are there the next morning, and the morning after.
The same chords decide on it, counting from the day shown: Add to Plan (⌘T)
plans it for that day, Remove from Plan (⌥⌘T) sends it back to the list (it is
a candidate again), and Defer to Tomorrow, Delegate…, Send to Someday and Drop
Task work as above. Another Day, in the context menu, plans it for one of the
next few days.

**Waiting for.** Lists the delegated tasks of the view, the longest wait
first, with who and since when. On the follow-up day the task is a candidate
again and the entry says to follow up. Reclaim (context menu) takes it back
at any time; planning a delegated task also takes it back.

## Calendar

The Calendar shows days, and what is on them, for the current view. Its first
column is a list of days, one row across the column each, from 60 days back
to a year ahead; it opens scrolled to today, which is in bold. Sundays have a
tinted row. A filled circle with a number on a row means that many tasks are
planned for the day; an orange diamond with a number means that many are due
on it (hard deadline or target date). A day with neither has no mark.
Completed and dropped tasks leave their days.

Click a day and the next column lists its tasks: the ones planned for it, in
the order of its plan, then the ones that are only due on it. Each says why
it is there, "Planned", "Deadline" or "Target date". Click a task and its card
opens in the column after, as everywhere else. The calendar only shows:
planning, rescheduling and deciding on tasks are done in Today and Review. ⇧⌘C
(Plan menu) opens it.

## Review

Review looks back on one day of the current view. It shows the day Today
shows: ◀ and ▶ (or ⌘[ and ⌘]) change it, and the Today button comes back. ⇧⌘N
opens it (Plan menu). The first column has the totals (minutes planned,
minutes logged, minutes unplanned) and **Done**, the tasks planned for the day
that were completed. The second column has **Not done**, the tasks still
planned for the day, and the box that closes the review.

**Time.** Each task has a field for the minutes it took on that day, typed by
hand; an empty field clears it. Time can be logged for a done task and for
one not done, and for a day that is over. "Unplanned time" is the minutes of
the day spent on work that was not in the plan. Typing again replaces the
minutes of that day; nothing is added up behind your back. Planned minutes
use the estimate, or the default estimate for a task without one (shown
"~5m").

**Estimate history.** Under a task that has an estimate and logged time, the
review says what it was estimated and what it took over all days ("Estimated
60m, took 90m (+30m)"). The task's card and the card of a project show the
same, for a project added up over its tasks and sub-projects. It is only
shown: Luthor never changes an estimate for you.

**Deciding.** Each task not done gets a decision, with the task selected or
from its context menu, with the same chords as Today and counting from the
day reviewed: Defer to Tomorrow (⌘D), Another Day (a few days to pick from),
Remove from Plan (⌥⌘T, back to the list), Delegate… (⌘L), Send to Someday
(⌘Y) or Drop Task (⇧⌘⌫). A decided task leaves the day. Or complete it with
its circle, and it moves to Done. There is no carry-over rule per task: the
review decides.

**Closing the review.** Type a one-line note (long reflection belongs in your
notes app) and press Review Day. The day then shows "Reviewed" with its note,
and reviewing it again replaces the note. A day that is not reviewed is not
blocked in any way: its leftovers wait in Today.

A task shows in the review of the day it was planned for. A task completed
without having been planned for any day is in no review; log its time as
unplanned time instead. A task that was decided on has left the day it was
decided from, so the review of that day lists only what was done and what is
still undecided.

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
  and their open tasks are completed with it, all the way down. The Completed
  toggle shows them again, and Reopen brings them back (see
  [Completing a task](#completing-a-task))
- Rename a project, switch it between parallel and sequential, or add notes
  in its card (see [Cards](#cards))

## Priorities and estimates

Give a task a priority from its context menu (Priority) or, with the task
selected, from Task → Priority; an estimate the same way, from Estimate (5,
15, 30 or 60 minutes). None clears either. Giving a task a priority or an
estimate clarifies it: it leaves the Inbox, same as filing it into a
project. A task keeps its priority and estimate when filed into a project or
taken to another view.

Prios lists Critical, Important, Optional, One day and No priority. It
behaves like any Mac list. Click one to list its tasks. Shift-click to pick
the range up to it, or ⌘-click to add a priority to the picked ones or drop it.
The list shows the tasks of all the picked priorities, the most urgent first
and those with no priority last. With none picked, the list is empty. You can
complete a task from the list like anywhere else.

A task given One day (someday) is kept out of next actions, wherever it is
filed, until you give it another priority.

## Settings

Settings shows two families in its first column: Global and Local.

- **Global** sets the numbers every view falls back to: the default estimate
  for a task given no estimate (5 minutes), the buffer percentage held back
  from each day's capacity (40%), and the capacity of each weekday in
  minutes (8 hours on weekdays, none at the weekend). It also picks the
  default view
- **Local** overrides the buffer and the weekday capacity for the view
  currently shown. Each is a toggle: off, it follows the global value
  (shown greyed with "(global)"); on, it shows its own value to change.
  Switching it off returns to following the global value

Today plans the day with these numbers.

## Where your data lives

Everything is one append-only event log. The first time you start the app it
asks where to keep it: **Dropbox** (the default, `~/Dropbox/backups/Luthor`,
created if missing) or the **Home Folder** (`~/.luthor/events.jsonl`, this
Mac only). Settings → This Mac changes the choice later; moving to Dropbox
copies the Home Folder's tasks in the first time. Back up by copying the
file or folder.

## The same tasks on several Macs

Choose Dropbox on every Mac. Each Mac writes only its own file in the folder,
`events-<device>.jsonl` (named after the Mac's host name and a short random ID
the app makes on first start, so Macs with the same host name stay apart), and
reads all of them, so a task captured on one Mac shows on
the other within a few seconds of Dropbox delivering it. Two Macs changing
things while apart both keep their changes: when the files meet, every Mac
shows the same result. If two Macs change the same thing, the later change
(by the events' order, not the clock) wins. The README has the details.

## Installing

See the README: `make install`, or a release from GitHub, which installs on
another Mac without compiling. The app is not notarised, so the first launch
of an app downloaded in a browser needs right-click → Open.
