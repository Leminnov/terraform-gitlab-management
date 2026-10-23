# Spec Delta

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Schedule IDs exposed
The output `pipeline_schedule_ids` SHALL map each schedule key, the `pipeline_schedules` key for the standalone input and `"<project key>:<description>"` for created projects, to its GitLab schedule ID.

#### Scenario: Two schedules
- **WHEN** entries `nightly` and `weekly` are created
- **THEN** `pipeline_schedule_ids` has the keys `nightly` and `weekly` with numeric IDs
