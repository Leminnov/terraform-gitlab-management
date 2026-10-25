# runners Specification

## Purpose
Runners created with `gitlab_user_runner` at instance, group or project level, with the owning ID, access level, tags and timeout checked at plan time and the authentication token returned only as a sensitive output.

## Requirements

### Requirement: One runner per entry
Each `gitlab_runners` entry SHALL create one `gitlab_user_runner` keyed by the entry name, with its `runner_type`, `description`, `group_id` or `project_id`, `access_level`, `tag_list`, `maximum_timeout`, `paused`, `untagged` and `locked`.

#### Scenario: Group runner
- **WHEN** an entry `ci` sets `runner_type = "group_type"` and `group_id = "123"`
- **THEN** the plan creates `gitlab_user_runner.this["ci"]` in group 123

### Requirement: Runner type and access level
`runner_type` SHALL be `group_type`, `project_type` or `instance_type`, and `access_level` SHALL be `not_protected` or `ref_protected`.

#### Scenario: Unknown runner type
- **WHEN** an entry sets `runner_type = "shared"`
- **THEN** the plan fails with "gitlab_runners[*].runner_type must be one of: group_type, project_type, instance_type."

#### Scenario: Unknown access level
- **WHEN** an entry sets `access_level = "protected"`
- **THEN** the plan fails with "gitlab_runners[*].access_level must be one of: not_protected, ref_protected."

### Requirement: Owning group or project
A `group_type` runner SHALL set `group_id` and a `project_type` runner SHALL set `project_id`, and both SHALL be numeric IDs, not paths.

#### Scenario: Group runner without group
- **WHEN** a `group_type` entry omits `group_id`
- **THEN** the plan fails with "gitlab_runners[*].group_id is required when runner_type == group_type."

#### Scenario: Project runner without project
- **WHEN** a `project_type` entry omits `project_id`
- **THEN** the plan fails with "gitlab_runners[*].project_id is required when runner_type == project_type."

#### Scenario: Group path instead of ID
- **WHEN** an entry sets `group_id = "org/platform"`
- **THEN** the plan fails with "gitlab_runners[*].group_id and project_id must be numeric IDs, not paths."

### Requirement: Tags and timeout
`tag_list` SHALL be non-empty unless `untagged = true`, and `maximum_timeout` SHALL be `null` or at least 600 seconds.

#### Scenario: Tagged runner without tags
- **WHEN** an entry sets `untagged = false` and `tag_list = []`
- **THEN** the plan fails with "gitlab_runners[*].tag_list must be non-empty unless untagged == true."

#### Scenario: Timeout below the GitLab minimum
- **WHEN** an entry sets `maximum_timeout = 300`
- **THEN** the plan fails with "gitlab_runners[*].maximum_timeout must be null or >= 600 (GitLab minimum)."

### Requirement: Runner outputs
The output `gitlab_runners` SHALL map each runner key, the `gitlab_runners` key for the standalone input and `"<owner key>:<name>"` for created groups and projects, to its runner's `id` (the GitLab runner ID), type, owning group or project and settings, and the sensitive output `gitlab_runner_tokens` SHALL map the same keys to the authentication tokens. Neither SHALL read an attribute the provider does not expose.

#### Scenario: Plan with a runner
- **WHEN** a call declares one runner
- **THEN** the plan succeeds and `gitlab_runners` has that entry's key (v12 read the non-existent `runner_id` and `status` attributes and failed)

#### Scenario: Registering the runner manager
- **WHEN** a runner is created
- **THEN** `gitlab_runner_tokens["<entry>"]` holds a `glrt-` token and is shown as `<sensitive>` by `tofu output`

### Requirement: Runners of created groups and projects
Each `runners` entry of a `groups` or `projects` entry SHALL register a group or project runner in it, keyed `"<owner key>:<name>"`, with `description` (default the name), `access_level` (default `ref_protected`), `tag_list`, `untagged`, `paused`, `locked` and `maximum_timeout` under the same rules as the standalone input.

#### Scenario: Group runner on a created group
- **WHEN** group `platform` sets `runners = { docker = { tag_list = ["docker"] } }`
- **THEN** the plan creates `gitlab_user_runner.this["platform:docker"]` as a `group_type` runner limited to protected refs

#### Scenario: Nested runner without tags
- **WHEN** a nested runner sets `tag_list = []` and `untagged = false`
- **THEN** the plan fails with "runners[*].tag_list must be non-empty unless untagged == true."

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
