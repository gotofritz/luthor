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

### CD-1. Ship the Mac app and CLI (slice 3) ✅

A version tag (`v0.x.y`) runs `make dist` on CI: the `.app` and the universal
`luthor` CLI, ad-hoc signed, zipped and attached to a GitHub Release. PRs that
change the release build run it without publishing. `make install` puts both
in `~/Applications` and `~/.local/bin` between releases. Not notarised: the
first launch needs right-click → Open.

### CI-3. Event format guard (slice 9)

- Golden-file replay tests are part of `make check-ci`; a change that breaks
  an old log fails CI

### CD-2. iOS (slice 12)

- `xcodebuild` the iOS target in CI
- Distribution decided with slice 12: free 7-day provisioning from Xcode, or
  TestFlight with the Developer Program

## Slices

### 1. Walking skeleton: CLI capture ✅

`luthor add`, `list` and `done <id-prefix>` over a JSON-Lines log
(`TaskCaptured`, `TaskCompleted`), path from an env var. Proves domain, log and
replay end to end with no UI.

### 2. Mac app: Inbox ✅

SwiftUI inbox on the same log: always-focused add field, complete by click or
key, full replay on launch, file watching keeps CLI and app in step.

### 3. Projects ✅

`ProjectCreated`, `TaskMovedToProject`, `ProjectCompleted` (which takes its
open tasks with it). Parallel and sequential projects; next actions are a pure
function of the project. The app gains a sidebar of Inbox and projects: drag a
task onto a project or press ⌥⌘1–9 to file it, capture straight into the
project shown, complete a project from the toolbar.

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
- Optional: split acceptance testing out of the TDD skill into its own
  `acceptance` skill, linked from the TDD skill. Likely needed here, because
  two-device flows need a shared harness (several simulated devices, an
  injected clock from slice 4, fixture logs) and a way to turn a slice's
  promises into scenarios. Do it only if that guidance outgrows a section of
  the TDD skill

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
