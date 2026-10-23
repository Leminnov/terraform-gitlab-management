# pipeline-schedules Specification

## Purpose
Pipeline schedules on a full git ref with a five-field cron, and their variables sent as redacted values, exposed to the caller by schedule ID.

## Requirements

### Requirement: Schedules and their variables
Each `pipeline_schedules` entry SHALL create one `gitlab_pipeline_schedule` with its `project`, `description`, `ref`, `cron` and `active`, and one `gitlab_pipeline_schedule_variable` per element of its `variables` map (default `{}`), keyed `"<schedule>-<variable name>"`.

#### Scenario: Schedule with one variable
- **WHEN** an entry `nightly` sets `variables = { BUILD_MODE = "full" }`
- **THEN** the plan creates `gitlab_pipeline_schedule.this["nightly"]` and `gitlab_pipeline_schedule_variable.this["nightly-BUILD_MODE"]` attached to it

#### Scenario: Schedule without variables
- **WHEN** an entry omits `variables`
- **THEN** the plan creates the schedule and no schedule variable

### Requirement: Full git ref
`ref` SHALL be a full reference matching `^refs/(heads|tags)/.+`, the form provider 19.4 and later require.

#### Scenario: Short branch name
- **WHEN** an entry sets `ref = "main"`
- **THEN** the plan fails with "pipeline_schedules[*].ref must be a full git ref: refs/heads/<branch> or refs/tags/<tag>."

#### Scenario: Full branch ref
- **WHEN** an entry sets `ref = "refs/heads/main"`
- **THEN** the plan succeeds

### Requirement: Required schedule fields
`project`, `ref` and `cron` SHALL be non-empty.

#### Scenario: Empty project
- **WHEN** an entry sets `project = ""`
- **THEN** the plan fails with "pipeline_schedules[*].project, ref, and cron must all be non-empty."

### Requirement: Five-field cron
`cron` SHALL have exactly five whitespace-separated fields (minute, hour, day, month, weekday).

#### Scenario: Six-field cron
- **WHEN** an entry sets `cron = "0 0 2 * * *"`
- **THEN** the plan fails with "pipeline_schedules[*].cron must have exactly 5 whitespace-separated fields (minute hour day month weekday)."

### Requirement: Schedule variable values redacted
Schedule variable values SHALL be sent as sensitive values and SHALL NOT be returned by any output.

#### Scenario: Value in plan output
- **WHEN** a schedule sets `variables = { API_KEY = "s3cr3t" }` and the plan is rendered
- **THEN** the plan shows `value = (sensitive value)` for `gitlab_pipeline_schedule_variable.this["<schedule>-API_KEY"]`

### Requirement: Schedule IDs exposed
The output `pipeline_schedule_ids` SHALL map each schedule key, the `pipeline_schedules` key for the standalone input and `"<project key>:<description>"` for created projects, to its GitLab schedule ID.

#### Scenario: Two schedules
- **WHEN** entries `nightly` and `weekly` are created
- **THEN** `pipeline_schedule_ids` has the keys `nightly` and `weekly` with numeric IDs

### Requirement: Schedules of created projects
Each `pipeline_schedules` entry of a `projects` entry SHALL create a pipeline schedule whose description is the entry key, keyed `"<project key>:<description>"`, on `ref` (a full ref, default `refs/heads/<default branch>`) with a five-field `cron`, `active` (default `true`) and redacted `variables`.

#### Scenario: Nightly build of a created project
- **WHEN** project `platform/api` sets `pipeline_schedules = { nightly = { cron = "0 2 * * *" } }`
- **THEN** the plan creates `gitlab_pipeline_schedule.this["platform/api:nightly"]` on `refs/heads/main`

#### Scenario: Short ref in a nested schedule
- **WHEN** a nested schedule sets `ref = "develop"`
- **THEN** the plan fails with "pipeline_schedules[*].ref must be a full git ref: refs/heads/<branch> or refs/tags/<tag>."

#### Scenario: Four-field cron in a nested schedule
- **WHEN** a nested schedule sets `cron = "0 2 * *"`
- **THEN** the plan fails with "pipeline_schedules[*].cron must have exactly 5 whitespace-separated fields (minute hour day month weekday)."
