# Tasks

## 1. Toolchain to the latest stable releases (MR 1)

- [ ] 1.1 `mise.toml` (design 1):
  - `min_version = '2026.10.17'`;
  - opentofu 1.13.2, pre-commit 4.7.0, python 3.14.9, trivy 0.76.1, checkov 3.3.30, osv-scanner 2.7.0, node 24.22.1.

  Verify `mise install` succeeds and `mise ls --current` shows every pin.
- [ ] 1.2 `.pre-commit-config.yaml`: pre-commit-terraform v1.109.3 with the `DEVIATION(terraform-repo-precommit)` comment. Verify `pre-commit run -a` passes twice in a row (the second run changes nothing).
- [ ] 1.3 CI copies: `MISE_VERSION`, `TRIVY_VERSION` and `TOFU_VERSION` in `.gitlab/global.yml`; matrix `["1.11.14", "1.13.2"]` in `.gitlab/release.yml`; `alpine:3.24` in `release.yml` and `integration.yml`; `ubuntu:26.04` in `pre-commit.yml`. Verify every image tag with the registry manifest API, that each `*_VERSION` equals its `mise.toml` pin, and that the Renovate custom managers still match (the regex dry run from adopt-store-standards 1.8).
- [ ] 1.4 CHANGELOG `[Unreleased]` Changed entry for the toolchain. Verify `tofu fmt -check -recursive`, `tofu validate`, `mise run test`, `mise run scan` and `pre-commit run -a` pass, and that the MR 1 pipeline is green.

## 2. Group hierarchy and file layout (MR 2)

- [ ] 2.1 Move the existing resources into themed files (`access.tf`, `ci.tf`) and leave `main.tf` with the header index (design 9). Verify `tofu validate`, `mise run test` (50 runs), and that `tofu state list` addresses are unchanged: plan the unit fixtures before and after and compare the planned addresses.
- [ ] 2.2 `variables.tf`: `parent_group_id` and the `groups` object (settings, defaults and nested collection shapes from the specs), with one validation per `groups` spec rule:
  - parent required;
  - segments and path format;
  - parent declared;
  - visibility values and nesting;
  - creation levels.

  Verify `tofu validate`.
- [ ] 2.3 `groups.tf`: `gitlab_group.level_1` to `level_7` from `local.group_args` and `local.groups_by_level`, with `default_branch_protection_defaults`, `archive_on_destroy` and `permanently_remove_on_delete`. `locals.tf`: `group_ids`. `outputs.tf`: `groups`. Verify `tofu validate` and `tflint --recursive`.
- [ ] 2.4 `tests/groups.tftest.hcl` with mock IDs:
  - one run per level 1 to 7, asserting the address `gitlab_group.level_<n>["<key>"]` and its parent;
  - several roots;
  - name defaulted;
  - the defaults;
  - one rejected-input run per `groups` validation;
  - `groups` output keys.

  Verify `mise run test`, and that deleting any new validation block makes the suite fail (mutation check).

## 3. Projects and repository protection (MR 2)

- [ ] 3.1 `variables.tf`: the `projects` object, with one validation per `projects` and `repository-protection` spec rule:
  - path and namespace;
  - visibility values and nesting;
  - merge method;
  - squash option;
  - branches needing a README;
  - protected-branch and tag access levels.

  Verify `tofu validate`.
- [ ] 3.2 `projects.tf`: `gitlab_project.this` (namespace from `local.project_namespace_ids`, merge settings, archive flags), `gitlab_branch.this`, `gitlab_branch_protection.this` (access-level sets per design 4, defaults from `locals.tf` when `protected_branches` is null) and `gitlab_tag_protection.this`. `outputs.tf`: `projects`. Verify `tofu validate` and `tflint --recursive`.
- [ ] 3.3 `tests/projects.tftest.hcl`:
  - namespace under a created group and under the parent;
  - every default from the specs (private, `main`, README, `develop`, protections for `main` and `develop`, `v*`, merge settings);
  - `protected_branches` replacing the defaults;
  - the trunk-based case;
  - `branches = {}`;
  - one rejected-input run per validation;
  - `projects` output keys.

  Verify `mise run test` and the mutation check.
- [ ] 3.4 `examples/complete`: a tree of two levels with a project per level, using the defaults. Example README updated (Owner role on the parent group). CHANGELOG Added entries. README Features and Usage. Verify `tofu validate` in the example, that it plans without warnings under a mock (adopt-store-standards 6.3 method), and `pre-commit run -a`.

## 4. Access and CI/CD objects nested in groups and projects (MR 3)

- [ ] 4.1 The `:` rule on the seven standalone inputs. Verify one rejected-input run per input in `tests/main.tftest.hcl`, then `mise run test`.
- [ ] 4.2 Nested collections merged into the existing resources: variables, group deploy tokens, group and project access tokens, pipeline schedules and their variables, runners. Their validations go on `groups` / `projects` with the messages from the specs. Verify `tofu validate`, and that the standalone runs in `tests/main.tftest.hcl` still pass unchanged.
- [ ] 4.3 New resources:
  - project deploy tokens and output `project_deploy_tokens`;
  - deploy keys;
  - memberships and shares (group and project);
  - environments;
  - pipeline triggers and output `pipeline_trigger_tokens`;
  - job token scopes;

  each with the spec validations. Nested values and hook tokens go through `sensitive()`. Verify `tofu validate` and `tflint --recursive`.
- [ ] 4.4 `tests/nested.tftest.hcl`:
  - every nested collection's keys `"<owner>:<item>"`;
  - `issensitive()` on nested values;
  - the shared outputs holding standalone and nested keys;
  - one rejected-input run per nested validation;
  - `shared_with` and `job_token_allowlist` resolving created keys.

  Verify `mise run test` and the mutation check.
- [ ] 4.5 `SECURITY.md`: rows for project deploy tokens, trigger tokens and nested secrets, and the rotation entries. `examples/complete`: a nested variable, a deploy token, a deploy key, an environment and a membership. CHANGELOG. Verify `pre-commit run -a`, and that the example plans without warnings.

## 5. Labels, badges and webhooks (MR 4)

- [ ] 5.1 Group and project labels and badges, and project hooks (`sensitive()` on `token` and `signing_token`), with the spec validations, in `metadata.tf`. Verify `tofu validate`.
- [ ] 5.2 Unit runs for keys, the defaults (push events on, TLS verification on), redaction of the hook tokens, and one rejected-input run per validation. Verify `mise run test` and the mutation check.

## 6. Premium features and guardrails (MR 4)

- [ ] 6.1 `premium.tf`: approval rules, merge request approval settings, push rules, protected environments and group hooks; `code_owner_approval_required` only when set. Validations from the `premium-features` spec. Verify `tofu validate`.
- [ ] 6.2 `tests/premium.tftest.hcl`: a run with no Premium setting asserting none of the five resources and no `code_owner_approval_required`; a run per feature asserting its defaults; one rejected-input run per validation. Verify `mise run test`.
- [ ] 6.3 `checks.tf`: `public_visibility`, `protected_branch_force_push`, `webhook_ssl_verification`, `deploy_key_write_access`, and deploy keys added to `token_lifetime`. `tests/guardrails.tftest.hcl`: one run per new check, the nested cases of the three existing checks, and the clean run. Verify `mise run test`, the check mutation (neutralise each condition, its run fails) and that `examples/complete` plans without warnings.
- [ ] 6.4 README Security Considerations (new warnings) and Known Limitations (top-level groups, archive keeps the path, CE protected branches, Premium untested); CHANGELOG. Verify `pre-commit run -a`.

## 7. Integration fixture and sandbox (MR 5, carries adopt-store-standards 7.1, 7.3, 7.4, 7.5)

- [ ] 7.1 Maintainer prerequisite, asked for and not done by the agent (carried 7.1):
  - a sandbox group and project on gitlab.com;
  - protected, masked CI variables `GITLAB_TOKEN` (Owner, able to create subgroups and projects) and `GITLAB_TOKEN_LEAST` (Maintainer), both expiring within one year;
  - `SANDBOX_GROUP_ID` and `SANDBOX_PROJECT_ID`.

  Verify read-only with `glab api projects/:id/variables` that the four keys exist, protected and masked where secret.
- [ ] 7.2 Extend `tests/integration/main.tf` and `run.sh` `MODE=owner` with the tree of design 11 (generated deploy key, member ID from the least-privilege token, permanent-removal flags) and its API assertions. Verify `bash -n`, shellcheck, and a mock-provider plan of the fixture in both modes without warnings.
- [ ] 7.3 Run `mise run test-integration` against the sandbox with the maintainer's tokens passed per command, only when the user asks (carried 7.3). All three modes pass. Fold any read-back finding into the code, its test and its spec in this change, including the protected-branch argument choice of design 4.
- [ ] 7.4 After MR 5 merges, the `develop` pipeline runs `test:integration:gitlab` green (carried 7.4).
- [ ] 7.5 Docs from the run (carried 7.5), checked by running the documented commands:
  - `SECURITY.md` minimum role per resource (from `MODE=least`) and the Owner requirement for the tree;
  - the README compatibility row: OpenTofu, provider 19.5.0, gitlab.com, what was applied, Premium untested;
  - `TESTING.md` for the tree.

## 8. Documentation and project instructions (MR 5)

- [ ] 8.1 README: Features, Usage (tree example), Requirements and Known Limitations updated for groups and projects. Verify `pre-commit run -a` leaves the README stable.
- [ ] 8.2 `AGENTS.md` and `openspec/config.yaml`:
  - the themed files and the 16 capability directories;
  - the nested-key rule;
  - Premium off by default;
  - the toolchain deviation.

  Verify `mise run spec-validate`, and that `openspec instructions proposal --change manage-groups-and-projects --json` shows the new context.
- [ ] 8.3 CHANGELOG `[Unreleased]` complete for this change: Added (hierarchy, projects, nested objects, Premium options, guardrails, outputs), Changed (toolchain, file layout), and the `:` rule under Changed (breaking) with its consumer edit. Verify each proposal bullet has an entry.

## 9. Integration checks (carries adopt-store-standards 9.1, 9.3)

- [ ] 9.1 Full local run, all passing, with the output reported as-is (carried 9.1): `tofu fmt -check -recursive`, `tofu init -backend=false && tofu validate`, `tflint --recursive`, `mise run test`, `mise run scan`, `pre-commit run -a`, `mise run spec-validate` and `mise run test-integration`.
- [ ] 9.2 Audit every store spec again. Each is met or covered by a `DEVIATION(<spec-id>)`; list them in the summary. Expected: `terraform-variables`, `repository-versioning`, `terraform-outputs`, `repository-gitlab-ci`, `terraform-repo-precommit`, and the GitLab project settings left to the maintainer.
- [ ] 9.3 The five MRs are merged into `develop` in order, each with the template filled and a green pipeline, and the `develop` pipeline, including `test:integration:gitlab`, is green (carried 9.3).

## Workflow follow-up

- Archive this change after the last MR merges and the sandbox run passes (`/openspec-archive-change`).
- Merge `develop` into `main` and cut `v13.0.0` with `mise run release major --push`; check that the tag pipeline creates the release from the CHANGELOG section.
