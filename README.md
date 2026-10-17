# Luthor

A task system built around the ALPEN daily-planning method, with OmniFocus as
a reference: local-first and event-sourced.
See `docs/guide.md` for how to use it, and `AGENTS.md` and `docs/plans/` for
the architecture and roadmap.

## CLI

A quick way to capture from the shell. It knows only tasks, not projects,
and works in one view: `list` shows every open task of that view, filed or
not. The app does everything it does
and more; from slice 13 of the roadmap it shrinks to `luthor add`, for Alfred.

```bash
swift build -c release                             # or `make install`, below, to put luthor on PATH
export LUTHOR_LOG=~/.luthor/events.jsonl           # optional, this is the default; created on first add
export LUTHOR_DEVICE_ID=macbook                   # optional, default: local
export LUTHOR_VIEW=Work                            # optional, default: the view chosen in Settings

.build/release/luthor add "buy milk"
.build/release/luthor add "call bank !a 15m"        # priority Critical, 15-minute estimate
.build/release/luthor add --view Private "call mum" # --view wins over LUTHOR_VIEW
.build/release/luthor list
.build/release/luthor done 9afc                    # any unique prefix of a task ID
```

## Mac app

```bash
make app
open .build/xcode/Build/Products/Release/Luthor.app
```

Or open `App/Luthor.xcodeproj` in Xcode and run. Like the CLI, the app
reads and writes `$LUTHOR_LOG` when it is set (launched from a shell, or from
Xcode's scheme), otherwise `~/.luthor/events.jsonl`, and picks up changes the
CLI makes. Type and press Return to capture; ↑ and ↓ select a task, ⌘Return
completes it, or click its circle.

The app shows one view at a time, such as Work or Private, and nothing of
another view leaks into it. The view switcher at the top of the window
switches view (no keyboard shortcut, so it cannot be hit by mistake), creates
and renames views; the app reopens on the view last used on that Mac. Task → Move to View, or Move to View in a
project's context menu, takes a task or a whole project across.

A narrow rail on the left, icons with their names underneath, picks the place
to look at: Inbox (a list of its tasks), Today, Projects or Prios, with
Settings pinned to the bottom (or ⌘,). Above the main area is a bar with a search box
(not working yet) and the view switcher.

Prios lists the priorities Critical, Important, Optional and One day. Click
one to list its tasks, click another to add it: the picked priorities add up,
the most urgent first; click a picked one again to drop it. Give a task a
priority from its context menu or Task → Priority, and an estimate in
minutes from Estimate. Either clarifies a task out of the Inbox, same as
filing it into a project; a task given One day is kept out of next actions
until promoted. The quick-capture syntax does both at once:
`call bank !a 15m`.

Projects nest to any depth and show in Miller columns: the first column lists
the top-level projects, and each project you open adds a column
of its sub-projects and tasks. Create a project with the field at the bottom,
choosing parallel (every child is active) or sequential (only the first open
child is; the rest are dimmed); it goes inside the project shown, or top-level
while none is open. Drag a project onto another to nest it, or onto the first
column to make it top-level. File a task by dragging it onto a project, or
select it and press ⌥⌘1 to ⌥⌘9 for the first nine projects (Task → Move to
Project). Typing in the capture field adds the task straight to the project
shown. Next actions follow the whole tree: a task is one only if every
project above it lets it be. Complete a project from the toolbar or its
context menu; its sub-projects and open tasks go with it.

Completed tasks and projects disappear, but the Completed toggle in the top
bar lists them again, dimmed after the open ones, and Reopen brings one
back. Click a task and a card opens in the next column with its title,
priority, estimate, project and notes; click a project and its column starts
with a card for its title, kind (parallel or sequential, also in its context
menu) and notes, with its children below. Notes are plain text, with web
addresses made clickable.

Today is the morning plan, one per view and day: a capacity meter (the day's
minutes less the protected buffer, what is planned and what is left, red and
informing when overloaded, never refusing), the ordered plan, the candidates
to pull in, and Waiting for. Add a task to the plan with ⌘T or its context
menu; it keeps its place in the order you choose (⌥⌘↑ and ⌥⌘↓) and otherwise
follows A before B before C, then project order, each place explained under
the task. Decide on a task in one chord: Defer to Tomorrow (⌘D), Delegate…
(⌘L, with an optional follow-up day), Send to Someday (⌘Y), Drop Task
(⇧⌘⌫). A delegated task leaves the plan and its totals and waits in Waiting
for until reclaimed or its follow-up day. ⌘[ and ⌘] move to the previous and
next day, ⇧⌘T returns to today (Plan menu).

Settings has two families of settings, Global and Local (overrides for the
view currently shown): Global sets the numbers every view falls back to
(default estimate for an unestimated task, buffer percentage, capacity per
weekday) and which view `luthor add` and imports use when none is named;
Local overrides the buffer and capacity for the current view only, and
follows the global value until switched on.

The build is ad-hoc signed: the first launch of a copied app needs
right-click → Open.

## Install and releases

```bash
make install   # the app into /Applications, the CLI into ~/.local/bin
```

`PREFIX` and `APP_INSTALL_DIR` change where (`make install PREFIX=/usr/local`).
Pushing a version tag (`git tag v0.1.0 && git push origin v0.1.0`) builds both
on CI and attaches them, zipped, to a GitHub Release. `make dist` builds the
same zips locally into `.build/dist/`.

## Development

Needs Xcode (for `make app`). Once per checkout:

```bash
make tools   # download the pinned SwiftLint into .tools/; make lint and make check-ci need it
make hooks   # run format, lint and commit-message checks on every commit
```

Then:

```bash
make check-ci   # lint, build, tests with a 90% coverage gate, and the Mac app: exactly what CI runs
```

## Repository settings

GitHub settings for this repo live in Terraform, in `infra/`:

- squash merge only, with the PR title as the commit title; auto-merge allowed
- head branches deleted after merge; PRs behind `main` offer "Update branch"
- a ruleset on `main`: changes go through a PR, no force pushes or
  deletion, and the `make check-ci` and `Conventional Commit title` checks
  must pass on a branch that is up to date with `main`

Rulesets on a private repo need GitHub Pro (or a paid plan); on GitHub Free
the apply fails for the ruleset.

### Setup

1. Install Terraform from HashiCorp's tap (Homebrew core no longer ships
   it): `brew install hashicorp/tap/terraform`.
2. Create a [fine-grained personal access
   token](https://github.com/settings/personal-access-tokens/new) for the
   `luthor` repo only (Repository access: Only select repositories). Under
   repository permissions, add **Administration** and switch its access
   from the default Read-only to **Read and write**, then export it:

   ```bash
   export GITHUB_TOKEN=github_pat_...
   ```

3. Initialise, then import the settings that already exist, so Terraform
   manages them instead of trying to create them:

   ```bash
   cd infra
   terraform init
   terraform import github_repository.luthor luthor
   # only if a ruleset already exists; its ID is in the ruleset's URL
   terraform import github_repository_ruleset.main luthor:<ruleset-id>
   cd ..
   ```

4. From the project root, run `make infra`. It runs `terraform init`, shows
   the plan and applies it only if you answer `yes`; anything else is a dry
   run.

   Read the plan before applying: it should only change settings, never
   destroy the repository (`prevent_destroy` blocks that anyway).

### State

State is local, in `infra/terraform.tfstate`, and gitignored. It holds no
secrets but is needed to manage the settings later; if it is lost, run the
imports in step 3 again.

### Changes later

Edit the `.tf` files, then `make infra`. A plan
with no edits shows drift, for example a setting changed in the GitHub UI.

Apply the ruleset only once both checks have run on a PR to `main`, or PRs
wait for checks that never report.
