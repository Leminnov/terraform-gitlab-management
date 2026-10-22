# Tasks

## 1. Toolchain, hooks and release flow (MR 1)

- [x] 1.1 `mise.toml` (design 8):
  - `min_version = '2026.9.14'`.
  - Exact pins equal to keycloak: pre-commit 4.6.2, git-cliff 2.14.2, python 3.14.7, opentofu 1.13.1, terraform-docs 0.24.0, tflint 0.64.0, trivy 0.74.0, checkov 3.3.20, osv-scanner 2.6.0, gitleaks 8.30.1, node 24.21.0; keep openspec 1.14.3.
  - Remove age, sops, shfmt and yamlfmt.
  - Replace `changelog` with `changelog-draft`, `changelog-verify` and `release`; add `test` and `scan`; give every task a `description`.

  Verify `mise install` succeeds and `mise tasks` lists every task with a description.
- [x] 1.2 Copy keycloak's `.pre-commit-config.yaml` (canonical general hooks, gitleaks v8.30.1, pre-commit-terraform v1.109.1 with `--tf-path=tofu`, checkov, trivy). This drops `no-commit-to-branch` and the extra general hooks; gitleaks covers `detect-aws-credentials`, which goes in the summary. Add `.terraform-docs.yml`, `.trivyignore.yaml` and `.gitattributes`, and pin the tflint ruleset (`0.15.0`) in `.tflint.hcl`. Verify `pre-commit run -a` and `mise run scan` pass, then `tflint --init && tflint --recursive`.
- [x] 1.3 `.gitignore`: add `age.key`, `*.dec.*`, `*.plain.*`, `crash.log` and `.claude/settings.local.json`, and replace `!secrets/*` with `!secrets/**-enc.*`. `.editorconfig`: move the `*.tf` and `*.hcl` sections after `[Makefile]`. Verify `git check-ignore -v` on a sample path for each new pattern and `git status` stays clean.
- [x] 1.4 Run `gitleaks git --redact` over the full history with the default rules and no allowlist. Rewrite `.gitleaks.toml` with one `[[allowlists]]` entry per false positive (commit or path, plus a regex and a reason) and no blanket path. For any real secret, stop and ask the maintainer to rotate it before recording it (design 8). Verify `gitleaks git --redact --config .gitleaks.toml` reports no finding and every allowlist entry matches at least one finding.
- [x] 1.5 Copy `scripts/changelog.sh` and `scripts/release.sh` from keycloak, change the release commit subject to `Release vX.Y.Z`, and make both executable. Verify `bash -n` on both, then `scripts/release.sh check v12.0.0` on a scratch clone, which must fail because CHANGELOG has no `12.0.0` section yet.
- [x] 1.6 Convert `CHANGELOG.md` to a curated file: Keep a Changelog header, `## [Unreleased]` with this group's entries, and hand-written `[12.0.0]` and `[11.1.0]` sections from `git log v11.1.0..v12.0.0` and `v11.0.0..v11.1.0`. Older sections stay unchanged. Verify `mise run changelog-verify 12.0.0` and `mise run changelog-verify 11.1.0` pass.
- [x] 1.7 Remove `.github/`, `RELEASE.md` and `CONTRIBUTING.md`. Add the README `Contributing` and `Releasing` sections (keycloak wording adapted: `pre-commit install`, branch from `develop`, `git-commits` subjects, `Co-Authored-By` for AI-assisted commits, `mise run release <bump> --push` on `main`). Update the README Documentation table and drop the removed paths from `CODEOWNERS`. Verify `git grep -n 'RELEASE.md\|CONTRIBUTING.md\|\.github'` returns nothing outside `openspec/` and `CHANGELOG.md`.
- [x] 1.8 `renovate.json`: remove `:semanticCommits`, `helpers:pinGitHubActionDigests` and the github-actions rule; turn `regexManagers` into `customManagers` with the correct `depName` and datasource per `.gitlab/global.yml` variable; put the mise, gitlabci and custom managers in one group. Verify with `npx -y --package renovate -- renovate-config-validator renovate.json`.

## 2. CI pipeline (MR 1)

- [x] 2.1 `.gitlab/global.yml` from keycloak: `workflow: rules` (MR, schedule, `main`/`develop`, `vX.Y.Z` tags), `default: interruptible: true`, stages `validate`, `test` and `release`. Version variables `MISE_VERSION`, `TFLINT_VERSION`, `TRIVY_VERSION`, `GITLEAKS_VERSION`, `RELEASE_CLI_VERSION`, `OPENSPEC_VERSION` and `TOFU_VERSION` must equal the `mise.toml` pins; drop `GIT_CLIFF_VERSION` and `OSV_SCANNER_VERSION`. Copy keycloak's `.gitlab/pre-commit.yml` (osv-scanner from mise, timeout). Verify `pre-commit run check-yaml --all-files`, and that every `*_VERSION` matches `mise.toml` (grep side by side).
- [x] 2.2 `.gitlab/release.yml` (design 8):
  - `validate:opentofu` and `validate:examples` on the 1.11.14 / 1.13.1 matrix, with `tofu test` in `validate:opentofu`; `validate:tftest` and `scan:trivy` are removed.
  - `validate:tflint`; `security:trivy` (config + fs, SBOM to the generic package registry on tags, `expire_in` on the artifact); `security:gitleaks` (MR diff via `$CI_MERGE_REQUEST_DIFF_BASE_SHA`, full history on schedule).
  - `verify:changelog` (`scripts/release.sh check`).
  - `create:release`: notes from `scripts/changelog.sh notes`, no `SHA256SUMS.txt`, `needs:` on every job, tag rule `^v\d+\.\d+\.\d+$`.
  - Every job has a `timeout`; no `when: always`.

  Verify YAML with `pre-commit run check-yaml --all-files`, and check that each image tag exists in its registry (`curl` on the registry manifest API).
- [x] 2.3 Add `timeout: 5m` to `.gitlab/specs.yml`. Verify the merge request pipeline of MR 1 runs green: pre-commit, validate:specs, validate:opentofu ×2, validate:examples ×2, validate:tflint, security:trivy and security:gitleaks.

## 3. Provider 19.5, deploy token migration and unit suite base (MR 2)

- [x] 3.1 Switch `tests/main.tftest.hcl` from the dummy-token provider block to `mock_provider "gitlab" {}`, with `mock_resource` defaults for the computed IDs the outputs read. Verify `tofu test` passes the 19 existing runs offline (unset `GITLAB_TOKEN`).
- [x] 3.2 `versions.tf`: `gitlabhq/gitlab ~> 19.5`. `main.tf`: replace `gitlab_deploy_token` with `gitlab_group_deploy_token` and add the `moved` block. `outputs.tf`: `deploy_tokens` reads the new resource. Remove the redundant `depends_on` from `gitlab_pipeline_schedule_variable`. Verify `tofu init -upgrade` resolves 19.5.x, then `tofu validate`, and that `tofu test` passes with a run asserting the `deploy_tokens` keys.
- [x] 3.3 Examples: move the provider blocks to `examples/*/providers.tf` and set `~> 19.5`.
  - `examples/complete`: secret values come from variables without defaults (`sensitive = true`), and `timestamp()` is replaced by a `token_expires_at` variable, which removes the perpetual diff.
  - Example READMEs list the prerequisites and how to pass each variable.

  Verify `tofu init -backend=false && tofu validate` in each example.
- [x] 3.4 CHANGELOG `[Unreleased]`: breaking provider floor, deploy token migration (`moved`, nothing to edit, back up state first) and the examples fix. README Requirements is updated by terraform-docs. Verify `pre-commit run -a` passes and regenerates the README block.

## 4. Validations aligned with the provider (MR 2)

- [x] 4.1 `variables.tf`, per the `access-tokens` and `deploy-tokens` specs:
  - access-token levels gain the nine provider values;
  - group and project scope lists are split;
  - access-token `expires_at` must be `YYYY-MM-DD`;
  - deploy-token `expires_at` becomes required (message from the spec).

  Update the descriptions to match. Verify `tofu validate`.
- [x] 4.2 `variables.tf`, per the `pipeline-schedules` and `runners` specs: `ref` must match `^refs/(heads|tags)/.+`; `group_id` and `project_id` must be numeric when set. Update the descriptions. Verify `tofu validate`.
- [x] 4.3 Unit tests: one `expect_failures` run for every validation block in `variables.tf` (all 27 existing ones that lack one, plus the new ones), and accepted-form runs (`no one`, `planner`, `refs/heads/main`, RFC 3339 deploy-token expiry). Verify `tofu test` passes, and that `grep -c 'validation {' variables.tf` is at most the number of rejected-input runs.
- [x] 4.4 Update `examples/*` for full refs, numeric runner IDs and deploy-token expiry. CHANGELOG `[Unreleased]` breaking entries with the consumer edit for each: expiry (and the token replacement it causes), refs, enums, date format, numeric IDs. Verify `tofu validate` in each example and `pre-commit run -a`.

## 5. Redaction and output set (MR 2)

- [x] 5.1 `main.tf`: `value = sensitive(each.value.value)` on the three variable resources, each with its `DEVIATION(terraform-variables)` comment. Verify with unit runs asserting `issensitive()` on the three values (`tofu test` passes); the plain-output check is done by the fixture in 7.2.
- [x] 5.2 `outputs.tf`: remove the 13 outputs listed in the proposal and keep the 8 in `main.tf` order. Update `examples/*/outputs.tf`. Add a unit run asserting the keys of each kept output. Verify `tofu test`, `tflint --recursive`, and `tofu validate` in each example.
- [x] 5.3 CHANGELOG `[Unreleased]`: the removed outputs, each with its replacement, and the `DEVIATION(repository-versioning)` reason; redaction under Security. `SECURITY.md`: rewrite the Outputs section and add the "What lands in state" table (design 9). Verify `pre-commit run -a`.

## 6. Security guardrails (MR 2)

- [x] 6.1 `checks.tf` with `secret_variables_masked_and_protected`, `token_lifetime` and `access_token_privilege` (design 4). The messages list keys only. Verify `tofu validate` and `tflint --recursive`.
- [x] 6.2 Unit tests: one run per spec scenario with `expect_failures = [check.<name>]` (unmasked password, unprotected token variable, two-year deploy token, owner token, unset level), plus a clean run with no warning (`LOG_LEVEL`, six-month expiry, `developer`). Dates come from `plantimestamp()`. Verify `tofu test`.
- [x] 6.3 README "Security Considerations" lists the three warnings and links `SECURITY.md`. CHANGELOG `[Unreleased]` Added entry. Make `examples/complete` produce no warning (masked and protected secrets, explicit levels). Verify `tofu plan` of `examples/complete` under `tofu test` shows no check warning, and `pre-commit run -a`.

## 7. Integration fixture (MR 3)

- [ ] 7.1 Maintainer prerequisite, asked for and not done by the agent: sandbox group and project on gitlab.com; protected, masked CI variables `GITLAB_TOKEN` (owner) and `GITLAB_TOKEN_LEAST` (Maintainer), both expiring within one year; `SANDBOX_GROUP_ID` and `SANDBOX_PROJECT_ID`. Verify read-only with `glab api projects/:id/variables` that the four keys exist, protected and masked where secret.
- [x] 7.2 `tests/integration/main.tf` and `run.sh` (design 7): `MODE=owner`, `MODE=least` and `MODE=upgrade`, with destroy in a trap, run suffix, server-side asserts that never echo a token, sentinel-not-in-plan, `plan -detailed-exitcode` exit 0, and the upgrade plan check from `tofu show -json`. Verify `bash -n` and `shellcheck` on `run.sh`.
- [ ] 7.3 Add the `test-integration` mise task (three modes, refusing to start without the env vars). Run it locally against the sandbox with the maintainer's tokens; all three modes pass. Fold any read-back finding (deploy-token expiry form, schedule ref) into the validation, its test and its spec in this change.
- [ ] 7.4 Add `.gitlab/integration.yml` with `test:integration:gitlab`: stage `test`, `resource_group: gitlab-sandbox`, runs only when `GITLAB_TOKEN` is defined, on changes to `*.tf`, `tests/**` and the CI files, and on tags; tofu downloaded with checksum verification. Include it from `.gitlab-ci.yml` and add it to `create:release` `needs:`. Verify the `develop` pipeline after the MR 3 merge runs it green.
- [ ] 7.5 Docs:
  - `TESTING.md` describes both suites, the env vars and the modes.
  - `SECURITY.md` gets the minimum role per resource found by `MODE=least` and the rotation procedures, including for the sandbox tokens.
  - README compatibility table: OpenTofu 1.11 / 1.13, provider 19.5, gitlab.com, `examples/complete` applied, `instance_type` runners not applied.
  - CHANGELOG entry.

  Verify that the documented commands run as written.

## 8. Documentation and project instructions (MR 4)

- [x] 8.1 README per `repository-readme` and `terraform-repo-readme`:
  - title `# GitLab CI/CD Settings Terraform Module`;
  - badges: license, Terraform `>= 1.11`, GitLab provider `~> 19.5`, release with the `gitlab-management` path;
  - Features, Requirements and compatibility;
  - Basic, Complete and Conditional Creation usage on `git::...?ref=v13.0.0`;
  - Security Considerations, Known Limitations;
  - the terraform-docs block, then the Documentation table with `examples/`, `openspec/` and `AGENTS.md`;
  - Contributing, Releasing, License, Disclaimer, link references.

  Verify `pre-commit run -a` leaves the README stable on a second run.
- [x] 8.2 `.gitlab/merge_request_templates/Default.md`: keycloak sections (what, why, how tested, linked issue, checklist with the curated CHANGELOG entry). Issue templates: the `deploy_tokens` resource name and the module source on a tag. Verify `pre-commit run -a`.
- [x] 8.3 `AGENTS.md`, `CLAUDE.md` and `openspec/config.yaml`:
  - Known exceptions: the `sensitive()` deviation and the state table.
  - Provider `~> 19.5`; `checks.tf`; the integration fixture.
  - Commands: `mise run test`, `scan` and `test-integration`.
  - CHANGELOG curated by hand under `## [Unreleased]` (replacing the git-cliff rule); commit subjects per `git-commits`.

  Verify `mise run spec-validate` and that `openspec instructions proposal --change adopt-store-standards --json` shows the new context.
- [x] 8.4 CHANGELOG `[Unreleased]` complete: Added, Changed, Changed (breaking) with an upgrade note per item, Removed, Fixed, Security. Verify every **BREAKING** bullet of proposal.md has an entry naming the consumer edit.

## 9. Integration checks

- [ ] 9.1 Full local run: `tofu fmt -check -recursive`, `tofu init -backend=false && tofu validate`, `tflint --recursive`, `mise run test`, `mise run scan`, `pre-commit run -a`, `mise run spec-validate` and `mise run test-integration`. All pass, and the output is reported as-is.
- [x] 9.2 Every store spec is audited against the repository (`openspec list --specs --store <id>` for the seven stores). Each spec is met or covered by a `DEVIATION(<spec-id>)` with its reason; list them all in the final summary. Expected: `terraform-variables` (sensitive inputs), `repository-versioning` (outputs removed without deprecation), `secrets-detection` (no history rewrite, if a real finding exists), and the GitLab project settings left to the maintainer.
- [ ] 9.3 The four MRs are merged into `develop` in order, each with the template filled and a green pipeline; the `develop` pipeline including `test:integration:gitlab` is green.

## Workflow follow-up

- The maintainer applies the GitLab settings outside the repository:
  - weekly pipeline schedule on `main` (gitleaks history);
  - protected `v*` tags; `main` and `develop` protection; merge request settings (`gitlab-project-settings`);
  - the public visibility recorded in the project description;
  - the default-branch decision.
- Archive the change after the last MR merges (`/openspec-archive-change`), so `openspec/specs/` holds the seven capabilities.
- Cut `v13.0.0` on `main` with `mise run release major --push`, and check that the tag pipeline creates the release from the CHANGELOG section.
