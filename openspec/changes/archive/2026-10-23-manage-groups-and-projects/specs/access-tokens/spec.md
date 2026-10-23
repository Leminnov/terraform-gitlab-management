# Spec Delta

## ADDED Requirements

### Requirement: Access tokens of created groups and projects
Each `access_tokens` entry of a `groups` or `projects` entry SHALL create a group or project access token named by its key, with `expires_at` (required, `YYYY-MM-DD`), `access_level` and `scopes` under the same rules as the standalone inputs (group or project scope list), keyed `"<owner key>:<name>"`.

#### Scenario: Release bot on a created project
- **WHEN** project `platform/api` sets `access_tokens = { release_bot = { expires_at = "2027-06-30", access_level = "developer", scopes = ["write_repository"] } }`
- **THEN** the plan creates `gitlab_project_access_token.this["platform/api:release_bot"]`

#### Scenario: Virtual registry scope on a nested project token
- **WHEN** a nested project access token sets `scopes = ["read_virtual_registry"]`
- **THEN** the plan fails with the message listing the accepted project token scopes

#### Scenario: Nested token with a timestamp
- **WHEN** a nested group access token sets `expires_at = "2027-06-30T00:00:00Z"`
- **THEN** the plan fails with "access_tokens[*].expires_at must be a date in YYYY-MM-DD format."

## MODIFIED Requirements

### Requirement: Access token outputs
The sensitive outputs `group_access_tokens` and `project_access_tokens` SHALL map each token key, `"<entry>_<target>"` for the standalone inputs and `"<owner key>:<name>"` for created groups and projects, to the token's `id`, its group or project, `name`, `token`, `expires_at`, `access_level` and `scopes`.

#### Scenario: Token used after apply
- **WHEN** a project token with `read_api` is created
- **THEN** `project_access_tokens["<entry>_<project>"].token` authenticates `GET /api/v4/projects/<project>`
