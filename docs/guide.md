# Luthor user guide

How to use Luthor as it is today. This describes shipped behaviour only: what
is planned lives in `docs/plans/`. Every PR that changes what the app or the
CLI does updates this guide in the same PR (see the docs check in
`AGENTS.md`).

## Concepts

- **Task**: one thing to do. Captured in the Inbox, optionally filed into a
  project, completed when done
- **Inbox**: tasks not filed into a project yet
- **Project**: a group of tasks. *Parallel*: every open task is a next action.
  *Sequential*: only the first open task is; the others are dimmed
- **Next action**: a task you can do now, in its project

## Capturing a task

Type in the capture field and press Return. The field is always focused, so
capture needs no click. With a project selected in the sidebar, the task goes
straight into that project; otherwise it goes to the Inbox.

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

A quick way to capture from a terminal. It knows tasks only, not projects.

```bash
luthor add "buy milk"
luthor list              # every open task, filed or not
luthor done 9afc         # any unique prefix of a task ID
```

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
