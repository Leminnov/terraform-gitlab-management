# Design

## Context

- See proposal.md (Why) for the gaps. The module is 87 lines of `main.tf` (8 resources, all `this`, `for_each` over maps flattened in `locals.tf`), 392 lines of `variables.tf` (27 validation blocks) and 26 outputs. Unit tests cover 14 validations with a real provider block and a dummy token. No test has ever applied the module.
- Provider facts, checked from `tofu providers schema -json` for 18.11.0 and 19.5.0 and the provider CHANGELOG:
  - No write-only argument and no ephemeral resource exists for any resource used here.
  - `gitlab_group_variable.value`, `gitlab_project_variable.value` and `gitlab_pipeline_schedule_variable.value` are not marked sensitive.
  - `gitlab_deploy_token` is removed in 19.0.0. 19.1.0 adds a state mover to `gitlab_group_deploy_token`.
  - 19.4.0 makes `gitlab_pipeline_schedule.ref` require `refs/heads/...` or `refs/tags/...`, and reads `project_id` back for project runners.
  - 19.5.0 stops sending `masked` on update for hidden variables.
  - `gitlab_user_runner.group_id` and `project_id` are numbers.
  - Access tokens: the `access_level` values are `no one`, `minimal`, `guest`, `planner`, `reporter`, `security_manager`, `developer`, `maintainer` and `owner` (default `maintainer`), and `expires_at` is `YYYY-MM-DD`.
  - Group and project scope lists differ: group tokens also accept the virtual registry scopes.
- `sensitive()` on a resource argument fed from a non-sensitive `for_each` map plans fine and renders `(sensitive value)`. A caller-side `sensitive` value nested in the map also plans fine with OpenTofu 1.11, because marks sit on values, not keys. `plantimestamp()` works in `check` blocks through a local. `issensitive()` is available. All checked locally.
- Reference implementation: the keycloak module (`v4.0.0`) already meets the same store pins. Its CI, hooks, scripts and config files are copied and adapted rather than rewritten.

## Goals / Non-Goals

**Goals:**
- Every spec of the seven referenced stores is either met or covered by a `DEVIATION(<spec-id>)` with its reason, listed in the summary.
- Consumers upgrade from v12 without any deploy token being recreated unless they add an expiry.
- Every validation and `check` has a unit test. The integration fixture proves an empty second plan and the upgrade path against gitlab.com.

**Non-Goals:**
- New module features (project deploy tokens, `rotation_configuration`, `hidden`, `environment_scope`, service accounts).
- Testing against self-managed GitLab versions, or testing `instance_type` runners against a server (no admin on gitlab.com).
- Renaming inputs or reshaping the outputs that are kept.

## Decisions

### 1. Provider floor `~> 19.5`, deploy tokens moved, not re-created
`versions.tf` pins `gitlabhq/gitlab ~> 19.5`.
- The minimum that works is 19.1 (state mover), but 19.4 and 19.5 fix read-backs that matter for an empty second plan (runner `project_id`, hidden variables), and 19.5 is the version the fixture runs.
- `main.tf` replaces `gitlab_deploy_token` with `gitlab_group_deploy_token` (same `group`, `name`, `username`, `expires_at` and `scopes` arguments) and adds `moved { from = gitlab_deploy_token.this  to = gitlab_group_deploy_token.this }`. The `"<entry>_<group>"` keys are unchanged, so every instance maps one to one.
- `required_version` stays `>= 1.11.0`. It is the oldest OpenTofu version CI tests (1.11.14), and cross-type `moved` needs a recent CLI anyway.
- Alternative rejected: staying on 18.11. That keeps a deprecated resource that Renovate's next bump breaks, and 18.x has no state mover, so the migration would have to happen later under worse conditions.

### 2. Redaction by `sensitive()` in the resource, not by sensitive inputs
In `main.tf`, `value = sensitive(each.value.value)` is set on `gitlab_group_variable`, `gitlab_project_variable` and `gitlab_pipeline_schedule_variable`. Each carries a `# DEVIATION(terraform-variables): ...` comment: the inputs cannot be `sensitive = true` because `for_each` iterates them, and the provider has no `value_wo`.
- Maintainer decision over keycloak's split sensitive maps: same plan-output result, no input change.
- State still holds the values, as documented (Decision 9).

### 3. Validations aligned with the provider; enums stay in the `variables.tf` locals block
- `access_token_levels` gets the provider's nine values (`no one` with a space).
- `access_token_scopes` is split into `group_access_token_scopes` and `project_access_token_scopes`.
- New validations, with the exact messages from the specs:
  - `deploy_tokens[*].expires_at`: required; the null check is folded into the existing format validation.
  - Access-token `expires_at`: `YYYY-MM-DD` only (`^\d{4}-\d{2}-\d{2}$`, plus the existing month and day ranges).
  - `pipeline_schedules[*].ref`: matches `^refs/(heads|tags)/.+`.
  - `gitlab_runners[*].group_id` and `project_id`: `null` or `^[0-9]+$`. The type stays `string`, so numeric strings keep working.
- `can(regex(...))` stays the idiom for format checks (it validates the input and hides nothing, per `terraform-code-style`).
- Deploy token `expires_at` is sent as given, not normalised. Normalising would change the value sent compared to what v12 stored, and every attribute of a deploy token forces replacement.
- Found while applying: providers 18.11 and 19.5 both reject a bare `YYYY-MM-DD` on deploy tokens at plan time ("valid RFC3339 date"), although v12's validation accepted it. The validation is narrowed to RFC 3339 and the `deploy-tokens` spec updated. No existing state can hold the bare form, so this is a fix with no migration. The fixture still requires an empty second plan for the RFC 3339 form.

### 4. Guardrails in a new `checks.tf`
Three `check` blocks: `secret_variables_masked_and_protected`, `token_lifetime` and `access_token_privilege`. Each condition is computed in a local list of offending keys, and the `error_message` joins those keys (never values).
- Secret-looking keys are matched with `(?i)(TOKEN|PASSWORD|PASSWD|SECRET|PRIVATE_KEY|API_KEY|CREDENTIAL)`.
- Lifetime: `timecmp(<expiry as RFC 3339>, timeadd(plantimestamp(), "8784h")) > 0` (366 days, date granularity). A `YYYY-MM-DD` expiry gets `T00:00:00Z` appended.
- `main.tf` stays under 200 lines, so no header index is needed (`terraform-module-structure`).
- Alternative rejected: validations instead of checks. These configurations are legal and sometimes intended (an owner bot), so `terraform-security` prescribes `check`.

### 5. Outputs: 13 removed, 8 kept unchanged in shape
The kept outputs are `group_variables_ids`, `project_variables_ids`, `deploy_tokens` (now reading `gitlab_group_deploy_token.this`), `pipeline_schedule_ids`, `gitlab_runners`, `gitlab_runner_tokens`, `group_access_tokens` and `project_access_tokens`. They keep their order, which follows `main.tf`.
- Removing instead of deprecating is the maintainer's decision. The `DEVIATION(repository-versioning)` is recorded in the CHANGELOG upgrade notes, which name the replacement for each removed output: `all_tokens` maps to the three token outputs; `*_by_group`, `*_by_project` and `*_summary` to the keyed token outputs; `resource_counts` to `length(...)` on the kept outputs; `pipeline_schedules` to `pipeline_schedule_ids`. The variable echo outputs have no replacement, since the caller already holds the values.
- The `id` format of `deploy_tokens[*]` may change with the resource type. The fixture prints it in upgrade mode and the upgrade note states it.

### 6. Unit suite on `mock_provider`
- `tests/main.tftest.hcl` switches from a real provider block with a dummy token to `mock_provider "gitlab" {}`, with `mock_resource` defaults where an output reads a computed ID.
- One `expect_failures` run per validation block. Today 14 of 27 are covered; this change adds the missing ones and the new ones.
- One run per `check` with `expect_failures = [check.<name>]`, plus one clean run with no warning.
- `issensitive()` asserts on the three redacted values, and asserts on output keys.
- Relative expiry dates are built in run `variables` from `plantimestamp()`, so the lifetime tests do not age.

### 7. Integration fixture against a gitlab.com sandbox
`tests/integration/main.tf` calls the module (`source = "../.."`) on a sandbox group and project given by `SANDBOX_GROUP_ID` and `SANDBOX_PROJECT_ID`. Names and keys get a run suffix (`CI_PIPELINE_ID` or random) so leftovers never collide. `tests/integration/run.sh` follows keycloak's structure, with destroy in a trap, in three modes:
- `MODE=owner`: run with `GITLAB_TOKEN` (owner).
  - Apply every resource type except `instance_type` runners.
  - Server-side assertions with `curl --fail -o /dev/null` and the tokens from `tofu output -json`, never echoed: the deploy token clones the sandbox project with `git ls-remote`; the project token reads `GET /projects/:id`; the group variable is masked.
  - A sentinel value never appears in `tofu plan -no-color` output.
  - `tofu plan -detailed-exitcode` exits 0 after apply.
- `MODE=least`: run with `GITLAB_TOKEN_LEAST` (Maintainer on the sandbox group). Same flow, limited to the resources a Maintainer may create. The minimum role per resource found here goes into `SECURITY.md`.
- `MODE=upgrade`:
  - Copy the fixture to a temp dir with `source = "git::https://gitlab.com/leminnov/terraform/modules/gitlab-management.git?ref=v12.0.0"` and provider `~> 18.11`, using v12 inputs (deploy token without expiry, `ref = "main"`), and apply.
  - Restore the local source and `~> 19.5`, apply the v13 upgrade-note edits except the deploy token expiry, run `tofu init -upgrade`, and plan.
  - `tofu show -json` must show the deploy tokens as moves with no delete or create.
  - A second variant adds `expires_at` and must show exactly one replacement per token.

  `mise run test-integration` runs the three modes. In CI, `.gitlab/integration.yml` runs `test:integration:gitlab`:
  - Only when `GITLAB_TOKEN` is defined, which means protected refs and tags, since the variables are protected and masked (`gitlab-ci-security`).
  - With `resource_group: gitlab-sandbox`, so pipelines never share the sandbox concurrently.
  - Listed in `create:release` `needs:`.
- Alternatives rejected: a GitLab CE service container (heavy, and seeding a root token in a service is not possible without exec); deferring with a DEVIATION (the moved block and the read-back forms are exactly what a mock cannot prove).

### 8. Repository and CI copied from keycloak, adapted
- **Copied unchanged:** `.pre-commit-config.yaml`, `.terraform-docs.yml`, `.trivyignore.yaml`, `.gitattributes`, the `.tflint.hcl` plugin pin, `.gitlab/pre-commit.yml`, and `scripts/changelog.sh`.
- **`scripts/release.sh`:** copied, but the release commit subject becomes `Release vX.Y.Z` (`git-commits`: imperative, capitalised). It keeps the signed tag (`git tag -s`, `git-identity`) and the README `?ref=` rewrite.
- **`.gitlab/global.yml`:** keycloak's workflow rules, `interruptible` and version variables, plus `OPENSPEC_VERSION`.
- **`.gitlab/release.yml`:**
  - `validate:opentofu` and `validate:examples` run on the 1.11.14 / 1.13.1 matrix; `tofu test` moves into `validate:opentofu`, replacing `validate:tftest`.
  - `security:trivy` publishes its SBOM to the generic package registry.
  - `verify:changelog` runs `scripts/release.sh check`.
  - `create:release` uses `scripts/changelog.sh notes` and lists every job in `needs:`; the `SHA256SUMS.txt` job artifact is dropped (`gitlab-releases`).
  - `security:gitleaks` replaces `scan:gitleaks`: on merge requests it runs `gitleaks git --log-opts "$CI_MERGE_REQUEST_DIFF_BASE_SHA..$CI_COMMIT_SHA"`, and on the weekly schedule it scans the full history. Today's `--no-git` working-tree scan sees no history, and the pre-commit hook scans only staged files, which is nothing in CI.
- **`mise.toml`:**
  - Tool pins equal keycloak's (one org toolchain); `openspec` 1.14.3.
  - `min_version = '2026.9.14'`, equal to `MISE_VERSION`.
  - age, sops, shfmt and yamlfmt are removed, since nothing invokes them.
  - Task changes: `changelog` is replaced by `changelog-draft`, `changelog-verify` and `release`; `test`, `scan` and `test-integration` are added; every task gets a description.
- **`CHANGELOG.md`** becomes curated: a Keep a Changelog header, `## [Unreleased]` with this change, and backfilled `11.1.0` and `12.0.0` from `git log v11.0.0..v11.1.0` and `v11.1.0..v12.0.0`. Older generated sections are kept as they are; `scripts/changelog.sh` parses their `## [X.Y.Z] - YYYY-MM-DD` headings.
- **`.gitleaks.toml`:** the blanket path allowlist becomes one `[[allowlists]]` entry per false positive found by a full-history scan with default rules, each with a reason (`secrets-detection`). A real secret found there is rotated by the maintainer and recorded in `SECURITY.md`. History is not rewritten (`DEVIATION(secrets-detection)`, because `git-history` forbids rewriting `main` and `develop`), as keycloak did.
- **Removed files:**
  - `.github/`: GitHub Actions on a GitLab-only project.
  - `RELEASE.md`: its pre-release tags, tag deletion and hook-generated changelog contradict `git-history` and `gitlab-releases`.
  - `CONTRIBUTING.md`: conventional-commit prefixes contradict `git-commits`, and it references `make` targets that do not exist.

  Their valid content moves to the README Contributing and Releasing sections required by `repository-readme`. `CODEOWNERS` drops the removed paths.
- **`renovate.json`:** `:semanticCommits` is removed, along with the GitHub-only presets and rules. The regex managers become `customManagers` with the right `depName` per variable (today all four point at `jdx/mise`). mise, gitlabci and the custom managers go in one group, so a pin and its CI copy move in the same commit (`repository-mise`).

### 9. `SECURITY.md` holds the state table, roles and rotation
- "What lands in state" table: CI variable values, schedule variable values, deploy, group, project and runner tokens. Each row gives why (no write-only argument in 19.5) and the mitigation: encrypted remote backend, restricted state access, OpenTofu state encryption, expiry at most one year.
- Minimum roles from the fixture.
- One rotation procedure per secret class (`secrets-rotation`):
  - CI variable values: change the input and apply.
  - Deploy and access tokens: change `expires_at`, or apply `-replace=<address>`, update the consumers, then check that the old token returns 401.
  - Runner tokens: `-replace`, then re-register the runner manager.
  - The sandbox CI tokens.
- The supply chain section is updated: the SBOM replaces the checksum manifest, and the gitleaks history schedule is described.

### 10. Delivery in ordered merge requests
One OpenSpec change, delivered as four merge requests into `develop` so each stays reviewable (`gitlab-merge-requests`):
1. Repository, CI and tooling (task groups 1 and 2).
2. Module contract and unit tests (3 to 5).
3. Integration fixture (6).
4. Docs, CHANGELOG and project instructions (7 and 8).

The change is archived after the last merge, and `v13.0.0` is cut with `mise run release major` on `main`.

## Risks / Trade-offs

- [The state mover misses an attribute, so the moved deploy token shows a diff that forces replacement] → Upgrade mode fails on any delete or create. Fallback is documented in the upgrade note: `tofu state rm` plus an `import` block. That loses the token value from state ("token is not available for imported resources"), so the note tells consumers to rotate instead.
- [Adding the required `expires_at` replaces every existing non-expiring deploy token] → Inherent in `secrets-rotation`. The upgrade note says so and gives the rollout order: apply, update consumers, then the old token is already revoked by the replacement.
- [GitLab reads a schedule `ref` back in a form other than the one sent] → The fixture's empty second plan catches it. The validation then accepts only the read-back form.
- [Bot tokens on gitlab.com may be unable to create some resources (group access tokens, group runners)] → Owner mode is the reference. Anything it cannot create is listed as untested in the README compatibility table, not hidden.
- [Integration never runs on merge requests from feature branches, because protected variables are absent] → It runs on `develop` and `main` pushes and on tags, and `create:release` needs it, so a release cannot skip it. Merge requests rely on the unit suite.
- [Removing 13 outputs at once breaks callers that read them] → Upgrade notes name each replacement. Recorded as a maintainer decision.
- [`sensitive()` also hides non-secret values such as `LOG_LEVEL` in plans] → Accepted trade-off. `nonsensitive()` is not offered as an opt-out, to keep the default safe.

## Migration Plan

1. Merge the four MRs into `develop` in order. The pipeline is green on each, and the integration job is green on `develop`.
2. Maintainer, outside the repository:
   - create the sandbox group and project, and the protected, masked tokens `GITLAB_TOKEN` (owner) and `GITLAB_TOKEN_LEAST` (Maintainer), with expiries of at most one year, plus `SANDBOX_GROUP_ID` and `SANDBOX_PROJECT_ID`;
   - add the weekly pipeline schedule on `main`;
   - protect `v*` tags; check `main` and `develop` protection and the merge request settings;
   - record the public visibility in the project description;
   - decide the default branch.
3. Merge `develop` into `main` and run `mise run release major --push`. This produces signed `v13.0.0`, the release from its CHANGELOG section, and the back-merge into `develop`.
4. Consumers follow the upgrade notes:
   - back up state;
   - bump `?ref=v13.0.0` and run `tofu init -upgrade`;
   - fix the inputs (expiry, refs, enums, numeric IDs) and references to removed outputs;
   - review the plan: deploy tokens should be moves, schedules in-place updates, and replacements only where an expiry was added;
   - apply.

Rollback: before a consumer applies, revert to `?ref=v12.0.0`. After apply, state holds `gitlab_group_deploy_token`, which v12 and provider 18.11 cannot read, so rolling back means restoring the backed-up state.
