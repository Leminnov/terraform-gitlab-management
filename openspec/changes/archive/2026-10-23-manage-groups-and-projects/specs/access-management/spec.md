# Spec Delta

## Purpose

Who can reach a created group or project: direct user memberships with an access level, and sharing with another group, created by the module or existing, so access can be granted at group level with the least role needed.

## ADDED Requirements

### Requirement: User memberships
Each `members` entry of a group or project SHALL grant the user `user_id` the `access_level`, one of `no one`, `minimal`, `guest`, `planner`, `reporter`, `security_manager`, `developer`, `maintainer` or `owner`, until `expires_at` (`YYYY-MM-DD`) when set. Resources are keyed `"<owner key>:<member key>"`.

#### Scenario: Developer on a project
- **WHEN** project `platform/api` sets `members = { alice = { user_id = 42, access_level = "developer" } }`
- **THEN** the plan creates `gitlab_project_membership.this["platform/api:alice"]` for user 42 as developer

#### Scenario: Unknown member level
- **WHEN** a member sets `access_level = "admin"`
- **THEN** the plan fails with "members[*].access_level must be one of: no one, minimal, guest, planner, reporter, security_manager, developer, maintainer, owner."

#### Scenario: Malformed membership expiry
- **WHEN** a member sets `expires_at = "2027-06-30T00:00:00Z"`
- **THEN** the plan fails with "members[*].expires_at must be a date in YYYY-MM-DD format."

### Requirement: Group sharing
Each `shared_with` entry of a group or project SHALL share it with exactly one group, given as `group` (a key of `groups`) or `group_id` (an existing group's ID), at `access_level` (same values as members), until `expires_at` when set.

#### Scenario: Share with a created team group
- **WHEN** project `platform/api` sets `shared_with = { team = { group = "teams/backend", access_level = "developer" } }`
- **THEN** the project is shared with the created group `teams/backend` as developer

#### Scenario: Both group and group_id
- **WHEN** a share sets both `group` and `group_id`
- **THEN** the plan fails with "shared_with[*] must set exactly one of group (a groups key) or group_id."

#### Scenario: Unknown group key
- **WHEN** a share sets `group = "teams/missing"` and `groups` has no such key
- **THEN** the plan fails with the same message
