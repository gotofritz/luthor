# Incremental Roadmap

Status: agreed 2026-10-16

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

## CI/CD track

Runs alongside the slices. Code quality comes first; building and shipping
the app comes once there is an app to ship. Every check CI runs can also be
run locally with the same command, so CI never surprises me.

### CI-1. Code quality, local and CI (slice 1)

- `Makefile` as the single entry point, used both locally and by CI:
  - `make format`: apply `swift-format`
  - `make lint`: `swift-format lint --strict` and SwiftLint
  - `make test`: `swift test`
  - `make check-ci`: lint + format check + build + tests, exactly what CI runs
- Tool versions pinned in the repo (SwiftLint and swift-format config files,
  versions in the `Makefile`), so local and CI results match
- Git hooks for local development, plain shell scripts in `.githooks/`
  (no hook framework to install); `make hooks` points
  `core.hooksPath` at them:
  - `pre-commit`: format check and lint on staged Swift files; fast enough
    not to slow commits down
  - `commit-msg`: rejects a message that is not a Conventional Commit
- One script, `scripts/check-conventional-commit.sh`, decides what a valid
  Conventional Commit header is (type list, optional scope, `!`, and a
  maximum length passed in: 72 for commits, 50 for PR titles). The
  `commit-msg` hook and CI both call it, so they never disagree
- GitHub Actions workflow on every PR and push to `main` that runs
  `make check-ci` on a macOS runner
- PR title check: a workflow on `pull_request` (opened, edited,
  synchronize) passes the title to the same script through an environment
  variable (never interpolated into the shell) and fails if it is not a
  Conventional Commit of at most 50 characters
- Branch protection on `main`: both checks must pass to merge

### CI-2. Build the Mac app (slice 2)

- `make app`: `xcodebuild` the Mac app; added to `make check-ci`
- View model tests run in CI alongside the package tests

### CD-1. Ship the Mac app and CLI (slice 2 or 3)

- On a version tag (`v0.x.y`): build the `.app` and the `luthor` CLI,
  ad-hoc sign them (no Developer Program needed), zip and attach to a GitHub
  Release
- `make install` builds and installs both locally, for day-to-day use
  between releases
- Without notarisation, the first launch needs right-click → Open; fine for
  one user

### CI-3. Event format guard (slice 9)

- Golden-file replay tests are part of `make check-ci`; a change that breaks
  an old log fails CI

### CD-2. iOS (slice 12)

- `xcodebuild` the iOS target in CI
- Distribution decided with slice 12: free 7-day provisioning from Xcode, or
  TestFlight with the Developer Program

## Slices

### 1. Walking skeleton: CLI capture

- Swift package: `LuthorDomain`, `LuthorStore`, `luthor` CLI target
- Events: `TaskCaptured`, `TaskCompleted`
- Store: one JSON-Lines file, append-only, path from an env var
- CLI: `luthor add "buy milk"`, `luthor list`, `luthor done <id-prefix>`
- Code quality gates, local and CI (stage CI-1 below)

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

## Decisions (2026-10-16)

1. **Soft event format until slice 9.** `AGENTS.md` event rules updated to
   match: format changes before the freeze ship with a migration script or a
   fresh log
2. **CLI first** in slice 1
3. **Dropbox folder sync** in slice 6, possibly as the permanent Mac solution
4. **Ordering key**: Lamport counter plus device ID (then event ID as the
   tiebreak). Hybrid logical clocks only if timestamps matter for display
5. **No SQLite until slice 10**, and only if replay is measurably slow
