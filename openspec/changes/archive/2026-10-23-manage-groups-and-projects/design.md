# Design

## Context

- See proposal.md (Why). The module today manages standalone CI/CD objects on existing groups and projects (8 resource types) and has no resource that creates a group or a project. Its 7 capability specs were archived on 2026-10-23 with 6 sandbox tasks still open; this change carries them.
- Provider facts, from the `gitlabhq/gitlab` 19.5.0 schema (no newer release exists):
  - `gitlab_group` cannot create top-level groups on gitlab.com. It takes `parent_id`, `archive_on_destroy`, `permanently_remove_on_delete` (subgroups only, must be applied before destroy) and a `default_branch_protection_defaults` block.
  - `gitlab_project` takes `namespace_id`, `default_branch`, `initialize_with_readme`, the merge request settings, `archive_on_destroy` and `permanently_delete_on_destroy`.
  - `gitlab_branch_protection` takes ownership of the default-branch protection GitLab creates by itself. On EE instances (gitlab.com is one) the provider documents `allowed_to_push` / `allowed_to_merge`, and `push_access_level` / `merge_access_level` for CE only.
  - None of the resources used has a write-only argument. Hook `token` and `signing_token` and every created token are sensitive and stored in state.
- OpenTofu facts checked locally: a validation can reference another variable (`parent_group_id` in `groups`), and nested `optional()` defaults resolve inside `map(object)` attributes.
- The `leminnov` namespace is on the Free plan, so the Premium resources can only be unit tested.

## Goals / Non-Goals

**Goals:**
- One call builds a whole subtree: groups up to 7 levels, projects, branches and protections, access, credentials and CI/CD objects. The standards' settings are the defaults, so the shortest call is the compliant one.
- Nested objects reuse the existing resources, rules and outputs; one set of validations and guardrails covers standalone and nested objects alike.
- Every new validation has a rejected-input run; the fixture proves an empty second plan for a created tree.

**Non-Goals:**
- Importing groups or projects that already exist. Callers use `import` blocks on the documented addresses.
- Self-managed CE protected branches; top-level groups; users; compliance and security policies.

## Decisions

### 1. Toolchain to the latest stable releases
- `mise.toml` pins:
  - `min_version = '2026.10.17'`;
  - opentofu 1.13.2, pre-commit 4.7.0, trivy 0.76.1, checkov 3.3.30, osv-scanner 2.7.0;
  - python 3.14.9 and node 24.22.1: latest patches of the current stable/LTS lines, since Python 3.15 and node 26 are not the LTS lines the toolchain runs on;
  - unchanged: git-cliff, terraform-docs, tflint, gitleaks, openspec (already latest).
- `.pre-commit-config.yaml`: pre-commit-terraform v1.109.3, with `# DEVIATION(terraform-repo-precommit): v1.109.3, the latest stable patch, above the store's v1.109.1 (maintainer decision: latest stable toolchain)`.
- CI copies:
  - `MISE_VERSION`, `TRIVY_VERSION` and `TOFU_VERSION`;
  - the `validate:*` matrix becomes 1.11.14 (still the latest 1.11 patch) and 1.13.2;
  - `alpine:3.24` (latest stable) replaces 3.22, and `ubuntu:26.04` (latest LTS) replaces 24.04 for the pre-commit job;
  - unchanged: release-cli v0.24.0, tflint v0.64.0, gitleaks v8.30.1 and `node:24-alpine` (already latest).
- Every tag is checked against its registry before commit.

### 2. Hierarchy as seven level blocks keyed by relative path
- `groups` is keyed by the path relative to `parent_group_id`. The level is the number of segments, and the parent is the key minus its last segment, so keys read like the tree and need no `parent` field.
- A resource instance cannot depend on another instance of its own block, so `groups.tf` holds `gitlab_group.level_1` to `gitlab_group.level_7`:
  - `level_1` has `parent_id = var.parent_group_id`;
  - `level_n` has `parent_id = tonumber(gitlab_group.level_<n-1>[<parent key>].id)`;
  - every block takes its arguments from one `local.group_args[each.key]`, so the seven bodies are one line each per argument.
- `local.group_ids` merges the seven levels. `local.project_namespace_ids` resolves each project to `parent_group_id` or its group's ID.
- Alternatives rejected:
  - a submodule per level: the same seven calls plus another module;
  - an explicit `parent` attribute: redundant with the path and allows inconsistent trees.

### 3. Nested objects declared inside groups and projects
- The shapes are `map(object({...}))` attributes with `optional()` defaults (see the specs). Each collection is flattened in `locals.tf` into a map keyed `"<owner key>:<item key>"`; for nested schedule variables, `"<schedule key>-<variable>"`.
- Collections that match an existing resource are merged into it with `merge(standalone, nested)`, so they share one block, its validations' semantics and its outputs: group and project variables, group deploy tokens, group and project access tokens, pipeline schedules and their variables, runners.
- Standalone keys may not contain `:`, which makes the two key spaces disjoint (owner keys are paths, which cannot contain `:`). The nested values reference `local.group_ids` and `local.project_ids`, unknown until apply, which `for_each` allows because the keys are known.
- New single blocks:
  - `gitlab_project.this`, `gitlab_branch.this`, `gitlab_branch_protection.this`, `gitlab_tag_protection.this`;
  - `gitlab_group_membership.this`, `gitlab_project_membership.this`, `gitlab_group_share_group.this`, `gitlab_project_share_group.this`;
  - `gitlab_project_deploy_token.this`, `gitlab_deploy_key.this`;
  - `gitlab_project_environment.this`, `gitlab_pipeline_trigger.this`, `gitlab_project_job_token_scopes.this`;
  - `gitlab_group_label.this`, `gitlab_project_label.this`, `gitlab_group_badge.this`, `gitlab_project_badge.this`, `gitlab_project_hook.this`;
  - Premium: `gitlab_group_hook.this`, `gitlab_project_approval_rule.this`, `gitlab_project_level_mr_approvals.this`, `gitlab_project_push_rules.this`, `gitlab_project_protected_environment.this`.
- `shared_with.group` and `job_token_allowlist` resolve keys of the module's own groups and projects through the same ID maps.

### 4. Protected branches sent as access-level sets, checked on gitlab.com
- On gitlab.com the module sends `allowed_to_push = [{ access_level = ... }]` and `allowed_to_merge = [{ access_level = ... }]`, the arguments the provider documents for EE instances, with `allow_force_push`, and `code_owner_approval_required` only when set (Premium).
- Settled by the owner-mode run on gitlab.com Free on 2026-10-23: the sets are accepted and read back unchanged (empty second plan), so no fallback. The fixture's empty second plan decides. If gitlab.com Free rejects the sets, or reads them back differently, the module switches to `push_access_level` / `merge_access_level` in this change; the spec does not change, since it states who may push and merge, not the argument.
- Protected tags use `create_access_level`.
- Defaults are computed in `locals.tf` when `protected_branches` is `null`: the default branch for maintainers, plus `develop` for developers when it is in `branches`. One protection resource per branch, because the provider takes over GitLab's own default-branch protection and two resources for one branch would fight.
- Groups also send `default_branch_protection_defaults` (maintainers push and merge, no force push, no developer initial push), so projects created later by people in the group start protected too.

### 5. Safe defaults mapped to the standards

| Default | Standard |
|---------|----------|
| `visibility = "private"` (groups and projects), `request_access_enabled = false` | `gitlab-project-settings` Visibility and defaults |
| `default_branch = "main"`, `branches = { develop = {} }` | `git-branching` Long-lived branches |
| `main` maintainers push/merge, `develop` developers, no force push | `gitlab-project-settings` Protected main / develop |
| `protected_tags = { "v*" = {} }` (maintainers) | `gitlab-project-settings` Protected tags |
| Pipelines must succeed, threads resolved, `squash_option = "default_on"`, source branch deleted, `merge_method = "merge"` | `gitlab-project-settings` Merge request settings |
| `project_creation_level = "maintainer"`, `subgroup_creation_level = "owner"` | `quality-security` Least privilege |
| `archive_on_destroy = true` | `quality-security` Safe defaults (destructive actions gated) |
| Deploy keys `can_push = false` with a required expiry; hooks with TLS verification | `quality-security`, `secrets-rotation` |

- Archiving keeps the path taken, so recreating the same key after a destroy fails until the archived object is removed by hand. This is documented as a known limitation.
- Callers who want deletion set `archive_on_destroy = false`. The fixture also sets the permanent-removal flags.

### 6. Premium features are inert unless set
- Premium collections default to `{}` and Premium objects to `null`, so `for_each` plans nothing and no Premium argument is sent: `approval_rules`, `protected_environments` and group `hooks` (`{}`); `merge_request_approvals` and `push_rules` (`null`); `code_owner_approval_required` (`null`).
- No tier detection: a Premium setting on a Free namespace fails at apply with GitLab's error, which names the feature.
- Unit runs prove the off state (no Premium resource or argument) and the on state (each planned with its defaults).

### 7. Secrets in nested objects
- Nested variable and schedule-variable values, hook `token` and `signing_token` go through `sensitive()` like the standalone values, with the same `DEVIATION(terraform-variables)` comment.
- New tokens join the sensitive outputs: project deploy tokens, pipeline trigger tokens, and the nested group deploy, access and runner tokens.
- `SECURITY.md` gets the new rows and rotation entries.

### 8. Guardrails extended in `checks.tf`
- The existing lists already read the merged locals, so nested variables and tokens are covered without new logic.
- Token lifetime also reads deploy keys.
- New checks: `public_visibility`, `protected_branch_force_push`, `webhook_ssl_verification` (project and group hooks) and `deploy_key_write_access`.
- Messages name `<input>["<key>"]` entries, never a value.

### 9. Files and validations
- `main.tf` keeps only the header index of the themed files:
  - `groups.tf`: the level blocks;
  - `projects.tf`: project, branches, protections, tags, environments, job token scopes;
  - `access.tf`: memberships, shares, deploy tokens and keys, access tokens, the existing `moved` block;
  - `ci.tf`: variables, schedules, runners, triggers;
  - `metadata.tf`: labels, badges, project hooks;
  - `premium.tf`.

  Moving a block between files changes no address.
- `variables.tf` stays the single input file, grouped by a comment header per theme (`terraform-variables` Ordering).
- Each rule of the specs is its own `validation` block with the spec's message, so each has a rejected-input run and the mutation check (delete one block, the suite fails) still applies.

### 10. Tests split by theme
- `tests/main.tftest.hcl` keeps the standalone suite. New files:
  - `tests/groups.tftest.hcl`: levels 1 to 7, the eighth rejected, missing parent, `parent_group_id` required, visibility nesting, defaults;
  - `tests/projects.tftest.hcl`: namespace, defaults, branches and protections, tags, merge settings;
  - `tests/nested.tftest.hcl`: every nested collection's keys, rejections and outputs, the `:` rule;
  - `tests/premium.tftest.hcl`: off by default, each feature on;
  - `tests/guardrails.tftest.hcl`: one run per check, plus the clean run.
- All use `mock_provider "gitlab"` with `mock_resource` defaults giving numeric IDs, so `tonumber()` on parent IDs resolves.

### 11. Integration fixture creates a small tree
`MODE=owner` adds, under the sandbox group:
- groups `it-<suffix>`, `it-<suffix>/team` and `it-<suffix>/team/svc`;
- projects `it-<suffix>/team/api` and `it-<suffix>/tools`, with the default branches and protections, a nested variable, deploy token, deploy key (generated by `ssh-keygen` in the work dir), label, badge, environment, trigger, hook to `https://example.com/it-<suffix>` with a signing token, and a job token allowlist naming the other project;
- `shared_with` from `api` to `team/svc`;
- a project membership for the least-privilege token's bot user, whose ID `run.sh` reads with `GET /personal_access_tokens/self` and that token;
- `archive_on_destroy = false` and the permanent-removal flags.

It asserts through the API:
- default branch `main`, branch `develop`, the protections of both and the `v*` tag protection;
- the merge settings;
- the full paths;
- the trigger token authenticating, the deploy key present, the allowlist content;
- an empty second plan.

`MODE=least` and `MODE=upgrade` are unchanged.

### 12. Delivery in five merge requests
1. Toolchain bump (group 1).
2. Hierarchy, projects and repository protection, with the file reorganisation (groups 2–3).
3. Nested access and CI/CD objects (group 4).
4. Labels, badges, webhooks, Premium and the new guardrails (groups 5–6).
5. Integration fixture, documentation and the carried-over sandbox tasks (groups 7–8).

Each is under the merge request size limit except the generated test runs, which are identified as such in the description.

## Risks / Trade-offs

- [`gitlab_project` reads back attributes in another form than sent (for example `squash_option`, topics order), giving a perpetual diff] → The fixture's empty second plan fails. The argument is normalised to the read-back form, or left unset when the default is the server's.
- [Protected-branch arguments on gitlab.com Free (decision 4)] → Settled by the fixture with a fallback named in advance. Self-managed CE stays a documented limitation.
- [Archive-by-default leaves paths taken after destroy] → Documented, with the opt-out. The fixture opts out so the sandbox stays clean.
- [gitlab.com delays group and project deletion] → `permanently_remove_on_delete` and `permanently_delete_on_destroy` are applied at creation in the fixture. The run suffix avoids collisions if a deletion is still pending.
- [Premium code paths never run against a server] → Unit-tested on and off, and labelled untested in the README compatibility table.
- [Seven duplicated level blocks] → One shared argument local, and a unit run per level that fails if a block drifts.
- [The merged resources make a wrong nested input fail with a standalone-style message] → Nested validations live on `groups` / `projects` with their own messages, so the error names the nested attribute.

## Migration Plan

- No consumer migration: v13.0.0 is unreleased, the new inputs default to empty, and existing addresses do not move (moving between files keeps them).
- Deliver the five merge requests in order into `develop`. Once the sandbox exists, run `mise run test-integration`; fill the role and compatibility tables; then archive this change and cut `v13.0.0` from `main`.
- Rollback: revert the merge commits. Nothing has been released.
