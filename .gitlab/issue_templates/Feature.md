## Feature request

### Problem

<!-- What can't you do today? Why does it matter? -->

### Proposed interface

```hcl
module "gitlab_management" {
  source = "git::https://gitlab.com/leminnov/terraform/modules/gitlab-management.git?ref=vX.Y.Z"

  # How you'd want to call it.
}
```

### Alternatives considered

<!-- Other shapes, or workarounds you rejected and why. -->

### GitLab resources involved

- [ ] gitlab_group_variable
- [ ] gitlab_project_variable
- [ ] gitlab_group_deploy_token
- [ ] gitlab_pipeline_schedule
- [ ] gitlab_user_runner
- [ ] gitlab_group_access_token
- [ ] gitlab_project_access_token
- [ ] Other: <!-- specify -->

### Breaking change?

- [ ] No — new optional input, existing callers unaffected
- [ ] Yes — describe migration path:

/label ~feature
