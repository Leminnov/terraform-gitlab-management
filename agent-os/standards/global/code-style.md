# HCL Code Style

## Formatting

- Always run `terraform fmt` — it is the single source of truth for formatting
- Use 2-space indentation (enforced by `terraform fmt`)

## Block Ordering in Resource Definitions

Order attributes within a resource block:

1. `count` or `for_each` (if applicable)
2. Required arguments (most important first)
3. Optional arguments
4. Nested blocks (`dynamic`, `lifecycle`, `provisioner`, `connection`)
5. `tags` (last)

## Expressions

- Prefer `for_each` over `count` for creating multiple resources — avoids index-based ordering issues
- Use `try()` and `can()` sparingly — they mask errors. Prefer explicit conditionals
- Use ternary for simple conditions: `var.enable_logging ? 1 : 0`
- Use `locals` to simplify complex expressions — don't inline long formulas in resource arguments

## Comments

- Use `#` for single-line comments
- Use `/* */` only for temporarily disabling blocks
- Comment the "why", not the "what" — HCL is already declarative and readable

## Lifecycle

Use `lifecycle` blocks intentionally:

```hcl
lifecycle {
  prevent_destroy = true   # protect critical resources
}
```

- `create_before_destroy` for zero-downtime replacements
- `ignore_changes` only when external systems manage specific attributes
- Never use `ignore_changes = all` — it hides drift
