# Spec Delta

## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Token rotation at apply
A token with `rotation_configuration = { expiration_days, rotate_before_days }` SHALL be issued for `expiration_days` days, and SHALL be rotated by the first apply that runs within `rotate_before_days` of its expiry. `expires_at` SHALL then be left to GitLab. `expiration_days` SHALL be at least 1, and `rotate_before_days` at least 1 and below `expiration_days`.

#### Scenario: Ninety-day rotating group token
- **WHEN** a group token sets `rotation_configuration = { expiration_days = 90, rotate_before_days = 14 }`
- **THEN** the plan sends that rotation and no `expires_at`, and the `group_access_tokens` output shows the expiry GitLab set

#### Scenario: Rotation window as long as the lifetime
- **WHEN** a project token sets `rotation_configuration = { expiration_days = 30, rotate_before_days = 30 }`
- **THEN** the plan fails with "gitlab_project_access_token[*] must set exactly one of expires_at (YYYY-MM-DD) or rotation_configuration (expiration_days >= 1, 1 <= rotate_before_days < expiration_days)."
