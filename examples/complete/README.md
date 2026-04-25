# Complete Example

Exercises every input of the `gitlab-management` module.

## What this example does

- Creates 2 group variables (one masked+protected)
- Creates 1 project variable
- Creates 1 group deploy token (`read_repository`, `read_registry`)
- Creates 1 pipeline schedule with 1 pipeline-schedule variable
- Registers 1 group-level GitLab runner
- Creates 1 group access token (`maintainer`)
- Creates 1 project access token (`developer`)

## Prerequisites

- A GitLab token with `api` scope exported as `GITLAB_TOKEN`.
- For self-managed GitLab, also export `GITLAB_BASE_URL`.
- Override `demo_group` and `demo_project` with identifiers you can manage.

## Usage

```sh
terraform init
terraform plan -var="demo_group=my-org/platform" -var="demo_project=my-org/platform/web"
terraform apply -var="demo_group=my-org/platform" -var="demo_project=my-org/platform/web"
```

## Outputs

- `resource_counts` — how many of each resource type were created.
- `all_tokens` — consolidated sensitive token output (requires `-json` to read).

## Cleanup

```sh
terraform destroy -var="demo_group=..." -var="demo_project=..."
```
