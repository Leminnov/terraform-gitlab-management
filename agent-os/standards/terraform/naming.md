# Naming Conventions

## Resources and Data Sources

- Use `snake_case` for all resource names
- Use `this` when a module creates a single instance of a resource type:

```hcl
resource "aws_s3_bucket" "this" { ... }
```

- Use descriptive names when multiple instances of the same type exist:

```hcl
resource "aws_security_group" "web" { ... }
resource "aws_security_group" "db" { ... }
```

- Never use the resource type in the name — it's already in the block label:

```hcl
# Good
resource "aws_instance" "web" { ... }

# Bad
resource "aws_instance" "web_instance" { ... }
```

## Locals

- Use `snake_case`
- Prefix computed names with their purpose (e.g., `name_prefix`, `common_tags`)

## Tags and Labels

- Apply consistent tags via a `locals` block with `common_tags`:

```hcl
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

- Merge `common_tags` with resource-specific tags using `merge()`

## Resource Naming (Cloud Names)

- Use a consistent pattern: `{project}-{environment}-{purpose}`
- Pass naming components as variables, assemble in locals
- Never hardcode names
