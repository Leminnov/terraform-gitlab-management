# Terraform Testing

## Native Tests

Use Terraform's built-in test framework (`.tftest.hcl` files) in a `tests/` directory:

```hcl
run "creates_bucket" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.bucket == "test-bucket"
    error_message = "Bucket name mismatch"
  }
}
```

- Use `command = plan` for fast validation without creating real resources
- Use `command = apply` for integration tests that provision real infrastructure
- Clean up: apply tests auto-destroy on completion

## What to Test

- Required variables are enforced (no default → must be provided)
- Validation blocks reject invalid input
- Resource counts match expected (e.g., `count` or `for_each` logic)
- Outputs contain expected values
- Conditional resources are created/skipped correctly

## Validation

Run these checks in CI:

```bash
terraform fmt -check -recursive
terraform validate
terraform test
```

## Examples as Tests

Every `examples/` directory should be a runnable Terraform config. CI should at minimum run `terraform init && terraform validate` against each example.
