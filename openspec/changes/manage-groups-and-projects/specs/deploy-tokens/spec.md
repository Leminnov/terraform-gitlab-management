# Spec Delta

## ADDED Requirements

### Requirement: Deploy tokens of created groups
Each `deploy_tokens` entry of a `groups` entry SHALL create a group deploy token named by its key, with `username`, `expires_at` (required, RFC 3339) and `scopes`, under the same rules as the standalone input, keyed `"<group key>:<name>"`.

#### Scenario: Registry token on a created group
- **WHEN** group `platform` sets `deploy_tokens = { registry = { expires_at = "2027-06-30T00:00:00Z", scopes = ["read_registry"] } }`
- **THEN** the plan creates `gitlab_group_deploy_token.this["platform:registry"]`

#### Scenario: Nested token without expiry
- **WHEN** a nested group deploy token omits `expires_at`
- **THEN** the plan fails with "deploy_tokens[*].expires_at is required, as an RFC 3339 timestamp (for example 2027-06-30T00:00:00Z)."

### Requirement: Project deploy tokens
Each `deploy_tokens` entry of a `projects` entry SHALL create a project deploy token with the same arguments and rules, keyed `"<project key>:<name>"`, and the sensitive output `project_deploy_tokens` SHALL map that key to its `id`, `project`, `name`, `username`, `token`, `expires_at` and `scopes`.

#### Scenario: Pull token for one project
- **WHEN** project `platform/api` sets `deploy_tokens = { pull = { expires_at = "2027-06-30T00:00:00Z", scopes = ["read_repository"] } }`
- **THEN** `project_deploy_tokens["platform/api:pull"].token` clones only that project

#### Scenario: Unknown project token scope
- **WHEN** a project deploy token sets `scopes = ["api"]`
- **THEN** the plan fails with the message listing the accepted deploy token scopes

## MODIFIED Requirements

### Requirement: Deploy token output
The sensitive output `deploy_tokens` SHALL map each group deploy token key, `"<entry>_<group>"` for the standalone input and `"<group key>:<name>"` for created groups, to the token's `id`, `group`, `name`, `username`, `token`, `expires_at` and `scopes`.

#### Scenario: Registry login after apply
- **WHEN** a deploy token with `read_registry` is created
- **THEN** `deploy_tokens["<entry>_<group>"].username` and `.token` authenticate against the group's registry
