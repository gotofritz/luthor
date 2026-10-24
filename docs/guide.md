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
- **Delete**: removing a task or a project for good. Dropping a task gives
  it up but is a decision you made; deleting is for the ones that are wrong,
  or that you only made to try the app. Nothing of a deleted task or project
  is left to show or to reopen
- **Plan**: the tasks you decided to do on one day in one view, in order. The
  work day and the evening are planned apart. A task keeps its identity when
  moved from day to day: rescheduling never duplicates it
- **Due date**: a deadline, set on its card. It is a way to prioritise: the
  closer it is, the closer the task's de facto priority comes to its own, and
  on the due day they are equal. Months ahead the task ranks near the bottom of
  the list. A due date plans nothing. There is one kind of due date: older logs
  that say hard deadline or target date are read as plain due dates
- **Scheduled date**: the day a task appears in Today's plan, set on its card
  or by planning it in Today. On every other day it is at the bottom of the
  candidates
- **Repeat**: a task that comes back. Completing it makes the next one, due
  by its rule (every N days, weeks, months or years). It counts from a due
  date, so a task that repeats always has one
- **Tag**: a label such as `@calls` or `@deep-work`, put on any number of
  tasks and shown with an `@`. A tag belongs to one view, so `@calls` at work
  and `@calls` at home are different tags
- **Weekly review**: looking over your projects so none goes stale. Each
  project has a next review day, one interval (a week unless you change it)
  after the day it was last reviewed, or created
- **Dropped**: an item you gave up. Like a completed one it leaves the
  lists, with the open items in it, and is not reviewed; the Completed and
  dropped toggle lists it and Reopen brings it back
- **Leftover**: an open task planned for a day before today. Nothing moves it
  on by itself: it waits at the top of Today until you decide on it
- **Review**: looking back on one day of a view: what was done, what was not,
  and how long it took against the estimates
- **Day start and end**: when a day begins and ends on the calendar of Today.
  Each weekday has its own in Settings; a day can have its own in Today
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
- **Projects**: the top-level projects, as Miller columns (see Projects)
- **Prios**: the priorities, then the tasks that have one of them (see
  Priorities)
- **Today**: the plan of a day, with its capacity (see Today); the Plan /
  Review toggle at the top flips it to the day looked back on (see Review)
- **Calendar**: the days, and the tasks of the one you pick (see Calendar)
- **Reviews** (the glasses): the projects whose review is due (see Reviews).
  The review of a day is Today's other face (see Review)
- **Tags**: the view's tags, then the tasks that carry the one you pick (see
  Tags)
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
- Each view has an accent colour, shown as the rail's fill, as the line under
  the title and in the Today and Calendar places, so you can tell which view
  you are in at a glance. Change it in Settings (see below)
- The app opens on the view you used last on this Mac
- A task can only be filed into a project of its own view. To take a task to
  another view, select it and use Task → Move to View: it lands in that
  view's Inbox. To take a whole project with its sub-projects and tasks, use
  Move to View in the project's context menu. A sub-project moved alone is
  top-level in the other view

## Capturing a task

Type in the capture field of the Inbox and press Return. The field is always
focused, so capture needs no click. The task goes to the Inbox of the current
view. The field is only there in the Inbox; every other place has the room to
itself. In the Projects place add tasks with the plus button at the end of a
column (see [Projects](#projects)).

Add `!a`, `!b`, `!c` or `!someday` for a priority and `<n>m` for an estimate
in minutes, anywhere in what you type: `call bank !a 15m` captures "call
bank" with priority Critical and a 15-minute estimate, already clarified.

## Completing a task

Select a task with ↑ and ↓ and press ⌘Return, or click its circle.

A completed or dropped task or project disappears from the lists. The Completed and dropped toggle
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

In the Projects place, click a task and its card opens in the column after the
list. Click a project and the column of its contents opens. To edit the
project itself, press the pencil on its row (it shows on the projects the
columns lead through): the project's card takes the place of the list of its
contents, right after the row. Press the pencil again, or click the project,
to bring the list back. Picking a task in the list shows the task's card.

The card of an open task or project shows every field and each one is changed
by clicking it, kept at once with no OK: the title (Return keeps it), the
priority as a row of four icon buttons (a thunderstorm for Critical, drizzle for Important, a cloud for Optional, a moon with stars for One day; the name is the tooltip, and a click on the lit one clears it; the lit one has the view's accent as its background), the
estimate (a slider, logarithmic from 5 minutes at the left to a week at the right, so any value can be picked; it is kept when you let go, and the cross beside it clears the estimate), the due date and the scheduled date, Repeat (see [Repeating tasks](#repeating-tasks)), the
Tags field (names separated by commas; Return keeps them), and for a project
its kind and how often it is reviewed. The Due and Scheduled rows (a task
only; a project has no scheduled date) always show, greyed out with today's
date until set: click the row, or pick a day, and it ticks and takes today or
that day; unticking the box clears it. Above them is the day the task or project was
created ("Created 2026-10-19", left out for what was created before the app
kept the day). A completed task or project shows its card read-only, with the
same facts as lines of text.

The notes are a list of bullet points, one for each line. Each bullet has a
small cross that deletes it, and a click on a bullet turns it into a field (Return or a click elsewhere keeps the change; emptying it deletes the note), and below them the "Add a note" field adds a
note on Return, without opening the editor. Web addresses in notes
(`https://…` or `www.…`) are clickable links, and the pointer turns into a
hand over one. A completed task or project
shows its notes with no cross and no field.

At the very top of an open card a pulldown shows the project the task is in
(the project the project is in, for a project's card) as the whole tree of
projects, indented by nesting. Pick another to move the task there, or No
project to take it out of its project. This matters in Prios, Calendar and
Tags, where the lists mix tasks of every project. A project cannot be moved into
itself or into anything inside it.

There is no edit mode: the card looks the same until you click a field, and
that field is then edited and kept at once. The title (Return keeps it, and a
blank title is not kept) heads the card, and a project's card also has its
kind (parallel or sequential, which can also be switched from Kind in the
project's context menu), how often it is reviewed and its next review day. A
sequential project dims every child but its first open one, so the next
actions change at once. A project shows an estimate of its own or, failing
that, the sum of its open tasks' estimates. Clearing the notes' last bullet
removes them. A completed task or project shows its card read-only; Reopen is
on the card.

## Today

Today plans one day of the current view. Its first column is the day as in a
calendar (◀ and ▶, or ⌘[ and ⌘], move to the previous and next day; the Today
button or ⇧⌘T in the Plan menu comes back to today): the hours of the day on a
grid, the capacity meter and the plan laid out on the grid. The second column
lists candidates; a toggle at its top switches it to what you are waiting for.

**Day start and end.** Two fields at the top of the day set when it starts and
ends (09:00 to 17:00 to begin with); the weekday's own hours come from Settings.
Changing a field sets the hours of that day alone. The hours outside the day are shaded, and a plan longer than the
day runs into them. The + and − magnifying glasses beside the fields zoom the
grid in and out. On today a red line marks the time now.

**No overlaps.** Tasks never overlap each other or a block. If a task's time,
or the estimate of the task before it, leaves no room, it and the tasks after it
move down to make room, and they move back if the room comes back. The time you
gave a task is kept, so it returns to it when the room is there again.

**Sessions.** A task done on and off through the day can have sessions: choose
Split Off a Session… in its block's context menu, give a start and an end, and
that stretch of the day becomes a block of its own, drawn with a dashed edge.
The task's own block shrinks by those minutes (and goes when the sessions take
all of them), so the estimate stays the total. Drag a session, or choose Set
Times… on it, to move it; Remove Session gives its minutes back to the task.
Stop Now makes the run you just did a session at its real time. Sessions push
other blocks aside, and are pushed, like tasks.

**Untracked time.** The calendar button beside the zoom buttons adds a block
of time that is not tracked, such as lunch or shopping: a title, a start and an end, each with a Now button
(the same window as Set Times… on a task). It is grey with a dashed edge, tasks flow round it, and it does not
count in the capacity. Drag it to another time (it keeps its length), double-click
it or choose Set Times… to change it, and Delete in its context menu or in that
window takes it off.

**Placing tasks.** Each planned task is a block as tall as its estimate (an
unestimated one at the default estimate). Drag a candidate onto the grid to
plan it at that time (to the quarter hour), and drag a block to another time to
move it. A task dragged onto others wins its place: they move out of the way as you drag, and stay where they
are put when you let go. A block's context menu has Start Now (on today: the same as Set Times… with
now filled in; while the task is under way it reads Stop Now, which adds the minutes
since the start to the time logged for the task and turns the run, from its start to now, into a session of the
task; see Sessions below), Set Times… (a start and an end, each with a Now button; the end sets the estimate),
Follow the Other Tasks (drops its set time) and Back to Candidates; dragging a
block back onto the candidates does the same. A task with no time of its own,
such as one added with ⌘T, follows the others in the plan's order from the
start of the day, or on today from now (to the quarter hour) if that is
later, and goes round any task with a set time. A set time holds only while the
task stays planned for that day. Click a block to select it; the other
context-menu items move it in the order or decide on it.

**Capacity.** The meter shows the usable time, what is planned and what is
left, with the buffer as its own grey segment. A task with no estimate is
never refused: it counts at the default estimate from Settings and shows
"~5m"; the meter says how many are unestimated. When more is planned than is
usable the meter turns red and says by how much. It informs and never blocks:
the task is still planned. To change one day's capacity, set it for that day
(the weekday capacity from Settings applies otherwise).

**Pulling tasks in.** Candidates are the open tasks of the view that are
clarified (they have a priority, an estimate or a project) or whose due date
has come, so a due date is not missed in the Inbox; not someday, not
held back by a sequential project, and not delegated until their follow-up
day. A task planned for another day is a candidate too, at the bottom of the
list, so you can pull it in. Select one and press ⌘T, or use Add to Plan in its context menu.
Remove from Plan (⌥⌘T) returns it to the candidates.

**Order.** The plan is in a suggested order unless you set your own: by
urgency, then the order of the tasks in their projects, then the order they
were captured. Urgency counts days: a priority weighs A 0, B 10, C 20 and none
30, plus the days left to the due date (no due date counts as 30, one more than
90 days off as 90; an overdue one counts below zero). The smallest total
comes first, so a critical task due in six months ranks below important ones with no deadline,
which rank below one due next week, and a task due today comes first. Ties go to the higher priority. Each task says why it sits where it does
("A priority, in project Move house, due 2026-10-19"). Move a task with ⌥⌘↑ and ⌥⌘↓ (Plan menu or its context
menu): from then on the order is yours, tasks you add later follow it, and it
survives a relaunch.

**Deciding.** From the plan, or from the candidates, with the task selected:

- Defer to Tomorrow (⌘D) plans it for the day after the one shown
- Delegate… (⌘L) asks whom, and optionally a follow-up day. It leaves the
  plan and the totals, and shows in Waiting for with who has it and since when
- Send to Someday (⌘Y) takes it off its day and gives it the One day priority
- Skip This One, for a task that repeats, passes over this occurrence (see
  [Repeating tasks](#repeating-tasks))
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

**Waiting for.** The toggle above the candidates lists the delegated tasks of the view, the longest wait
first, with who and since when. On the follow-up day the task is a candidate
again and the entry says to follow up. Reclaim (context menu) takes it back
at any time; planning a delegated task also takes it back.

## Calendar

The Calendar shows days, and what is on them, for the current view. Its first
column is a list of days, one row across the column each, from 60 days back
to a year ahead; it opens scrolled to today, which is in bold. Sundays have a
tinted row. A filled circle with a number on a row means that many tasks are
planned for the day; an orange diamond with a number means that many are due
on it. A day with neither has no mark.
Completed and dropped tasks leave their days.

Click a day and the next column lists its tasks: the ones planned for it, in
the order of its plan, then the ones that are only due on it. Each says why
it is there, "Planned" or "Due". Click a task and its card
opens in the column after, as everywhere else. The calendar only shows:
planning, rescheduling and deciding on tasks are done in Today and Review. ⇧⌘C
(Plan menu) opens it.

## Review

Review looks back on one day of the current view. It is Today's other face:
the Plan / Review toggle at the top of Today flips between the two, and the
day shown stays. It shows the day Today
shows: ◀ and ▶ (or ⌘[ and ⌘]) change it, and the Today button comes back. ⇧⌘N
opens it (Plan menu). The first column has the totals (minutes planned,
minutes logged, minutes unplanned) and **Done**, the tasks planned for the day
that were completed. The second column has **Not done**, the tasks still
planned for the day, and the box that closes the review.

**Time.** Each task has a field for the minutes it took on that day, typed by
hand; an empty field clears it. Time can be logged for a done task and for
one not done, and for a day that is over. "Unplanned time" is the minutes of
the day spent on work that was not in the plan. Typing again replaces the
minutes of that day; nothing is added up behind your back, except by Stop Now.
The field shows the estimate greyed when no time is logged, and closing the
review logs that estimate for each done task that has an estimate and no time. Planned minutes
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

## Reviews

The Reviews place (the glasses icon, after Calendar) keeps projects from going
stale. Its first column lists the projects of the current view whose review is
due, the longest overdue first, each with the day the review fell due. A
project is due once its next review day is today or has passed, so a project
reviewed on a Monday is due again the Monday after. Sub-projects are reviewed
as projects of their own. The first project is picked for you.

- The second column is the picked project's card (its next review day, in
  red when overdue; edited in place as anywhere else) with the buttons
  below it: **Mark Reviewed**, how often it is reviewed, and its status
- The third column lists its tasks, which you can complete, give a priority,
  estimate or tags, open and edit, exactly as in the Projects place
- **Mark Reviewed** (⇧⌘R, Plan → Mark Project Reviewed) records today as the
  day it was reviewed and picks the next project. The project is due again an
  interval later
- Plan → Show Project Reviews opens the place

**How often.** Every project is reviewed weekly until you say otherwise.
Settings → Global → Project review sets the default (Off, Daily, Every 3
days, Weekly, Every 14 days, Every 30 days) for all projects. A project's own
interval overrides it: pick it in the review, or from Review in the project's
context menu in Projects. Choosing Default goes back to following the
default. Off leaves one project out of the review; with the default off, only
projects with an interval of their own are reviewed. Changing an interval
changes the next review day at once.

**Choosing the next review day.** A project card shows its next review day
and how often it is reviewed. To spread projects made together over the weeks,
pick a day under Next review on the card (and, if you
like, a different interval under Review). The project is left out of
the review until that day. Mark Reviewed drops the chosen day, and the next
review is an interval after the day reviewed. A project whose review is off
shows "Review off" and has no day to pick.

**Dropping.** Drop Project (the button, or the project's context menu) gives
up a project: it and its open tasks leave the lists and the review, and
nothing is deleted. The Completed and dropped toggle lists it with a cross
symbol, and Reopen brings it back with the tasks it took along.

A project that was never reviewed counts from the day it was created, so a
project older than a week is due the first time you look. A project created
before the app kept the day is due at once.

## Projects

Projects show in Miller columns. The first column lists the top-level
projects. Click a project to open it: a column of its sub-projects and tasks
appears to its right, and so on down the tree.

- The plus button at the end of a column adds to it. One press shows a box
  above the button, which cannot be typed in, and replaces the card in the next
  column with the card of the new item, in edit mode with the title focused.
  The box shows the title as you type it. The card has a choice of a task, a
  parallel project or a sequential project (the first column offers only the
  two projects, which are top-level there), and the fields of any card,
  including the Due and Scheduled rows (a project has no Scheduled row). A new
  task starts with priority optional and an estimate of 5 minutes, a project
  with neither; switching the kind on the card swaps these defaults, unless
  you have changed that field yourself. Nothing is written until OK (or
  Return in the title); Cancel, Escape, or clicking anywhere else drops the item
- Clicking the empty part of a column closes every column to its right: in the
  first column no project is open any more, in a later one its project is
  shown with no task picked
- Clicking in a column scrolls the columns so that it moves to the left edge,
  as in Finder, as far as the columns to its right leave room
- Nest a project by dragging it onto another, or onto a column to move it
  into that column's project. Drag it onto the + at the end of the
  first column, or use Move to Top Level in its context menu, to make it top-level again. A project cannot
  go inside itself or one of its own sub-projects
- File a task by dragging it onto a project, or select it and press ⌥⌘1 to
  ⌥⌘9 for the first nine projects (Task → Move to Project)
- Complete a project from the toolbar or its context menu. Its sub-projects
  and their open tasks are completed with it, all the way down. The Completed
  toggle shows them again, and Reopen brings them back (see
  [Completing a task](#completing-a-task))
- Rename a project, switch it between parallel and sequential, or add notes
  in its card (see [Cards](#cards))

## Duplicating, deleting and growing an item

A task and a project are the same kind of item. A project is an item that
holds others, so it has everything a task has: priority, estimate, due date,
repeat and tags. Its priority and tags are its own and do not pass down to its
tasks. Only the tasks in it are planned: a project's due date ranks them as
if it were theirs (a hard deadline on "File taxes" ranks its tasks), and the
calendar marks the project itself. Its estimate is shown, not planned.

- **Duplicate** an item from its context menu, or select it and press ⇧⌘D
  (Task → Duplicate). The copy is a new open item in the same project with
  the same title, notes, priority, estimate, due date, tags and repeat, and
  for a project a copy of every task and sub-project in it that was not given
  up. The day it was planned for, a delegation and the time logged are not
  copied. The copy is selected when the list shows it. An item that repeats
  is copied with its rule, so the copy starts a series of its own
- **Add Tasks** (the button on a card, or in its context menu) makes the
  item a project, shows it and starts a new task in it, so the card of that
  task is ready to type in: no second press of the plus button. It
  keeps its title, notes, view, creation day and everything set on it, and if
  it was in a project, it is a sub-project there, in the same place
- **Turn into Task** (context menu of a project with nothing in it) makes
  the project a task again, in the same place, with everything set on it.
  If the columns were showing it, they show its parent and the task is
  selected. A project with an open task or sub-project in it has no such
  entry: complete, move or delete what is in it first
- **Delete Permanently…** (context menu of a task or a project, after a
  confirmation) removes it for good, whether it is open, dropped or
  completed. Deleting a project deletes its sub-projects and every task in
  them, completed ones too. There is no undo; the choice to complete or
  drop is there for what you may want back. If the columns showed the deleted
  project, or went through it, they show its parent afterwards

## Repeating tasks

Routines (pay the rent, water the plants, the weekly report) are captured
once. In a task's card, switch Repeat on and pick how often:
every N days, weeks, months or years. A weekly repeat can also pick the days
of the week (Mon and Thu), and a repeat can count from the due date (the
default) or from the day the task is done. The task's context menu has a
Repeat submenu for the common cases, and Stop Repeating.

Repeat and the due date are independent: switching Repeat on never gives a
task a due date, and unticking the due date never stops the repeat. A task
with no due date repeats from the day it is done ("After it is done"), and
"From the due date" cannot be picked until it has one. Clearing the due date of
a task that repeats keeps the repeat and switches it to "After it is done". The
next tasks get the day their rule gives as their due date.

Completing a task that repeats makes the next one at once, in the same
project, with the same title, notes, priority, estimate, tags and repeat, and
the next due date. A project can repeat too: completing it makes the next
project, holding fresh copies of its tasks, which have no due dates. The day it was planned for, a delegation and the time
logged are not copied. The completed one stays in Completed. Nothing is
planned by itself: the next task shows in the lists straight away (there is
no start date), and as a candidate under the usual due-date rules. Editing
the task that is open changes what the next ones copy.

- *Counted from the due date*: the next due date is the first one of the
  rule after the previous due date and after today, so a week of missed days
  does not pile up. Monthly keeps the day number, and the 31st falls on the
  last day of a shorter month
- *Counted from the day it is done*: the next due date is that day plus the
  interval. The weekdays do not apply
- Skip This One (Task menu, context menu, or in Today's decisions) is for
  "not this week": it drops this task and makes the next one
- Stop Repeating clears the repeat; the task stays, with its due date
- Drop Task and Send to Someday end the series: giving a task up is
  explicit, and Skip is the way to pass over one occurrence
- Reopening a completed task leaves the next one as it is. Completing a
  project completes its open tasks without making new ones

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

## Tags

A tag is a label for a context: `@home`, `@calls`, `@deep-work`. Tags belong
to a view, so the tags of Work and of Private are separate, even when they
have the same name, and taking a task to another view leaves its tags behind.

Put tags on a task in the Tags field of its card: type names
separated by commas, with or without the `@`, in any case. A name the view
does not have yet creates the tag; a name you take out of the field takes
the tag off the task. The tag button beside the field adds a tag the view
already has. Tags show next to the task in lists and on its card. Tags in
the task's context menu (Tags) puts one on or takes it off in one click.

Tags is a place on the rail. Its first column lists the view's tags, each
with how many open tasks carry it; click one and the next column lists
those tasks, and a task opens its card. A completed task leaves the list and
the count, and brings its tags back when reopened. There is no way yet to
rename or delete a tag.

To narrow Today's candidates by tag, priority, project or deadline, see
Today.

## Settings

Settings shows three families in its first column: Global, Views and This Mac.

- **Global** sets the numbers every view falls back to: the default estimate
  for a task given no estimate (5 minutes), the buffer percentage held back
  from each day's capacity (40%), and the capacity of each weekday in
  minutes (8 hours on weekdays, none at the weekend), and when each weekday
starts and ends (09:00 to 17:00; a day's own fields in Today beat them). Day
start and end and Capacity are single entries; each opens its settings in the
next column. Day start and end is a week of quarter-hour rows: drag down a
weekday's column to pick its hours (a click picks one quarter hour, Shift-click
or Shift-drag adds to the hours the weekday has), and Reset
above the column goes back to 09:00 to 17:00. Capacity is a list of fields, one
for each weekday, in minutes. It sets how often
  projects are reviewed (weekly; see Reviews), and picks the default
  view. Under Appearance it picks the accent colour views have unless they
  choose their own (navy to start with)
- **Views** lists every view, each with a small square in its accent
  colour. Pick one to override the buffer and the weekday capacity for that
  view alone. Each is a toggle: off, it follows the global value (shown
  greyed with "(global)"); on, it shows its own value to change. Switching
  it off returns to following the global value. Under Appearance the same
  toggle gives the view its own accent colour, picked from eight squares: use
  one for Work and another for Private. Edit View… in the view switcher
  opens Settings → Views on the view you are in

Today plans the day with these numbers.

## Where your data lives

Everything is one append-only event log. The first time you start the app it
asks where to keep it: **Dropbox** (the default, `~/Dropbox/backups/Luthor`,
created if missing) or the **Home Folder** (`~/.luthor/events.jsonl`, this
Mac only). Settings → This Mac changes the choice later; moving to Dropbox
copies the Home Folder's tasks in the first time. Back up by copying the
file or folder.

## Export and import as text

File → **Export to Text…** saves your views, tags, tasks and projects as one
YAML file (`format: 1`), readable in any editor: for every item its title,
notes, priority, estimate, kind, parent, day created, whether it is open,
completed or dropped, and its planned day, due date, repeat, delegation and
tags. It is a copy of what exists, not of how it came about: time logged,
daily and weekly reviews, the plan's manual order and settings are not in it.
File → **Import from Text…** adds the views, tags and items of such a file
that you do not have yet, with the same IDs, so importing the same file twice
changes nothing, and a file from another Mac merges. A file from a newer
version of the app, or one that is not an export, is refused and nothing is
changed.

### Compacting the log

The log only grows, because it keeps every change. Settings → This Mac →
**Compact Log…** rebuilds it: it copies the old log files and a YAML copy of
your tasks into a `backups/compact-<date>` folder next to the log, writes a
new log with one short run of events for each task and project, checks that it
holds the same library, and swaps it in. Tasks, projects, settings and the
weekly project reviews stay; time logged and the days you reviewed are
dropped. Delete the `backups` folder when you no longer need it.

With Dropbox the Macs do not have to be together. Compact Log first asks the
others, through small `compaction-…` files in the shared folder, to stop
writing. Settings shows "Waiting for …" until each Mac that Luthor is open on
has answered and its last changes have reached Dropbox; open Luthor there to
let it answer. Then **Compact Now** rebuilds the log and every Mac writes
again. If a Mac stays away you can **Cancel**, or **Compact Anyway**: the new
log then outranks anything older, but changes that Mac made offline may be
partly overridden when it comes back.

A request that is not finished within ten minutes (the app was quit, or a Mac
never came back) is given up on its own, so it cannot hold the Macs back for
good. While another Mac's request is open, Settings shows **Cancel Their
Compaction…**, which ends it at once.

If the new log does not check out, Luthor changes nothing, says what differed
(for example which task and which field), and cancels the request so every Mac
writes again.

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
