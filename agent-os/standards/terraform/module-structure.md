# Module Structure

Standard file layout for every Terraform module:

```
module/
├── main.tf           # Primary resources
├── variables.tf      # All input variables
├── outputs.tf        # All outputs
├── versions.tf       # terraform and required_providers blocks
├── locals.tf         # Local values (if needed)
├── data.tf           # Data sources (if needed)
├── README.md         # Module documentation
├── examples/         # Usage examples
│   └── basic/
│       ├── main.tf
│       └── outputs.tf
└── tests/            # Terraform tests
    └── main.tftest.hcl
```

- `versions.tf` always contains the `terraform {}` block with `required_version` and `required_providers`
- Never put provider configuration (`provider {}` blocks) in reusable modules — only in root modules
- Split `main.tf` into logical files (`network.tf`, `compute.tf`, etc.) when it exceeds ~200 lines
- Every module must have an `examples/` directory with at least one working example
- create an examples/complete/ that exercises all features