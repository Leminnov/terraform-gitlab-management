# Spec Delta

## ADDED Requirements

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

## MODIFIED Requirements

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
