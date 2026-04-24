# Versioning

## Semantic Versioning

Follow semver for published modules:

- **Major** (`x.0.0`) — Breaking changes: removed variables, renamed resources (causes state recreation), changed provider requirements
- **Minor** (`0.x.0`) — New features: added variables with defaults, new resources, new outputs
- **Patch** (`0.0.x`) — Bug fixes: corrected logic, updated descriptions, documentation

## Git Tags

- Tag releases as `vX.Y.Z` (e.g., `v1.2.0`)
- Reference modules by tag in `source`:

```hcl
module "vpc" {
  source  = "git::https://github.com/org/terraform-aws-vpc.git?ref=v1.2.0"
}
```

## Registry Modules

For Terraform Registry or private registries, use `version` constraint:

```hcl
module "vpc" {
  source  = "org/vpc/aws"
  version = "~> 1.2"
}
```

## Pre-1.0

Use `0.x.y` while the module is in active development and the interface is unstable. Bump to `1.0.0` when the input/output contract is stable.

## Breaking Change Checklist

Before a major version bump, verify:
- Migration guide documented
- Old variable names deprecated with `moved` blocks where possible
- State migration instructions provided if resources are renamed
