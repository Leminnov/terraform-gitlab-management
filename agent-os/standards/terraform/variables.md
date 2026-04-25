# Variables

## Naming

- Use `snake_case` for all variable names
- Prefix booleans with `enable_` or `is_` (e.g., `enable_logging`, `is_public`)
- Use noun phrases, not verbs (e.g., `instance_count` not `create_instances`)

## Declarations

Every variable must include `description` and `type`:

```hcl
variable "instance_type" {
  description = "EC2 instance type for the web servers"
  type        = string
  default     = "t3.micro"
}
```

- Put `description` first, then `type`, then `default`, then `validation`
- Use specific types (`string`, `number`, `bool`, `list(string)`, `map(string)`) — avoid `any`
- Only set `default` if a sensible default exists; required variables omit `default`

## Validation

Add `validation` blocks for variables with known constraints:

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

## Sensitive Variables

- Mark secrets with `sensitive = true`
- Never set default values for sensitive variables
- Document how secrets should be provided (env vars, tfvars, vault)

## Ordering

Variables in `variables.tf` should be ordered:
1. Required variables (no default) — most important first
2. Optional variables (with default) — most commonly overridden first
