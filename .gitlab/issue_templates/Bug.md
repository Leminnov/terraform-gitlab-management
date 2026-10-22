## Bug report

### What happened

<!-- Describe the unexpected behavior. Include error messages verbatim (redact tokens). -->

### What you expected

<!-- What should have happened instead? -->

### Reproduction

Minimal module input that reproduces the issue:

```hcl
module "gitlab_management" {
  source = "git::https://gitlab.com/leminnov/terraform/modules/gitlab-management.git?ref=vX.Y.Z"

  # Minimal inputs that trigger the bug. REDACT real values.
}
```

Steps:

1.
2.
3.

### Environment

| | Version |
|---|---|
| Module version / tag | |
| OpenTofu | `tofu version` |
| `gitlabhq/gitlab` provider | |
| GitLab version (self-managed) or "gitlab.com" | |
| OS | |

### Additional context

<!-- Logs (redacted), state dumps, screenshots. Do NOT paste secrets. -->

/label ~bug
