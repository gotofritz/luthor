# Incremental Roadmap

Status: draft for discussion

Turns the broad phases of `20260512_initial_plan.md` into small slices. Each
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
- **Pre-1.0 event format is soft.** While I am the only user, an event format
  change may be handled by a one-off migration script over the log, or by
  starting a new log. The immutability rules in `AGENTS.md` apply in full from
  the slice that freezes the format (slice 9)

## Slices

### 1. Walking skeleton: CLI capture

- Swift package: `LuthorDomain`, `LuthorStore`, `luthor` CLI target
- Events: `TaskCaptured`, `TaskCompleted`
- Store: one JSON-Lines file, append-only, path from an env var
- CLI: `luthor add "buy milk"`, `luthor list`, `luthor done <id-prefix>`
- `Makefile` (`test`, `lint`, `check-ci`) and GitHub Actions CI

Usable: capture and tick off tasks from the terminal.
Why a CLI first: it proves the domain, log and replay end to end with no UI
work, and stays useful later for scripting.

### 2. Mac app: Inbox

- SwiftUI app reading and writing the same log file
- Inbox list, an always-focused add field (Return to capture), complete with
  a click or a key
- Replay the whole log into memory on launch; watch the file for changes so
  the CLI and app stay in step

Usable: a real window for the inbox.

### 3. Projects

- `ProjectCreated`, `TaskMovedToProject`, `ProjectCompleted`
- Parallel and sequential projects; "next action" rule as a pure function
- Sidebar: Inbox, Projects; drag or keyboard shortcut to file a task

Usable: inbox processing into projects.

### 4. Defer and due, Today

- `TaskDeferred`, `TaskDueSet` (and clearing both)
- Availability rule (deferred, blocked by sequence, completed) in the domain,
  clock injected
- Views: Available, Today (due or overdue), Forecast-lite list

Usable: the daily "what can I do now" view.

### 5. Tags

- `TagCreated`, `TaskTagged`, `TaskUntagged`
- Filter any view by tag

Usable: contexts (`@home`, `@calls`, `@computer`).

### 6. Mac ↔ Mac sync via a Dropbox folder (THROWAWAY candidate)

- Log lives in the Dropbox folder, synced by the Dropbox desktop app
- One file per device (`events-<deviceID>.jsonl`), so two machines never
  write the same file and Dropbox never makes conflict copies
- Read = merge all device files, order by `(lamport, deviceID, eventID)`,
  replay. Shuffled-order and duplicate-event tests land here

Usable: same tasks on every Mac, with almost no sync code. If this proves
reliable, the "proper" Dropbox API sync can come much later or never for Mac.

### 7. iPhone capture without an iOS app (THROWAWAY)

- An iOS Shortcut appends a line to `Dropbox/Luthor/inbox.txt`
- The Mac app imports new lines as `TaskCaptured` events and truncates the
  file once imported (idempotent by line hash)

Usable: capture from the phone, lock screen and Siri included, months before
an iOS app exists.

### 8. Review

- `ProjectReviewed`, per-project review interval
- Review view: projects due for review, mark reviewed, next one

Usable: the weekly review.

### 9. Freeze the event format

- Write down every event type and field as v1
- Golden-file tests: a checked-in fixture log must always replay to the same
  state
- From here, `AGENTS.md` event rules are strict

### 10. Speed pass

- Measure launch replay time and capture latency on the real log
- Only if needed: GRDB projections, snapshotting, global capture hotkey,
  command palette

### 11. Dropbox API sync

- OAuth, token in Keychain, sync of the same per-device files over the API
- Sync behind a `Transport` protocol; in-memory fake for tests; two-device
  convergence tests
- Required for iOS, which has no Dropbox folder to watch

### 12. iOS app

- Same package; inbox, Today, Available, capture first
- Without the Apple Developer Program, a free provisioning profile expires
  every 7 days; decide then whether to pay

### Later

- Perspectives as saved queries
- Repeating tasks
- Notes field kept minimal (notes live in Joplin)
- CloudKit transport, if ever

## Open questions

1. **Soft event format until slice 9**: OK to bend the `AGENTS.md`
   immutability rules until then, or keep them strict from day one?
2. **CLI first**: worth it, or go straight to the Mac app in slice 1?
3. **Dropbox folder sync (slice 6)** before the Dropbox API: acceptable as a
   possibly permanent Mac solution?
4. **Ordering key**: a Lamport counter per event plus device ID is enough for
   one user; hybrid logical clocks only if timestamps matter for display.
   Agree?
5. **No SQLite until slice 10**: fine to drop it from the early slices?
