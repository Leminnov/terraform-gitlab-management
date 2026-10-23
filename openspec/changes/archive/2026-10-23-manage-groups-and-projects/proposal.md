# Proposal

## Why

The module only configures groups and projects that already exist. Consumers still create the group tree, the projects, their default branch, branch and tag protection, merge request settings, memberships and credentials by hand, so the `gitlab-project-settings` and `git-branching` standards are applied unevenly. The toolchain has also fallen behind its latest stable releases. v13.0.0 is not released, so this lands in the same major.

## What Changes

Toolchain, pinned to the latest stable releases (patch-level, no contract change):
- Tool pins: OpenTofu 1.13.2, pre-commit 4.7.0, trivy 0.76.1, checkov 3.3.30, osv-scanner 2.7.0, mise 2026.10.17, and the latest patches of the current runtime lines: Python 3.14.9 and node 24.22.1 (LTS).
- pre-commit-terraform v1.109.3, above the v1.109.1 the terraform store pins (`DEVIATION(terraform-repo-precommit)`).
- The CI images that copy those pins, and the latest stable base images.
- The provider (`gitlabhq/gitlab` 19.5.0) and the store refs are already the latest releases and stay.

Hierarchy and projects (new inputs, semver **minor** within the unreleased v13.0.0):
- `parent_group_id`: the existing group the tree is created under. On gitlab.com the provider cannot create top-level groups.
- `groups`: keyed by the path relative to that parent (`platform`, `platform/infra`, ..., up to 7 levels). Each level is its own resource block, since a group cannot depend on another instance of the same block. Several roots and siblings are allowed.
- `projects`: keyed the same way (`platform/infra/api`), in a created group or directly under the parent.
- Safe defaults follow `gitlab-project-settings` and `git-branching`:
  - private visibility, access requests off;
  - project creation by maintainers, subgroup creation by owners;
  - default branch `main`, initialised with a README, plus a `develop` branch;
  - `main` protected for maintainers and `develop` for developers, both without force push; `v*` tags protected for maintainers;
  - merges only on a green pipeline with all threads resolved; squash encouraged; source branch deleted; merge commits.
- Groups and projects are archived instead of deleted on destroy unless the caller opts out (`quality-security`: destructive actions gated).

Nested objects, each declared inside the group or project it belongs to:
- Groups and projects: CI/CD variables, deploy tokens, access tokens, members (`user_id` and level), sharing with a created or existing group, labels, badges and runners.
- Projects also: deploy keys, pipeline schedules, pipeline triggers, environments, webhooks (secret and signing tokens) and the CI/CD job token inbound allowlist.
- Variables, group deploy tokens, access tokens, schedules and runners reuse the existing resources and outputs, keyed `"<group or project key>:<item key>"`. The keys of the existing standalone inputs therefore must not contain `:` (new validation).

Premium and Ultimate features, optional and off by default (empty or null, only sent when set): project approval rules, merge request approval settings, push rules, protected environments, code-owner approval on protected branches, and group webhooks. They cannot be tested on the Free sandbox.

Guardrails and contract:
- New `check` warnings:
  - public visibility (`gitlab-project-settings`: public is an explicit, reviewed decision);
  - force push allowed on a protected branch;
  - a webhook with SSL verification off;
  - a deploy key with write access.
- The existing checks also cover nested variables, tokens and deploy keys.
- New outputs `groups`, `projects`, `project_deploy_tokens` and `pipeline_trigger_tokens`; the existing token outputs also carry the nested tokens.

What lands in state, since provider 19.5 has no write-only argument for any of these:
- nested variable values;
- webhook secret and signing tokens;
- every created token: project deploy tokens, nested group deploy tokens, access tokens, runner and pipeline trigger tokens.

Values sent to the provider are wrapped in `sensitive()` as today, and `SECURITY.md` lists the new rows. Deploy keys are public keys and carry no secret.

Carried over from the archived `2026-10-23-adopt-store-standards`:
- the sandbox set-up;
- the integration run (owner, least privilege, upgrade from v12);
- the minimum-role and compatibility tables;
- a green `develop` pipeline that includes the integration job.

Out of scope:
- top-level group creation (impossible on gitlab.com; on self-managed, pass the top-level group as `parent_group_id`);
- users and service accounts;
- compliance frameworks and security policies;
- project mirroring, forks and templates;
- protected branches on GitLab CE instances (the provider needs different arguments there).

## Capabilities

### New Capabilities
- `groups`: the group hierarchy under `parent_group_id`, its path rules, depth limit, settings, safe defaults and archive-on-destroy.
- `projects`: projects in the hierarchy, their settings, merge request defaults and archive-on-destroy.
- `repository-protection`: default branch, extra branches, protected branches and protected tags of created projects.
- `access-management`: user memberships and group sharing on created groups and projects.
- `deploy-keys`: project deploy keys with a required expiry and a read-only default.
- `project-ci-settings`: environments, pipeline triggers and the CI/CD job token inbound allowlist of created projects.
- `labels-and-badges`: group and project labels and badges.
- `webhooks`: project webhooks.
- `premium-features`: approval rules, merge request approval settings, push rules, protected environments, code-owner approval and group webhooks, all off by default.

### Modified Capabilities
- `module-contract`: nested-object keys, the `:` rule on standalone keys, the extended output set and the additional state-held secrets.
- `ci-variables`: variables declared inside created groups and projects.
- `deploy-tokens`: deploy tokens inside created groups, and project deploy tokens.
- `access-tokens`: access tokens inside created groups and projects.
- `pipeline-schedules`: schedules inside created projects.
- `runners`: group and project runners inside created groups and projects.
- `security-guardrails`: the new checks, and the existing ones extended to nested objects.

## Impact

- Consumers of v12: nothing beyond the v13 upgrade notes already written. Existing standalone inputs keep their shape; only keys containing `:` are newly rejected.
- Provider and server:
  - `gitlabhq/gitlab ~> 19.5` (unchanged).
  - gitlab.com, any tier, for the Free resources. Premium features need a Premium or Ultimate namespace.
  - Which protected-branch arguments the provider accepts on gitlab.com Free (an EE instance) is settled by the integration fixture (design decision 4).
- Files:
  - New `groups.tf`, `projects.tf`, `access.tf`, `ci.tf`, `metadata.tf` and `premium.tf`. Existing resources move into them with unchanged addresses; `main.tf` keeps the index.
  - Also touched: `variables.tf`, `locals.tf`, `outputs.tf`, `checks.tf`, `tests/`, `tests/integration/`, `examples/complete`, README, `SECURITY.md`, `TESTING.md`, `CHANGELOG.md`, `mise.toml`, `.gitlab/*`, `.pre-commit-config.yaml`, `renovate.json`, `AGENTS.md` and `openspec/config.yaml`.
- Sandbox: the owner token must be able to create subgroups and projects under the sandbox group. The fixture deletes them for good (archive off, permanent removal on), since the module's safe default would only archive them.
