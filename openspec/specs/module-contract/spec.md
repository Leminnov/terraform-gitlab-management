# module-contract Specification

## Purpose
Cross-cutting contract of the module: supported tooling and provider, how list inputs fan out into stable resource keys, what is redacted in plans and what lands in state, and which outputs a caller can rely on.

## Requirements

### Requirement: Supported tooling and provider
The module SHALL declare `required_version = ">= 1.11.0"` and SHALL pin `gitlabhq/gitlab ~> 19.5` in `versions.tf`. It SHALL work on OpenTofu, and SHALL be tested on OpenTofu 1.11 and on the version pinned in `mise.toml`, against gitlab.com.

#### Scenario: Provider resolution
- **WHEN** the module is initialised
- **THEN** the gitlab provider resolves to a 19.x release at or above 19.5

#### Scenario: Provider below the floor
- **WHEN** the caller's lock file pins provider 18.11
- **THEN** initialisation fails on the `~> 19.5` constraint until the lock is upgraded

### Requirement: No provider or backend configuration
The module SHALL NOT contain `provider {}` or `backend {}` blocks, `local-exec` provisioners or calls to a GitLab CLI or API; the caller configures the gitlab provider (base URL, token) and the state backend.

#### Scenario: Provider block inside the module
- **WHEN** a change adds a `provider "gitlab" {}` or `backend` block to a module file
- **THEN** it is moved to the caller or to the example's `providers.tf`, and the module only declares `required_providers`

### Requirement: Empty inputs create nothing
Every input SHALL default to an empty map, and each resource type SHALL be created only for the entries of its input.

#### Scenario: Call with no input
- **WHEN** the module is called with no argument
- **THEN** the plan contains no resource and every output is an empty map or list

### Requirement: Stable fan-out keys
Inputs with a `groups` or `projects` list SHALL produce one resource per (entry, target) keyed `"<entry>_<target>"`, schedule variables SHALL be keyed `"<schedule>-<variable>"`, and created groups and projects SHALL be keyed by their relative path, so adding or reordering targets never replaces an existing resource.

#### Scenario: Target appended to a list
- **WHEN** a second group is appended to the `groups` list of an existing `group_variables` entry
- **THEN** the plan creates one resource keyed `"<entry>_<new group>"` and changes nothing else

#### Scenario: Targets reordered
- **WHEN** the `groups` list of an entry is reordered
- **THEN** the plan is empty

#### Scenario: Sibling group added
- **WHEN** `platform/data` is added next to an existing `platform/infra`
- **THEN** the plan creates one group and changes nothing else

### Requirement: Values redacted in plan output
CI variable values and pipeline schedule variable values SHALL be sent to the provider as sensitive values, so plan output shows `(sensitive value)` instead of the value, even when the caller passes plain strings.

#### Scenario: Plain-string variable value
- **WHEN** a `group_variables` entry sets `value = "s3cr3t"` and the plan is rendered
- **THEN** the plan shows `value = (sensitive value)` for that variable and never the string

#### Scenario: Caller passes a sensitive value
- **WHEN** the caller sets a `value` from a variable declared `sensitive = true`
- **THEN** the plan succeeds and the value is redacted

### Requirement: What lands in state is documented
The module SHALL list in `SECURITY.md` every secret that lands in state, with its mitigation, because provider 19.5 offers no write-only argument for any of them: CI variable values (standalone and nested), schedule variable values, webhook `token` and `signing_token`, and every created token (group and project deploy tokens, group and project access tokens, runner tokens, pipeline trigger tokens).

#### Scenario: New secret-bearing attribute
- **WHEN** a change sends a new secret to the provider or exposes a new token
- **THEN** the change uses a write-only argument if the provider has one, and otherwise adds a row to the `SECURITY.md` table

#### Scenario: Webhook signing token
- **WHEN** a project hook sets `signing_token`
- **THEN** `SECURITY.md` lists `gitlab_project_hook.this[*].signing_token` as stored in state

### Requirement: Output set
The module SHALL expose exactly these outputs: `groups`, `projects`, `group_variables_ids`, `project_variables_ids`, `deploy_tokens`, `project_deploy_tokens`, `pipeline_schedule_ids`, `pipeline_trigger_tokens`, `gitlab_runners`, `gitlab_runner_tokens`, `group_access_tokens` and `project_access_tokens`. Every output carrying a token SHALL be `sensitive`, and no output SHALL echo a variable value.

#### Scenario: Removed output referenced
- **WHEN** a caller upgrading from v12 references `module.<name>.all_tokens` or `module.<name>.group_variables`
- **THEN** the plan fails with an unsupported attribute error, and the upgrade note names the replacement output

#### Scenario: Token output displayed
- **WHEN** `tofu output` is run without `-json` on a root module re-exporting `deploy_tokens`
- **THEN** the value is shown as `<sensitive>`

#### Scenario: Nested tokens in the shared outputs
- **WHEN** group `platform` declares the deploy token `registry` and `deploy_tokens` also declares a standalone token
- **THEN** `deploy_tokens` holds both, keyed `platform:registry` and `"<entry>_<group>"`

### Requirement: Empty second plan
After a successful apply, a second plan with unchanged inputs SHALL report no change for every resource the module creates.

#### Scenario: Re-plan after apply
- **WHEN** the integration fixture plans again right after apply
- **THEN** `tofu plan -detailed-exitcode` exits 0

### Requirement: Nested object keys
Objects declared inside a `groups` or `projects` entry SHALL be keyed `"<group or project key>:<item key>"`, and nested pipeline schedule variables `"<schedule key>-<variable>"`, so renaming one item or adding a sibling never replaces another resource.

#### Scenario: Nested variable key
- **WHEN** group `platform/infra` declares the variable `DEPLOY_ENV`
- **THEN** the plan creates `gitlab_group_variable.this["platform/infra:DEPLOY_ENV"]`

### Requirement: Standalone keys without colon
The keys of `group_variables`, `project_variables`, `deploy_tokens`, `pipeline_schedules`, `gitlab_runners`, `gitlab_group_access_token` and `gitlab_project_access_token` SHALL NOT contain `:`, so they never collide with nested keys in the resources and outputs they share.

#### Scenario: Colon in a standalone key
- **WHEN** a `deploy_tokens` entry is keyed `registry:prod`
- **THEN** the plan fails with "deploy_tokens keys must not contain \":\" (reserved for objects nested in groups and projects)."

### Requirement: File layout
Resources SHALL live in themed files listed in the header of `main.tf`: `groups.tf`, `projects.tf`, `access.tf`, `ci.tf`, `metadata.tf`, `premium.tf` and `checks.tf`, with addresses unchanged for the resources that existed before.

#### Scenario: Upgrade over the reorganised files
- **WHEN** a v13 state written before the reorganisation is planned with it
- **THEN** no resource is moved, created or destroyed
