# Tech Stack

## Infrastructure as Code

- Terraform (HCL)
- OpenTofu compatible

## Providers

- Configure per-project (AWS, GCP, Azure, etc.)
- Pin provider versions with pessimistic constraint (`~>`)

## Testing

- Terraform native test framework (`*.tftest.hcl`)
- `terraform validate` and `terraform fmt` in CI
- create an examples/complete/ that exercises all features

## Documentation

- terraform-docs for auto-generated module docs

## CI/CD

- Configure per-project (GitHub Actions, GitLab CI, etc.)

## Other

