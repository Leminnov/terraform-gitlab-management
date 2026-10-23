# GitLab CI/CD Settings Terraform Module

[![Apache 2.0][apache-shield]][apache]
[![Terraform][terraform-badge]][terraform-url]
[![GitLab Provider][provider-badge]][provider-url]
[![Latest Release][release-badge]][release-url]

OpenTofu module that manages GitLab CI/CD settings across many groups and projects from one call: CI/CD variables, deploy tokens, pipeline schedules, runners and access tokens.

## Features

- A **group and project tree** under an existing parent group: up to 7 group levels and any number of projects, keyed by path, created with the `gitlab-project-settings` defaults (private, `main` and `develop` protected, `v*` tags protected, merge only on green pipelines with threads resolved) and archived rather than deleted on destroy
- **Objects nested in each group and project**: variables, deploy tokens, access tokens, memberships, group shares and runners, labels and badges, plus deploy keys, pipeline schedules, triggers, environments, webhooks and a CI/CD job token allowlist on projects
- **Group and project CI/CD variables** declared once and created in every group or project of their `groups` / `projects` list, with the GitLab key rule and the variable type checked at plan time
- **Group deploy tokens** and **group / project access tokens**, fanned out the same way, always with an expiry, with access levels and scopes accepted exactly as the provider accepts them
- **Pipeline schedules** on a full git ref, with their variables
- **Runners** (`gitlab_user_runner`) at group, project or instance level, with their authentication tokens as a sensitive output
- Stable `"<entry>_<target>"` resource keys: adding or reordering targets never recreates an existing resource
- Every CI variable and schedule variable value is **redacted in plan output**; every token output is sensitive
- **Plan-time warnings** (`check` blocks) for secret-looking variables that are not masked and protected, tokens living longer than a year, and owner or default-level access tokens
- No `provider {}` block: the caller configures the gitlab provider
- Unit tests on a mock provider, and an integration fixture run against a gitlab.com sandbox as owner and as Maintainer, plus an upgrade run from v12 (empty second plan required)

## Requirements

| Name | Version |
|------|---------|
| OpenTofu | >= 1.11 |
| gitlabhq/gitlab provider | ~> 19.5 |
| GitLab | gitlab.com; self-managed GitLab with the API level of provider 19.5 |

### Compatibility

| Module | OpenTofu | Provider | GitLab | Examples applied |
|--------|----------|----------|--------|------------------|
| 13.0.0 (unreleased) | 1.11.14, 1.13.2 (validate and unit tests) | 19.5.0 | gitlab.com | Integration fixture not yet run against the sandbox |

CI validates every example and runs the unit suite on OpenTofu 1.11.14 and 1.13.2. `instance_type` runners need an instance administrator token and are covered by the unit suite only.

## Usage

### Basic Example

```hcl
# GITLAB_TOKEN (and GITLAB_BASE_URL for a self-managed GitLab) come from the environment.
provider "gitlab" {}

module "gitlab_management" {
  source = "git::https://gitlab.com/leminnov/terraform/modules/gitlab-management.git?ref=v13.0.0"

  group_variables = {
    pipeline_log_level = {
      key    = "PIPELINE_LOG_LEVEL"
      groups = ["my-org/platform", "my-org/data"]
      value  = "info"
    }
  }
}
```

### Group and project tree

```hcl
module "gitlab_management" {
  source = "git::https://gitlab.com/leminnov/terraform/modules/gitlab-management.git?ref=v13.0.0"

  parent_group_id = 6055239 # an existing group you own

  groups = {
    platform         = {}
    "platform/infra" = { description = "Infrastructure" }
  }

  projects = {
    "platform/infra/terraform-modules" = {}                                   # main + develop, protected
    "platform/docs"                    = { branches = {}, merge_method = "ff" } # trunk-based
  }
}
```

### Tokens and schedules

```hcl
module "gitlab_management" {
  source = "git::https://gitlab.com/leminnov/terraform/modules/gitlab-management.git?ref=v13.0.0"

  deploy_tokens = {
    registry = {
      groups     = ["my-org/platform"]
      name       = "read-registry"
      expires_at = "2027-06-30T00:00:00Z" # RFC 3339, at most a year ahead
      scopes     = ["read_registry"]
    }
  }

  gitlab_project_access_token = {
    release_bot = {
      projects     = ["my-org/platform/web"]
      name         = "release-bot"
      expires_at   = "2027-06-30" # YYYY-MM-DD
      access_level = "developer"
      scopes       = ["read_api", "write_repository"]
    }
  }

  pipeline_schedules = {
    nightly = {
      project     = "my-org/platform/web"
      description = "Nightly build"
      ref         = "refs/heads/main" # full ref
      cron        = "0 2 * * *"
      active      = true
    }
  }
}

# Store tokens straight in the system that consumes them.
output "registry_login" {
  value     = module.gitlab_management.deploy_tokens["registry_my-org/platform"]
  sensitive = true
}
```

### Complete Example

[`examples/complete`](examples/complete) sets every input with settings that raise no warning: masked and protected secrets, explicit access levels, tokens expiring within a year.

### Conditional Creation

Every input is a map and defaults to `{}`; leave an input out, or set it to `{}`, to create nothing of that kind:

```hcl
module "gitlab_management" {
  source = "git::https://gitlab.com/leminnov/terraform/modules/gitlab-management.git?ref=v13.0.0"

  gitlab_runners = var.enable_runner ? {
    ci = {
      runner_type  = "group_type"
      description  = "CI runner"
      group_id     = "12345678"
      access_level = "ref_protected"
      tag_list     = ["docker"]
      paused       = false
      untagged     = false
      locked       = false
    }
  } : {}
}
```

### Upgrading from v12

Back up the state, then follow the "Changed (breaking)" and "Removed" upgrade notes in [CHANGELOG.md](CHANGELOG.md):

1. Bump `?ref=` to the new tag and run `tofu init -upgrade` (provider `~> 19.5`).
2. Give every deploy token an RFC 3339 `expires_at`. A token that had none is replaced: roll out the new one from `deploy_tokens`.
3. Write schedule refs as `refs/heads/<branch>` or `refs/tags/<tag>`.
4. Replace references to removed outputs as the CHANGELOG lists.
5. Review the plan. Deploy tokens show as moves to `gitlab_group_deploy_token`, and nothing is destroyed except deploy tokens that just got an expiry. Then apply.

## Security Considerations

1. CI variable values, schedule variable values and every token GitLab creates land in state, since the provider has no write-only arguments for them: keep the state in an encrypted, access-restricted backend. [SECURITY.md](SECURITY.md) lists each one with its mitigation.
2. Values are redacted in plan output (`(sensitive value)`); pass secrets from `TF_VAR_*` or a secret store, never from a committed file.
3. Three plan-time warnings (`check` blocks in `checks.tf`) flag configurations GitLab accepts but that weaken security, naming the entries and never a value:
   - `secret_variables_masked_and_protected`: a variable whose key contains `TOKEN`, `PASSWORD`, `PASSWD`, `SECRET`, `PRIVATE_KEY`, `API_KEY` or `CREDENTIAL` (any case) is not both masked and protected;
   - `token_lifetime`: a deploy or access token expires more than one year after the plan;
   - `access_token_privilege`: an access token has `access_level = "owner"`, or no level (GitLab then grants `maintainer`).
4. Every deploy and access token needs an expiry; rotate tokens before it (see [SECURITY.md](SECURITY.md)).

## Known Limitations

1. CI variable values, schedule variable values and every token GitLab creates are stored in state: provider 19.5 has no write-only argument for them (see [SECURITY.md](SECURITY.md)).
2. Tokens are immutable: changing any argument of a deploy or access token makes GitLab issue a new token, and consumers must pick it up.
3. Only group deploy tokens are supported (`gitlab_group_deploy_token`); project deploy tokens are out of scope.
4. The `environment_scope`, `hidden`, `raw` and `description` arguments of CI variables, the schedule `cron_timezone`, and `rotation_configuration` on access tokens are not exposed, so the provider defaults apply (all environments, visible, expanded, no description, UTC).
5. `instance_type` runners need an instance administrator token; gitlab.com users cannot create them.
6. GitLab limits access-token lifetime per instance; an `expires_at` beyond that limit fails at apply.
7. Only OpenTofu is tested; HashiCorp Terraform >= 1.11 is expected to work but is not part of CI.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_gitlab"></a> [gitlab](#requirement\_gitlab) | ~> 19.5 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_gitlab"></a> [gitlab](#provider\_gitlab) | ~> 19.5 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [gitlab_branch.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/branch) | resource |
| [gitlab_branch_protection.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/branch_protection) | resource |
| [gitlab_deploy_key.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/deploy_key) | resource |
| [gitlab_group.level_1](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group) | resource |
| [gitlab_group.level_2](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group) | resource |
| [gitlab_group.level_3](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group) | resource |
| [gitlab_group.level_4](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group) | resource |
| [gitlab_group.level_5](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group) | resource |
| [gitlab_group.level_6](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group) | resource |
| [gitlab_group.level_7](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group) | resource |
| [gitlab_group_access_token.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group_access_token) | resource |
| [gitlab_group_badge.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group_badge) | resource |
| [gitlab_group_deploy_token.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group_deploy_token) | resource |
| [gitlab_group_label.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group_label) | resource |
| [gitlab_group_membership.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group_membership) | resource |
| [gitlab_group_share_group.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group_share_group) | resource |
| [gitlab_group_variable.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group_variable) | resource |
| [gitlab_pipeline_schedule.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/pipeline_schedule) | resource |
| [gitlab_pipeline_schedule_variable.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/pipeline_schedule_variable) | resource |
| [gitlab_pipeline_trigger.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/pipeline_trigger) | resource |
| [gitlab_project.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/project) | resource |
| [gitlab_project_access_token.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/project_access_token) | resource |
| [gitlab_project_badge.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/project_badge) | resource |
| [gitlab_project_deploy_token.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/project_deploy_token) | resource |
| [gitlab_project_environment.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/project_environment) | resource |
| [gitlab_project_hook.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/project_hook) | resource |
| [gitlab_project_job_token_scopes.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/project_job_token_scopes) | resource |
| [gitlab_project_label.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/project_label) | resource |
| [gitlab_project_membership.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/project_membership) | resource |
| [gitlab_project_share_group.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/project_share_group) | resource |
| [gitlab_project_variable.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/project_variable) | resource |
| [gitlab_tag_protection.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/tag_protection) | resource |
| [gitlab_user_runner.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/user_runner) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_deploy_tokens"></a> [deploy\_tokens](#input\_deploy\_tokens) | Map of GitLab group deploy tokens. Each entry is expanded across its `groups` list. Fields:<br/>  - groups      : Group paths or IDs to create the token in. Must be non-empty.<br/>  - name        : Human-readable token name.<br/>  - username    : Optional token username; null lets GitLab generate gitlab+deploy-token-<n>.<br/>  - expires\_at  : Required expiry, an RFC 3339 timestamp such as 2027-06-30T00:00:00Z (the provider rejects a bare date), at most one year ahead (see the token\_lifetime check); without one the token would never expire.<br/>  - scopes      : Token scopes, non-empty: read\_repository, read\_registry, write\_registry, read\_package\_registry, write\_package\_registry, read\_virtual\_registry, write\_virtual\_registry. | <pre>map(object({<br/>    groups     = list(string)<br/>    name       = string<br/>    username   = optional(string)<br/>    expires_at = optional(string)<br/>    scopes     = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_gitlab_group_access_token"></a> [gitlab\_group\_access\_token](#input\_gitlab\_group\_access\_token) | Map of GitLab group access tokens. Each entry is expanded across its `groups` list. Fields:<br/>  - groups        : Group paths or IDs to create the token in. Must be non-empty.<br/>  - name          : Human-readable token name.<br/>  - expires\_at    : Required expiry date, YYYY-MM-DD, within the instance's maximum token lifetime.<br/>  - access\_level  : One of no one, minimal, guest, planner, reporter, security\_manager, developer, maintainer, owner; null lets GitLab grant maintainer.<br/>  - scopes        : Token scopes, non-empty: api, read\_api, read\_registry, write\_registry, read\_virtual\_registry, write\_virtual\_registry, read\_repository, write\_repository, create\_runner, manage\_runner, ai\_features, k8s\_proxy, read\_observability, write\_observability, self\_rotate. | <pre>map(object({<br/>    groups       = list(string)<br/>    name         = string<br/>    expires_at   = string<br/>    access_level = optional(string)<br/>    scopes       = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_gitlab_project_access_token"></a> [gitlab\_project\_access\_token](#input\_gitlab\_project\_access\_token) | Map of GitLab project access tokens. Each entry is expanded across its `projects` list. Fields:<br/>  - projects      : Project paths or IDs to create the token in. Must be non-empty.<br/>  - name          : Human-readable token name.<br/>  - expires\_at    : Required expiry date, YYYY-MM-DD, within the instance's maximum token lifetime.<br/>  - access\_level  : One of no one, minimal, guest, planner, reporter, security\_manager, developer, maintainer, owner; null lets GitLab grant maintainer.<br/>  - scopes        : Token scopes, non-empty: api, read\_api, read\_registry, write\_registry, read\_repository, write\_repository, create\_runner, manage\_runner, ai\_features, k8s\_proxy, read\_observability, write\_observability, self\_rotate. | <pre>map(object({<br/>    projects     = list(string)<br/>    name         = string<br/>    expires_at   = string<br/>    access_level = optional(string)<br/>    scopes       = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_gitlab_runners"></a> [gitlab\_runners](#input\_gitlab\_runners) | Map of GitLab runner registrations (gitlab\_user\_runner). Fields:<br/>  - runner\_type     : "group\_type", "project\_type", or "instance\_type".<br/>  - description     : Human-readable description.<br/>  - group\_id        : Numeric group ID, not a path (required when runner\_type == "group\_type").<br/>  - project\_id      : Numeric project ID, not a path (required when runner\_type == "project\_type").<br/>  - access\_level    : "not\_protected" or "ref\_protected".<br/>  - tag\_list        : Runner tags. Required to be non-empty when `untagged = false`.<br/>  - maximum\_timeout : Optional max job timeout in seconds (min 600).<br/>  - paused          : Whether the runner starts paused.<br/>  - untagged        : Whether to run untagged jobs.<br/>  - locked          : Whether the runner is locked to its project. | <pre>map(object({<br/>    runner_type     = string<br/>    description     = string<br/>    group_id        = optional(string)<br/>    project_id      = optional(string)<br/>    access_level    = string<br/>    tag_list        = list(string)<br/>    maximum_timeout = optional(number)<br/>    paused          = bool<br/>    untagged        = bool<br/>    locked          = bool<br/>  }))</pre> | `{}` | no |
| <a name="input_group_variables"></a> [group\_variables](#input\_group\_variables) | Map of GitLab group CI/CD variables. Each entry is expanded across its `groups` list, producing one `gitlab_group_variable` per (entry, group). Fields:<br/>  - key            : Variable key as it appears in GitLab.<br/>  - groups         : Group paths or IDs to create this variable in. Must be non-empty.<br/>  - value          : Variable value. Redacted in plan output but stored in state (SECURITY.md); pass secrets from TF\_VAR\_* or a secret store, never from a committed file.<br/>  - variable\_type  : "env\_var" (default) or "file".<br/>  - protected      : Expose only to protected refs. Default false.<br/>  - masked         : Mask the value in job logs. Default false; the check secret\_variables\_masked\_and\_protected warns when a secret-looking key is not masked and protected. | <pre>map(object({<br/>    key           = string<br/>    groups        = list(string)<br/>    value         = string<br/>    variable_type = optional(string, "env_var")<br/>    protected     = optional(bool, false)<br/>    masked        = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_groups"></a> [groups](#input\_groups) | Groups to create under parent\_group\_id, keyed by their path relative to it: "platform", "platform/infra", ... up to 7 levels. The parent of a key (all segments but the last) must be declared too. Fields:<br/>  - name                              : Display name; default the last path segment.<br/>  - description                       : Optional description.<br/>  - visibility                        : private (default), internal or public; never more open than the parent group's.<br/>  - default\_branch                    : Initial default branch of new projects in the group; default main.<br/>  - project\_creation\_level            : Who can create projects: noone, owner, maintainer (default), developer, administrator.<br/>  - subgroup\_creation\_level           : Who can create subgroups: owner (default) or maintainer.<br/>  - request\_access\_enabled            : Let users request access; default false.<br/>  - require\_two\_factor\_authentication : Require two-factor authentication for members; null keeps the GitLab default.<br/>  - archive\_on\_destroy                : Archive the group instead of deleting it on destroy; default true.<br/>  - permanently\_remove\_on\_delete      : With archive\_on\_destroy = false, remove the group at once instead of scheduling the deletion; default false.<br/>  - variables     : CI/CD variables keyed by variable key: value, variable\_type (env\_var default, file), protected and masked (default false). Values are redacted in plans and stored in state (SECURITY.md).<br/>  - deploy\_tokens : Deploy tokens keyed by name: username, expires\_at (required, RFC 3339), scopes (read\_repository, read\_registry, write\_registry, read\_package\_registry, write\_package\_registry, read\_virtual\_registry, write\_virtual\_registry).<br/>  - access\_tokens : Access tokens keyed by name: expires\_at (required, YYYY-MM-DD), access\_level (null lets GitLab grant maintainer), scopes.<br/>  - members       : User memberships keyed by any label: user\_id, access\_level (no one, minimal, guest, planner, reporter, security\_manager, developer, maintainer, owner), expires\_at (YYYY-MM-DD).<br/>  - shared\_with   : Shares keyed by any label: exactly one of group (a groups key) or group\_id (an existing group ID), access\_level, expires\_at (YYYY-MM-DD).<br/>  - runners       : Runners keyed by name: description (default the name), access\_level (ref\_protected default, not\_protected), tag\_list (required unless untagged), untagged, paused, locked, maximum\_timeout (seconds, >= 600).<br/>  - labels        : Labels keyed by name: color (#RRGGBB or a CSS colour name), description.<br/>  - badges        : Badges keyed by name: link\_url and image\_url (http(s); GitLab placeholders such as %{project\_path} allowed, written with a doubled % in HCL strings). | <pre>map(object({<br/>    name                              = optional(string)<br/>    description                       = optional(string)<br/>    visibility                        = optional(string, "private")<br/>    default_branch                    = optional(string, "main")<br/>    project_creation_level            = optional(string, "maintainer")<br/>    subgroup_creation_level           = optional(string, "owner")<br/>    request_access_enabled            = optional(bool, false)<br/>    require_two_factor_authentication = optional(bool)<br/>    archive_on_destroy                = optional(bool, true)<br/>    permanently_remove_on_delete      = optional(bool, false)<br/>    variables = optional(map(object({<br/>      value         = string<br/>      variable_type = optional(string, "env_var")<br/>      protected     = optional(bool, false)<br/>      masked        = optional(bool, false)<br/>    })), {})<br/>    deploy_tokens = optional(map(object({<br/>      username   = optional(string)<br/>      expires_at = optional(string)<br/>      scopes     = list(string)<br/>    })), {})<br/>    access_tokens = optional(map(object({<br/>      expires_at   = string<br/>      access_level = optional(string)<br/>      scopes       = list(string)<br/>    })), {})<br/>    members = optional(map(object({<br/>      user_id      = number<br/>      access_level = string<br/>      expires_at   = optional(string)<br/>    })), {})<br/>    shared_with = optional(map(object({<br/>      group        = optional(string)<br/>      group_id     = optional(number)<br/>      access_level = string<br/>      expires_at   = optional(string)<br/>    })), {})<br/>    runners = optional(map(object({<br/>      description     = optional(string)<br/>      access_level    = optional(string, "ref_protected")<br/>      tag_list        = optional(list(string), [])<br/>      untagged        = optional(bool, false)<br/>      paused          = optional(bool, false)<br/>      locked          = optional(bool, false)<br/>      maximum_timeout = optional(number)<br/>    })), {})<br/>    labels = optional(map(object({<br/>      color       = string<br/>      description = optional(string)<br/>    })), {})<br/>    badges = optional(map(object({<br/>      link_url  = string<br/>      image_url = string<br/>    })), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_parent_group_id"></a> [parent\_group\_id](#input\_parent\_group\_id) | Numeric ID of the existing group under which groups and projects are created (gitlab.com does not let the provider create top-level groups). Required when either is declared. | `number` | `null` | no |
| <a name="input_pipeline_schedules"></a> [pipeline\_schedules](#input\_pipeline\_schedules) | Map of GitLab pipeline schedules. Fields:<br/>  - project      : Project path or ID.<br/>  - description  : Schedule description.<br/>  - ref          : Full git ref to run against: refs/heads/<branch> or refs/tags/<tag> (provider 19.4+ rejects a short name such as main).<br/>  - cron         : Cron expression with 5 fields (e.g. "0 2 * * *"), in the schedule's time zone (GitLab default UTC).<br/>  - active       : Whether the schedule is active.<br/>  - variables    : Optional map of pipeline variables keyed by variable name. Values are redacted in plan output but stored in state (SECURITY.md). | <pre>map(object({<br/>    project     = string<br/>    description = string<br/>    ref         = string<br/>    cron        = string<br/>    active      = bool<br/>    variables   = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_project_variables"></a> [project\_variables](#input\_project\_variables) | Map of GitLab project CI/CD variables. Each entry is expanded across its `projects` list. Fields:<br/>  - key            : Variable key as it appears in GitLab.<br/>  - projects       : Project paths or IDs to create this variable in. Must be non-empty.<br/>  - value          : Variable value. Redacted in plan output but stored in state (SECURITY.md); pass secrets from TF\_VAR\_* or a secret store, never from a committed file.<br/>  - variable\_type  : "env\_var" (default) or "file".<br/>  - protected      : Expose only to protected refs. Default false.<br/>  - masked         : Mask the value in job logs. Default false; the check secret\_variables\_masked\_and\_protected warns when a secret-looking key is not masked and protected. | <pre>map(object({<br/>    key           = string<br/>    projects      = list(string)<br/>    value         = string<br/>    variable_type = optional(string, "env_var")<br/>    protected     = optional(bool, false)<br/>    masked        = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_projects"></a> [projects](#input\_projects) | Projects to create, keyed by their path relative to parent\_group\_id: "tools" is created directly under it, "platform/infra/api" in the created group "platform/infra". Fields:<br/>  - name                    : Display name; default the last path segment.<br/>  - description             : Optional description.<br/>  - visibility              : private (default), internal or public; never more open than its group's.<br/>  - topics                  : Optional set of topics.<br/>  - default\_branch          : Default branch, created with a README commit; default main.<br/>  - initialize\_with\_readme  : Create the default branch with a README commit; default true. Must stay true for branches to be created.<br/>  - branches                : Extra branches keyed by name, each from ref (default: the default branch); default { develop = {} }.<br/>  - protected\_branches      : Protected branches or wildcards keyed by name, with push\_access\_level and merge\_access\_level (no one, developer, maintainer (default), admin) and allow\_force\_push (default false). Default: the default branch for maintainers, plus develop for developers when it is in branches.<br/>  - protected\_tags          : Protected tags or wildcards keyed by name, with create\_access\_level (no one, developer, maintainer (default), admin); default { "v*" = {} }.<br/>  - merge\_method            : merge (default), rebase\_merge or ff.<br/>  - squash\_option           : never, always, default\_on (default) or default\_off.<br/>  - only\_allow\_merge\_if\_pipeline\_succeeds            : Merge only on a green pipeline; default true.<br/>  - only\_allow\_merge\_if\_all\_discussions\_are\_resolved : Merge only with every thread resolved; default true.<br/>  - remove\_source\_branch\_after\_merge                 : Delete the source branch on merge by default; default true.<br/>  - archive\_on\_destroy            : Archive the project instead of deleting it on destroy; default true.<br/>  - permanently\_delete\_on\_destroy : With archive\_on\_destroy = false, delete the project at once instead of scheduling the deletion; default false.<br/>  - variables     : CI/CD variables keyed by variable key: value, variable\_type (env\_var default, file), protected and masked (default false). Values are redacted in plans and stored in state (SECURITY.md).<br/>  - deploy\_tokens : Deploy tokens keyed by name: username, expires\_at (required, RFC 3339), scopes (read\_repository, read\_registry, write\_registry, read\_package\_registry, write\_package\_registry, read\_virtual\_registry, write\_virtual\_registry).<br/>  - access\_tokens : Access tokens keyed by name: expires\_at (required, YYYY-MM-DD), access\_level (null lets GitLab grant maintainer), scopes.<br/>  - members       : User memberships keyed by any label: user\_id, access\_level (no one, minimal, guest, planner, reporter, security\_manager, developer, maintainer, owner), expires\_at (YYYY-MM-DD).<br/>  - shared\_with   : Shares keyed by any label: exactly one of group (a groups key) or group\_id (an existing group ID), access\_level, expires\_at (YYYY-MM-DD).<br/>  - runners       : Runners keyed by name: description (default the name), access\_level (ref\_protected default, not\_protected), tag\_list (required unless untagged), untagged, paused, locked, maximum\_timeout (seconds, >= 600).<br/>  - deploy\_keys         : SSH deploy keys keyed by title: key (OpenSSH public key), expires\_at (required, RFC 3339), can\_push (default false).<br/>  - pipeline\_schedules  : Schedules keyed by description: ref (full ref, default refs/heads/<default\_branch>), cron (5 fields), active (default true), variables (redacted in plans).<br/>  - pipeline\_triggers   : Set of pipeline trigger descriptions; their tokens are in the pipeline\_trigger\_tokens output.<br/>  - environments        : Environments keyed by name: tier (production, staging, testing, development, other), external\_url, description.<br/>  - labels              : Labels keyed by name: color (#RRGGBB or a CSS colour name), description, priority (>= 0).<br/>  - badges              : Badges keyed by name: link\_url and image\_url (http(s); GitLab placeholders such as %{project\_path} allowed, written with a doubled % in HCL strings).<br/>  - hooks               : Webhooks keyed by name: url (http(s)), push\_events (default true), tag\_push\_events, merge\_requests\_events, pipeline\_events, job\_events, deployment\_events, releases\_events, issues\_events, note\_events (default false), enable\_ssl\_verification (default true), token and signing\_token (redacted in plans, stored in state).<br/>  - job\_token\_allowlist : When set, only the job tokens of this project and of the listed projects and groups (keys of projects / groups, or existing project\_ids / group\_ids) may access the project; null leaves GitLab's default. | <pre>map(object({<br/>    name                   = optional(string)<br/>    description            = optional(string)<br/>    visibility             = optional(string, "private")<br/>    topics                 = optional(set(string))<br/>    default_branch         = optional(string, "main")<br/>    initialize_with_readme = optional(bool, true)<br/>    branches = optional(map(object({<br/>      ref = optional(string)<br/>    })), { develop = {} })<br/>    protected_branches = optional(map(object({<br/>      push_access_level  = optional(string, "maintainer")<br/>      merge_access_level = optional(string, "maintainer")<br/>      allow_force_push   = optional(bool, false)<br/>    })))<br/>    protected_tags = optional(map(object({<br/>      create_access_level = optional(string, "maintainer")<br/>    })), { "v*" = {} })<br/>    merge_method                                     = optional(string, "merge")<br/>    squash_option                                    = optional(string, "default_on")<br/>    only_allow_merge_if_pipeline_succeeds            = optional(bool, true)<br/>    only_allow_merge_if_all_discussions_are_resolved = optional(bool, true)<br/>    remove_source_branch_after_merge                 = optional(bool, true)<br/>    archive_on_destroy                               = optional(bool, true)<br/>    permanently_delete_on_destroy                    = optional(bool, false)<br/>    variables = optional(map(object({<br/>      value         = string<br/>      variable_type = optional(string, "env_var")<br/>      protected     = optional(bool, false)<br/>      masked        = optional(bool, false)<br/>    })), {})<br/>    deploy_tokens = optional(map(object({<br/>      username   = optional(string)<br/>      expires_at = optional(string)<br/>      scopes     = list(string)<br/>    })), {})<br/>    access_tokens = optional(map(object({<br/>      expires_at   = string<br/>      access_level = optional(string)<br/>      scopes       = list(string)<br/>    })), {})<br/>    members = optional(map(object({<br/>      user_id      = number<br/>      access_level = string<br/>      expires_at   = optional(string)<br/>    })), {})<br/>    shared_with = optional(map(object({<br/>      group        = optional(string)<br/>      group_id     = optional(number)<br/>      access_level = string<br/>      expires_at   = optional(string)<br/>    })), {})<br/>    runners = optional(map(object({<br/>      description     = optional(string)<br/>      access_level    = optional(string, "ref_protected")<br/>      tag_list        = optional(list(string), [])<br/>      untagged        = optional(bool, false)<br/>      paused          = optional(bool, false)<br/>      locked          = optional(bool, false)<br/>      maximum_timeout = optional(number)<br/>    })), {})<br/>    labels = optional(map(object({<br/>      color       = string<br/>      description = optional(string)<br/>      priority    = optional(number)<br/>    })), {})<br/>    badges = optional(map(object({<br/>      link_url  = string<br/>      image_url = string<br/>    })), {})<br/>    hooks = optional(map(object({<br/>      url                     = string<br/>      push_events             = optional(bool, true)<br/>      tag_push_events         = optional(bool, false)<br/>      merge_requests_events   = optional(bool, false)<br/>      pipeline_events         = optional(bool, false)<br/>      job_events              = optional(bool, false)<br/>      deployment_events       = optional(bool, false)<br/>      releases_events         = optional(bool, false)<br/>      issues_events           = optional(bool, false)<br/>      note_events             = optional(bool, false)<br/>      enable_ssl_verification = optional(bool, true)<br/>      token                   = optional(string)<br/>      signing_token           = optional(string)<br/>    })), {})<br/>    deploy_keys = optional(map(object({<br/>      key        = string<br/>      expires_at = optional(string)<br/>      can_push   = optional(bool, false)<br/>    })), {})<br/>    pipeline_schedules = optional(map(object({<br/>      ref       = optional(string)<br/>      cron      = string<br/>      active    = optional(bool, true)<br/>      variables = optional(map(string), {})<br/>    })), {})<br/>    pipeline_triggers = optional(set(string), [])<br/>    environments = optional(map(object({<br/>      tier         = optional(string)<br/>      external_url = optional(string)<br/>      description  = optional(string)<br/>    })), {})<br/>    job_token_allowlist = optional(object({<br/>      projects    = optional(set(string), [])<br/>      groups      = optional(set(string), [])<br/>      project_ids = optional(set(number), [])<br/>      group_ids   = optional(set(number), [])<br/>    }))<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_deploy_tokens"></a> [deploy\_tokens](#output\_deploy\_tokens) | Group deploy tokens keyed "<entry>\_<group>" (deploy\_tokens input) or "<group key>:<name>" (groups input): id, group, name, username, token, expires\_at and scopes. Sensitive; username and token log in to the group's repositories and registries. |
| <a name="output_gitlab_runner_tokens"></a> [gitlab\_runner\_tokens](#output\_gitlab\_runner\_tokens) | Runner authentication tokens (glrt-...) keyed like the gitlab\_runners output, for registering the runner manager. Sensitive. |
| <a name="output_gitlab_runners"></a> [gitlab\_runners](#output\_gitlab\_runners) | Runners keyed like the gitlab\_runners input, or "<owner key>:<name>" for created groups and projects: id (the GitLab runner ID), runner\_type, description, group\_id, project\_id, access\_level, tag\_list, maximum\_timeout, paused, untagged and locked |
| <a name="output_group_access_tokens"></a> [group\_access\_tokens](#output\_group\_access\_tokens) | Group access tokens keyed "<entry>\_<group>" (gitlab\_group\_access\_token input) or "<group key>:<name>" (groups input): id, group, name, token, expires\_at, access\_level and scopes. Sensitive. |
| <a name="output_group_variables_ids"></a> [group\_variables\_ids](#output\_group\_variables\_ids) | IDs of the group CI/CD variables, in the form <group>:<key>:<environment\_scope> |
| <a name="output_groups"></a> [groups](#output\_groups) | Created groups keyed like the groups input (path relative to parent\_group\_id): id, full\_path and web\_url |
| <a name="output_pipeline_schedule_ids"></a> [pipeline\_schedule\_ids](#output\_pipeline\_schedule\_ids) | GitLab pipeline schedule IDs keyed like the pipeline\_schedules input, or "<project key>:<description>" for created projects |
| <a name="output_pipeline_trigger_tokens"></a> [pipeline\_trigger\_tokens](#output\_pipeline\_trigger\_tokens) | Pipeline trigger tokens keyed "<project key>:<description>", for triggering the project's pipelines through the API. Sensitive. |
| <a name="output_project_access_tokens"></a> [project\_access\_tokens](#output\_project\_access\_tokens) | Project access tokens keyed "<entry>\_<project>" (gitlab\_project\_access\_token input) or "<project key>:<name>" (projects input): id, project, name, token, expires\_at, access\_level and scopes. Sensitive. |
| <a name="output_project_deploy_tokens"></a> [project\_deploy\_tokens](#output\_project\_deploy\_tokens) | Project deploy tokens keyed "<project key>:<name>": id, project, name, username, token, expires\_at and scopes. Sensitive; username and token log in to the project's repository and registries. |
| <a name="output_project_variables_ids"></a> [project\_variables\_ids](#output\_project\_variables\_ids) | IDs of the project CI/CD variables, in the form <project>:<key>:<environment\_scope> |
| <a name="output_projects"></a> [projects](#output\_projects) | Created projects keyed like the projects input (path relative to parent\_group\_id): id, path\_with\_namespace, web\_url, http\_url\_to\_repo, ssh\_url\_to\_repo and default\_branch |
<!-- END_TF_DOCS -->

## Documentation

| Document | Purpose |
|----------|---------|
| [README.md](README.md) | Module overview, usage, inputs and outputs |
| [SECURITY.md](SECURITY.md) | What lands in state, rotation, least privilege, vulnerability reporting |
| [TESTING.md](TESTING.md) | Unit and integration suites, how to run them locally and in CI |
| [CHANGELOG.md](CHANGELOG.md) | Release history and upgrade notes, curated by hand |
| [examples/](examples/) | Runnable `basic` and `complete` examples |
| [openspec/](openspec/) | Specification of the module's behaviour and planned changes |
| [AGENTS.md](AGENTS.md) | Rules and standards lookup for contributors and coding agents |

## Contributing

1. Open an issue describing the problem or the input you need, using the templates in `.gitlab/issue_templates/`.
2. For a behaviour change, plan it as an [OpenSpec](https://github.com/Fission-AI/OpenSpec) change before writing HCL: `/openspec-propose` in Claude Code or OpenCode creates `openspec/changes/<name>/` with a proposal, delta specs, a design and tasks; `openspec/specs/` holds the current specification. Implement with `/openspec-apply-change`, then `/openspec-archive-change` merges the deltas into the main specs. The engineering standards are OpenSpec stores referenced from `openspec/config.yaml` with a pinned tag; run `mise run spec-setup` once per machine to register them ([AGENTS.md](AGENTS.md) explains when to read them).
3. Create a `feature/<topic>`, `fix/<topic>`, `chore/<topic>` or `docs/<topic>` branch from `develop`, run `mise install` and `pre-commit install` once, then `pre-commit run -a`, `mise run test` and `mise run spec-validate`.
4. Write commit subjects as a capitalised imperative sentence of at most 72 characters without a type prefix (`Add project deploy tokens`, not `feat: add ...`), explain why in the body and reference the issue (`Closes #12`). Declare a pairing partner or an AI coding agent with a `Co-Authored-By:` trailer.
5. Add an entry under `## [Unreleased]` in `CHANGELOG.md`, with the edit consumers must make for anything breaking, then open a merge request into `develop` with the template filled. It stays Draft until the pipeline is green.

## Releasing

A release is an annotated, signed `vX.Y.Z` tag on `main` with a dated `CHANGELOG.md` section. `mise run release` produces one; a tag made by hand that meets both checks is accepted too.

```sh
# On main: runs pre-commit, the unit tests and openspec validate, dates the
# [Unreleased] CHANGELOG section, points the README examples at the new tag,
# commits "Release vX.Y.Z", creates the signed tag and, with --push, pushes
# main and the tag together, then merges main back into develop.
git checkout main && git pull
mise run release major --push     # or: minor | patch | 13.0.0
```

Pick the bump from the CHANGELOG entries, following [semantic versioning](https://semver.org): **major** for anything under *Changed (breaking)* or *Removed*, or a raised OpenTofu or provider floor; **minor** for new inputs, outputs or resources; **patch** for fixes and docs.

On the tag, CI runs `verify:changelog` (the tag is on `main` and its CHANGELOG section is dated and non-empty) plus every validation, scanning and integration job; `create:release` then publishes the GitLab release with that CHANGELOG section as notes. Tags are never moved or deleted: if a tag pipeline fails, fix forward with a new patch release.

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE).

## Disclaimer

This module is provided "as is", without warranty of any kind, express or implied. See the [LICENSE](LICENSE) for details.

[apache]: https://opensource.org/licenses/Apache-2.0
[apache-shield]: https://img.shields.io/badge/License-Apache%202.0-blue.svg

[terraform-badge]: https://img.shields.io/badge/Terraform-%3E%3D1.11-623CE4
[terraform-url]: https://opentofu.org

[provider-badge]: https://img.shields.io/badge/GitLab%20Provider-~%3E19.5-FC6D26
[provider-url]: https://search.opentofu.org/provider/gitlabhq/gitlab/latest

[release-badge]: https://img.shields.io/gitlab/v/release/leminnov/terraform/modules/gitlab-management?include_prereleases&sort=semver
[release-url]: https://gitlab.com/leminnov/terraform/modules/gitlab-management/-/releases
