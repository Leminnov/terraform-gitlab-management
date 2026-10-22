# Spec Delta

## Purpose

Group deploy tokens declared once and created in every group of their target list, always with an expiry, migrated without recreation from the removed `gitlab_deploy_token` resource.

## ADDED Requirements

### Requirement: Deploy tokens fan out across groups
Each `deploy_tokens` entry SHALL create one `gitlab_group_deploy_token` per group in its `groups` list, with the entry's `name`, `username` (GitLab generates one when `null`), `expires_at` and `scopes`.

#### Scenario: Entry with two groups
- **WHEN** an entry `registry` sets `groups = ["org/a", "org/b"]`
- **THEN** the plan creates `gitlab_group_deploy_token.this["registry_org/a"]` and `["registry_org/b"]`

### Requirement: Migration from gitlab_deploy_token
A `moved` block SHALL map `gitlab_deploy_token.this` to `gitlab_group_deploy_token.this`, so state written by v12 migrates through the provider's state mover and no existing token is destroyed or recreated.

#### Scenario: Upgrade from v12
- **WHEN** state holds `gitlab_deploy_token.this["registry_org/a"]` created by v12 with provider 18.11 and the caller upgrades to this release with unchanged inputs
- **THEN** the plan moves it to `gitlab_group_deploy_token.this["registry_org/a"]` and shows no destroy or create for it

### Requirement: Expiry required
`expires_at` SHALL be set on every entry as an RFC 3339 timestamp, the only form the provider accepts; a deploy token without expiry is rejected.

#### Scenario: Entry without expiry
- **WHEN** a `deploy_tokens` entry omits `expires_at`
- **THEN** the plan fails with "deploy_tokens[*].expires_at is required, as an RFC 3339 timestamp (for example 2027-06-30T00:00:00Z)."

#### Scenario: Bare date
- **WHEN** an entry sets `expires_at = "2027-06-30"`
- **THEN** the plan fails with the same message, instead of the provider's parse error

#### Scenario: Malformed expiry
- **WHEN** an entry sets `expires_at = "next year"`
- **THEN** the plan fails with the same message

### Requirement: Non-empty groups, name and scopes
`groups` and `scopes` SHALL contain at least one element and `name` SHALL be non-empty.

#### Scenario: Empty groups
- **WHEN** an entry sets `groups = []`
- **THEN** the plan fails with "deploy_tokens[*].groups must be a non-empty list."

#### Scenario: Empty scopes
- **WHEN** an entry sets `scopes = []`
- **THEN** the plan fails with "deploy_tokens[*].scopes must be a non-empty list."

#### Scenario: Empty name
- **WHEN** an entry sets `name = ""`
- **THEN** the plan fails with "deploy_tokens[*].name must be non-empty."

### Requirement: Deploy token scopes
Every scope SHALL be one of `read_repository`, `read_registry`, `write_registry`, `read_package_registry`, `write_package_registry`, `read_virtual_registry` or `write_virtual_registry`.

#### Scenario: API scope on a deploy token
- **WHEN** an entry sets `scopes = ["api"]`
- **THEN** the plan fails with the message listing the accepted scopes

### Requirement: Deploy token output
The sensitive output `deploy_tokens` SHALL map each `"<entry>_<group>"` key to the token's `id`, `group`, `name`, `username`, `token`, `expires_at` and `scopes`.

#### Scenario: Registry login after apply
- **WHEN** a deploy token with `read_registry` is created
- **THEN** `deploy_tokens["<entry>_<group>"].username` and `.token` authenticate against the group's registry
