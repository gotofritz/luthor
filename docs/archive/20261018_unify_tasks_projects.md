# One Kind of Item: Tasks and Projects Merged

Status: done in slice 14c of the roadmap (issue #50); kept as the design record. The
design lands with the PR that added Duplicate, Delete and Add Tasks; the
implementation is its own PRs, before slice 15 freezes the event format.

## Why

A project is a task with children. Today the two are separate models, and it
shows:

- a project cannot have a due date, a priority, an estimate, tags or a repeat,
  so "plan the trip, due in spring" needs a task *and* a project
- a task cannot grow children. PR #52 added Add Tasks, which turns a task into
  a project and has to let go of its priority, estimate, due date, tags and
  repeat, because a project holds none of them
- every feature is written twice: rename, notes, complete, reopen, move to a
  view, delete, review, and the two nesting events (`TaskMovedToProject`,
  `ProjectMovedToProject`)
- `ProjectID` and `TaskID` exist side by side, and `ProjectChild` is a sum
  type only to say "task or project"

The format is soft until slice 15, so this is the cheapest moment: the log may
be started afresh (see `AGENTS.md`), and after the freeze this would be a
public-format change.

## The model

One entity, `Item` (the type stays called `TaskItem` in the first PR to keep the
diff small, renamed in the last). Everything that was a task field is an item
field, and any item can have children.

- **Identity**: one `TaskID`. `ProjectID` goes away
- **Fields**: title, notes, view, parent, `createdOn`, priority, estimate, due
  date, tags, repeat rule, `kind` (parallel or sequential), review interval
  and last review, status (open, completed, dropped)
- **A project is an item with children, or created as a project.** Creating
  with the new project field writes the item with `kind` set, so an empty
  project is still a project; a task that gets its first child becomes one,
  with kind parallel. `isProject = hasChildren || created as a project`. There
  is no promote event and no "Add Tasks" conversion: Add Tasks on a card just
  captures a child
- **Leaves are actionable.** Next actions, Today's candidates, the plan, the
  calendar's planned marks and the review's done / not done list only leaves
  (items with no open children). A container is planned through its children.
  A container's own priority, estimate and tags are shown, not planned
- **A container's estimate** is shown as its own number if set, else the sum of
  its open leaves' estimates. Never both added, never applied to the plan
- **Due dates inherit downwards for ranking.** A leaf's effective due date is its
  own, else the nearest ancestor's (hard or target as set there), so a hard
  deadline on "File taxes" ranks its subtasks. The calendar shows the date on
  the item that carries it, not on every descendant
- **Completing a container completes its open descendants**, as completing a
  project does today, and reopening brings back what it took along. Completing
  a leaf does not touch the parent; a container whose children are all done is
  not completed by itself (a prompt in the UI can offer it, later)
- **Deleting a container deletes its subtree** (as `ProjectDeleted` does in PR #52)
- **Dropping** (see decisions below)

## Events

Before slice 15, so a rewrite is allowed and old logs need not replay. One
event per intention, no `Project*` twins.

| Today | After |
|-------|-------|
| `TaskCaptured`, `ProjectCreated` | `TaskCaptured` with optional `parentID` and optional `kind` |
| `TaskMovedToProject`, `ProjectMovedToProject` | `TaskMoved(task, parent?)`; a cycle or another view is ignored by the reducer and refused by the command, as nesting is today |
| `TaskCompleted`, `ProjectCompleted` | `TaskCompleted`; takes open descendants |
| `TaskReopened`, `ProjectReopened` | `TaskReopened`; brings back what the completion took |
| `TaskRenamed`/`ProjectRenamed`, `TaskNoted`/`ProjectNoted` | `TaskRenamed`, `TaskNoted` |
| `ProjectKindChanged` | `TaskKindChanged` |
| `TaskMovedToView`, `ProjectMovedToView` | `TaskMovedToView`; takes the subtree |
| `ProjectReviewIntervalSet`, `ProjectReviewed` | `ReviewIntervalSet(task, …)`, `TaskReviewed` for any container |
| `TaskDeleted`, `ProjectDeleted` (PR #52) | `TaskDeleted`; takes the subtree |
| `TaskPromotedToProject` (PR #52) | gone; Add Tasks captures a child |
| `TaskDropped`, `ProjectDropped` | `TaskDropped`; see below |
| `TaskDuplicated` (PR #52) | stays; copies the whole subtree |

Unchanged: priority, estimate, due, tags, repeat, scheduling, delegation,
time logging and settings events. They already name a `TaskID`, and now
accept any item. `TaskRecurred` and `TaskDuplicated` copy a subtree: the new
children get IDs derived from the copy's ID and the source child's ID, so two
devices make the same ones, the way `TaskID.recurring(after:)` does.

## No migration: start the log afresh

The owner is the only user and the log holds test data, so there is no
migration script and no old-log replay. The first PR says the log is to be
started afresh, as `AGENTS.md` allows while the format is soft: delete the old
log (or the Dropbox folder's `events-*.jsonl` files) on every Mac before
opening the new build. Both Macs must run the new build at once, as an older
build cannot read the new lines.

## Slices

1. **Domain, no visible change.** Fold `ProjectID` into `TaskID`; one item
   reducer; the events above; the existing view models and UI keep their
   behaviour by deriving "projects" and "tasks" from `isProject`. All current
   tests are ported. The PR says the log is to be started afresh. Acceptance:
   the existing acceptance flows pass unchanged on a new log
2. **Any item takes children, in the UI.** Add Tasks on any card captures a
   child (PR #52's promote is removed). Priority, estimate, due date, tags and
   repeat on the project card. Columns show any item that has children as a
   folder. Project-only menu items (Kind, review) appear on any container
3. **Planning learns containers.** Leaves only are actionable; effective due
   date; roll-up estimate; Today, the calendar and the review follow. Repeat
   on a container copies its subtree

## Decisions to confirm with the owner

1. **Dropped.** Today a dropped task vanishes and a dropped project stays,
   dimmed, because it is reviewed. Proposal: every dropped item is hidden like
   a completed one and listed with the Completed toggle (renamed "Completed
   and dropped"), a dropped container hands out no next actions and is not
   reviewed, dropping takes the subtree, and Reopen undoes it. This makes a
   drop reversible, which it is not today. Keeping dropped projects visible is
   the alternative
2. **Repeat on a container** copies its subtree in slice 3. Until then a
   container cannot be given a repeat, and a repeating task that gets a child
   stops repeating (after a confirmation)
3. **Priority on a container** is its own and does not flow down. The
   alternative, children inherit it unless set, is simple to add later
4. **Tags on a container** do not flow down. Same alternative
5. **The inbox** keeps listing unclarified leaves with no parent. A container
   with no parent is in Projects, not in the Inbox, even with no priority

## Risks

- the biggest rewrite since slice 5: reducer, planning, calendar, review, view
  models and the columns all touch projects. Mitigation: slice 1 changes no
  behaviour, and the existing acceptance flows must pass unchanged
- the old log stops opening. Accepted: it is test data
