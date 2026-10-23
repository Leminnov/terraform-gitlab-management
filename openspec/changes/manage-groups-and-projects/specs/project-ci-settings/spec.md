# Spec Delta

## Purpose

CI/CD objects of created projects beyond variables and schedules: deployment environments, pipeline trigger tokens, and the allowlist of projects and groups whose CI/CD job token may access the project.

## ADDED Requirements

### Requirement: Environments
Each `environments` entry of a project SHALL create an environment named by its key, keyed `"<project key>:<name>"`, with optional `tier` (`production`, `staging`, `testing`, `development` or `other`), `external_url` and `description`.

#### Scenario: Production environment
- **WHEN** project `platform/api` sets `environments = { production = { tier = "production" } }`
- **THEN** the plan creates `gitlab_project_environment.this["platform/api:production"]`

#### Scenario: Unknown tier
- **WHEN** an environment sets `tier = "prod"`
- **THEN** the plan fails with "environments[*].tier must be one of: production, staging, testing, development, other."

### Requirement: Pipeline triggers
Each description in a project's `pipeline_triggers` set SHALL create one pipeline trigger, keyed `"<project key>:<description>"`, and the sensitive output `pipeline_trigger_tokens` SHALL map that key to its token.

#### Scenario: Trigger for an upstream pipeline
- **WHEN** project `platform/api` sets `pipeline_triggers = ["release from platform/sdk"]`
- **THEN** `pipeline_trigger_tokens["platform/api:release from platform/sdk"]` holds the trigger token and is shown as `<sensitive>`

#### Scenario: Empty description
- **WHEN** `pipeline_triggers` contains `""`
- **THEN** the plan fails with "pipeline_triggers entries must be non-empty descriptions."

### Requirement: CI/CD job token allowlist
When a project sets `job_token_allowlist`, the module SHALL enable its job token inbound allowlist with exactly the listed `projects` and `groups` (keys of `projects` and `groups`) and `project_ids` and `group_ids` (existing IDs). When unset, the module SHALL leave the allowlist to GitLab's default.

#### Scenario: Allow one sibling project
- **WHEN** project `platform/api` sets `job_token_allowlist = { projects = ["platform/sdk"] }`
- **THEN** only the job tokens of `platform/api` itself and `platform/sdk` can access `platform/api`

#### Scenario: Unknown project key in the allowlist
- **WHEN** the allowlist names `platform/missing`
- **THEN** the plan fails with "job_token_allowlist projects and groups must be keys of projects and groups."
