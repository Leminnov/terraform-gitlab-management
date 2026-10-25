# access-tokens Specification

## Purpose
Group and project access tokens declared once and created in every group or project of their target list, with access levels, scopes and expiry format accepted exactly as the provider accepts them.

## Requirements

### Requirement: Access tokens fan out across targets
Each `gitlab_group_access_token` entry SHALL create one `gitlab_group_access_token` per group in its `groups` list, and each `gitlab_project_access_token` entry one `gitlab_project_access_token` per project in its `projects` list, with the entry's `name`, `expires_at`, `access_level` (server default `maintainer` when `null`) and `scopes`.

#### Scenario: Group token in two groups
- **WHEN** an entry `ci_bot` sets `groups = ["org/a", "org/b"]`
- **THEN** the plan creates `gitlab_group_access_token.this["ci_bot_org/a"]` and `["ci_bot_org/b"]`

#### Scenario: Project token in one project
- **WHEN** an entry `release_bot` sets `projects = ["org/app"]`
- **THEN** the plan creates `gitlab_project_access_token.this["release_bot_org/app"]`

### Requirement: Access levels
`access_level` SHALL be `null` or one of `no one`, `minimal`, `guest`, `planner`, `reporter`, `security_manager`, `developer`, `maintainer` or `owner`, for group and project tokens alike.

#### Scenario: Underscore spelling
- **WHEN** a group token sets `access_level = "no_one"`
- **THEN** the plan fails with "gitlab_group_access_token[*].access_level must be one of: no one, minimal, guest, planner, reporter, security_manager, developer, maintainer, owner."

#### Scenario: Unknown project token level
- **WHEN** a project token sets `access_level = "admin"`
- **THEN** the plan fails with the message listing the accepted levels

#### Scenario: Planner level
- **WHEN** a project token sets `access_level = "planner"`
- **THEN** the plan succeeds

### Requirement: Group token scopes
Every group token scope SHALL be one of `api`, `read_api`, `read_registry`, `write_registry`, `read_virtual_registry`, `write_virtual_registry`, `read_repository`, `write_repository`, `create_runner`, `manage_runner`, `ai_features`, `k8s_proxy`, `read_observability`, `write_observability` or `self_rotate`.

#### Scenario: Personal-token scope on a group token
- **WHEN** a group token sets `scopes = ["sudo"]`
- **THEN** the plan fails with the message listing the accepted scopes

### Requirement: Project token scopes
Every project token scope SHALL be one of `api`, `read_api`, `read_registry`, `write_registry`, `read_repository`, `write_repository`, `create_runner`, `manage_runner`, `ai_features`, `k8s_proxy`, `read_observability`, `write_observability` or `self_rotate`.

#### Scenario: Virtual registry scope on a project token
- **WHEN** a project token sets `scopes = ["read_virtual_registry"]`
- **THEN** the plan fails with the message listing the accepted scopes

#### Scenario: read_user on a project token
- **WHEN** a project token sets `scopes = ["read_user"]`
- **THEN** the plan fails with the message listing the accepted scopes

### Requirement: Expiry date format
Each group and project token, standalone or nested, SHALL set exactly one of `expires_at` or `rotation_configuration`. `expires_at`, when set, SHALL be in `YYYY-MM-DD` form.

#### Scenario: Timestamp instead of a date
- **WHEN** a group token sets `expires_at = "2027-01-01T00:00:00Z"`
- **THEN** the plan fails with "gitlab_group_access_token[*].expires_at must be a date in YYYY-MM-DD format."

#### Scenario: Malformed project token date
- **WHEN** a project token sets `expires_at = "01/01/2027"`
- **THEN** the plan fails with "gitlab_project_access_token[*].expires_at must be a date in YYYY-MM-DD format."

#### Scenario: Token without expiry or rotation
- **WHEN** a group token sets neither `expires_at` nor `rotation_configuration`
- **THEN** the plan fails with "gitlab_group_access_token[*] must set exactly one of expires_at (YYYY-MM-DD) or rotation_configuration (expiration_days >= 1, 1 <= rotate_before_days < expiration_days)."

#### Scenario: Both expiry and rotation on a project token
- **WHEN** a project token sets both
- **THEN** the plan fails with "gitlab_project_access_token[*] must set exactly one of expires_at (YYYY-MM-DD) or rotation_configuration (expiration_days >= 1, 1 <= rotate_before_days < expiration_days)."

### Requirement: Non-empty targets, name and scopes
Each entry SHALL have a non-empty `groups` (group tokens) or `projects` (project tokens) list, a non-empty `scopes` list and a non-empty `name`.

#### Scenario: Group token without scopes
- **WHEN** a group token sets `scopes = []`
- **THEN** the plan fails with "gitlab_group_access_token[*] must have non-empty groups, scopes, and name."

#### Scenario: Project token without projects
- **WHEN** a project token sets `projects = []`
- **THEN** the plan fails with "gitlab_project_access_token[*] must have non-empty projects, scopes, and name."

### Requirement: Access token outputs
The sensitive outputs `group_access_tokens` and `project_access_tokens` SHALL map each token key, `"<entry>_<target>"` for the standalone inputs and `"<owner key>:<name>"` for created groups and projects, to the token's `id`, its group or project, `name`, `token`, `expires_at`, `access_level` and `scopes`.

#### Scenario: Token used after apply
- **WHEN** a project token with `read_api` is created
- **THEN** `project_access_tokens["<entry>_<project>"].token` authenticates `GET /api/v4/projects/<project>`

### Requirement: Access tokens of created groups and projects
Each `access_tokens` entry of a `groups` or `projects` entry SHALL create a group or project access token named by its key, keyed `"<owner key>:<name>"`. It SHALL take exactly one of `expires_at` (`YYYY-MM-DD`) or `rotation_configuration`, plus `access_level` and `scopes`, under the same rules as the standalone inputs (group or project scope list).

#### Scenario: Release bot on a created project
- **WHEN** project `platform/api` sets `access_tokens = { release_bot = { expires_at = "2027-06-30", access_level = "developer", scopes = ["write_repository"] } }`
- **THEN** the plan creates `gitlab_project_access_token.this["platform/api:release_bot"]`

#### Scenario: Virtual registry scope on a nested project token
- **WHEN** a nested project access token sets `scopes = ["read_virtual_registry"]`
- **THEN** the plan fails with the message listing the accepted project token scopes

#### Scenario: Nested token with a timestamp
- **WHEN** a nested group access token sets `expires_at = "2027-06-30T00:00:00Z"`
- **THEN** the plan fails with "access_tokens[*].expires_at must be a date in YYYY-MM-DD format."

#### Scenario: Nested token without expiry or rotation
- **WHEN** a nested access token sets neither `expires_at` nor `rotation_configuration`
- **THEN** the plan fails with "access_tokens[*] must set exactly one of expires_at (YYYY-MM-DD) or rotation_configuration (expiration_days >= 1, 1 <= rotate_before_days < expiration_days)."

### Requirement: Token rotation at apply
A token with `rotation_configuration = { expiration_days, rotate_before_days }` SHALL be issued for `expiration_days` days, and SHALL be rotated by the first apply that runs within `rotate_before_days` of its expiry. `expires_at` SHALL then be left to GitLab. `expiration_days` SHALL be at least 1, and `rotate_before_days` at least 1 and below `expiration_days`.

#### Scenario: Ninety-day rotating group token
- **WHEN** a group token sets `rotation_configuration = { expiration_days = 90, rotate_before_days = 14 }`
- **THEN** the plan sends that rotation and no `expires_at`, and the `group_access_tokens` output shows the expiry GitLab set

#### Scenario: Rotation window as long as the lifetime
- **WHEN** a project token sets `rotation_configuration = { expiration_days = 30, rotate_before_days = 30 }`
- **THEN** the plan fails with "gitlab_project_access_token[*] must set exactly one of expires_at (YYYY-MM-DD) or rotation_configuration (expiration_days >= 1, 1 <= rotate_before_days < expiration_days)."
