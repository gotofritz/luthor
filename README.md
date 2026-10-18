# Luthor

A task system built around the ALPEN daily-planning method, with OmniFocus as
a reference: local-first and event-sourced.
See `docs/guide.md` for how to use it, and `AGENTS.md` and `docs/plans/` for
the architecture and roadmap.

## Mac app

```bash
make app
open .build/xcode/Build/Products/Release/Luthor.app
```

Or open `App/Luthor.xcodeproj` in Xcode and run. The app reads and writes
`$LUTHOR_LOG` when it is set (launched from a shell, or from Xcode's scheme),
otherwise `~/.luthor/events.jsonl`, and picks up changes another process
makes to that file. Type and press Return to capture; ↑ and ↓ select a task, ⌘Return
completes it, or click its circle.

The app shows one view at a time, such as Work or Private, and nothing of
another view leaks into it. The view switcher at the top of the window
switches view (no keyboard shortcut, so it cannot be hit by mistake), creates
and renames views; the app reopens on the view last used on that Mac. Task → Move to View, or Move to View in a
project's context menu, takes a task or a whole project across.

A narrow rail on the left, icons with their names underneath, picks the place
to look at: Inbox (a list of its tasks), Today, Calendar, Reviews (the glasses), Projects, Prios or Tags, with
Settings pinned to the bottom (or ⌘,). Above the main area is a bar with a search box
(not working yet) and the view switcher.

Prios lists the priorities Critical, Important, Optional and One day, and No
priority. It picks like any Mac list: click one, shift-click for a range,
⌘-click to add or drop one; the tasks of all picked are listed, the most
urgent first. Give a task a
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

Completed and dropped tasks and projects disappear, but the Completed and dropped toggle in the top
bar lists them again, dimmed after the open ones, and Reopen brings one
back. Click a task and a card opens in the next column; click a project and
its column starts with a card, with its children below. A card is read-only:
it shows the day it was created, the due date and the notes (web addresses are
clickable), not the title, which is in the column before. The pencil opens it
for editing (title, priority, estimate, due date, repeat, tags and notes for a task; title,
kind and notes for a project), and OK keeps the changes or Cancel drops them.

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
next day, ⇧⌘T returns to today (Plan menu). Tasks planned for a day that has
passed and not decided on wait at the top of Today as leftovers; nothing moves
them on by itself.

Tags are `@calls`-style contexts that belong to one view. Type them in the Tags
field of a task's card (names separated by commas; a new name creates the
tag), or toggle them in a task's context menu. The Tags place lists the view's
tags, then the tasks that carry the one picked. The Filter button above Today's
candidates narrows them by tag, priority, project or deadline.

A task can have a due date, set on its card: a hard deadline or a target date.
A hard deadline that is due on the day Today shows (or overdue) puts the task
ahead of the other tasks of its priority among the candidates, saying so under
it; a target date only shows. A due date never plans a task by itself.

A task can repeat, set in the Repeat field of its card or from its context
menu: every N days, weeks, months or years, a weekly one on chosen weekdays,
counted from the due date or from the day it is done. Completing it makes the
next one, due by the rule; Skip This One passes over one occurrence, Stop
Repeating clears the repeat, and Drop Task or Send to Someday end the series.

A task and a project are the same kind of item: a project is an item that holds others. A project has
the card of a task, with a priority, estimate, due date, repeat and tags, and a task can be filed under another
task. Add Tasks (on a card or in its context menu) makes an item a project that you then add tasks to, keeping
everything set on it. An item can be duplicated (Duplicate in its context menu, or ⇧⌘D): the copy has the
same title, notes, priority, estimate, due date, tags and repeat, in the same project, planned for no
day, and a project's copy holds copies of its tasks. Delete Permanently… (context menu, after a confirmation) removes an item,
and what it holds, completed ones too, for good, where dropping only gives it up.
A project's due date ranks the tasks in it, and its estimate is its own, else the sum of its open tasks'.

Calendar (⇧⌘C) lists the days as rows, from two months back to a year ahead,
Sundays tinted, with a mark on a day that has tasks planned for it and another
on a day that has tasks due on it. Click a day to list its tasks in the next
column, and a task to open its card. It only shows: planning stays in Today.

Review is the other face of Today: the Plan / Review toggle at the top of Today flips between planning a day and looking back on it (⇧⌘N, Plan → Show Day Review). It closes the loop on a day: the tasks planned for it that were done
and the ones not, the minutes each took typed by hand against its estimate,
unplanned minutes, and a one-line note that marks the day reviewed. Each task
not done gets a decision with the same chords as Today (tomorrow, another day,
back to the list, delegate, someday, drop). What a task was estimated and what
it took is shown on the review and on the cards, and never applied to the
estimate.

Reviews (the glasses icon) is the weekly project review. Projects are due for
review once a week by default; the place lists those whose review is due, the
longest overdue first. Pick one to see its card and its tasks, which you can
edit and add to in place, then Mark Reviewed (⇧⌘R) to move to the next. A
project can be reviewed more or less often (or never) from its context menu or
here, and Settings → Global sets the default for all of them. A project that
is no longer wanted can be dropped (Drop Project: it and its open tasks leave
the lists and the review; the Completed and dropped toggle lists them, and Reopen brings them back).

Settings has two families of settings, Global and Local (overrides for the
view currently shown): Global sets the numbers every view falls back to
(default estimate for an unestimated task, buffer percentage, capacity per
weekday), how often projects are reviewed and a default view;
Local overrides the buffer and capacity for the current view only, and
follows the global value until switched on. A third family, This Mac, chooses
where the tasks live (see below).

The build is ad-hoc signed: the first launch of a copied app needs
right-click → Open.

## Where the tasks live, and sync between Macs

The first time you start the app, a window asks where to keep the tasks:

- **Dropbox**, the default: a folder the Dropbox desktop app syncs
  (`~/Dropbox/backups/Luthor`; type another folder if yours is elsewhere).
  The folders are created if they are not there. Use it on every Mac and all
  of them show the same tasks.
- **Home Folder**: `~/.luthor/events.jsonl`, on this Mac only.

Change the choice later in Settings → This Mac. Moving to Dropbox copies the
tasks of the Home Folder in the first time, so none are lost; moving back
copies nothing, and the Home Folder keeps the tasks it had.

How the sync works: Luthor has no sync code of its own. Each Mac appends only
to its own file in the folder, `events-<device>.jsonl`, so two Macs never
write the same file and Dropbox never makes a conflict copy. Every Mac reads
all the files, merges the events and replays them in one order, so all Macs
end with the same state. The app picks up what Dropbox delivers within a
second or two. Wait for Dropbox to finish syncing before you quit a Mac, or
the other Mac sees your latest changes only when that Mac next syncs; nothing
is lost either way.

A Mac is named in the folder after its host name and a random ID the app
makes on first start and keeps on that Mac, e.g. `events-MacBook-3f9a2c1b.jsonl`,
so two Macs with the same host name still write different files. To name a
Mac yourself instead, `defaults write com.gotofritz.luthor LUTHOR_DEVICE_ID
desk` and restart the app (give each Mac a different name).

Environment variables override the choice, and are for running the app from a
shell or Xcode: `LUTHOR_SYNC_DIR` (a shared folder), `LUTHOR_LOG` (a single
file) and `LUTHOR_DEVICE_ID`. While one of the first two is set, Settings
shows that it decides.

## Install and releases

```bash
make install   # the app into /Applications
```

`APP_INSTALL_DIR` changes where (`make install APP_INSTALL_DIR=~/Applications`).
Releases are automatic. When a merge to `main` brings a `feat`, a `fix` or a
`perf` commit since the last release, CI works out the next version from the
Conventional Commit titles, builds the app and publishes it, zipped, in a
GitHub Release (which creates the tag): `feat` bumps the minor version, `fix`
and `perf` the patch, and a `!` after the type (`feat!:`) is a breaking change
and bumps the major version, or the minor one while the major is 0, so 1.0.0
is a choice of yours. `docs`, `test`, `ci`, `chore`, `style`, `build` and
`refactor` merges make no release. The first release is `v0.1.0`. Pushing a
version tag by hand (`git tag v0.1.0 && git push origin v0.1.0`) still
publishes that version instead. `make dist` builds the same zip locally into
`.build/dist/`.

### On another Mac, without compiling

Every release has `Luthor-<version>.zip` attached. Fetch the latest with the GitHub CLI (`brew install gh`, then
`gh auth login` once; the repo is private, so a browser would need a login
too):

```bash
cd "$(mktemp -d)"
gh release download --repo gotofritz/luthor --pattern 'Luthor-*.zip'
unzip -q Luthor-*.zip
rm -rf /Applications/Luthor.app && mv Luthor.app /Applications/
open /Applications/Luthor.app
```

To update, quit the app and run the same commands; your data lives in the
log, not in the app.

The build is ad-hoc signed, not notarised. `gh` does not mark the download
as quarantined, so the app opens normally. If you download the zip in a
browser, or get it over AirDrop, macOS blocks the first launch: right-click
the app → Open, or clear the flag once:

```bash
xattr -dr com.apple.quarantine /Applications/Luthor.app
```

Notarising (an Apple Developer ID, $99 a year) would remove that step; it is
not set up.

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
