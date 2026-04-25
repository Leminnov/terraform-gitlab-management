# Gitlab Terraform Module

[![Apache 2.0][apache-shield]][apache]
[![Terraform][terraform-badge]][terraform-url]
[![Latest Release][release-badge]][release-url]

Terraform module which initialize Gitlab with:

- Group Variables
- Project Variables
- Deploy Tokens
- Pipeline Schedules
- GitLab Runners
- Group Access Tokens
- Project Access Tokens

## Usage

```hcl
module "gitlab_management" {
  source  = "gitlab.com/leminnov/terraform/modules/gitlab-management"
  version = "~> 1.0"

  group_variables = {
    pipeline_log_level = {
      key           = "PIPELINE_LOG_LEVEL"
      groups        = ["my-org/platform"]
      value         = "info"
      variable_type = "env_var"
      protected     = false
      masked        = false
    }
  }
}
```

See [`examples/basic`](examples/basic) for the simplest usage, or [`examples/complete`](examples/complete) for every input exercised together.

## Documentation

| File | Purpose |
|------|---------|
| [README.md](README.md) | This file — overview, usage, inputs/outputs |
| [SECURITY.md](SECURITY.md) | Security considerations, secret handling, reporting vulnerabilities |
| [TESTING.md](TESTING.md) | How to run tests locally and in CI |
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guidelines |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_gitlab"></a> [gitlab](#requirement\_gitlab) | ~> 18.11 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_gitlab"></a> [gitlab](#provider\_gitlab) | 18.11.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [gitlab_deploy_token.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/deploy_token) | resource |
| [gitlab_group_access_token.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group_access_token) | resource |
| [gitlab_group_variable.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group_variable) | resource |
| [gitlab_pipeline_schedule.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/pipeline_schedule) | resource |
| [gitlab_pipeline_schedule_variable.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/pipeline_schedule_variable) | resource |
| [gitlab_project_access_token.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/project_access_token) | resource |
| [gitlab_project_variable.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/project_variable) | resource |
| [gitlab_user_runner.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/user_runner) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_deploy_tokens"></a> [deploy\_tokens](#input\_deploy\_tokens) | Map of GitLab group deploy tokens. Each entry is expanded across its `groups` list. Fields:<br/>  - groups      : Group paths or IDs to create the token in. Must be non-empty.<br/>  - name        : Human-readable token name.<br/>  - username    : Optional token username.<br/>  - expires\_at  : Optional expiration timestamp (YYYY-MM-DD or ISO-8601).<br/>  - scopes      : Token scopes. Must be non-empty; see `_deploy_token_scopes` in locals for allowed values. | <pre>map(object({<br/>    groups     = list(string)<br/>    name       = string<br/>    username   = optional(string)<br/>    expires_at = optional(string)<br/>    scopes     = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_gitlab_group_access_token"></a> [gitlab\_group\_access\_token](#input\_gitlab\_group\_access\_token) | Map of GitLab group access tokens. Each entry is expanded across its `groups` list. Fields:<br/>  - groups        : Group paths or IDs to create the token in. Must be non-empty.<br/>  - name          : Human-readable token name.<br/>  - expires\_at    : Required expiration date (YYYY-MM-DD or ISO-8601). GitLab disallows perpetual tokens.<br/>  - access\_level  : One of no\_one, minimal, guest, reporter, developer, maintainer, owner.<br/>  - scopes        : Token scopes. Must be non-empty. | <pre>map(object({<br/>    groups       = list(string)<br/>    name         = string<br/>    expires_at   = string<br/>    access_level = optional(string)<br/>    scopes       = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_gitlab_project_access_token"></a> [gitlab\_project\_access\_token](#input\_gitlab\_project\_access\_token) | Map of GitLab project access tokens. Each entry is expanded across its `projects` list. Fields:<br/>  - projects      : Project paths or IDs to create the token in. Must be non-empty.<br/>  - name          : Human-readable token name.<br/>  - expires\_at    : Required expiration date (YYYY-MM-DD or ISO-8601).<br/>  - access\_level  : One of no\_one, minimal, guest, reporter, developer, maintainer, owner.<br/>  - scopes        : Token scopes. Must be non-empty. | <pre>map(object({<br/>    projects     = list(string)<br/>    name         = string<br/>    expires_at   = string<br/>    access_level = optional(string)<br/>    scopes       = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_gitlab_runners"></a> [gitlab\_runners](#input\_gitlab\_runners) | Map of GitLab runner registrations (gitlab\_user\_runner). Fields:<br/>  - runner\_type     : "group\_type", "project\_type", or "instance\_type".<br/>  - description     : Human-readable description.<br/>  - group\_id        : Group ID (required when runner\_type == "group\_type").<br/>  - project\_id      : Project ID (required when runner\_type == "project\_type").<br/>  - access\_level    : "not\_protected" or "ref\_protected".<br/>  - tag\_list        : Runner tags. Required to be non-empty when `untagged = false`.<br/>  - maximum\_timeout : Optional max job timeout in seconds (min 600).<br/>  - paused          : Whether the runner starts paused.<br/>  - untagged        : Whether to run untagged jobs.<br/>  - locked          : Whether the runner is locked to its project. | <pre>map(object({<br/>    runner_type     = string<br/>    description     = string<br/>    group_id        = optional(string)<br/>    project_id      = optional(string)<br/>    access_level    = string<br/>    tag_list        = list(string)<br/>    maximum_timeout = optional(number)<br/>    paused          = bool<br/>    untagged        = bool<br/>    locked          = bool<br/>  }))</pre> | `{}` | no |
| <a name="input_group_variables"></a> [group\_variables](#input\_group\_variables) | Map of GitLab group CI/CD variables. Each entry is expanded across its `groups` list, producing one `gitlab_group_variable` per (entry, group). Fields:<br/>  - key            : Variable key as it appears in GitLab.<br/>  - groups         : Group paths or IDs to create this variable in. Must be non-empty.<br/>  - value          : Variable value.<br/>  - variable\_type  : "env\_var" (default) or "file".<br/>  - protected      : Expose only to protected refs. Default false.<br/>  - masked         : Mask the value in job logs. Default false. | <pre>map(object({<br/>    key           = string<br/>    groups        = list(string)<br/>    value         = string<br/>    variable_type = optional(string, "env_var")<br/>    protected     = optional(bool, false)<br/>    masked        = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_pipeline_schedules"></a> [pipeline\_schedules](#input\_pipeline\_schedules) | Map of GitLab pipeline schedules. Fields:<br/>  - project      : Project path or ID.<br/>  - description  : Schedule description.<br/>  - ref          : Git ref (branch/tag) to run against.<br/>  - cron         : Cron expression (e.g. "0 2 * * *").<br/>  - active       : Whether the schedule is active.<br/>  - variables    : Optional map of pipeline variables keyed by variable name. | <pre>map(object({<br/>    project     = string<br/>    description = string<br/>    ref         = string<br/>    cron        = string<br/>    active      = bool<br/>    variables   = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_project_variables"></a> [project\_variables](#input\_project\_variables) | Map of GitLab project CI/CD variables. Each entry is expanded across its `projects` list. Fields:<br/>  - key            : Variable key as it appears in GitLab.<br/>  - projects       : Project paths or IDs to create this variable in. Must be non-empty.<br/>  - value          : Variable value.<br/>  - variable\_type  : "env\_var" (default) or "file".<br/>  - protected      : Expose only to protected refs. Default false.<br/>  - masked         : Mask the value in job logs. Default false. | <pre>map(object({<br/>    key           = string<br/>    projects      = list(string)<br/>    value         = string<br/>    variable_type = optional(string, "env_var")<br/>    protected     = optional(bool, false)<br/>    masked        = optional(bool, false)<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_all_tokens"></a> [all\_tokens](#output\_all\_tokens) | Consolidated map of all tokens (deploy, group access, project access) |
| <a name="output_deploy_tokens"></a> [deploy\_tokens](#output\_deploy\_tokens) | Map of all deploy tokens with comprehensive details |
| <a name="output_deploy_tokens_by_group"></a> [deploy\_tokens\_by\_group](#output\_deploy\_tokens\_by\_group) | Deploy tokens organized by group ID |
| <a name="output_deploy_tokens_summary"></a> [deploy\_tokens\_summary](#output\_deploy\_tokens\_summary) | Summary of deploy tokens (non-sensitive metadata) |
| <a name="output_gitlab_runner_tokens"></a> [gitlab\_runner\_tokens](#output\_gitlab\_runner\_tokens) | Map of runner authentication tokens |
| <a name="output_gitlab_runners"></a> [gitlab\_runners](#output\_gitlab\_runners) | Map of all GitLab runners with their configurations |
| <a name="output_gitlab_runners_by_type"></a> [gitlab\_runners\_by\_type](#output\_gitlab\_runners\_by\_type) | Runners organized by type (group\_type or project\_type) |
| <a name="output_group_access_tokens"></a> [group\_access\_tokens](#output\_group\_access\_tokens) | Map of all group access tokens with comprehensive details |
| <a name="output_group_access_tokens_by_group"></a> [group\_access\_tokens\_by\_group](#output\_group\_access\_tokens\_by\_group) | Group access tokens organized by group ID |
| <a name="output_group_access_tokens_summary"></a> [group\_access\_tokens\_summary](#output\_group\_access\_tokens\_summary) | Summary of group access tokens (non-sensitive metadata) |
| <a name="output_group_variables"></a> [group\_variables](#output\_group\_variables) | Map of all created group variables with their configurations |
| <a name="output_group_variables_ids"></a> [group\_variables\_ids](#output\_group\_variables\_ids) | List of all group variable IDs |
| <a name="output_pipeline_schedule_ids"></a> [pipeline\_schedule\_ids](#output\_pipeline\_schedule\_ids) | Map of pipeline schedule names to their IDs |
| <a name="output_pipeline_schedule_variables"></a> [pipeline\_schedule\_variables](#output\_pipeline\_schedule\_variables) | Map of all pipeline schedule variables |
| <a name="output_pipeline_schedules"></a> [pipeline\_schedules](#output\_pipeline\_schedules) | Map of all pipeline schedules with their details |
| <a name="output_project_access_tokens"></a> [project\_access\_tokens](#output\_project\_access\_tokens) | Map of all project access tokens with comprehensive details |
| <a name="output_project_access_tokens_by_project"></a> [project\_access\_tokens\_by\_project](#output\_project\_access\_tokens\_by\_project) | Project access tokens organized by project ID |
| <a name="output_project_access_tokens_summary"></a> [project\_access\_tokens\_summary](#output\_project\_access\_tokens\_summary) | Summary of project access tokens (non-sensitive metadata) |
| <a name="output_project_variables"></a> [project\_variables](#output\_project\_variables) | Map of all created project variables with their configurations |
| <a name="output_project_variables_ids"></a> [project\_variables\_ids](#output\_project\_variables\_ids) | List of all project variable IDs |
| <a name="output_resource_counts"></a> [resource\_counts](#output\_resource\_counts) | Count of all created resources by type |
<!-- END_TF_DOCS -->

## License
[![Apache 2.0][apache-shield]][apache]

This work by LEMINNOV is licensed under the Apache License, Version 2.0.

You may obtain a copy of the License at:
http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

[![Apache 2.0][apache-image]][apache]

[apache]: http://www.apache.org/licenses/LICENSE-2.0
[apache-image]: https://img.shields.io/badge/License-Apache%202.0-blue.svg
[apache-shield]: https://img.shields.io/badge/License-Apache%202.0-blue.svg

[terraform-badge]: https://img.shields.io/badge/Terraform-%3E%3D1.10.7-purple.svg
[terraform-url]: https://www.terraform.io/downloads.html

[release-badge]: https://img.shields.io/gitlab/v/release/leminnov/terraform/modules/gitlab?include_prereleases&sort=semver
[release-url]: https://gitlab.com/leminnov/terraform/modules/gitlab/-/releases
