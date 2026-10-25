# Design

## Context

- See `proposal.md` (Why). v13.0.0 manages a group and project tree:
  - resources in themed files listed in `main.tf`;
  - nested objects keyed `"<owner key>:<item key>"`, merged into the standalone resource maps in `locals.tf`;
  - every validation on `variables.tf`;
  - guardrails as `check` blocks in `checks.tf`.
- The provider floor stays `gitlabhq/gitlab ~> 19.5`. Every resource below exists in 19.5.0; the newest are `gitlab_project_service_account_access_token` (19.3), `gitlab_project_container_tag_protection` (18.11) and `gitlab_project_cicd_catalog` (18.8).
- The module makes no API call (`AGENTS.md`), so anything the provider cannot express stays out. Fine-grained CI/CD job token permissions (GitLab 18.3) are the case here: provider 19.5 has no argument for them.
- The test namespace `leminnov/test` is on gitlab.com Free, and its owner run creates a three-level tree (`tests/integration/`).
- GitLab facts checked against the GitLab and provider sources:
  - Subgroup and project service accounts are GA on Free since GitLab 18.
  - Provider 19.5's "must be a top level group" note on `gitlab_group_service_account` is documentation only: its code has no such check.
  - Service accounts have no access until invited as members.
  - Package protection takes types `cargo`, `conan`, `generic`, `helm`, `maven`, `npm`, `nuget`, `pypi`, `terraform_module`, a push level of `maintainer`, `owner` or `admin`, and a delete level of `owner` or `admin`.
  - Container repository patterns must start with the project's full path.
  - Protected container tags are Free; immutable tags are Ultimate.

## Goals / Non-Goals

**Goals:**
- Offer opt-in CI hardening per created project, enforced on each apply once enabled, without changing any existing project by default.
- Give a Free namespace an automation identity at the top-level, subgroup and project level, with expiring or self-rotating tokens.
- Share runners and deploy keys across created projects, and let Kubernetes agents serve other groups' pipelines.
- Protect the registries of created projects.
- Let projects start with governed files.
- Keep the second plan empty and keep every v13 address.

**Non-Goals:**
- Instance service accounts (administrator only).
- Personal access tokens of users.
- The agent's `user_access` and GitOps configuration.
- Repository files outside the default branch.
- Binary secure files.
- Notifications integrations.
- Fine-grained job token permissions (no provider support).

## Decisions

### 1. Service accounts: two resource types, three places
- **Resources:**
  - `gitlab_group_service_account` covers top-level groups and subgroups;
  - `gitlab_project_service_account` covers projects;
  - their tokens use `gitlab_group_service_account_access_token` and `gitlab_project_service_account_access_token`.
- **Inputs:**
  - the standalone `service_accounts` (key without `:`) targets an existing group by ID or full path (top-level or intermediate);
  - `groups[*].service_accounts` and `projects[*].service_accounts` target the created group or project.
- **Keys:**
  - accounts: `"<name>"` or `"<owner key>:<name>"`;
  - tokens: `"<account key>:<token name>"`, unique because owner keys never contain `:`.
- **Arguments:**
  - `name` defaults to the item name;
  - `username` and `email` are sent only when set (both are Optional+Computed, so null reads back without diff);
  - `skip_wait_for_deletion = true`, because gitlab.com deletes users asynchronously and destroy would otherwise block until the timeout.
- **Access:** through `members[*].service_account`. The membership resources take `user_id = <account>.service_account_id`, unknown until apply, which `for_each` allows because the keys are static.
- **Invitation scope:** GitLab's rule is checked at plan from the keys alone:
  - a group account `"G:n"` is valid on group G, on its descendants (key equal to G or starting with `G/`) and on their projects;
  - a project account `"P:n"` is valid on project P only;
  - standalone accounts are not checked, since their group lies outside the tree and GitLab enforces the rule at apply.
- Alternatives rejected:
  - a separate `service_account_memberships` input, which would duplicate `members`;
  - implicit membership, which GitLab does not do, and the explicit grant is the point.

### 2. Token rotation
- **Where:** `rotation_configuration = { expiration_days, rotate_before_days }` is accepted on:
  - group and project access tokens (provider 16.11), standalone and nested;
  - service-account tokens.
- **Exactly one of `expires_at` and `rotation_configuration`:** the provider declares the two in conflict. When rotation is set, the module sends `expires_at = null` and reads back the expiry GitLab computed. One validation per input covers exactly-one and the day ranges; the existing date-format validation now also accepts a null `expires_at`.
- **Standalone `expires_at`:** it becomes optional. That is not breaking: every existing caller already sets it.
- **Guardrail:** `token_lifetime` reads `expiration_days` (above 366) as well as `expires_at`.

### 3. Opt-in CI hardening in a `ci` object
- `projects[*].ci` (default `{}`) groups the CI/CD settings, mirroring GitLab's CI/CD settings page, instead of adding 20 more flat attributes to a 50-attribute object.
- `ci.hardening_enabled` (default `false`, by maintainer decision) gates seven security settings. Each of those fields is `optional()` with no default, so `null` means "not set by the caller". The value sent is computed in `locals.tf`:
  - the explicit value when set;
  - otherwise the hardened value when hardening is on;
  - otherwise `null`, which sends nothing.

  A bare project therefore plans exactly as in v13.0.0.
- The table gives the hardened value of each setting and its `gitlab_project` argument:

| `ci` field | Hardened value | `gitlab_project` argument |
|---|---|---|
| `public_jobs` | `false` | `public_jobs` |
| `pipeline_variables_minimum_override_role` | `no_one_allowed` | `ci_pipeline_variables_minimum_override_role` |
| `protect_merge_request_pipelines` | `true` | `protect_merge_request_pipelines` |
| `separated_caches` | `true` | `ci_separated_caches` |
| `forward_deployment_enabled` | `true` | `ci_forward_deployment_enabled` |
| `push_repository_for_job_token_allowed` | `false` | `ci_push_repository_for_job_token_allowed` |
| `allow_merge_on_skipped_pipeline` | `false` | `allow_merge_on_skipped_pipeline` |

- Every other field defaults to `null`. These provider arguments are Optional+Computed, so null sends nothing and reads back without diff:
  - `config_path` → `ci_config_path` (Optional only, so null must read back as null; checked by the integration run);
  - `auto_cancel_pending_pipelines`, `build_timeout`;
  - `default_git_depth` → `ci_default_git_depth`;
  - `delete_pipelines_in_seconds` → `ci_delete_pipelines_in_seconds`;
  - `id_token_sub_claim_components` → `ci_id_token_sub_claim_components`;
  - `group_runners_enabled`, `shared_runners_enabled`;
  - Premium: `merge_pipelines_enabled`, `merge_trains_enabled`, `restrict_pipeline_cancellation_role` → `ci_restrict_pipeline_cancellation_role`, `allow_pipeline_trigger_approve_deployment`.
- `groups[*].shared_runners_setting` (Optional+Computed) is added to all seven `gitlab_group` level blocks.
- **Migration:** none. With hardening off by default, a v13.0.0 state plans with no change, so this is semver minor. Turning hardening on is an in-place update of `gitlab_project.this[*]`.
- Alternative rejected: hardening on by default (a major release changing every existing project), replaced by maintainer decision with the opt-in flag.

### 4. Freeze periods, secure files, CI/CD catalog (`ci.tf`)
- **Freeze periods:** `gitlab_project_freeze_period` (`freeze_start`, `freeze_end`, `cron_timezone` defaulting to `UTC`, sent so it reads back stable), keyed `"<pk>:<label>"`.
- **Secure files:** `gitlab_project_secure_file`, keyed `"<pk>:<name>"`.
  - The content goes through `sensitive()` with the existing `DEVIATION(terraform-variables)`, because `for_each` iterates the input and the provider has no write-only argument. The content is stored in state.
  - The provider uploads the string as the file body, so only text works; binary files are a documented limitation.
- **CI/CD catalog:** `gitlab_project_cicd_catalog`, keyed `"<pk>"`, created only when `cicd_catalog = true` (`enabled = true`, `keep_settings_on_destroy` left at false so destroy resets it).

### 5. Cross-project runners and deploy keys
- **Runners:** `gitlab_project_runner_enablement`, keyed `"<pk>:<source key>"` or `"<pk>:<id>"`, with `runner_id = tonumber(gitlab_user_runner.this[<source key>].id)`.
- **Deploy keys:** `gitlab_deploy_key_enable`, keyed the same way, with `key_id = gitlab_deploy_key.this[<source key>].deploy_key_id` and `can_push = false` always: a writable shared key would be an undeclared write path.
- Validations accept only another created project's unlocked project runner, or another project's deploy key.

### 6. Registry protection (`registry.tf`)
- **Package rules:** `gitlab_project_package_protection_rule`. The push level defaults to `maintainer`; the delete level is sent only when set.
- **Container repositories:** `gitlab_project_container_repository_protection` with `repository_path_pattern = "${path_with_namespace}${path_pattern}"`. Callers write the pattern relative to the project, because GitLab requires the full-path prefix.
- **Container tags:** `gitlab_project_container_tag_protection`.
  - Levels are sent upper-cased (`MAINTAINER`), the form the provider validates and GitLab returns.
  - With `immutable = true` (Ultimate) both levels are sent as null, which the provider requires.
- **Cleanup policy:** a dynamic `container_expiration_policy` block on `gitlab_project`, rendered only when the input is set, so a null input leaves GitLab's (computed) policy untouched.

### 7. Repository files (`files.tf`)
- **Two blocks:**
  - `gitlab_repository_file.managed`;
  - `gitlab_repository_file.seeded`, with `lifecycle { ignore_changes = [content, encoding, execute_filemode] }`.

  `ignore_changes` cannot vary per instance, so the per-file choice needs two blocks.
- **Arguments:** both commit to the project's default branch, with `overwrite_on_create = true` so a file may replace the initial `README.md` (the only file a new project holds) and fixed commit messages.
- **Order:** `gitlab_branch.this` gets `depends_on` on both blocks, so `develop` is created after the files and contains them.
- **Agent configuration:** each Kubernetes agent's `config.yaml` is merged into the managed map, so one code path writes every file.

### 8. Kubernetes agents
- **Resources:** `gitlab_cluster_agent` (provider 3.15) and one `gitlab_cluster_agent_token` per agent, keyed `"<pk>:<name>"`. The token goes to the sensitive `kubernetes_agent_tokens` output and is rotated by replacement.
- **`ci_access`:** created keys resolve to `full_path` and `path_with_namespace`; existing paths pass through. The result is written with `yamlencode({ ci_access = { groups = [{ id = ... }], projects = [{ id = ... }] } })`, with empty lists omitted and no file at all when both are empty.
- **Stable content:** `yamlencode` and sorted sets keep the content byte-stable between plans.

### 9. Premium and Ultimate
- **In `premium.tf`:** `gitlab_project_target_branch_rule` (provider 17.10), keyed `"<pk>:<pattern>"`.
- **On `gitlab_project`:** the Premium `ci` fields, null by default.
- **Immutable container tags:** in `registry.tf`, a field of the existing rule.

### 10. Guardrails
- **New checks:** `public_jobs` and `job_token_push`.
- **`token_lifetime`:** extended to service-account tokens and to `rotation_configuration.expiration_days`.
- Messages name the entry, never a value (existing rule).

### 11. Validations
- **Where they live:** on the variable that holds the field.
- **Cross-variable references:**
  - `projects` validations may read `var.groups` and `var.service_accounts`;
  - `groups` validations read only `var.service_accounts`, which keeps the variable graph acyclic, since `projects` already reads `groups`.
- **Messages:** taken verbatim from the delta specs, with one rejected-input run each.

### 12. Integration fixture (owner mode)
- **Adds:**
  - a standalone service account on the existing subgroup `leminnov/test`;
  - a subgroup account on `it-<suffix>/team`, member of `team/api`;
  - a project account on `team/api`;
  - each account with a token;
  - `ci.hardening_enabled = true` on `team/api` plus `delete_pipelines_in_seconds`, with `tools` left unhardened;
  - a weekend freeze period;
  - a text secure file;
  - an unlocked project runner on `team/api`, enabled in `tools`;
  - `team/api`'s deploy key, enabled in `tools`;
  - a package rule, a container repository rule and a protected container tag rule on `team/api`;
  - a cleanup policy on `tools`;
  - a managed `CODEOWNERS` and a seeded `docs/README.md`;
  - an agent `it` on `team/api` with `ci_access` to the tree's root group.
- **Asserts through the API:**
  - each account's token reads `team/api`, which proves membership and token;
  - the CI settings read back;
  - the freeze period, secure file, enabled runner, enabled deploy key and the three registry rules exist;
  - `CODEOWNERS` is on `main` and on `develop`;
  - the agent's `config.yaml` names the root group;
  - the agent token starts with `glagent-`.
- **Second plan:** must be empty. Then `run.sh` commits an edit to the seeded file through the API, and a third plan must still be empty.
- **No `.gitlab-ci.yml`:** the fixture writes none, so its commits never start pipelines on the sandbox's group runner.
- **Not run for real:** a top-level service account (unit tests only, by maintainer decision) and the Premium fields.

## Risks / Trade-offs

- [GitLab reads a sent CI value back differently, giving a perpetual diff] → The owner run's empty second plan covers every sent value; a mismatch is fixed in this change before release.
- [Older self-managed GitLab rejects `ci_pipeline_variables_minimum_override_role` (17.1+), `ci_id_token_sub_claim_components` (17.10+) or subgroup and project service accounts (18+)] → Server floor stated in the README compatibility table and the CHANGELOG.
- [Reading a service-account token's status needs a top-level Owner or admin token on gitlab.com; the provider then ignores permission errors and trusts state, so a rotation run without that right fails at apply] → SECURITY.md rotation row: rotate with a top-level group Owner token.
- [gitlab.com deletes service accounts asynchronously, so a deleted account's username stays taken for a while] → `skip_wait_for_deletion = true`. The fixture names carry the run suffix; renaming an account replaces it under a new username.
- [Commits to a default branch whose protection allows no push, or that Premium push rules such as `reject_unsigned_commits` block, fail at apply] → Known limitation in the README; the default protections allow maintainers.
- [Each file is one commit, and a `.gitlab-ci.yml` among them starts pipelines] → Documented. Seeded files keep later commits out of Terraform.
- [Secure files are text only] → Documented limitation.
- [Top-level service accounts are not exercised against GitLab] → Same resource and arguments as the subgroup case, which is exercised. Unit-tested and documented as such.

## Migration Plan

- **v13.0.0 to v13.1.0:** no change in the plan. Checked once by applying a small v13.0.0 tree to the sandbox and planning it with this version; the output is reported in tasks.
- **Rollback:** pin `?ref=v13.0.0`. v13.0.0 does not manage the new arguments, so GitLab keeps the values a hardened project received until changed by hand. Resources added by the new inputs must be removed from the inputs before rolling back.
- **Delivery:** one merge request into `develop`, the `develop` pipeline with the integration job, then `mise run release minor --push` for v13.1.0, as the maintainer chose.
