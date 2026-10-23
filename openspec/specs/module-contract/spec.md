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
Inputs with a `groups` or `projects` list SHALL produce one resource per (entry, target) keyed `"<entry>_<target>"`, and schedule variables SHALL be keyed `"<schedule>-<variable>"`, so adding or reordering targets never replaces an existing resource.

#### Scenario: Target appended to a list
- **WHEN** a second group is appended to the `groups` list of an existing `group_variables` entry
- **THEN** the plan creates one resource keyed `"<entry>_<new group>"` and changes nothing else

#### Scenario: Targets reordered
- **WHEN** the `groups` list of an entry is reordered
- **THEN** the plan is empty

### Requirement: Values redacted in plan output
CI variable values and pipeline schedule variable values SHALL be sent to the provider as sensitive values, so plan output shows `(sensitive value)` instead of the value, even when the caller passes plain strings.

#### Scenario: Plain-string variable value
- **WHEN** a `group_variables` entry sets `value = "s3cr3t"` and the plan is rendered
- **THEN** the plan shows `value = (sensitive value)` for that variable and never the string

#### Scenario: Caller passes a sensitive value
- **WHEN** the caller sets a `value` from a variable declared `sensitive = true`
- **THEN** the plan succeeds and the value is redacted

### Requirement: What lands in state is documented
The module SHALL list in `SECURITY.md` every secret that lands in state (CI variable values, schedule variable values, deploy, access and runner tokens), with its mitigation, because provider 19.5 offers no write-only argument for any of them.

#### Scenario: New secret-bearing attribute
- **WHEN** a change sends a new secret to the provider or exposes a new token
- **THEN** the change uses a write-only argument if the provider has one, and otherwise adds a row to the `SECURITY.md` table

### Requirement: Output set
The module SHALL expose exactly these outputs: `group_variables_ids`, `project_variables_ids`, `deploy_tokens`, `pipeline_schedule_ids`, `gitlab_runners`, `gitlab_runner_tokens`, `group_access_tokens` and `project_access_tokens`. Every output carrying a token SHALL be `sensitive`, and no output SHALL echo a variable value.

#### Scenario: Removed output referenced
- **WHEN** a caller upgrading from v12 references `module.<name>.all_tokens` or `module.<name>.group_variables`
- **THEN** the plan fails with an unsupported attribute error, and the upgrade note names the replacement output

#### Scenario: Token output displayed
- **WHEN** `tofu output` is run without `-json` on a root module re-exporting `deploy_tokens`
- **THEN** the value is shown as `<sensitive>`

### Requirement: Empty second plan
After a successful apply, a second plan with unchanged inputs SHALL report no change for every resource the module creates.

#### Scenario: Re-plan after apply
- **WHEN** the integration fixture plans again right after apply
- **THEN** `tofu plan -detailed-exitcode` exits 0
