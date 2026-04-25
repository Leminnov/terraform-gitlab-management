# Providers

## Version Constraints

Always pin providers with pessimistic constraint in `versions.tf`:

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

- `~> 5.0` allows `5.x` but not `6.0` — prevents breaking changes
- Pin `required_version` to the minimum Terraform version the module supports

## Reusable Modules

- Never include `provider {}` configuration blocks in reusable modules
- Providers are passed implicitly from the calling root module
- If a module needs a non-default provider (e.g., a different region), use `providers` argument in the `module` block

## Root Modules

- Configure providers in the root module only
- Use `provider` aliases when multiple configurations of the same provider are needed:

```hcl
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}
```

## Feature Flags

When a provider feature is optional, guard it with a boolean variable rather than conditional provider blocks.
