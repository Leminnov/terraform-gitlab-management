# Spec Delta

## MODIFIED Requirements

### Requirement: Values redacted in plan output
CI variable values, pipeline schedule variable values and secure file contents SHALL be sent to the provider as sensitive values, so plan output shows `(sensitive value)` instead of the value, even when the caller passes plain strings.

#### Scenario: Plain-string variable value
- **WHEN** a `group_variables` entry sets `value = "s3cr3t"` and the plan is rendered
- **THEN** the plan shows `value = (sensitive value)` for that variable and never the string

#### Scenario: Caller passes a sensitive value
- **WHEN** the caller sets a `value` from a variable declared `sensitive = true`
- **THEN** the plan succeeds and the value is redacted

#### Scenario: Secure file content
- **WHEN** a project sets `secure_files = { "ca.pem" = "-----BEGIN CERTIFICATE-----..." }`
- **THEN** the plan shows the content as `(sensitive value)`

### Requirement: What lands in state is documented
The module SHALL list in `SECURITY.md` every secret that lands in state, with its mitigation, because provider 19.5 offers no write-only argument for any of them:
- CI variable values (standalone and nested);
- schedule variable values;
- secure file contents;
- webhook `token` and `signing_token`;
- every created token: group and project deploy tokens, group and project access tokens, service-account tokens, runner tokens, pipeline trigger tokens and Kubernetes agent tokens.

#### Scenario: New secret-bearing attribute
- **WHEN** a change sends a new secret to the provider or exposes a new token
- **THEN** the change uses a write-only argument if the provider has one, and otherwise adds a row to the `SECURITY.md` table

#### Scenario: Webhook signing token
- **WHEN** a project hook sets `signing_token`
- **THEN** `SECURITY.md` lists `gitlab_project_hook.this[*].signing_token` as stored in state

#### Scenario: Service account token
- **WHEN** a service account declares a token
- **THEN** `SECURITY.md` lists `gitlab_group_service_account_access_token.this[*].token` and `gitlab_project_service_account_access_token.this[*].token` as stored in state, with their rotation

### Requirement: Output set
The module SHALL expose exactly these outputs:
- `groups`, `projects`;
- `group_variables_ids`, `project_variables_ids`;
- `deploy_tokens`, `project_deploy_tokens`;
- `pipeline_schedule_ids`, `pipeline_trigger_tokens`;
- `gitlab_runners`, `gitlab_runner_tokens`;
- `group_access_tokens`, `project_access_tokens`;
- `service_accounts`, `service_account_tokens`;
- `kubernetes_agent_tokens`.

Every output carrying a token SHALL be `sensitive`, and no output SHALL echo a variable value or a secure file.

#### Scenario: Removed output referenced
- **WHEN** a caller upgrading from v12 references `module.<name>.all_tokens` or `module.<name>.group_variables`
- **THEN** the plan fails with an unsupported attribute error, and the upgrade note names the replacement output

#### Scenario: Token output displayed
- **WHEN** `tofu output` is run without `-json` on a root module re-exporting `deploy_tokens`
- **THEN** the value is shown as `<sensitive>`

#### Scenario: Nested tokens in the shared outputs
- **WHEN** group `platform` declares the deploy token `registry` and `deploy_tokens` also declares a standalone token
- **THEN** `deploy_tokens` holds both, keyed `platform:registry` and `"<entry>_<group>"`

### Requirement: Standalone keys without colon
The keys of `group_variables`, `project_variables`, `deploy_tokens`, `pipeline_schedules`, `gitlab_runners`, `gitlab_group_access_token`, `gitlab_project_access_token` and `service_accounts` SHALL NOT contain `:`, so they never collide with nested keys in the resources and outputs they share.

#### Scenario: Colon in a standalone key
- **WHEN** a `deploy_tokens` entry is keyed `registry:prod`
- **THEN** the plan fails with "deploy_tokens keys must not contain \":\" (reserved for objects nested in groups and projects)."

#### Scenario: Colon in a service account key
- **WHEN** a `service_accounts` entry is keyed `ci:bot`
- **THEN** the plan fails with "service_accounts keys must not contain \":\" (reserved for objects nested in groups and projects)."

### Requirement: File layout
Resources SHALL live in themed files listed in the header of `main.tf`: `groups.tf`, `projects.tf`, `access.tf`, `service_accounts.tf`, `ci.tf`, `registry.tf`, `files.tf`, `metadata.tf`, `premium.tf` and `checks.tf`, with addresses unchanged for the resources that existed before.

#### Scenario: Upgrade over the reorganised files
- **WHEN** a v13.0.0 state is planned with this version and the same inputs
- **THEN** the plan is empty
