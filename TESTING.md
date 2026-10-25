# Testing

Two suites: unit tests that never contact GitLab, and an integration fixture that applies the module to a sandbox group on a real GitLab. Run the cheap checks first.

## Format, lint, validate

```sh
tofu fmt -check -recursive
tflint --init && tflint --recursive
tofu init -backend=false && tofu validate
for d in examples/*/; do (cd "$d" && tofu init -backend=false && tofu validate); done
```

`pre-commit run -a` runs these hooks plus terraform-docs (README tables), checkov, trivy and gitleaks; `mise run scan` runs the same scanners as CI.

## Unit tests

```sh
mise run test     # tofu test
```

`tests/main.tftest.hcl` uses `mock_provider "gitlab"` and `command = plan` only, so it needs no server, no token and no network beyond `tofu init`. It covers:

- the fan-out of every list input into `"<entry>_<target>"` keys, and the keys of every output;
- one rejected-input run per validation block in `variables.tf`, each input valid except for the rule under test, plus the accepted forms at the edges (`no one`, `planner`, tag refs, numeric runner IDs);
- the redaction of CI variable and schedule variable values (`issensitive`);
- one run per guardrail in `checks.tf` (`expect_failures = [check.<name>]`) and a clean configuration that raises none. Expiry dates are computed from `timestamp()` so the runs do not age.

CI runs the suite in `validate:opentofu` on OpenTofu 1.11.14 and 1.13.2.

## Integration tests

`tests/integration/` applies the module to a sandbox group and project on gitlab.com. It is run by `mise run test-integration` and by the CI job `test:integration:gitlab`, never by the unit suite. `tests/integration/run.sh` has three modes:

| Mode | Token | What it proves |
|------|-------|----------------|
| `owner` | `GITLAB_TOKEN` (Owner of the sandbox group) | Every resource type except `instance_type` runners and the Premium ones: the plan output never contains the secret sentinel (also used as a webhook signing token); GitLab holds the masked, protected group variable and the schedule variable; the deploy token clones the sandbox project; the project and group access tokens read their project and group (skipped on a gitlab.com Free namespace, where they need Premium); a `glrt-` runner token is issued. A tree `it-<suffix>`, `it-<suffix>/team`, `it-<suffix>/team/svc` with the projects `team/api` and `tools` (the token's own user as a direct member) gets the expected full paths, `main` and `develop` protected for maintainers and developers, `v*` tags protected, the merge settings, a read-only deploy key (generated with `ssh-keygen`), a job token allowlist naming `tools` and a trigger token that authenticates.<br>The run also checks:<ul><li>three service accounts (one of the sandbox group, one of `team`, one of `team/api`) each read `team/api` through their memberships;</li><li>`team/api` reads back the hardened CI settings, and has a freeze period, a secure file, package and container repository protection rules (tag rules are GraphQL-only and covered by the apply), a managed `CODEOWNERS` on `main` and `develop`, and a Kubernetes agent whose `config.yaml` names the tree's root group;</li><li>`tools` has `team/api`'s runner and deploy key enabled.</li></ul>The second plan is empty, and so is the plan after an edit of a seeded file in the repository. Destroy removes the tree for good, and the deploy token no longer works |
| `least` | `GITLAB_TOKEN_LEAST` (Maintainer of the sandbox group); skipped by `mise run test-integration` and CI when unset | The same flow for what a Maintainer may create: no group access token, a project runner instead of a group runner, no tree (subgroups need the Owner role) |
| `upgrade` | `GITLAB_TOKEN` | State written by `v12.0.0` on provider 18.11 is planned with this module on 19.5: the deploy token that already had an expiry is moved to `gitlab_group_deploy_token` without replacement, the undated one is replaced once, nothing else is destroyed; then apply and an empty second plan |

Every mode destroys what it created on exit, also on failure. Names and keys carry a run suffix (`RUN_SUFFIX`, the CI pipeline ID or the epoch); if a run is killed before its cleanup, delete the leftovers suffixed accordingly.

### Sandbox

A maintainer prepares it once:

1. A group dedicated to the tests (for example `leminnov/sandbox/terraform-gitlab-management`) and a project in it with a `main` branch.
2. Two tokens with scope `api`, expiring within one year: one for an Owner of the group (also `create_runner`), one for a Maintainer. On self-managed GitLab or a Premium gitlab.com group, use two group access tokens. On a Free gitlab.com group, where access tokens need Premium, use the personal access tokens of two dedicated accounts; `run.sh` then skips the access-token resources.
3. In the project's CI/CD settings, four variables, all protected: `GITLAB_TOKEN` and `GITLAB_TOKEN_LEAST` (masked and hidden), `SANDBOX_GROUP_ID` and `SANDBOX_PROJECT_ID` (the numeric IDs).

The project uses the `leminnov/test` group (ID 145539486) and its project `leminnov/test/sandbox` (ID 87995031). `GITLAB_TOKEN_LEAST` is not set yet: a Free group has no Maintainer access token, so the least run waits for a second account.

Because the variables are protected, `test:integration:gitlab` runs on `main`, `develop`, release tags and the weekly schedule, not on merge requests from feature branches, and `create:release` waits for it.

### Running locally

Pass the tokens for the command only, from your secret store, never through `export` or a file:

```sh
SANDBOX_GROUP_ID=<group id> SANDBOX_PROJECT_ID=<project id> \
GITLAB_TOKEN="$(bao kv get -field=owner kv/gitlab/sandbox)" \
GITLAB_TOKEN_LEAST="$(bao kv get -field=maintainer kv/gitlab/sandbox)" \
  mise run test-integration
```

`MODE=owner|least|upgrade tests/integration/run.sh` runs a single mode with `GITLAB_TOKEN` set to the matching token; `MODE=owner` also needs `ssh-keygen`. If a destroy fails, `run.sh` keeps the work directory with the state and prints its path. Set `GITLAB_BASE_URL` to test a self-managed GitLab.
