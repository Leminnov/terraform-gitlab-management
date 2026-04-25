# State Management

## Remote State

- Always use remote backends for shared infrastructure (S3, GCS, Azure Blob, Terraform Cloud)
- Enable state locking (DynamoDB for S3, native for GCS/Azure/TF Cloud)
- Enable encryption at rest

Example S3 backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state"
    key            = "project/environment/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## State Key Structure

Use a consistent key pattern: `{project}/{environment}/{component}/terraform.tfstate`

## State References

Use `terraform_remote_state` or data sources to read outputs from other state files — never hardcode values that come from another module's resources.

## Reusable Modules

- Reusable modules must not contain `backend` configuration
- Only root modules define backends

## State Hygiene

- Run `terraform plan` before every `apply`
- Never edit state files manually — use `terraform state mv`, `terraform import`, `terraform state rm`
- Review plan output for unexpected destroys/recreates before applying
