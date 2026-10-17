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
- **Inbox**: tasks of the current view not filed into a project yet
- **Project**: a group of tasks. *Parallel*: every open task is a next action.
  *Sequential*: only the first open task is; the others are dimmed
- **Next action**: a task you can do now, in its project

## Views

- The view you are in is shown at the top of the sidebar. Click it to switch
  to another view, or press ⌃⌘1 to ⌃⌘9 for the first nine (View menu)
- Create a view with New View… in the same menu; the window switches to it.
  Rename the current view with Rename View…. Names are unique, ignoring case
- The app opens on the view you used last on this Mac
- A task can only be filed into a project of its own view. To take a task to
  another view, select it and use Task → Move to View: it lands in that
  view's Inbox. To take a whole project with its tasks, use Move to View in
  the project's context menu in the sidebar

## Capturing a task

Type in the capture field and press Return. The field is always focused, so
capture needs no click. With a project selected in the sidebar, the task goes
straight into that project; otherwise it goes to the Inbox of the current
view.

## Completing a task

Select a task with ↑ and ↓ and press ⌘Return, or click its circle.

## Projects

- Create one with the field at the bottom of the sidebar, choosing parallel or
  sequential
- File a task by dragging it onto a project in the sidebar, or select it and
  press ⌥⌘1 to ⌥⌘9 for the first nine projects (Task → Move to Project)
- Complete a project from the toolbar or its context menu in the sidebar. Its
  open tasks are completed with it

## The luthor command

A quick way to capture from a terminal. It knows tasks only, not projects,
and works in one view: the one named with `--view`, else `LUTHOR_VIEW`, else
Default. View names ignore case.

```bash
luthor add "buy milk"
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
