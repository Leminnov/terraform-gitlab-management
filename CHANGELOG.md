# Changelog

All notable changes to this project will be documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com) and the
project follows [Semantic Versioning](https://semver.org). Sections before
11.1.0 were generated from commit messages by git-cliff.

## [Unreleased]

### Added

- `projects[*].files` commits files to the default branch, before the module creates other branches. A file is managed (the default: Terraform owns it and reverts edits) or seeded with `managed = false` (committed once, then owned by the developers).
- `projects[*].kubernetes_agents` registers GitLab agents for Kubernetes, each with a token (new sensitive output `kubernetes_agent_tokens`). Its `ci_access` (created groups and projects by key, existing ones by full path) is written to the agent's managed `.gitlab/agents/<name>/config.yaml`.
- Registry protection on created projects:
  - `package_protection_rules` (push by maintainers by default);
  - `container_protection_rules`, whose `path_pattern` is appended to the project's full path;
  - `container_tag_protection_rules` (protected container tags; `immutable = true` needs Ultimate);
  - `container_expiration_policy`, off unless set because cleanup deletes images.
- Cross-project sharing: `projects[*].enabled_runners` enables an unlocked project runner of another created project (`"<project key>:<runner name>"`), and `enabled_runner_ids` an existing runner by ID. `enabled_deploy_keys` and `enabled_deploy_key_ids` do the same for deploy keys, always read-only.
- Opt-in CI hardening on created projects: `projects[*].ci.hardening_enabled` (default `false`, so existing projects do not change). When on, it sends `public_jobs = false`, pipeline variable overrides by no one, protected merge request pipelines, separate caches for protected branches, forward deployment, no job-token pushes and no merge on skipped pipelines. Each of these can also be set on its own, and an explicit value wins.
- Other CI settings in `projects[*].ci`, each sent only when set: `config_path`, `auto_cancel_pending_pipelines`, `build_timeout`, `default_git_depth`, `delete_pipelines_in_seconds`, `id_token_sub_claim_components` (the OIDC `sub` claim), `group_runners_enabled` and `shared_runners_enabled`. Also `groups[*].shared_runners_setting`.
- `projects[*].freeze_periods` (deploy freezes), `projects[*].secure_files` (CI/CD secure files, text content, redacted in plans and stored in state) and `projects[*].cicd_catalog`.
- `rotation_configuration = { expiration_days, rotate_before_days }` on group and project access tokens, standalone and nested: the first apply within `rotate_before_days` of expiry rotates the token. `expires_at` becomes optional, and exactly one of the two is required.
- Service accounts (GitLab 18+, Free tier included) at three levels:
  - `service_accounts`, in an existing top-level group or intermediate subgroup;
  - `groups[*].service_accounts`, in a created subgroup;
  - `projects[*].service_accounts`, in a created project.

  Each account has `tokens` with `scopes` (administrator scopes rejected) and exactly one of `expires_at` or `rotation_configuration`. Accounts get access through `members[*].service_account`, checked at plan against GitLab's invitation scope; `members[*].user_id` becomes optional. New outputs `service_accounts` and `service_account_tokens` (sensitive). Dated and rotating tokens live in separate resource blocks, because provider 19.5 crashes validating an unknown `rotation_configuration`.

## [13.0.0] - 2026-10-23

### Changed (breaking)

- Keys of `group_variables`, `project_variables`, `deploy_tokens`, `pipeline_schedules`, `gitlab_runners`, `gitlab_group_access_token` and `gitlab_project_access_token` can no longer contain `:`, which the objects nested in `groups` and `projects` use in their keys. Upgrade: rename such an entry and move each of its resources, or they are replaced; for an entry `ci:lint` of `group_variables` on group `org/a` renamed `ci_lint`: `moved { from = module.<name>.gitlab_group_variable.this["ci:lint_org/a"] to = module.<name>.gitlab_group_variable.this["ci_lint_org/a"] }`.
- Provider floor raised from `gitlabhq/gitlab ~> 18.11` to `~> 19.5`: 19.0 removes `gitlab_deploy_token`, 19.1 adds the state mover the migration below relies on, and 19.5 is the tested version. Upgrade: back up your state, bump the module `?ref=`, run `tofu init -upgrade` (provider 18.x no longer satisfies the constraint).
- Deploy tokens are managed by `gitlab_group_deploy_token` instead of the removed `gitlab_deploy_token`. A `moved` block migrates every `gitlab_deploy_token.this["<entry>_<group>"]` to `gitlab_group_deploy_token.this["<entry>_<group>"]` through the provider's state mover: the plan shows a move, not a destroy and create, and the existing tokens keep working. Nothing to edit; review the plan before applying.
- `deploy_tokens[*].expires_at` is required (`secrets-rotation`: no token without expiry). Upgrade: set `expires_at = "YYYY-MM-DDT00:00:00Z"`, at most a year ahead, on every deploy token. A deploy token cannot be updated, so adding an expiry makes GitLab issue a new token: apply, then read the new `username` and `token` from the `deploy_tokens` output and roll them out to the consumers (the replaced token is revoked).
- `pipeline_schedules[*].ref` must be a full git ref, as provider 19.4+ requires. Upgrade: write `ref = "refs/heads/main"` instead of `ref = "main"`, and `refs/tags/<tag>` for a tag.
- 13 outputs removed. They duplicated another output or echoed inputs back; they were removed rather than deprecated, by maintainer decision (`DEVIATION(repository-versioning)`). Upgrade, for each reference to a removed output:
  - `all_tokens`: read `deploy_tokens`, `group_access_tokens` and `project_access_tokens`.
  - `deploy_tokens_by_group`, `deploy_tokens_summary`: read `deploy_tokens` (keyed `"<entry>_<group>"`, with `group`, `name`, `username`, `expires_at` and `scopes` next to `token`).
  - `group_access_tokens_by_group`, `group_access_tokens_summary`: read `group_access_tokens`; `project_access_tokens_by_project`, `project_access_tokens_summary`: read `project_access_tokens`.
  - `gitlab_runners_by_type`: filter `gitlab_runners` on `runner_type`.
  - `pipeline_schedules`: read `pipeline_schedule_ids`; the other attributes are the module input.
  - `resource_counts`: use `length()` on the kept outputs.
  - `group_variables`, `project_variables`, `pipeline_schedule_variables`: removed with no replacement, since they returned the values the caller already holds.

### Added

- Group and project tree: `parent_group_id` names the existing group the tree is created under (gitlab.com does not let the provider create top-level groups), `groups` creates up to 7 levels keyed by path (`platform`, `platform/infra`, ...) and `projects` creates projects keyed the same way (`platform/infra/api`). Defaults follow the `gitlab-project-settings` and `git-branching` standards: private, access requests off, project creation by maintainers and subgroup creation by owners, `main` initialised with a README plus a `develop` branch, `main` protected for maintainers and `develop` for developers without force push, `v*` tags protected for maintainers, merges only on a green pipeline with every thread resolved, squash encouraged, merge commits and source branches deleted. Groups and projects are archived instead of deleted on destroy unless `archive_on_destroy = false`. New outputs `groups` and `projects`.
- Objects nested in each `groups` and `projects` entry, keyed `"<group or project key>:<item key>"`: `variables`, `deploy_tokens`, `access_tokens`, `members`, `shared_with` (a created group by key or an existing one by ID) and `runners` on both, plus `deploy_keys` (read-only by default, expiry required), `pipeline_schedules` (on the default branch by default), `pipeline_triggers`, `environments` and `job_token_allowlist` on projects. They share resources and outputs with the standalone inputs, under the same validations. New sensitive outputs `project_deploy_tokens` and `pipeline_trigger_tokens`.
- `labels` and `badges` on each `groups` and `projects` entry, and `hooks` on projects: webhooks send push events and verify TLS by default, and their `token` and `signing_token` are redacted in plans (stored in state, `SECURITY.md`); `signing_token` must be `whsec_` followed by the base64 of a 32-byte key, the only form GitLab accepts.
- Premium settings, off by default so a Free namespace plans none of them: `approval_rules`, `merge_request_approvals` (approvals reset on push, no self-approval, approvers fixed), `push_rules` (secrets, tag deletion and non-member commits rejected), `protected_environments` (maintainers deploy) and `protected_branches[*].code_owner_approval_required` on projects, and `hooks` on groups.
- Plan-time warnings `public_visibility`, `protected_branch_force_push`, `webhook_ssl_verification` and `deploy_key_write_access`; `token_lifetime` also reads project deploy tokens and deploy keys, and every existing warning covers the objects nested in groups and projects.
- Integration fixture `tests/integration/` against a sandbox group on gitlab.com, run by `mise run test-integration` and by the CI job `test:integration:gitlab` (protected refs, release tags, weekly schedule; `create:release` waits for it): an owner run, a least-privilege run and an upgrade run from `v12.0.0`. Each applies, checks the result on the server, requires an empty second plan and destroys; `TESTING.md` describes both suites.
- `SECURITY.md` lists what lands in state and a rotation procedure per secret class.
- Plan-time warnings (`checks.tf`): `secret_variables_masked_and_protected` (a secret-looking variable key that is not both masked and protected), `token_lifetime` (a token expiring more than a year after the plan) and `access_token_privilege` (an `owner` access token, or one with no level, which GitLab turns into `maintainer`). They warn without blocking the apply and never print a value.

### Changed

- Toolchain on the latest stable releases: OpenTofu 1.13.2 (CI also validates on 1.11.14), pre-commit 4.7.0, trivy 0.76.1, checkov 3.3.30, osv-scanner 2.7.0, mise 2026.10.17, Python 3.14.9, node 24.22.1 (LTS) and pre-commit-terraform v1.109.3, one patch above the terraform store's pin (`DEVIATION(terraform-repo-precommit)`); CI on `alpine:3.24` and `ubuntu:26.04`, one LTS above the `repository` store's `ubuntu:24.04` for the pre-commit job (`DEVIATION(repository-gitlab-ci)`).
- Resources live in themed files (`groups.tf`, `projects.tf`, `access.tf`, `ci.tf`, `metadata.tf`, `premium.tf`) listed in `main.tf`; addresses are unchanged.
- Repository tooling follows the `repository`, `terraform`, `git`, `gitlab` and `secrets` OpenSpec stores: exact tool pins in `mise.toml` (OpenTofu 1.13.2, tflint 0.64.0, terraform-docs 0.24.0, trivy 0.76.1, checkov 3.3.30, osv-scanner 2.7.0) with a `min_version`; pre-commit-terraform v1.109.1 with the validate, checkov and trivy hooks on `tofu`; pinned tflint ruleset; `.terraform-docs.yml` (`lockfile: false`, so the README shows the provider constraint), `.trivyignore.yaml` and `.gitattributes`.
- `CHANGELOG.md` is curated by hand under `## [Unreleased]`. The `changelog` mise task, which regenerated it, is replaced by `changelog-draft`, `changelog-verify` and `release` (`scripts/release.sh`, `scripts/changelog.sh`); `test` and `scan` tasks are added.
- Unit tests run on `mock_provider "gitlab"` and need no network or token.
- Examples keep the provider configuration in `examples/*/providers.tf` and take every site-specific value and secret as a variable. `examples/complete` no longer computes token expiry with `timestamp()`, which changed on every plan and replaced its tokens on every apply, and no longer hard-codes the `change-me` registry password.
- `.gitleaks.toml` uses the default rules without the blanket path allowlist: a full-history scan found nothing to exempt.
- CI follows the `gitlab` store: `workflow: rules`, interruptible jobs with timeouts and `needs:`, `validate:opentofu` and `validate:examples` on OpenTofu 1.11.14 and 1.13.2 with `tofu test`, `security:trivy` publishing a CycloneDX SBOM to the package registry on tags, `security:gitleaks` on merge request commits and on the weekly schedule, `verify:changelog` checking the tag is on `main` with a dated CHANGELOG section, and `create:release` publishing that section as notes once every job passed.
- Renovate opens one "toolchain" pull request for a `mise.toml` pin and its CI copies, and no longer prefixes commit subjects (`:semanticCommits` removed). The CI version variables were all mapped to the mise package before.

### Fixed

- The `gitlab_runners` and `gitlab_runners_by_type` outputs read `runner_id` and `status`, which `gitlab_user_runner` does not have, so any call declaring a runner failed at plan. `gitlab_runners[*].id` is the runner ID.
- Validations now accept exactly what the provider accepts, so a wrong value fails with the module's message instead of the provider's parse error. None of these values ever worked:
  - access-token `access_level` takes `no one` (not `no_one`) and also `planner` and `security_manager`;
  - access-token `scopes` follow each resource's list: `read_user`, `sudo` and `admin_mode` are rejected, `read_observability` and `write_observability` accepted, and the virtual registry scopes on group tokens only;
  - access-token `expires_at` is a `YYYY-MM-DD` date and deploy-token `expires_at` an RFC 3339 timestamp, the only forms each resource parses;
  - `gitlab_runners[*].group_id` and `project_id` are numeric IDs, not paths.

### Security

- CI variable values and pipeline schedule variable values reach the provider as sensitive values, so plan and apply output show `(sensitive value)` instead of the value. They still land in state: `SECURITY.md` now lists everything that does, with its mitigation.
- Nested CI variable and schedule variable values and webhook `token` / `signing_token` are redacted in plans the same way. They, and the tokens GitLab creates for the new resources (project deploy tokens, pipeline trigger tokens) and for nested group deploy, access and runner tokens, land in state; `SECURITY.md` lists each one with its rotation.

### Removed

- The general pre-commit hooks outside the canonical set (`no-commit-to-branch`, `detect-aws-credentials`, `check-added-large-files`, `check-case-conflict`, `check-executables-have-shebangs`, `check-toml`); gitleaks covers AWS credentials.
- The GitHub Actions workflows (`.github/`): the project is built on GitLab CI only.
- The `SHA256SUMS.txt` release asset: it was a job artifact that expired after a year. The signed tag and the SBOM replace it.
- `RELEASE.md` and `CONTRIBUTING.md`: the README Releasing and Contributing sections replace them (the old guides described pre-release and moved tags and conventional-commit prefixes, which the `git-history` and `git-commits` standards rule out).

## [12.0.0] - 2026-04-25

### Changed (breaking)

- `required_version` raised from `>= 1.10.7` to `>= 1.11.0`, and the provider from `gitlabhq/gitlab ~> 18.6` to `~> 18.11`. Upgrade: use OpenTofu 1.11 or later and run `tofu init -upgrade`.
- Every input is typed (`map(object({...}))` instead of `any`), so unknown attributes are rejected at plan time. Upgrade: remove attributes the module never read; the variable descriptions list the accepted fields and their defaults.

### Added

- Validation blocks on every input (variable keys and types, deploy and access token scopes, access levels, expiry formats, runner settings, cron) and a plan-level unit suite in `tests/main.tftest.hcl`.
- `examples/basic` and `examples/complete`, `SECURITY.md`, `TESTING.md`, `CODEOWNERS`, issue and merge request templates, Renovate, and gitleaks and trivy scanning in CI.

## [11.1.0] - 2025-12-25

### Added

- GitLab CI and GitHub Actions pipelines: pre-commit, vulnerability scanning, OpenTofu and TFLint validation, changelog verification and release creation on tags.

### Changed

- The changelog is generated by CI instead of a pre-commit hook.

## [11.0.0] - 2025-12-13
- Adds explicit key assignment to variables

Ensures that the 'key' attribute is explicitly assigned within the example variable definitions, improving clarity and consistency.

Removes redundant key assignment within local variables as it is implicitly defined.
## [10.0.0] - 2025-12-13
- Migrates CI/CD pipeline to GitLab

Migrates the CI/CD pipeline from GitHub Actions to GitLab CI, enabling release process handling via GitLab features.

Removes the previous GitHub Actions workflow and introduces corresponding GitLab CI configuration files.

Ensures .gitlab/global.yml ends with a newline.
- Migrates CI/CD pipeline to GitLab

Migrates the CI/CD pipeline from GitHub Actions to GitLab CI, enabling release process handling via GitLab features.

Removes the previous GitHub Actions workflow and introduces corresponding GitLab CI configuration files.
- fix(gitlab): Ensure .gitlab/global.yml ends with a newline
- Migrates CI/CD pipeline to GitLab

This commit migrates the CI/CD pipeline from GitHub Actions to GitLab CI.
The release process is now handled by GitLab CI, leveraging its features
for validation, release creation, and registry notification.

The previous GitHub Actions workflow is removed, and corresponding GitLab
CI configuration files are added to define the pipeline stages and jobs.
- Auto stash before rebase of "develop"
- ci: Optimize pre-commit job script by removing redundant commands
- ci: Update pre-commit job image to Ubuntu 24.04 LTS
- Update README to match CI terraform-docs output

The README provider version now reflects the version constraint from
versions.tf (~> 18.6) instead of the locked version (18.6.1).

This resolves the CI pre-commit failure where terraform-docs was
modifying the README during the pipeline run.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
- Relax gitlab provider version constraint

Updates the gitlab provider version constraint to allow for more flexibility in minor version upgrades.

This change removes the specific patch version, allowing updates within the 18.6.x range without requiring immediate code modifications.
- Enables pre-commit and simplifies tflint

Adds pre-commit installation to the CI pipeline to ensure consistent code formatting and quality.

Simplifies tflint execution by removing the redundant --chdir parameter.
- Updates terraform-docs version

Specifies the full version string for terraform-docs in mise.toml.

This ensures that the correct and intended version of
terraform-docs is used, avoiding potential compatibility
issues or unexpected behavior that might arise from
implicit version resolution.
- Updates pre-commit image version

Updates the pre-commit job image to a newer Ubuntu version.

This ensures the pre-commit hooks run in an environment with the latest tooling and security updates, potentially resolving compatibility issues and improving reliability.
- Updates dependencies

Updates the version of terraform-docs and removes the tilde from the gitlab provider version constraint.
- Updates gitlab provider version constraint.

Updates the gitlab provider version constraint in the README to allow for more flexible versioning.
This ensures compatibility with a wider range of minor and patch versions, while still maintaining a degree of control over the provider version used.
- Adds terraform-docs version check

Adds a check for the terraform-docs version during the pre-commit stage to ensure the tool is available and properly configured.
- Improves pre-commit job output

Enhances the pre-commit job by adding flags for increased verbosity, displaying diffs on failure, and forcing color output.

This aids in debugging and understanding pre-commit failures in the CI pipeline.
- Updates CI and migrates to OpenTofu

Refactors the CI configuration to use OpenTofu, providing
improved infrastructure management.

Configures entrypoints for both the main ToFu image and the
tflint image, ensuring proper execution of Terraform tasks.

Updates the tflint image and adds the chdir option to ensure
that linters execute in the correct directory.
- Updates CI configuration and migrates to OpenTofu

Refactors CI configuration, migrates to OpenTofu, and updates tooling versions.
This change enhances the CI pipeline's reliability and efficiency.

It includes updates to various tools, such as tflint and opentofu,
and modifies pre-commit configurations to leverage mise.
The migration to OpenTofu and Ubuntu 24.04 aims to improve
compatibility and maintainability.
- Refactors CI config and adds entrypoint to ToFu image

Removes redundant environment variables for GITHUB_TOKEN in the CI configuration, as they are no longer needed.

Adds an entrypoint to the OpenTofu image in the release configuration to ensure proper execution of scripts.
- Configures entrypoint for tflint image

Adds an entrypoint configuration to the tflint image definition.

This ensures proper execution of the linter within the GitLab CI environment.
- Updates tflint image and adds chdir option

Updates the tflint image version to a specific version to ensure consistent linting.

Adds the `--chdir` option to the tflint command to specify the working directory, ensuring that tflint correctly identifies and lints Terraform files within the project.
- Adds GH_TOKEN for mise authentication

Adds GH_TOKEN environment variable to pre-commit job for mise authentication.

This ensures that mise can properly authenticate with GitHub using either GITHUB_TOKEN or GH_TOKEN.
- Exposes GITHUB_TOKEN to pre-commit jobs

Allows mise to automatically use the GITHUB_TOKEN for pre-commit jobs, enabling access to GitHub resources.
- Adds python3 to pre-commit image

Ensures that the pre-commit job has python3 available.
This resolves issues where pre-commit hooks require python3.
- Removes unused tool versions

Removes versions for tools that are no longer in use, reducing clutter in the configuration file.
- Updates opentofu to v1.11

Updates the opentofu version used in the validation stage and mise configuration.

This ensures the project utilizes the latest features, improvements, and security patches provided by the new opentofu version.
- Migrates to OpenTofu and Ubuntu 24.04

Updates the CI configuration to use OpenTofu for infrastructure validation and Ubuntu 24.04 as the base image for pre-commit checks.

This migration ensures compatibility with the latest infrastructure-as-code tools and provides an up-to-date environment for static code analysis.
- Adds validate stage to pre-commit job

Configures the pre-commit job to run during the
validate stage in the CI/CD pipeline. This ensures
code quality checks are performed early in the
process.
- Improves pre-commit configuration and adds OSV scanning

Updates the pre-commit configuration to use a dedicated Python image and installs necessary dependencies, including the OSV scanner.

Adds OSV scanning to the pre-commit job to identify vulnerabilities.

Uses specific osv-scanner version and fixes the skipping logic.
- first commit

