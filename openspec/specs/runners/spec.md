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
