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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.7 |
| <a name="requirement_gitlab"></a> [gitlab](#requirement\_gitlab) | ~> 18.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_gitlab"></a> [gitlab](#provider\_gitlab) | ~> 18.6 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
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
|------|-------------|------|---------|:--------:|
| <a name="input_deploy_tokens"></a> [deploy\_tokens](#input\_deploy\_tokens) | Map of Gitlab Deploy-Token variables objects | `any` | `{}` | no |
| <a name="input_gitlab_group_access_token"></a> [gitlab\_group\_access\_token](#input\_gitlab\_group\_access\_token) | Map of Gitlab Group access token | `any` | `{}` | no |
| <a name="input_gitlab_project_access_token"></a> [gitlab\_project\_access\_token](#input\_gitlab\_project\_access\_token) | Map of Gitlab Project access token | `any` | `{}` | no |
| <a name="input_gitlab_runners"></a> [gitlab\_runners](#input\_gitlab\_runners) | Map of Gitlab Runners | `any` | `{}` | no |
| <a name="input_group_variables"></a> [group\_variables](#input\_group\_variables) | Map of Gitlab group variables objects | `any` | `{}` | no |
| <a name="input_pipeline_schedules"></a> [pipeline\_schedules](#input\_pipeline\_schedules) | Map of Gitlab pipeline schedules | `map(any)` | `{}` | no |
| <a name="input_project_variables"></a> [project\_variables](#input\_project\_variables) | Map of Gitlab project variables objects | `any` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
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
