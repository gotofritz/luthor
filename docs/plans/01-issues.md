## Long-term evolution assessment (external architect, 2026-10-26)

Scope: will this codebase still be fast, safe with the user's data and cheap to
change in three to five years, with an iPhone client added? Read: the Swift
sources of all four layers, the Makefile, CI and release workflows, `AGENTS.md`,
the roadmap and the iOS plan, and the 20 open GitHub issues (to avoid
repeating them). No Swift toolchain was available in the session, so
nothing below was measured; where a number matters, the first step of the
item is to measure it.

What is already good and should not be touched: the event-sourcing core
(pure reducers, Lamport order with device and ID tie-breaks, idempotent replay),
one-writer-per-file Dropbox sync, the frozen-format rules with a golden log,
`TaskID.recurring` / `TaskID.copied` derived IDs so two devices converge, thin
views over tested view models, and the Conventional-Commit release pipeline.
The items below are what I would change or decide, most urgent first. Priorities:
**P1** before the log has a year of history or before iOS starts, **P2** within
the next few slices, **P3** whenever convenient.

Each item says why, what to do, and how to know it is done. They are
independent unless they say otherwise; A-2, A-3 and A-4 are best designed
together.

---

### A-1. Make each user action O(change), not O(log) (P1)

**Why.** A single action (say, ticking a task) does the following, all on the
main actor:

1. `LibraryViewModel.perform` reads and JSON-decodes the whole log
   (`LibraryViewModel+Presenting.swift:18-25`).
2. The command replays the whole log again to validate: `Commands*.swift` has 65
   `LibraryState.replay(log)` call sites, e.g. `Commands.swift:66`.
   Every new event also computes `log.map(\.lamport).max()` (`Commands.swift:329`).
3. `show(current + events)` replays the whole log a third time and then
   `present()` recomputes every place's state eagerly: plan, review, carry-over,
   calendar, tags, project review, settings of *every* view, whether or not
   that place is on screen (`+Presenting.swift:53-90`).
4. The app's own append changes the file signature, so the 1 s poller in
   `LibraryView.watchLog` (`LibraryView.swift:160-170`) sees a "foreign" change
   and does steps 1, 3 again about a second later.
5. Some view-model actions replay a fourth time (`+Repeat.swift:16`,
   `+Running.swift:32`, `+Tags.swift:34`).

The project's own sizing is about 200 bytes per event and "a few megabytes a
year" (roadmap, Decisions 2026-10-18 slice 15). That is tens of thousands of
events a year, each action costs several full decode-sort-replay passes, and the
UI thread waits for all of it. With the log in a Dropbox folder the read can
also block while a file is fetched. This is the "speed pass" (slice 16), which
has never been measured; the roadmap rule is "no SQLite until replay is
measurably slow", and nothing here needs SQLite.

**Do.**
1. Build a synthetic log generator (1, 3 and 5 years of heavy use) and a
   benchmark target that reports cold launch, action latency and `present()`
   time. Run it in CI as a budget (fail above, say, 50 ms per action at the
   3-year size; pick the number after the first measurement).
2. Keep `LibraryState` in memory across actions. After `append`, apply the new
   events to the existing state (`state.apply`) instead of re-reading. Re-read
   only when `FileChangeMonitor` reports a change that was not our own write
   (compare file size to what we wrote, or record our own signature after each
   append).
3. Read other devices' files incrementally: remember a byte offset per file and
   decode only the tail; fall back to a full read if the file shrank or its
   prefix hash changed (a compaction or a replaced file).
4. Commands should take the current `LibraryState` (and the next Lamport value),
   not `[EventEnvelope]`. That removes the 65 replays and the `max()` scans;
   tests can still build a state from events.
5. Make `present()` lazy per place: compute only what the visible place shows.
6. Move file I/O and decoding off the main actor (an `actor` owning the log and
   state, publishing snapshots). This is also the shape the iOS client needs
   (see A-2), where reading must never wait on the network.

**Done when** the benchmark shows action latency flat in log size (within noise)
at the 5-year size, and `AGENTS.md`'s "speed of capture is a feature" has a
number behind it.

---

### A-2. Decide the log layout before iOS: rotate each device's file into segments (P1)

**Why.** The log is one ever-growing `events-<device>.jsonl` per device.
Three things depend on that, and all of them get worse with age:

- **Dropbox API (iOS plan, slice 17).** The Dropbox HTTP API has no append
  operation, so syncing a growing file means re-uploading and re-downloading
  the whole file on every sync, on a phone, on mobile data.
- **Reading.** Nothing in a file below its tail ever changes, but every read
  decodes all of it again (A-1.3 only helps for the tail of the *current* file).
- **Retention.** The only way to make the log smaller today is to rewrite it
  (A-3), because there is nothing smaller than "a whole device's history" to drop,
  archive or cache.

Issue #45 already notes that anything that touches the log layout is an
event-format matter that should be decided before iOS; the freeze (slice 15) did
not cover layout, only the event lines.

**Do.** Write a short design note, then implement it before slice 17:
`events-<device>-<NNNNNN>.jsonl` segments, rotated at a size (about 1 MB) or
at a month boundary; only the newest segment of a device is ever appended to,
older segments are immutable. Immutable segments can be cached decoded (keyed
by name, size and hash), uploaded once, listed with their content hash in a
manifest so a phone can tell what it lacks, and archived or dropped as a unit.
`DeviceFilesEventLog` reads all segments of all devices; a single legacy file
is segment 0. An older build only reads files whose name matches
`isDeviceLog` (`events-*.jsonl`), so either keep that pattern for segments or ship
the new reader a release before the first rotation, so no device silently stops
seeing another's newer events.

**Done when** a two-device convergence test (the roadmap's sync test) runs
across a rotation, an old single-file log opens unchanged, and the Dropbox API
transport in the iOS plan can be written against "list segments, fetch the
missing immutable ones, push the one open segment".

---

### A-3. Replace "Compact Log" (rewrite history) with snapshots over immutable segments (P1)

**Why.** `AGENTS.md` says events are append-only and never edited or deleted, and
the whole format-freeze apparatus exists to protect old logs. `LogCompactor`
does the opposite: it rebuilds the log from the current library and deletes the
other devices' files (`LogCompactor.swift:25-55`). Concretely:

- **It drops user data on purpose.** "History (time logged, reviewed days, the
  plan's manual order) is dropped" (doc comment, `LogCompactor.swift:19`). Time
  logged and day reviews are what `estimateHistory`, the daily review and issue
  #42 (estimate suggestions) are built on. The user's own estimating track
  record is the thing a planning app should keep longest.
- **It drops events it does not understand.** `readAll` skips events of an
  unknown type and leaves them in the file, which is what makes old builds safe;
  `LogCompactor` reads with `readAll`, replays, rebuilds and deletes the files
  they were in. An older build compacting a folder that a newer build wrote to
  silently removes the newer build's data from the live log (it survives only in
  `backups/`). Nothing warns the user that skipped events exist (the app has no
  "N events from a newer version were ignored" message anywhere), and nothing
  blocks compaction when they do.
- **It cannot tell a device from a stray file.** `CompactionHandshake.waitingFor`
  (`CompactionHandshake.swift:86`) waits for an ack from every `events-*.jsonl`
  name. A Dropbox "conflicted copy" file, a renamed Mac (the file name derives
  from host name plus the first 8 characters of a machine ID stored in
  `UserDefaults`) or a reinstalled Mac makes a phantom device that never answers.
  The only way out is `force`, which skips the guarantee the handshake exists to give.
- **"Delete for good" does not delete.** A deleted item's title and notes stay
  in the log forever, and compaction copies the old files into
  `backups/compact-<stamp>` inside the same synced folder, so they stay in
  Dropbox as well. There is no story for removing something pasted by mistake
  (a password in a note).

Compaction exists to keep replay fast and the log small. With A-1 and A-2 that
need mostly goes away; what remains should not rewrite history.

**Do.** After A-1 and A-2: add a **snapshot** per device and closed segment set
(`snapshot-<devices+segments hash>.json`: the reducer state or a minimal event
list at that point, written by any device, verified by replaying the segments and
comparing, never replacing them). Launch replays snapshot plus tail. Closed
segments older than a retention horizon can be moved to an `archive/` folder (kept,
not deleted) once a snapshot covers them. Until then, at minimum: refuse to
compact while any line was skipped as unknown, say how many lines were skipped
in Settings → This Mac, keep the time-logged and review events in what
compaction writes, ignore file names that are not valid device tokens in the
handshake, and give "Forget this device" a button in place of `force`.
A separate, explicit "Purge item" (rewrite the one segment holding it, with a
backup that is not in the synced folder) is the honest answer to deleting
secrets.

**Done when** no code path deletes an event line the running build cannot
decode, history needed by the review survives, and the log-survives-it test
(AGENTS.md "Data & Secrets") exists for the replacement.

---

### A-4. Record when things happened: optional wall-clock `at` on every event (P1)

**Why.** An event has an ID, a device and a Lamport counter, and nothing that
says when it was written (`Events.swift:84-97`). `TaskCompleted` and
`TaskReopened` carry just a task ID. So the app cannot answer "when did I finish
this?", "what did I complete last week?", or show a history of anything. Today
that surfaces as workarounds: the daily review decides "done on day D" by the day
the task was *planned* for (`ReviewRecords.plannedDays`), so finishing a task a
day late credits it to the wrong day; `createdOn` had to be bolted onto
`TaskCaptured` as its own optional field; issue #65 (a repeating task shows no
sign that this occurrence was done) cannot be fixed without a completion time.
It also makes sync problems hard to debug: there is no way to see which of two
devices acted first in real time.

This is cheap now and expensive later: every event written before the field
exists has none, forever, and the freeze (slice 15) did not cover it.

**Do.** Add `at: String?` (ISO-8601 UTC, written by `Commands` from an injected
clock, never read by reducers for ordering) to the envelope line as a new optional
field; old lines decode with `nil`. Add a golden-log line with and without it.
Then use it additively: a completion date on `Completed<Item>`, a logbook place
or a "done this week" list, per-occurrence completion for repeating tasks (#65),
and the review crediting the day a task was actually completed. Replay must not
change for logs that lack the field.

**Done when** an old log replays to the same state as before, new events carry
`at`, and a completed task can say when it was completed.

---

### A-5. The log must survive a bad line and a crash mid-write (P1)

**Why.** Priority one in `AGENTS.md` is never losing user data, and the read path
is fail-closed with no way out:

- One undecodable line anywhere makes `readAll` throw `unreadableLine(n)` and the
  whole app stops loading (`JSONLinesEventLog.swift:270-290`). The message says
  "Line 4812 of the event log is not a readable event" with no file name, which
  in a shared folder means up to N device files.
- The only tolerated damage is the last line of *another* device's file
  (`skippingIncompleteTail: name != ownFileName`). A crash, a force-quit or a
  power cut during an append to the *own* file leaves a partial last line; the
  next launch refuses to open, and `append` (`:293`) does not check that the file
  ends with a newline, so if the error were bypassed the next event would be
  glued onto the partial line and corrupt both.
- No `fsync`, so a power cut can lose events the UI already showed as saved.

**Do.** (1) Put the file name in `unreadableLine`. (2) Before the first append of
a session, check that the own file ends with `\n`; if not, quarantine the partial
tail into `backups/` and terminate the line (repair is the one place where
rewriting the tail of the own file is justified; test it). (3) Add a "safe mode":
on an unreadable line elsewhere, open read-only with the readable events, show
what was skipped, and offer to move the bad line aside. (4) `fsync` after append
(or `F_FULLFSYNC` on macOS if the cost measures acceptable under A-1). (5) Surface
the count of events skipped as unknown (see A-3).

**Done when** tests truncate the own file mid-line and corrupt a line in another
device's file, and in both cases the app opens, no event is lost, and the user is
told what happened.

---

### A-6. Put the shared SwiftUI views in a package target before starting iOS (P2)

**Why.** The iOS plan says "same package", but the package has no UI: all 31 views
(about 4,800 lines) are in the Xcode project's `App/Luthor` target, three of them
import AppKit (`LinkedText`, `LuthorApp`, `WeekdaySettingsViews`), and
`Package.swift` declares `platforms: [.macOS(.v14)]` only. Starting iOS from here
means copying the views or moving them under time pressure, and the Xcode project
(a 281-line `project.pbxproj`) is the only thing that links them.

**Do.** Add a `LuthorUI` library target to the package with the views that have
no AppKit dependency, behind small platform shims for the three that do
(`NSViewRepresentable` vs `UIViewRepresentable` for linked notes, and so on);
`App/` becomes a thin shell with the window, menus and wiring. Add `.iOS(.v17)`
to `platforms` and make `swift build` for an iOS destination part of CI so
iOS-hostile API creeps in nowhere. Mac-only pieces (menu commands, Settings
window, drag of calendar blocks if it needs AppKit) stay in `App/`.

**Done when** the Mac app builds from `LuthorUI` unchanged in behaviour, and an
empty iOS shell target renders the Inbox from the same views.

---

### A-7. Run the package tests on Linux, in CI and in agent sessions (P2)

**Why.** `AGENTS.md` makes TDD mandatory ("code written before its test is
deleted") and also says remote agent sessions may have no Swift toolchain. In
this session `swift` was not installed, so the red/green loop could not be run at
all; the fallback is "push and use CI as the build", which on a macOS runner
(macOS minutes are the expensive kind, and CI runs on every PR push) is a slow
loop. `LuthorDomain`, `LuthorStore` and `LuthorViewModels` import no SwiftUI, the
store already has `#if canImport(Glibc)` branches, and Yams supports Linux, so
`swift test --skip` for the package should run on a Linux runner.

**Do.** Add a Linux job (the official `swift:6.x` image) running `swift build`
and `make test-unit` plus the acceptance tests, in parallel with the macOS job
that still does lint, coverage and the app build. Add a SessionStart hook in
`.claude/settings.json` that installs the Swift toolchain when missing (the
`session-start-hook` skill covers this) so agents can run the tests. While there:
the current SessionStart hook says to ask the user which branch to use, which
contradicts the project rule to cut a `feature/<name>` branch without asking.

**Done when** a PR gets Linux unit-test feedback in a couple of minutes and a
fresh agent session can run `swift test`.

---

### A-8. Decide what happens to edits that arrive after a completion, and report what replay ignored (P2)

**Why.** Reducers guard with "ignores an item that is not open"
(`LibraryState+Items.swift:192`, `updateItem`): a rename, note, priority,
estimate or tag change is dropped if the item is completed at that point in replay
order. Order is Lamport, and a device that was offline and did more events than the
gap to the other device's completion will have its later edits ordered *after* the
completion. Typical case: the laptop edits a task's notes on a plane while the
desktop completes the same task; on reconnect the notes edit silently vanishes
from the state, though it is still in the log. Same for filing a task into a
project another device completed (it lands top-level, by design, documented in
`TaskCaptured`). Silent dropping is the right default for a sync that must
converge, but the user gets no signal, and neither does anyone debugging a sync.

**Do.** Two small things. (1) Let content edits (title, notes, priority, estimate,
tags, due) apply to completed items too; only status transitions and plan-related
events need "open". The state still converges, and reopening shows the edit.
Replay of old logs changes only in the cases that today lose data; add the
cases to the golden log. (2) Have `replay` return, next to the state, a count of
events it ignored by reason; show it in Settings → This Mac. It costs nothing and
is how two devices that disagree get diagnosed.

**Done when** a table test per event type states what happens to it on an open,
completed and dropped item, and the ignored count is visible.

---

### A-9. The golden log guards decoding, not meaning (P2)

**Why.** The freeze rule is "old logs must always replay". `GoldenLogTests`
checks that every type decodes, round-trips, and that reversed and duplicated
replay are equal, but the one state assertion is that the views Work and Home
exist (`GoldenLogTests.swift:32-38`). A reducer change that alters what old
events mean (a different default, a changed guard, as in A-8) passes. Replay
semantics are the part of a frozen format that can drift without anyone
touching an event definition.

**Do.** Commit the expected export of the replayed golden log
(`LibraryExport`/YAML via `LibraryText`, plus the review and planning state the
export omits, or a canonical dump of `LibraryState`) as a second fixture and diff
against it, so any change of meaning is a visible fixture change in the PR. Add a
second fixture made from a scrubbed copy of the author's real log once a year; real
logs contain sequences no hand-written fixture does.

**Done when** changing a reducer's behaviour on an old event fails a test until
the fixture is edited on purpose.

---

### A-10. Remove 14 MB of unrelated Python wheels from the repo root (P1, five minutes)

**Why.** Commit `c23826a` ("freeze event format", #63) added 16 `.whl` files
at the repository root: `swift-2.38.2` (the OpenStack object-storage package, not
the language), `eventlet`, `cryptography`, `lxml` and their dependencies, about 14
MB of binaries nothing refers to. It looks like an accidental `pip download`.
The repo is public and every clone carries them.

**Do.** `git rm *.whl`, add `*.whl` to `.gitignore`. Purging them from history
needs a force-push to `main` and is not worth it for 14 MB unless the repo is
about to be cloned a lot; say so in the PR and leave history alone.

**Done when** `git ls-files | grep whl` is empty.

---

### A-11. Make builds reproducible: commit `Package.resolved`, pin the toolchain (P2)

**Why.** `Package.swift` depends on Yams with `from: 5.1.3` and no
`Package.resolved` is committed (nor the Xcode workspace's resolved file), so a
build next year resolves whatever is newest. CI also selects "the newest stable
Xcode" at run time (`ci.yml`, `release.yml`), so the same commit can build today
and fail next month without anyone touching it. "Forever software" wants
the opposite: the only moving part in a green build should be the commit. There
is no Dependabot or Renovate either, so updates are noticed only when something
breaks.

**Do.** Commit `Package.resolved` (and the Xcode one), add a `.swift-version` or
pin Xcode in the workflow with a deliberate bump procedure in `AGENTS.md`, and
turn on Dependabot for `swift` and `github-actions`. Keep the macOS runner
version pinned (it already is).

**Done when** a build from a clean clone resolves the same package versions as CI.

---

### A-12. Make the work/private separation honest about what it is (P3, decision)

**Why.** The product promise is "work and private kept strictly apart". The
separation is real in the UI and the domain (`LibraryState.view(_:)`), but not in
the data: every device that shares the folder gets every view's events in plain
text (issue #45 describes this). On an employer's laptop that is a confidentiality
gap, and after the freeze "separate logs per view" is the expensive option the
issue warned about. The cheap and adequate answer already half exists:
`LogStorage` lets each Mac choose its own folder, so a work Mac can use a
different log. What is missing is a way to move a view's items between logs
(`LibraryExport` already serialises by item and imports by ID, so exporting and
importing *one view* is a small feature) and a sentence in the guide saying that
views are an organisation boundary, not a confidentiality boundary, within one log.

**Do.** Decide, and write the decision into issue #45 and the guide. Recommended:
document the boundary, add "Export view" / "Import" scoped to one view, and use
a second log folder on any machine that must not see the other views. Do not
build per-view log files.

**Done when** the guide states where the boundary is and how to keep a Mac
view-only.

---

### A-13. Documentation that will not scale with the codebase (P3)

**Why.** `AGENTS.md` is 31 KB and loaded as context in every agent session; most
of it is a per-file "Code map" that the rules require every PR to keep current
(and it is already the longest section). The roadmap is 1,138 lines, of which
about 800 are dated "Decisions" sections. `README.md` (316 lines) repeats
`docs/guide.md`. Each of these is a place where a stale line misleads the next
reader, and an agent reading them pays for it in every session. The Code map
duplicates what a directory listing and doc comments say, and rots first.

**Do.** Cut the Code map to a module-level paragraph (one line per target and
the boundary rules) and let file-level orientation come from doc comments and
grep; move dated decisions into `docs/decisions/NNNN-title.md` (one short ADR
each, the roadmap keeps a link and the slice status); make `README.md` a page of
install, build and links, and leave behaviour to the guide. Keep "update the
docs in the PR" for the guide and the ADRs only.

**Done when** `AGENTS.md` fits comfortably in one screenful of rules plus a
short module list, and no behaviour is described in both README and guide.

---

### A-14. First-launch instructions are out of date for current macOS (P3)

**Why.** `README.md:233` and `docs/guide.md:654` tell a user whose download was
quarantined to right-click → Open. As far as I know, macOS 15 removed that
Control-click bypass: the user must try to open the app, then go to System
Settings → Privacy & Security → Open Anyway. (Please verify on the current macOS;
I could not here.) The docs also say notarisation costs $99 a year and is "not set
up"; the iOS plan will likely need the Developer Program anyway (A-6), at which
point notarising the Mac build and attaching it to releases is a Makefile step.

**Do.** Fix the two sentences after checking on the Mac, and when iOS settles the
Developer Program question, add `notarytool` to `make dist`.

**Done when** the install steps match what happens on the author's current macOS.


## Security assessment: risk and attack surface (external review, 2026-10-26)

Scope: the repo at `fix/assessment-2026-10-25` (Swift packages, Mac app target, CI/release workflows, Terraform).
Method: code reading of the store, sync, import and CI layers; nothing was run. Severity is for a single-user,
local-first app whose log lives in a Dropbox folder. Findings below may duplicate others and are meant to be
merged later.

### Threat model

| Asset | Where | Who can reach it |
|-------|-------|------------------|
| Event log (tasks, notes, time, plans) | `~/.luthor/events.jsonl` or `Dropbox/backups/Luthor/events-<device>.jsonl` | the user's Mac account; Dropbox (the company); anyone the folder is shared with; anyone holding the Dropbox account |
| Release binary | GitHub Releases, ad-hoc signed | anyone downloading it; the repo owner's CI |
| Repo and CI | public GitHub repo | contributors, forks, dependencies fetched in CI |

There is no server, no network code in the app (no `URLSession`), no auth. The realistic attack surface is
therefore (1) files other parties can place in the shared folder, (2) text the user imports, (3) the build and
release pipeline, and (4) confidentiality of data at rest.

### Findings

**S-1 (medium) Sixteen third-party Python wheels (14 MB) are committed at the repo root.**
`PasteDeploy`, `eventlet`, `lxml`, `cryptography`, `requests`, `swift` (OpenStack), `urllib3` and others, added in
`c23826a feat(store)!: freeze event format (#63)` and still on `main`. They have nothing to do with a Swift app,
are unreviewable binaries in a public repo, bloat every clone, and will trigger dependency scanners. Treat as an
accidental `pip download`. Fix: `git rm *.whl`, add `*.whl` to `.gitignore`, confirm nothing in the repo or CI
reads them. History rewrite is not needed unless the wheels are considered sensitive.

**S-2 (medium) Anyone who can write into the shared folder can forge or shadow events; nothing authenticates a
device file.**
`DeviceFilesEventLog.readAll` merges every `events-*.jsonl` (including the "conflict copies" it deliberately
accepts). The `device` field inside an event is not checked against the file name, there is no signature or MAC,
and replay de-duplicates by event ID *after* sorting by Lamport counter, so a forged copy of an existing event
ID with a lower counter wins over the genuine one, and a `TaskDeleted` or `TaskDropped` with a high counter
wins over everything. Relevant if the Dropbox folder is ever shared, the Dropbox account is phished, or a
rogue app has Dropbox write access. Options: accept as documented risk (one user, own folder) and say so in
`docs/guide.md`; or sign each line with a per-device key kept in the Keychain and refuse unsigned or
mismatched lines. At minimum, reject a line whose `device` differs from its file's device token.

**S-3 (medium) A single forged event with `lamport = 18446744073709551615` crashes every write.**
`Commands.envelope` (`Commands.swift:329`) computes `(log.map(\.lamport).max() ?? 0) + 1` and
`ImportWriter` does `lamport + 1` / `next += 1` (`Commands+Import.swift:52,59`). In Swift, `UInt64` overflow
traps, so once such a line is in any device file the app crashes on the next capture, edit or compaction, on every
launch, and the line can only be removed by editing the file by hand. The same line from a buggy build has the
same effect. Fix: use `&+`/saturating add with a typed error (`CommandError.logCorrupt`), or reject lamports
above a sane bound when reading. Test: golden-log style fixture with the maximum value.

**S-4 (medium) A compaction request file can pause every Mac indefinitely.**
`CompactionHandshake.isExpired` returns `false` when `requestedAt` cannot be parsed, and a time in the future
also never expires (`now - asked` is negative). Any file named `compaction-<x>-request.json` with such a value
makes `PausableEventLog.append` refuse all writes on all devices until someone cancels it from Settings. It also
trusts the *content*: the request's `id` is taken from the JSON, not from the file name. Fix: treat an unparsable
or future `requestedAt` as expired (or as the file's modification date), and require `id` to equal the id in the
file name.

**S-5 (low-medium) Path traversal through the compaction request `id`.**
`CompactionHandshake.name(_:_:)` builds `compaction-\(id)-ack-<token>.json`, `-done.json` and `-cancel.json` from
`request.id` read out of an untrusted file, then writes it with `appendingPathComponent`. An id such as
`x/../../..` combined with a directory the attacker also syncs into the folder (`compaction-x`) makes the app
write a small JSON file outside the shared folder, with a name that must end in `-done.json` or
`-ack-<token>.json`. The impact is limited by the fixed suffix and content, but it is a write primitive driven by
file contents from another party. Fix: validate ids against `^[A-Za-z0-9-]{1,64}$` when reading and when
creating (they are UUIDs today).

**S-6 (medium) Compaction deletes other devices' files on the strength of an advisory handshake.**
`LogCompactor.replace` removes every other `events-*.jsonl` after the handshake. The handshake only works if every
device runs a build that knows it. An older build, a Mac that is asleep, or a late Dropbox sync that lands
after the "events have arrived" check means those events are removed from the live log; they survive only in
`backups/compact-<stamp>/` and are not merged back. Mitigation ideas: write a tombstone/marker so a build that
does not know the handshake refuses to open a folder that holds one; keep the other devices' files renamed
rather than deleted until each device has acknowledged the done marker; add a test where a device appends
between the ack and the swap and the event is not lost.

**S-7 (medium) Plain-text personal data at rest and in Dropbox; some files are world-readable.**
The log is plain JSON (task titles, notes, time spent, daily reviews). The event files are created `0600`
(`JSONLinesEventLog.append`), but several siblings are not: the `.new` temporary file made by
`LogCompactor.replace` (`Data().write`, default `0644`, and it may become the live log), `library.yml` in
`backups/compact-*`, the handshake JSON files, the `~/.luthor` directory and the `backups` folders (default
`0755`), and `backups/` holds a full copy of the log after every compaction and is never pruned. Dropbox itself
and anything with the shared folder see everything. Fixes: create the directory `0700` and every file `0600`
(set attributes explicitly, test with `stat`), document the Dropbox trust assumption in the guide, and offer to
prune old backups.

**S-8 (low-medium) Untrusted YAML import: possible alias expansion and no size or shape limits.**
`LibraryText.library(from:)` decodes a user-picked file with Yams. libyaml has no alias-expansion limit, and
decoding a document of nested anchors (a "billion laughs" file) into `LibraryExport` can balloon memory and
hang the main thread. There is also no cap on file size or item count, and an imported text can contain very
long titles or notes that go into the log forever (the log is append-only). Fix: reject files above a size limit
before decoding (a few MB), refuse documents containing aliases (`*x`), cap per-field lengths, and add a test
with a nested-alias fixture. Import runs on the main thread, so a bad file is also a UI freeze.

**S-9 (low) The app is not sandboxed and not notarised.**
`App/Luthor.xcodeproj` has hardened runtime but no entitlements file, so no App Sandbox, and signing is ad-hoc
(`CODE_SIGN_IDENTITY = "-"`). A compromised dependency or a parsing bug therefore runs with the user's full file
access, and users who download the release zip must bypass Gatekeeper by hand. The app only needs the Dropbox
folder, the home log and user-picked import/export files. A sandbox with a security-scoped bookmark for the
chosen folder would limit blast radius; it is a real piece of work, so decide deliberately. Notarisation needs an
Apple Developer ID. Until then, the README should say how to verify the zip (S-11).

**S-10 (low-medium) No dependency lock file and no automated dependency or secret scanning.**
`Package.swift` takes `Yams from: "5.1.3"` and there is no committed `Package.resolved`, so every CI build and
every release resolves whatever 5.x is newest. Yams embeds libyaml and parses untrusted input (S-8), so that is
the one dependency that matters. There is no `.github/dependabot.yml`, no `SECURITY.md`, and
`infra/repository.tf` does not enable secret scanning, push protection or Dependabot alerts
(`security_and_analysis`). `.gitignore` ignores `*.jsonl` but not `backups/`, `library.yml` or `*.yml`
exports. Fix: commit `Package.resolved`, add Dependabot for `swift` and `github-actions`, enable the repo
security features in Terraform, add a short `SECURITY.md`.

**S-11 (low-medium) CI and release hygiene.**
- Actions are pinned by tag (`actions/checkout@v4`, `actions/upload-artifact@v4`), not commit SHA.
- `make tools` downloads SwiftLint with `curl -fsSL` and does not check a checksum, then runs it in CI.
- `release.yml` grants `contents: write` for the whole workflow, including the `pull_request` trigger that
  runs `make dist` from PR code. Fork PRs get a read-only token, but a branch in the repo does not. Move the
  write permission to the publishing steps (a separate job that needs the build job).
- A hand-pushed tag goes into `make dist VERSION=$VERSION` and then into shell recipes via `$(VERSION)` in the
  `Makefile`. Git allows `;`, `$`, backticks and `|` in tag names, so a tag like ``v1;cmd`` is a command
  injection on a runner holding a write token. Only owners can push tags, but quote the value and validate it
  against `^v[0-9]+\.[0-9]+\.[0-9]+$` in the workflow.
- Release zips carry no checksum, signature or build provenance. Add `actions/attest-build-provenance` and a
  `SHA256SUMS` file, and say in the README how to verify.
- The `main` ruleset has `required_approving_review_count = 0` and no bypass list, which suits one person;
  just note that a compromised owner token can still merge without review.

**S-12 (low) Smaller items.**
- `NoteLinks` turns `www.` text into `http://` links; use `https://`. Only http(s) links are generated, which is
  the right call; keep a test that `javascript:`, `file:` and custom schemes never become links.
- `LUTHOR_LOG`, `LUTHOR_SYNC_DIR` and `LUTHOR_DEVICE_ID` (also read from `UserDefaults`) override where the
  log lives. A process that can set the app's environment or defaults can redirect the log; that is already
  full compromise of the account, so this is informational only.
- `DeviceFilesEventLog.fileName(for:)` sanitises the device ID to `[A-Za-z0-9._-]`, which is good. Two different
  IDs that sanitise to the same string (`my host` and `my-host`) share one file, which would break the
  "one writer per file" rule; the machine ID suffix makes this unlikely, but a test would pin it.
- `readAll` loads whole files into memory as one `String`. A multi-hundred-megabyte file (corrupt or hostile)
  stalls the app at launch. A size guard with a clear error is enough.

### What looks good

- No network code, no credentials, no secrets in the repo; Dropbox is used only through its desktop app's folder.
- The event file is opened `O_APPEND` with `0600`, and the device file name is sanitised.
- Unknown event types are skipped, and a parse error is reported with a line number rather than swallowed.
- Parent/child cycles are refused in the reducer (`LibraryState+Items.swift:171`), so a forged `TaskMoved`
  cannot loop the tree walks.
- Reducers are pure and deterministic; the compactor checks the rebuilt library equals the old one and backs
  up before deleting.
- `ENABLE_USER_SCRIPT_SANDBOXING` and hardened runtime are on; CI uses read-only `contents` permission outside
  the release workflow; squash-only merges and required checks protect `main`.

### Suggested order

1. S-3 (crash on max Lamport) and S-4/S-5 (handshake input validation): small, test-first, and they close the
   ways a stray file can break every device.
2. S-1 (remove the wheels), S-10 (lock file, Dependabot, `SECURITY.md`): minutes of work.
3. S-7 (file modes) and S-8 (import limits).
4. S-2 and S-6 are design decisions: write down the trust assumption now; change the format or the handshake
   only if the folder is ever shared with someone else or an older build can still be running.
5. S-9 and the rest of S-11 when a signing identity is available.

## Production readiness (SRE / platform review, 2026-10-26)

Scope: can one person run this on their own Macs for years without losing data, and find out when something goes
wrong? IDs use the prefix P- to stay apart from the security items. Duplicates with other findings to be merged
later. Ranked by what would hurt most.

### P-1 One bad line makes the whole library unopenable (high)

`JSONLinesEventLog.readAll` throws `unreadableLine` for any undecodable line that is not the last line of another
device's file. Reading is all-or-nothing, so one damaged line in any device file (a torn write, a sync conflict
copy, a hand edit) means no device can show any task.

- Add a recovery path: open with the readable events, report the bad lines (file, line number) in the UI, and
  never rewrite the file.
- Test first: a log with a garbage line in the middle still opens, the line is reported, the file is untouched.

### P-2 A crash during an append can corrupt the next write (high)

`append` writes with a single `write(2)` and never checks that the file ends in a newline. If the process dies or
the disk fills mid-write, the file ends in a half line. The next append glues a valid event onto it, and that
event is lost along with the half line, in the middle of the file where P-1 turns it into a fatal error. There is
also no `fsync`, so a power cut right after a user action can lose the event the UI already showed.

- Before appending, check the last byte; if it is not `\n`, write a newline first so the damage stays one line.
- Call `fsync` (or `F_FULLFSYNC`) after the write.
- Test first: a log ending in a partial line takes a new event, and only the partial line is lost.

### P-3 No backup of the log outside compaction (high)

The log is the only copy of the data on a single Mac with the Home Folder option, and Dropbox history is not a
backup (a bad compaction or a sync bug is replicated). The only backup today is the one taken by Compact Log.

- Keep a rolling local snapshot (for example a daily copy of the log files and the YAML export under `backups/`,
  last N kept), taken on launch.
- Add a "Restore from backup" description to `docs/guide.md`, tested by restoring into a temporary folder.

### P-4 No diagnostics: nothing is logged (medium)

There is no `Logger`/`os_log` use anywhere in `Sources` or `App`. When a user-visible error, a skipped unknown
event type, a failed handshake or a slow replay happens, there is nothing to look at afterwards.

- Add `os.Logger` with subsystem and categories (store, sync, compaction) and log: log opened (event count, time to
  replay), skipped unknown events, compaction steps, append failures. No task titles or notes in log lines.
- Show the last storage error in Settings → This Mac with a "Reveal log folder" button.

### P-5 Startup and replay time grow without bound (medium)

Every read loads each device file whole into a `String`, decodes all of it, and replays it from the start, and the
file monitor polls and re-reads. Fine today; a few years of use on several devices will make launch and every
external change slower. The plan already says SQLite/snapshots only "once replay is slow", but nothing measures
"slow".

- Add a performance test that replays a synthetic log of, say, 200k events and fails above a budget, so the
  decision is made on a number.
- Make the monitor compare size and modification date before re-reading, and read only the appended tail when
  the file grew.

### P-6 Releases are unsigned, not notarised, and the version is not tied to the tag (medium)

`CODE_SIGN_IDENTITY = "-"` and the zip is not notarised, so a downloaded release is blocked by Gatekeeper and
cannot auto-update. `MARKETING_VERSION` is a hard-coded `0.2.0` in the Xcode project while the tags are `v0.9.0`,
`v1.0.0`; the app reports the wrong version, which makes bug reports and the "which build wrote this event"
question hard.

- Pass the release version into the build (`MARKETING_VERSION=$VERSION`, build number from the commit count) in
  `make dist`, and show it in the About box and in Settings → This Mac.
- Signing and notarisation need an Apple Developer identity; track as a decision, and until then document the
  right-click-open step in the README.

### P-7 Build and CI are not reproducible (medium)

- No `Package.resolved` is committed (and Yams is `from: "5.1.3"`), so a CI run can pick up a different Yams than
  the one a release was built with. Commit `Package.resolved` and build with `--force-resolved-package-versions`.
- GitHub Actions use floating tags (`actions/checkout@v4`, `upload-artifact@v4`) and `macos-26`; pin by SHA, and
  let Dependabot update them (also covers `swift` packages).
- `make tools` downloads SwiftLint without a checksum check; verify a pinned SHA-256.
- The CI job has no `timeout-minutes`, and failed runs upload nothing (coverage report, test log) to debug with.
  Add a timeout and `upload-artifact` of `.build/coverage.txt` with `if: always()`.

### P-8 Release workflow can publish a broken or half-made release (low)

- The release job runs on `main` pushes independently of the CI job, so a commit whose CI is red can still be
  published. Make release depend on a green `make check-ci` (reuse the CI workflow, or run `check-ci` in release).
- Attach a SHA-256 file next to the zip, so a downloaded build can be verified.
- Document how to roll back: a bad release is deleted and the tag re-pointed by hand today.

### P-9 No LICENSE, SECURITY.md or support information (low)

The repo has no `LICENSE`, so the legal status of the code is "all rights reserved" by default, whichever is
intended. Add the intended licence, and a short `SECURITY.md` (where to report, supported versions).

### P-10 Stray files in the repository root (low)

About 17 Python `.whl` files sit in the repo root and are not ignored. They are unrelated to the app, bloat every
clone, and could be committed with a `git add .`. Remove them and add `*.whl` to `.gitignore`. (The security
review lists the same files as S-1; this is the same fix.)

### P-11 Operations documentation is missing (low)

`docs/guide.md` describes features, but there is no runbook for the cases that matter: log damaged, device lost
or replaced, Dropbox conflict copies appearing in the shared folder, a stuck compaction handshake (what files to
delete, and when it is safe), and migrating from Home Folder to Dropbox. Add `docs/runbook.md` and link it from
the README. The stuck-handshake case in particular needs a timeout or a "cancel compaction" button, since a
device that is switched off blocks compaction for everyone.

### Not raised on purpose

No server, metrics, alerting, on-call or SLOs: this is a single-user local-first app, so those would be
ceremony. No telemetry or crash-reporting service: privacy of the user's tasks matters more; local logs (P-4) and
macOS crash reports are enough.

### Suggested order

P-2, then P-1 (small and test-first, protect the data), P-3, P-10, P-7 and P-9 (minutes of work), then P-4,
P-6, P-11, with P-5 and P-8 when they start to matter.

---

## Architect's assessment: long-term evolution (second independent pass)

IDs use the `A-` prefix so they do not clash with the other pass; merge duplicates later. Each item is
here because it changes whether the app survives years of daily use, not for completeness.

### A-1. Stop an older build writing to a newer log

**Problem.** A build skips event types it does not know (`JSONLinesEventLog`, AGENTS.md "Event-sourcing
rules") and carries on. With two Macs on different versions, the older one replays a library that is
missing the effect of those events, shows it as truth, and lets the user edit on top of it. A new optional
field on a known event is dropped the same way, silently. The edits it writes are valid events, so the
damage is a wrong picture that then drives wrong decisions (a task shown as open that is done, a plan
that ignores a new rule), not corruption.

**Proposal.** Count the events skipped on read, expose it in `LibraryViewModel`, and when it is above zero
show a banner ("this log has changes from a newer Luthor") and make the app read-only until updated.
Optional and cheaper: a `minReader` marker event (an additive new type) that a build older than it
refuses to write past. Test first: a log with an unknown line opens read-only.

**Why now.** Free before iOS exists; once a second client ships on its own cadence, version skew is the
normal case, not the exception.

### A-2. Decide what compaction may forget, before the log gets big

**Problem.** `LogCompactor` rebuilds the log from `LibraryState.export()`, which by design drops history
(time logged, reviewed days, estimate history, plan orders; see the doc comments in `LibraryExport.swift`
and `LogCompactor.swift`). That conflicts with "events are the source of truth": the one operation meant
to keep the app fast for years permanently deletes the data behind the daily review and estimate
calibration, which are the point of ALPEN (L and N). Compaction is also a stop-the-world handshake across
all devices.

**Proposal.** Pick one and write it in the architecture doc: (a) compaction keeps history events
(`TaskTimeLogged`, `UnplannedTimeLogged`, `DayReviewed`) and only collapses edit chatter on items, or
(b) take a **snapshot event** that is a checkpoint (state at lamport N) while leaving older events in an
archive file that replay does not read but that is never deleted. (b) removes the need for the handshake
because a snapshot is just another append. Either way compaction must be a test of "history queries give
the same answers before and after".

### A-3. Make a user action cost O(change), not O(log)

**Problem.** `LibraryViewModel.perform` calls `log.readAll()` (reads and decodes every device file) and
`Commands` computes the next Lamport as `(log.map(\.lamport).max() ?? 0) + 1`, then `show` replays the
entire list again. Every keystroke-level action is two full passes over the history. The roadmap defers
SQLite until replay is "measurably slow", which is right, but nothing measures it, so the decision will
be made by the app feeling sluggish.

**Proposal.** Small and no new dependency: (1) the view model keeps the replayed `LibraryState` and the
max Lamport in memory and applies only the new events (`reduce` already exists), re-reading the files
only when `FileChangeMonitor` reports an outside write; (2) add a benchmark test that generates a
synthetic 5 years of use (roughly 300k events) and records read plus replay time, with a budget in the
roadmap's slice 16 so "slow" has a number. SQLite stays deferred.

### A-4. Run the package tests on Linux CI

**Problem.** CI is macOS-only (`macos-26`), and AGENTS.md notes remote agent sessions often have no Swift
toolchain, so the test-first rule cannot be followed there: tests are written and only seen to run after a
push. `LuthorDomain`, `LuthorStore` and `LuthorViewModels` use Foundation only (the app target is the only
SwiftUI user).

**Proposal.** Add an `ubuntu-latest` job running `swift test --filter` over the three packages (excluding
anything needing AppKit or `Yams` problems, if any) and a Dockerfile or setup step for agent sessions that
installs the same toolchain. Fastest feedback loop for the most-tested layers, cheaper minutes than macOS,
and it keeps the domain honestly platform-free, which the iOS app and any future non-Apple client depend
on. Keep `make check-ci` as the full gate.

### A-5. Property-based convergence tests across every event type

**Problem.** The core promise is "replay of the same set of events in any arrival order produces the same
state". Today that is covered by shuffle tests on chosen scenarios and a golden log. Concurrent edits
between two Macs are exactly where an event-sourced design with Lamport ordering breaks quietly: an edit
to an item another device deleted, a move into a project that was meanwhile completed, a drop and a
reschedule of the same task, two devices producing the same `TaskID.recurring(after:)`.

**Proposal.** One test target that generates random sequences of valid commands on two simulated
devices (using the existing `Commands`, `SequentialIDs`, `InMemoryEventLog`), merges the logs in random
interleavings, and asserts equal `LibraryState` plus no crash. Runs seeded and fast in `make test`.
Fix whatever it finds; each failing seed becomes a regression test. This is the safety net for slice 17
(Dropbox API) and for iOS, where concurrency is routine.

### A-6. Keep the code map honest with a script

**Problem.** The Code map in AGENTS.md is ~100 lines that must be hand-edited in every PR that touches a
file, and it is already the most likely thing to drift. A map that is wrong is worse than none for the
agents that rely on it.

**Proposal.** A small `scripts/check-code-map.sh` (with a shell test, like the other scripts) that fails
`make lint` when a file named in the map does not exist, or a source file under `Sources/` or `App/Luthor/`
is not mentioned in it. No generation, just a guard; the prose stays hand-written.

### Not proposed (considered, left alone)

- SQLite/GRDB projections: correct to defer; A-3 gives the trigger a number.
- A CloudKit/other sync backend: the per-device-file design already isolates this behind the log
  protocol; revisit only if Dropbox API sync (slice 17) proves painful.
- Splitting `LibraryState` into more types: the extension-per-concern layout is working; the file-length
  pressure is cosmetic.
