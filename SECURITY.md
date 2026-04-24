# Security

## Reporting a Vulnerability

Please report security issues privately to the maintainers at `security@leminnov.com`. Do not open public issues for security reports.

## Secret Handling

### Inputs

Several module inputs accept values that are commonly secret:

| Variable | Secret fields |
|----------|--------------|
| `group_variables` | `value` (especially when `masked = true` or `protected = true`) |
| `project_variables` | `value` (especially when `masked = true` or `protected = true`) |
| `pipeline_schedules` | `variables` map values |

These variables are **not** themselves marked `sensitive` at the module level because `for_each` cannot operate on sensitive values in Terraform. Consumers should:

- Source secret values from `TF_VAR_*` environment variables, a secrets manager (Vault, SOPS, AWS Secrets Manager, etc.), or CI/CD secrets — never hard-code them in `.tfvars` files committed to version control.
- Pass secret-bearing inputs through locals or caller variables marked `sensitive = true` where possible.

### Outputs

All outputs that surface tokens, variable values, or other secrets are marked `sensitive = true`:

- `group_variables`, `project_variables`
- `deploy_tokens`, `deploy_tokens_by_group`
- `group_access_tokens`, `group_access_tokens_by_group`
- `project_access_tokens`, `project_access_tokens_by_project`
- `pipeline_schedule_variables`
- `gitlab_runner_tokens`
- `all_tokens`

Use `terraform output -json <name>` to read them programmatically; plain `terraform output` redacts sensitive values.

## State Security

The Terraform state for this module contains all tokens created by GitLab in plaintext. Root modules that call this module must:

- Use a remote backend with encryption at rest (S3 + KMS, GCS + CMEK, Azure Blob + encryption keys, or Terraform Cloud).
- Enable state locking (DynamoDB for S3, native locking for other backends).
- Restrict IAM access to the state bucket/object to the smallest set of principals required.
- Never commit `.tfstate` or `.tfstate.backup` to version control (the root `.gitignore` already covers this).

## Least Privilege

- Use the smallest `access_level` and `scopes` that satisfy the consumer's needs.
- Prefer project-scoped tokens over group-scoped tokens where project-level access suffices.
- Set an explicit `expires_at` on every access token; avoid perpetual tokens.
