# Basic Example

Minimal usage of the `gitlab-management` module: creates a single group-level CI/CD variable.

## What this example does

- Creates one `gitlab_group_variable` (`PIPELINE_LOG_LEVEL`) on the group `my-org/platform`.

## Prerequisites

- A GitLab token with `api` scope exported as `GITLAB_TOKEN`.
- For self-managed GitLab, also export `GITLAB_BASE_URL`.
- Replace `my-org/platform` with a group path or numeric group ID you can manage.

## Usage

```sh
terraform init
terraform plan
terraform apply
```

## Cleanup

```sh
terraform destroy
```
