# Spec Delta

## MODIFIED Requirements

### Requirement: User memberships
Each `members` entry of a group or project SHALL set exactly one of `user_id` (an existing user) or `service_account` (the key of a service account the module manages). It SHALL grant that user the `access_level`, one of `no one`, `minimal`, `guest`, `planner`, `reporter`, `security_manager`, `developer`, `maintainer` or `owner`, until `expires_at` (`YYYY-MM-DD`) when set. Resources are keyed `"<owner key>:<member key>"`.

#### Scenario: Developer on a project
- **WHEN** project `platform/api` sets `members = { alice = { user_id = 42, access_level = "developer" } }`
- **THEN** the plan creates `gitlab_project_membership.this["platform/api:alice"]` for user 42 as developer

#### Scenario: Service account as a member
- **WHEN** project `platform/api` sets `members = { release = { service_account = "platform/api:release", access_level = "developer" } }`
- **THEN** the plan creates `gitlab_project_membership.this["platform/api:release"]` for the user ID of that service account

#### Scenario: Both user and service account
- **WHEN** a member sets both `user_id` and `service_account`, or neither
- **THEN** the plan fails with "members[*] must set exactly one of user_id or service_account."

#### Scenario: Unknown member level
- **WHEN** a member sets `access_level = "admin"`
- **THEN** the plan fails with "members[*].access_level must be one of: no one, minimal, guest, planner, reporter, security_manager, developer, maintainer, owner."

#### Scenario: Malformed membership expiry
- **WHEN** a member sets `expires_at = "2027-06-30T00:00:00Z"`
- **THEN** the plan fails with "members[*].expires_at must be a date in YYYY-MM-DD format."

## ADDED Requirements

### Requirement: Service account invitation scope
A member's `service_account` SHALL name a service account that GitLab lets the group or project invite:
- a `service_accounts` key (an account of an existing group, which GitLab checks at apply);
- an account of a created group that is the member's own group or one of its ancestors, or contains the member's project;
- on a project only, one of that project's own service accounts.

#### Scenario: Team bot on a project of the team
- **WHEN** group `platform` declares the service account `deployer` and project `platform/api` adds the member `{ service_account = "platform:deployer", access_level = "developer" }`
- **THEN** the plan succeeds

#### Scenario: Bot outside its subgroup
- **WHEN** group `platform` declares the service account `deployer` and group `data` adds it as a member
- **THEN** the plan fails with "members[*].service_account must be a service_accounts key, a service account of this group or of a created ancestor group, or one of this project's own service accounts."

#### Scenario: Another project's bot
- **WHEN** project `tools` adds `{ service_account = "platform/api:release" }`
- **THEN** the plan fails with the same message
