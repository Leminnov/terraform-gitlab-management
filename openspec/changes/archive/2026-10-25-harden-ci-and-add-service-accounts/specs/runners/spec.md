# Spec Delta

## ADDED Requirements

### Requirement: Instance runners on created groups
A created group's `shared_runners_setting` SHALL default to `null`, which leaves GitLab's inherited value. Otherwise it SHALL be `enabled`, `disabled_and_overridable`, `disabled_and_unoverridable` or `disabled_with_override`, applied to the group's subgroups and projects.

#### Scenario: Instance runners off for a team
- **WHEN** group `platform` sets `shared_runners_setting = "disabled_and_unoverridable"`
- **THEN** the plan sets that value on the group, and its projects cannot use instance runners

#### Scenario: Unknown runner setting
- **WHEN** a group sets `shared_runners_setting = "off"`
- **THEN** the plan fails with "groups[*].shared_runners_setting must be one of: enabled, disabled_and_overridable, disabled_and_unoverridable, disabled_with_override."

### Requirement: Project runners shared with other projects
Each project's `enabled_runners` SHALL enable, in that project, the project runners of other created projects, given as `"<project key>:<runner name>"`. Its `enabled_runner_ids` SHALL do the same for existing runners given by ID. Each enablement is keyed `"<project key>:<runner key or ID>"`. A runner SHALL be unlocked (`locked = false`) to be shared.

#### Scenario: Build runner shared with a sibling
- **WHEN** project `platform/api` declares the unlocked runner `build` and project `platform/sdk` sets `enabled_runners = ["platform/api:build"]`
- **THEN** the plan creates `gitlab_project_runner_enablement.this["platform/sdk:platform/api:build"]`

#### Scenario: Locked or unknown runner
- **WHEN** `enabled_runners` names a locked runner, a group runner, the project's own runner or an undeclared key
- **THEN** the plan fails with "enabled_runners entries must name an unlocked runner of another created project, as \"<project key>:<runner name>\"."
