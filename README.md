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

## Security Considerations

1. CI variable values, schedule variable values and every token GitLab creates land in state, since the provider has no write-only arguments for them: keep the state in an encrypted, access-restricted backend. [SECURITY.md](SECURITY.md) lists each one with its mitigation.
2. Values are redacted in plan output (`(sensitive value)`); pass secrets from `TF_VAR_*` or a secret store, never from a committed file.
3. Three plan-time warnings (`check` blocks in `checks.tf`) flag configurations GitLab accepts but that weaken security, naming the entries and never a value:
   - `secret_variables_masked_and_protected`: a variable whose key contains `TOKEN`, `PASSWORD`, `PASSWD`, `SECRET`, `PRIVATE_KEY`, `API_KEY` or `CREDENTIAL` (any case) is not both masked and protected;
   - `token_lifetime`: a deploy or access token expires more than one year after the plan;
   - `access_token_privilege`: an access token has `access_level = "owner"`, or no level (GitLab then grants `maintainer`).
4. Every deploy and access token needs an expiry; rotate tokens before it (see [SECURITY.md](SECURITY.md)).

## Documentation

| File | Purpose |
|------|---------|
| [README.md](README.md) | This file — overview, usage, inputs/outputs |
| [SECURITY.md](SECURITY.md) | Security considerations, secret handling, reporting vulnerabilities |
| [TESTING.md](TESTING.md) | How to run tests locally and in CI |
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [openspec/](openspec/) | Specification of the module's behaviour and planned changes |

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
| [gitlab_group_access_token.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group_access_token) | resource |
| [gitlab_group_deploy_token.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group_deploy_token) | resource |
| [gitlab_group_variable.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/group_variable) | resource |
| [gitlab_pipeline_schedule.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/pipeline_schedule) | resource |
| [gitlab_pipeline_schedule_variable.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/pipeline_schedule_variable) | resource |
| [gitlab_project_access_token.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/project_access_token) | resource |
| [gitlab_project_variable.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/project_variable) | resource |
| [gitlab_user_runner.this](https://registry.terraform.io/providers/gitlabhq/gitlab/latest/docs/resources/user_runner) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_deploy_tokens"></a> [deploy\_tokens](#input\_deploy\_tokens) | Map of GitLab group deploy tokens. Each entry is expanded across its `groups` list. Fields:<br/>  - groups      : Group paths or IDs to create the token in. Must be non-empty.<br/>  - name        : Human-readable token name.<br/>  - username    : Optional token username; null lets GitLab generate gitlab+deploy-token-<n>.<br/>  - expires\_at  : Required expiry, an RFC 3339 timestamp such as 2027-06-30T00:00:00Z (the provider rejects a bare date), at most one year ahead (see the token\_lifetime check); without one the token would never expire.<br/>  - scopes      : Token scopes, non-empty: read\_repository, read\_registry, write\_registry, read\_package\_registry, write\_package\_registry, read\_virtual\_registry, write\_virtual\_registry. | <pre>map(object({<br/>    groups     = list(string)<br/>    name       = string<br/>    username   = optional(string)<br/>    expires_at = optional(string)<br/>    scopes     = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_gitlab_group_access_token"></a> [gitlab\_group\_access\_token](#input\_gitlab\_group\_access\_token) | Map of GitLab group access tokens. Each entry is expanded across its `groups` list. Fields:<br/>  - groups        : Group paths or IDs to create the token in. Must be non-empty.<br/>  - name          : Human-readable token name.<br/>  - expires\_at    : Required expiry date, YYYY-MM-DD, within the instance's maximum token lifetime.<br/>  - access\_level  : One of no one, minimal, guest, planner, reporter, security\_manager, developer, maintainer, owner; null lets GitLab grant maintainer.<br/>  - scopes        : Token scopes, non-empty: api, read\_api, read\_registry, write\_registry, read\_virtual\_registry, write\_virtual\_registry, read\_repository, write\_repository, create\_runner, manage\_runner, ai\_features, k8s\_proxy, read\_observability, write\_observability, self\_rotate. | <pre>map(object({<br/>    groups       = list(string)<br/>    name         = string<br/>    expires_at   = string<br/>    access_level = optional(string)<br/>    scopes       = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_gitlab_project_access_token"></a> [gitlab\_project\_access\_token](#input\_gitlab\_project\_access\_token) | Map of GitLab project access tokens. Each entry is expanded across its `projects` list. Fields:<br/>  - projects      : Project paths or IDs to create the token in. Must be non-empty.<br/>  - name          : Human-readable token name.<br/>  - expires\_at    : Required expiry date, YYYY-MM-DD, within the instance's maximum token lifetime.<br/>  - access\_level  : One of no one, minimal, guest, planner, reporter, security\_manager, developer, maintainer, owner; null lets GitLab grant maintainer.<br/>  - scopes        : Token scopes, non-empty: api, read\_api, read\_registry, write\_registry, read\_repository, write\_repository, create\_runner, manage\_runner, ai\_features, k8s\_proxy, read\_observability, write\_observability, self\_rotate. | <pre>map(object({<br/>    projects     = list(string)<br/>    name         = string<br/>    expires_at   = string<br/>    access_level = optional(string)<br/>    scopes       = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_gitlab_runners"></a> [gitlab\_runners](#input\_gitlab\_runners) | Map of GitLab runner registrations (gitlab\_user\_runner). Fields:<br/>  - runner\_type     : "group\_type", "project\_type", or "instance\_type".<br/>  - description     : Human-readable description.<br/>  - group\_id        : Numeric group ID, not a path (required when runner\_type == "group\_type").<br/>  - project\_id      : Numeric project ID, not a path (required when runner\_type == "project\_type").<br/>  - access\_level    : "not\_protected" or "ref\_protected".<br/>  - tag\_list        : Runner tags. Required to be non-empty when `untagged = false`.<br/>  - maximum\_timeout : Optional max job timeout in seconds (min 600).<br/>  - paused          : Whether the runner starts paused.<br/>  - untagged        : Whether to run untagged jobs.<br/>  - locked          : Whether the runner is locked to its project. | <pre>map(object({<br/>    runner_type     = string<br/>    description     = string<br/>    group_id        = optional(string)<br/>    project_id      = optional(string)<br/>    access_level    = string<br/>    tag_list        = list(string)<br/>    maximum_timeout = optional(number)<br/>    paused          = bool<br/>    untagged        = bool<br/>    locked          = bool<br/>  }))</pre> | `{}` | no |
| <a name="input_group_variables"></a> [group\_variables](#input\_group\_variables) | Map of GitLab group CI/CD variables. Each entry is expanded across its `groups` list, producing one `gitlab_group_variable` per (entry, group). Fields:<br/>  - key            : Variable key as it appears in GitLab.<br/>  - groups         : Group paths or IDs to create this variable in. Must be non-empty.<br/>  - value          : Variable value. Redacted in plan output but stored in state (SECURITY.md); pass secrets from TF\_VAR\_* or a secret store, never from a committed file.<br/>  - variable\_type  : "env\_var" (default) or "file".<br/>  - protected      : Expose only to protected refs. Default false.<br/>  - masked         : Mask the value in job logs. Default false; the check secret\_variables\_masked\_and\_protected warns when a secret-looking key is not masked and protected. | <pre>map(object({<br/>    key           = string<br/>    groups        = list(string)<br/>    value         = string<br/>    variable_type = optional(string, "env_var")<br/>    protected     = optional(bool, false)<br/>    masked        = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_pipeline_schedules"></a> [pipeline\_schedules](#input\_pipeline\_schedules) | Map of GitLab pipeline schedules. Fields:<br/>  - project      : Project path or ID.<br/>  - description  : Schedule description.<br/>  - ref          : Full git ref to run against: refs/heads/<branch> or refs/tags/<tag> (provider 19.4+ rejects a short name such as main).<br/>  - cron         : Cron expression with 5 fields (e.g. "0 2 * * *"), in the schedule's time zone (GitLab default UTC).<br/>  - active       : Whether the schedule is active.<br/>  - variables    : Optional map of pipeline variables keyed by variable name. Values are redacted in plan output but stored in state (SECURITY.md). | <pre>map(object({<br/>    project     = string<br/>    description = string<br/>    ref         = string<br/>    cron        = string<br/>    active      = bool<br/>    variables   = optional(map(string), {})<br/>  }))</pre> | `{}` | no |
| <a name="input_project_variables"></a> [project\_variables](#input\_project\_variables) | Map of GitLab project CI/CD variables. Each entry is expanded across its `projects` list. Fields:<br/>  - key            : Variable key as it appears in GitLab.<br/>  - projects       : Project paths or IDs to create this variable in. Must be non-empty.<br/>  - value          : Variable value. Redacted in plan output but stored in state (SECURITY.md); pass secrets from TF\_VAR\_* or a secret store, never from a committed file.<br/>  - variable\_type  : "env\_var" (default) or "file".<br/>  - protected      : Expose only to protected refs. Default false.<br/>  - masked         : Mask the value in job logs. Default false; the check secret\_variables\_masked\_and\_protected warns when a secret-looking key is not masked and protected. | <pre>map(object({<br/>    key           = string<br/>    projects      = list(string)<br/>    value         = string<br/>    variable_type = optional(string, "env_var")<br/>    protected     = optional(bool, false)<br/>    masked        = optional(bool, false)<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_deploy_tokens"></a> [deploy\_tokens](#output\_deploy\_tokens) | Group deploy tokens keyed "<entry>\_<group>": id, group, name, username, token, expires\_at and scopes. Sensitive; username and token log in to the group's repositories and registries. |
| <a name="output_gitlab_runner_tokens"></a> [gitlab\_runner\_tokens](#output\_gitlab\_runner\_tokens) | Runner authentication tokens (glrt-...) keyed like the gitlab\_runners input, for registering the runner manager. Sensitive. |
| <a name="output_gitlab_runners"></a> [gitlab\_runners](#output\_gitlab\_runners) | Runners keyed like the gitlab\_runners input: id (the GitLab runner ID), runner\_type, description, group\_id, project\_id, access\_level, tag\_list, maximum\_timeout, paused, untagged and locked |
| <a name="output_group_access_tokens"></a> [group\_access\_tokens](#output\_group\_access\_tokens) | Group access tokens keyed "<entry>\_<group>": id, group, name, token, expires\_at, access\_level and scopes. Sensitive. |
| <a name="output_group_variables_ids"></a> [group\_variables\_ids](#output\_group\_variables\_ids) | IDs of the group CI/CD variables, in the form <group>:<key>:<environment\_scope> |
| <a name="output_pipeline_schedule_ids"></a> [pipeline\_schedule\_ids](#output\_pipeline\_schedule\_ids) | GitLab pipeline schedule IDs keyed like the pipeline\_schedules input |
| <a name="output_project_access_tokens"></a> [project\_access\_tokens](#output\_project\_access\_tokens) | Project access tokens keyed "<entry>\_<project>": id, project, name, token, expires\_at, access\_level and scopes. Sensitive. |
| <a name="output_project_variables_ids"></a> [project\_variables\_ids](#output\_project\_variables\_ids) | IDs of the project CI/CD variables, in the form <project>:<key>:<environment\_scope> |
<!-- END_TF_DOCS -->

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
