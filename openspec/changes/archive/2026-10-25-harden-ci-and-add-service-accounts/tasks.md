# Tasks

## 1. Service accounts and memberships (design 1)

- [x] 1.1 `variables.tf`:
  - the standalone `service_accounts` input (`group`, `name`, `username`, `email`, `tokens`);
  - `service_accounts` on the `groups` and `projects` objects;
  - `members[*].user_id` optional, plus `members[*].service_account`;
  - validations with the spec messages:
    - group non-empty;
    - keys without `:`;
    - token scopes, exactly-one expiry or rotation, expiry date format;
    - members exactly-one;
    - invitation scope (`groups` reads only `var.service_accounts`).

  Verify `tofu validate`.
- [x] 1.2 `service_accounts.tf` and `locals.tf`:
  - `gitlab_group_service_account.this` (standalone and nested groups) and `gitlab_project_service_account.this`, both with `skip_wait_for_deletion = true`;
  - the two token resources keyed `"<account key>:<token>"`;
  - memberships resolving `service_account` to `service_account_id`.

  `outputs.tf`: `service_accounts` and the sensitive `service_account_tokens`. `main.tf`: header lists `service_accounts.tf`. Verify `tofu validate` and `tflint --recursive`.
- [x] 1.3 `tests/service_accounts.tftest.hcl` with mock IDs:
  - keys at the three levels;
  - display name default;
  - rotation sending no `expires_at`;
  - membership `user_id` from the account;
  - outputs, with the token output sensitive;
  - one rejected-input run per new validation, valid in every other respect.

  Verify `mise run test` and the mutation check: deleting each new validation fails the suite.
- [x] 1.4 `SECURITY.md`:
  - rows for service-account tokens in state;
  - the rotation entry (rotate with a top-level group Owner token on gitlab.com);
  - least-privilege note on scoping bots by membership.

  `examples/complete`: a project service account with a rotating token and its membership. CHANGELOG Added. Verify `pre-commit run -a` and that `examples/complete` plans on a mock provider without warnings.

## 2. Token rotation on access tokens (design 2)

- [x] 2.1 `gitlab_group_access_token` and `gitlab_project_access_token` inputs and the nested `access_tokens`:
  - `expires_at` optional plus `rotation_configuration`;
  - the exactly-one validation per input;
  - the date-format validations accept null;
  - `access.tf` sends `rotation_configuration` and `expires_at = null` when rotating.

  Verify `tofu validate`.
- [x] 2.2 Unit runs in `tests/main.tftest.hcl` (standalone) and `tests/nested.tftest.hcl` (nested): a rotating token plans with the configuration, and one rejected run each for neither, both, and a window equal to the lifetime. Verify `mise run test` and the mutation check.
- [x] 2.3 README input notes unchanged (terraform-docs regenerates them). CHANGELOG Added: rotation. Verify `pre-commit run -a` leaves the README stable.

## 3. Hardened CI settings, freeze periods, secure files, catalog (design 3, 4)

- [x] 3.1 `variables.tf`:
  - the `projects[*].ci` object with `hardening_enabled` (default `false`), the seven security fields without defaults (hardened values applied in `locals.tf`), and the null optional fields (Premium fields included, wired in group 7);
  - `groups[*].shared_runners_setting`;
  - `freeze_periods`, `secure_files`, `cicd_catalog`;
  - validations from the specs: override role, auto-cancel, timeout, git depth, retention, sub claim, shared runner setting, freeze cron, secure file names and content, catalog description.

  Verify `tofu validate`.
- [x] 3.2 `projects.tf` sends the `ci` fields. `groups.tf` sends `shared_runners_setting` on all seven levels. `ci.tf`: `gitlab_project_freeze_period`, `gitlab_project_secure_file` (`sensitive()` and the `DEVIATION(terraform-variables)` comment), `gitlab_project_cicd_catalog`. Verify `tofu validate` and `tflint --recursive`.
- [x] 3.3 `tests/ci.tftest.hcl`:
  - a bare project sending none of the seven settings;
  - `hardening_enabled = true` sending each hardened value;
  - an explicit value winning over hardening, and one set without it;
  - null optional fields not sent;
  - the group runner setting;
  - a freeze period in UTC;
  - secure file content `issensitive()`;
  - catalog;
  - one rejected-input run per new validation.

  Verify `mise run test` and the mutation check.
- [x] 3.4 `SECURITY.md` row for secure file content and its rotation. CHANGELOG Added: opt-in CI hardening, freeze periods, secure files, catalog, group runner setting. `examples/complete`: a hardened project with a freeze period and pipeline retention. Verify `pre-commit run -a` and the example plan without warnings.

## 4. Cross-project runners and deploy keys (design 5)

- [x] 4.1 `projects[*].enabled_runners` and `enabled_runner_ids`, and `enabled_deploy_keys` and `enabled_deploy_key_ids`, with their validations (unlocked runner of another created project; deploy key of another created project). Add `gitlab_project_runner_enablement.this` to `ci.tf` and `gitlab_deploy_key_enable.this` (`can_push = false`) to `access.tf`. Verify `tofu validate`.
- [x] 4.2 Unit runs in `tests/nested.tftest.hcl`: keys `"<pk>:<source key>"` and `"<pk>:<id>"`, the runner ID and deploy key ID resolved, `can_push = false`, and the rejected runs (own runner, locked runner, group runner, unknown key; own deploy key, unknown key). Verify `mise run test` and the mutation check.
- [x] 4.3 CHANGELOG Added. Verify `pre-commit run -a`.

## 5. Registry protection (design 6)

- [x] 5.1 `package_protection_rules`, `container_protection_rules`, `container_tag_protection_rules` and `container_expiration_policy` on `projects`, with their validations. `registry.tf` holds the three rule resources: upper-cased tag levels; null levels when `immutable`; repository path prefixed with `path_with_namespace`. The dynamic `container_expiration_policy` block goes on `gitlab_project`. `main.tf` header. Verify `tofu validate` and `tflint --recursive`.
- [x] 5.2 `tests/registry.tftest.hcl`:
  - keys;
  - push default `maintainer`;
  - delete level not sent when null;
  - path prefix;
  - upper-cased tag levels;
  - cleanup defaults, with no block when null;
  - one rejected run per validation.

  Verify `mise run test` and the mutation check.
- [x] 5.3 CHANGELOG Added. `examples/complete`: a package rule and a protected container tag. Verify `pre-commit run -a` and the example plan.

## 6. Repository files and Kubernetes agents (design 7, 8)

- [x] 6.1 `projects[*].files` and `projects[*].kubernetes_agents`, with their validations: relative path, encoding, default branch required, agent name, `ci_access` keys, no hand-written agent config. In `files.tf`: `gitlab_repository_file.managed` and `.seeded` (seeded with `ignore_changes`), and `gitlab_branch.this` `depends_on` both. In `ci.tf`: `gitlab_cluster_agent.this` and `gitlab_cluster_agent_token.this`, plus the agent `config.yaml` merged into the managed files. `outputs.tf`: the sensitive `kubernetes_agent_tokens`. Verify `tofu validate` and `tflint --recursive`.
- [x] 6.2 `tests/files.tftest.hcl`:
  - managed and seeded keys;
  - branch equal to the default branch;
  - `overwrite_on_create`;
  - the agent config file content (`yamldecode` of the planned content with mock full paths);
  - no config file for an empty `ci_access`;
  - the token output sensitive;
  - one rejected run per validation.

  Verify `mise run test` and the mutation check.
- [x] 6.3 `SECURITY.md` row for agent tokens and their rotation. README Known Limitations: commits to the default branch versus branch protection and push rules; one commit per file; text-only secure files. CHANGELOG Added. `examples/complete`: a managed `CODEOWNERS`, a seeded file and an agent. Verify `pre-commit run -a` and the example plan.

## 7. Premium and Ultimate additions (design 9)

- [x] 7.1 `projects[*].target_branch_rules` and `gitlab_project_target_branch_rule.this` in `premium.tf`; the Premium `ci` fields sent only when set; `immutable` on tag rules. Add the merge-train, cancellation-role and target-branch validations. Verify `tofu validate`.
- [x] 7.2 `tests/premium.tftest.hcl`: the off-by-default run extended (no target branch rule, no Premium `ci` argument, no immutable rule); one run per feature; one rejected run per validation. Verify `mise run test` and the mutation check.
- [x] 7.3 README Known Limitations: Premium list extended. CHANGELOG Added. Verify `pre-commit run -a`.

## 8. Guardrails (design 10)

- [x] 8.1 `checks.tf`: `public_jobs` and `job_token_push`; `token_lifetime` extended to service-account tokens and `rotation_configuration.expiration_days`. Verify `tofu validate`.
- [x] 8.2 `tests/guardrails.tftest.hcl`: one run per new check, the two new `token_lifetime` cases, and the clean run extended with service accounts, rotation and the default CI settings. Verify `mise run test` and the check mutation (neutralise each condition and drop each source line; the suite fails).
- [x] 8.3 README Security Considerations lists the new warnings. CHANGELOG Added. Verify `pre-commit run -a` and that `examples/complete` raises no warning.

## 9. Integration fixture against the sandbox (design 12)

- [x] 9.1 `tests/integration/main.tf` owner mode: the objects of design 12. `run.sh`: the API assertions of design 12 and the seeded-file edit followed by a third empty plan. Verify `bash -n`, ShellCheck, and a mock-provider plan of the fixture in owner, least and Free modes without warnings.
- [x] 9.2 Run `MODE=owner tests/integration/run.sh` against `leminnov/test` (maintainer approved real runs for this change). Fold any read-back finding into the code, its unit test and its spec. Verify PASS, then that nothing suffixed with the run is left in `leminnov/test`.
  - 2026-10-25, `MODE=owner` against `leminnov/test`: PASS on the first run. Service accounts (existing subgroup, created subgroup, project) read `team/api` through their memberships; hardened CI settings read back; freeze period, secure file, runner and deploy-key enablement, package and container repository rules, CODEOWNERS on `main` and `develop`, and the agent with its `config.yaml` and `glagent-` token were all present; the second plan and the plan after the seeded-file edit were empty. Nothing was left in `leminnov/test` afterwards.
- [x] 9.3 One-off upgrade check: apply a small v13.0.0 tree to the sandbox, plan it with this branch, then destroy. Verify the plan is empty, and report it here.
  - 2026-10-25: a tree applied with `v13.0.0` (group, project with a variable and a label) then planned with this branch: `No changes. Your infrastructure matches the configuration.` (exit 0), then destroyed.
- [x] 9.4 `TESTING.md` (what owner mode now proves) and the README compatibility row (server floor 18 for service accounts; what was applied). Verify `pre-commit run -a`.

## 10. Project instructions (AGENTS.md, OpenSpec config)

- [x] 10.1 `AGENTS.md` and `openspec/config.yaml`: the three new themed files, the 20 capability directories, service-account keys and scope, and opt-in CI hardening. Verify `mise run spec-validate` and that `openspec instructions specs --change harden-ci-and-add-service-accounts --json` shows the new context.

## 11. Integration checks and delivery

- [x] 11.1 Full local gate, all passing, output reported as-is: `tofu fmt -check -recursive`, `tofu init -backend=false && tofu validate`, `tflint --recursive`, `mise run test`, `mise run scan`, `pre-commit run -a` and `mise run spec-validate`.
- [x] 11.2 Audit the touched store specs (`terraform-variables`, `terraform-outputs`, `terraform-security`, `terraform-versioning`, `terraform-testing`, `secrets-rotation`, `gitlab-project-settings`). Each is met or covered by a `DEVIATION(<spec-id>)`; list them in the summary.
  - Audit 2026-10-25: `terraform-variables` (description, type and validations on every new field; secure file contents through `sensitive()` with `DEVIATION(terraform-variables)`), `terraform-outputs` (the three new outputs described, the two token outputs sensitive; order fixed to follow the themed files), `terraform-security` (stored secrets listed in `SECURITY.md`; two new checks), `terraform-versioning` (minor: new inputs with defaults that change nothing; `members[*].user_id` and access-token `expires_at` relaxed to optional; v13.0.0 state plans empty), `terraform-testing` (one rejected run per validation, mutation-checked; integration owner run), `terraform-code-style` (no `try()`; `depends_on` and the dynamic block after the arguments), `secrets-rotation` (expiry or rotation required, rotation rows in `SECURITY.md`) and `gitlab-project-settings` (defaults unchanged). Deviations: `terraform-variables` (CI variable, schedule variable, secure file and webhook values through `sensitive()`), `terraform-outputs` (kept v12 output names), `repository-versioning` (outputs removed in v13.0.0), `repository-gitlab-ci` (no osv-scanner CI variable; `ubuntu:26.04`), `terraform-repo-precommit` (v1.109.3).
- [x] 11.3 One merge request into `develop` with a green pipeline, merged. Then the `develop` pipeline, including `test:integration:gitlab` (owner and upgrade), is green.
  - MR !10 pipeline 2986293046 green, merged. The `develop` pipeline 2986298300 then failed on a non-empty second plan: provider 19.5 read the shared runner's `project_id` as `tools`. Fixed in MR !11 (pipeline 2986321568 green, merged). The `develop` pipeline 2986327253 is green, with `test:integration:gitlab` owner PASS, upgrade PASS and least skipped (no `GITLAB_TOKEN_LEAST`).

## Workflow follow-up

- Archive this change after the merge (`/openspec-archive-change`), syncing the 4 new and 8 modified specs.
- Merge `develop` into `main` and cut v13.1.0 with `mise run release minor --push`, then check that the tag pipeline creates the release.
