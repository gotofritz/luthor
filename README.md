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
