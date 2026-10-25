# service-accounts Specification

## Purpose
Service accounts as the automation identity of the module: in an existing top-level group or intermediate subgroup, in a created subgroup or in a created project, each with expiring or rotating tokens. They work on GitLab Free, where group and project access tokens do not exist on gitlab.com.

## Requirements

### Requirement: Service accounts in existing groups
Each `service_accounts` entry SHALL create a group service account in `group`, the ID or full path of an existing top-level group or intermediate subgroup, keyed by the entry key. Its display `name` SHALL default to the key, and `username` and `email` SHALL be left to GitLab when unset.

#### Scenario: Top-level bot
- **WHEN** `service_accounts = { ci-bot = { group = "leminnov" } }`
- **THEN** the plan creates `gitlab_group_service_account.this["ci-bot"]` in the group `leminnov`, named `ci-bot`

#### Scenario: Bot in an existing intermediate subgroup
- **WHEN** `service_accounts = { sandbox-bot = { group = "leminnov/test" } }`
- **THEN** the plan creates `gitlab_group_service_account.this["sandbox-bot"]` in `leminnov/test`

#### Scenario: Empty group
- **WHEN** a `service_accounts` entry sets `group = ""`
- **THEN** the plan fails with "service_accounts[*].group must be a non-empty group ID or full path."

### Requirement: Service accounts of created subgroups
Each `service_accounts` entry of a `groups` entry SHALL create a group service account in that created group, keyed `"<group key>:<name>"`, with the same `name`, `username` and `email` rules.

#### Scenario: Team bot
- **WHEN** group `platform/infra` sets `service_accounts = { deployer = {} }`
- **THEN** the plan creates `gitlab_group_service_account.this["platform/infra:deployer"]` in the created group `platform/infra`

### Requirement: Service accounts of created projects
Each `service_accounts` entry of a `projects` entry SHALL create a project service account in that created project, keyed `"<project key>:<name>"`, with the same `name`, `username` and `email` rules.

#### Scenario: Project bot
- **WHEN** project `platform/api` sets `service_accounts = { release = {} }`
- **THEN** the plan creates `gitlab_project_service_account.this["platform/api:release"]`

### Requirement: Service account tokens
Each `tokens` entry of a service account SHALL create a personal access token of that account named by the entry key, keyed `"<service account key>:<token name>"`. Its `scopes` SHALL be non-empty and taken from the personal access token scopes without the administrator scopes `sudo` and `admin_mode`.

#### Scenario: Rotating token of a project bot
- **WHEN** project `platform/api` sets `service_accounts = { release = { tokens = { ci = { scopes = ["write_repository"], rotation_configuration = { expiration_days = 90, rotate_before_days = 14 } } } } }`
- **THEN** the plan creates `gitlab_project_service_account_access_token.this["platform/api:release:ci"]` with that rotation and no `expires_at`

#### Scenario: Administrator scope
- **WHEN** a service account token sets `scopes = ["sudo"]`
- **THEN** the plan fails with "service_accounts[*].tokens[*].scopes must be non-empty, each one of: api, read_user, read_api, read_repository, write_repository, read_registry, write_registry, read_virtual_registry, write_virtual_registry, create_runner, manage_runner, ai_features, self_rotate, read_service_ping."

### Requirement: Service account token expiry
Each service-account token SHALL set exactly one of `expires_at` (`YYYY-MM-DD`) or `rotation_configuration`, whose `expiration_days` is at least 1 and whose `rotate_before_days` is at least 1 and below `expiration_days` (`secrets-rotation`: no credential without expiry).

#### Scenario: Token without expiry
- **WHEN** a service account token sets neither `expires_at` nor `rotation_configuration`
- **THEN** the plan fails with "service_accounts[*].tokens[*] must set exactly one of expires_at (YYYY-MM-DD) or rotation_configuration (expiration_days >= 1, 1 <= rotate_before_days < expiration_days)."

#### Scenario: Rotation that never triggers
- **WHEN** a token sets `rotation_configuration = { expiration_days = 7, rotate_before_days = 7 }`
- **THEN** the plan fails with the same message

#### Scenario: Timestamp expiry
- **WHEN** a service account token sets `expires_at = "2027-06-30T00:00:00Z"`
- **THEN** the plan fails with "service_accounts[*].tokens[*].expires_at must be a date in YYYY-MM-DD format."

### Requirement: Service account outputs
The output `service_accounts` SHALL map every service account key, standalone or nested, to its `id` (the service account's user ID), `username` and `email`. The sensitive output `service_account_tokens` SHALL map every token key `"<service account key>:<token name>"` to its `token` and `expires_at`.

#### Scenario: Token read after apply
- **WHEN** the service account `platform/api:release` has the token `ci`
- **THEN** `service_account_tokens["platform/api:release:ci"].token` authenticates as that account and is shown as `<sensitive>` by `tofu output`
