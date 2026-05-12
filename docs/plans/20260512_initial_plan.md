# 1. Luthor

A personal GTD-style task system (OmniFocus-like) with these constraints:

* Primary goal: **fast, reliable personal execution system**
* Must support:

  * Mac + iPhone usage (cross-device from day 1)
  * extremely fast capture and interaction
  * sophisticated GTD workflows (projects, tags, defer/due, review, etc.)
* Must be **forever software** (long-term personal system)
* You want:

  * to avoid committing to Apple Developer Program initially
  * to avoid CloudKit dependency at the start
  * to still have working sync immediately across devices
* You already use Joplin for notes (so this is strictly task execution, not knowledge management)

Core technical challenge:

> Build a fast local-first task system with reliable cross-device sync, without committing early to Apple infrastructure.

---

# 2. Summary of solution + stack

## Core architecture choice

You are building a:

> **local-first, event-driven GTD system with Dropbox API-based sync**

NOT:

* cloud-first app
* raw SQLite file sync system
* web backend system

---

## Key design principle

> “Events are the source of truth, not the database.”

SQLite is a performance layer, not the canonical store.

---

## Stack

### UI layer

* Swift
* SwiftUI (Mac first, iOS later)

### Domain layer

* Pure Swift business logic (tasks, projects, GTD rules)

### Local persistence

* SQLite (recommended via GRDB)
* used as a fast projection / cache layer

### Source of truth

* Append-only **event log**

  * TaskCreated
  * TaskCompleted
  * TaskDeferred
  * TagAdded
  * DueDateSet
  * etc.

### Sync layer (day 1)

* Dropbox API
* syncs event log files (NOT SQLite DB)

---

## Why this works

* No Apple Developer dependency
* No backend required
* Safe multi-device sync (because events are immutable)
* Future-proof (can migrate to CloudKit later without redesign)
* Avoids SQLite file corruption issues entirely

---

# 3. Implementation plan (broad strokes)

## Phase 0 — Architecture setup (foundation)

Goal: define system shape before features

### Build:

* SwiftUI Mac app shell
* basic navigation shell (Inbox / Projects / Today)
* event model definitions (pure Swift structs)
* event store (append-only log locally)

### Output:

* app runs locally
* can create events
* can replay events into in-memory state

---

## Phase 1 — Local GTD system (no sync yet)

Goal: working personal task system on one device

### Build:

* Inbox capture flow (fast add)
* Task lifecycle (create / complete / defer / due)
* Projects (parallel + sequential only)
* Tags (simple context filtering)
* Basic review view

### Add:

* SQLite (GRDB) as projection store for speed
* event → state reducer layer

### Output:

* fully usable Mac GTD app
* extremely fast local experience
* no sync complexity yet

---

## Phase 2 — Dropbox API sync layer

Goal: cross-device sync without Apple stack dependency

### Build:

* Dropbox OAuth login
* event log upload/download
* sync cursor tracking
* batch event file system (append-only)

### Sync behavior:

* each device writes events locally
* periodically uploads new events
* downloads remote events
* merges deterministically (replay)

### Output:

* Mac ↔ Mac sync works
* portable GTD system across machines

---

## Phase 3 — iOS expansion (optional at this stage)

Goal: mobile usage

### Build:

* SwiftUI iOS app
* same domain + event system
* same Dropbox sync layer

### Output:

* real cross-device GTD system (phone + laptop)

---

## Phase 4 — system refinement

Goal: make it feel like a premium execution tool

### Improve:

* capture speed (command palette / shortcuts)
* review system (OmniFocus-like cadence)
* perspectives replaced with query system
* performance tuning of projections
* UI polish for speed-of-use

---

## Phase 5 — future migration path (optional)

Once system proves valuable:

You can replace Dropbox sync with:

* CloudKit sync (if you join Apple Developer Program)
* or hybrid sync adapter

Important:

> No core model changes required because events remain the source of truth.

---

# Key takeaway

Your system is fundamentally:

> a local-first event-sourced GTD engine with Dropbox API as the initial transport layer

Not:

* a database app
* a sync problem
* a UI framework experiment
