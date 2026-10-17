A GTD system loosely inspired by OmniFocus

## Repository settings

GitHub settings for this repo live in Terraform, in `infra/`:

- squash merge only, with the PR title as the commit title; auto-merge allowed
- head branches deleted after merge
- a ruleset on `main`: changes go through a PR, no force pushes or
  deletion, and the `make check-ci` and `Conventional Commit title` checks
  must pass

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
   ```

4. Preview, then apply:

   ```bash
   terraform plan
   terraform apply
   ```

   Read the plan before applying: it should only change settings, never
   destroy the repository (`prevent_destroy` blocks that anyway).

### State

State is local, in `infra/terraform.tfstate`, and gitignored. It holds no
secrets but is needed to manage the settings later; if it is lost, run the
imports in step 3 again.

### Changes later

Edit the `.tf` files, then `terraform plan` and `terraform apply`. A plan
with no edits shows drift, for example a setting changed in the GitHub UI.

Apply the ruleset only once both checks have run on a PR to `main`, or PRs
wait for checks that never report.
# Luthor

A GTD system loosely inspired by OmniFocus: local-first and event-sourced.
See `AGENTS.md` and `docs/plans/` for the architecture and roadmap.

## CLI

```bash
swift build -c release
export LUTHOR_LOG=~/.luthor/events.jsonl           # optional, this is the default; created on first add
export LUTHOR_DEVICE_ID=macbook                   # optional, default: local

.build/release/luthor add "buy milk"
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
CLI makes. Type
and press Return to capture; ↑ and ↓ select a task, ⌘Return completes it, or
click its circle.

The sidebar lists the Inbox and the active projects. Create a project with the
field at the bottom of the sidebar, choosing parallel (every task is a next
action) or sequential (only the first open task is; the others are dimmed).
File a task by dragging it onto a project, or select it and press ⌥⌘1 to ⌥⌘9
for the first nine projects (Task → Move to Project). Typing in a project's
capture field adds the task straight to that project. Complete a project from
the toolbar or its context menu in the sidebar; its open tasks go with it.

The build is ad-hoc signed: the first launch of a copied app needs
right-click → Open.

## Install and releases

```bash
make install   # the app into ~/Applications, the CLI into ~/.local/bin
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
