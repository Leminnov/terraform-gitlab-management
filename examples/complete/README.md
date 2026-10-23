# Complete Example

Exercises every input of the module with settings that raise no guardrail warning: secret-looking variables masked and protected, explicit token access levels, and tokens that expire within a year.

## What this example does

- Creates the groups `platform` and `platform/backend` under the demo group, and the projects `platform/docs` and `platform/backend/api`, with the module defaults: private, `main` initialised and protected for maintainers, `develop` created and protected for developers, `v*` tags protected, merges only on a green pipeline with threads resolved.
- Creates 2 group variables (`PIPELINE_LOG_LEVEL`, and `REGISTRY_PASSWORD` masked and protected) and 1 file-type project variable.
- Creates 1 group deploy token (`read_repository`, `read_registry`).
- Creates 1 pipeline schedule on `refs/heads/main` with 1 schedule variable.
- Registers 1 group runner limited to protected refs.
- Creates 1 group access token (`maintainer`) and 1 project access token (`developer`).

## Prerequisites

- OpenTofu >= 1.11.
- A group you own (subgroups, group runners and group access tokens need the Owner role) and a project in it, on gitlab.com or a self-managed GitLab.
- A token with the `api` scope (and `create_runner` for the runner) for that group, kept in your secret store.
- The value of `REGISTRY_PASSWORD` in your secret store; it lands in state, like every token this example creates ([SECURITY.md](../../SECURITY.md)).

## Usage

Pass the token and the secret for the command only, from your secret store, never through `export` or a file; set `GITLAB_BASE_URL` for a self-managed GitLab:

```sh
cat > example.tfvars <<'VARS'
demo_group       = "my-org/platform"
demo_group_id    = "12345678"
demo_project     = "my-org/platform/web"
token_expires_at = "2027-06-30"
VARS

tofu init
GITLAB_TOKEN="$(bao kv get -field=token kv/gitlab/terraform)" \
TF_VAR_registry_password="$(bao kv get -field=password kv/registry/ci)" \
  tofu apply -var-file=example.tfvars
```

## Outputs

- `pipeline_schedule_ids`: schedule IDs keyed like the input.
- `deploy_tokens`, `gitlab_runner_tokens`: sensitive; read them with `tofu output -json <name>` and store them straight in the system that consumes them.

## Cleanup

The created groups and projects are archived, not deleted, on destroy (the module's safe default), so their paths stay taken; delete them in the GitLab UI afterwards, or set `archive_on_destroy = false` on each entry before destroying a throwaway tree.

```sh
GITLAB_TOKEN="$(bao kv get -field=token kv/gitlab/terraform)" \
TF_VAR_registry_password="$(bao kv get -field=password kv/registry/ci)" \
  tofu destroy -var-file=example.tfvars
```
