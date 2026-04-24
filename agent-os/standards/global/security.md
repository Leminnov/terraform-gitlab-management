# Security

## Secrets

- Never commit secrets to `.tf` or `.tfvars` files
- Mark sensitive variables and outputs with `sensitive = true`
- Pass secrets via environment variables (`TF_VAR_*`), CI/CD secrets, or a vault
- Add `*.tfvars` to `.gitignore` if it may contain secrets

## State Security

- State files contain plaintext secrets — always encrypt at rest
- Restrict access to state storage (S3 bucket policies, GCS IAM, etc.)
- Never commit `.tfstate` or `.tfstate.backup` to version control

## Least Privilege

- IAM roles/policies should grant minimum required permissions
- Avoid `*` in resource ARNs and actions where possible
- Use separate roles for plan vs. apply in CI/CD

## Network Defaults

- Default security groups and NACLs should deny all inbound
- Open only required ports with specific CIDR ranges
- Never use `0.0.0.0/0` for SSH or RDP access in production

## Static Analysis

Run security scanning in CI:
- `tfsec` or `trivy config` for misconfiguration detection
- `checkov` for compliance policy checks
- `terraform plan` output review for unexpected permission changes
