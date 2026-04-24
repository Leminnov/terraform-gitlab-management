# Documentation

## Module README

Every module must have a `README.md` with:

1. **Summary** — One paragraph describing what the module does
2. **Usage** — Minimal HCL example showing how to call the module
3. **Requirements** — Terraform version, provider versions
4. **Inputs** — Table of variables (auto-generate with `terraform-docs`)
5. **Outputs** — Table of outputs (auto-generate with `terraform-docs`)

## terraform-docs

Use `terraform-docs` to auto-generate input/output tables. Add markers in README:

```markdown
<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
```

Run `terraform-docs markdown table . > README.md` or use the marker-based injection.

## Variable Descriptions

- Write descriptions as if the reader has zero context about your module
- Include valid values, units, or format when not obvious:

```hcl
variable "retention_days" {
  description = "Number of days to retain logs (1-365)"
  type        = number
  default     = 30
}
```

## Examples

- Each example in `examples/` should have its own README explaining the scenario
- Examples should be copy-pasteable — a user should be able to `terraform init && terraform plan` without modification (except variables)

## Changelog

Maintain a `CHANGELOG.md` for published modules following semver.
