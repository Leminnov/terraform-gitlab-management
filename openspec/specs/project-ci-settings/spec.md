# project-ci-settings Specification

## Purpose
CI/CD objects of created projects beyond variables and schedules: deployment environments, pipeline trigger tokens, and the allowlist of projects and groups whose CI/CD job token may access the project.

## Requirements

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

### Requirement: Opt-in CI hardening
A created project's `ci.hardening_enabled` SHALL default to `false`, which sends no hardened setting. With `ci.hardening_enabled = true`, the project SHALL receive:
- `public_jobs = false`;
- `pipeline_variables_minimum_override_role = "no_one_allowed"`;
- `protect_merge_request_pipelines = true`;
- `separated_caches = true`;
- `forward_deployment_enabled = true`;
- `push_repository_for_job_token_allowed = false`;
- `allow_merge_on_skipped_pipeline = false`.

#### Scenario: Project without hardening
- **WHEN** project `platform/api` sets no `ci`
- **THEN** the plan sends none of `public_jobs`, `ci_pipeline_variables_minimum_override_role`, `protect_merge_request_pipelines`, `ci_separated_caches`, `ci_forward_deployment_enabled`, `ci_push_repository_for_job_token_allowed` and `allow_merge_on_skipped_pipeline`

#### Scenario: Hardened project
- **WHEN** project `platform/api` sets `ci = { hardening_enabled = true }`
- **THEN** the plan sets `public_jobs = false`, `ci_pipeline_variables_minimum_override_role = "no_one_allowed"`, `protect_merge_request_pipelines = true`, `ci_separated_caches = true`, `ci_forward_deployment_enabled = true`, `ci_push_repository_for_job_token_allowed = false` and `allow_merge_on_skipped_pipeline = false`

### Requirement: Explicit CI security settings
Each of the seven hardened settings SHALL also be settable on its own in `ci`. An explicit value SHALL win over hardening, and SHALL be sent whether hardening is on or off. A setting that is sent is enforced: a change made in the GitLab UI is reverted on the next apply.

#### Scenario: Hardened project with one exception
- **WHEN** a project sets `ci = { hardening_enabled = true, public_jobs = true }`
- **THEN** the plan sends `public_jobs = true` and the other six hardened values

#### Scenario: One setting without hardening
- **WHEN** a project sets `ci = { pipeline_variables_minimum_override_role = "developer" }`
- **THEN** the plan sends only that setting

#### Scenario: Unknown override role
- **WHEN** a project sets `ci = { pipeline_variables_minimum_override_role = "guest" }`
- **THEN** the plan fails with "ci.pipeline_variables_minimum_override_role must be one of: no_one_allowed, developer, maintainer, owner."

### Requirement: Optional CI settings
The `ci` object SHALL accept the following settings, each leaving GitLab's value when `null`:
- `config_path`;
- `auto_cancel_pending_pipelines` (`enabled` or `disabled`);
- `build_timeout` (600 to 2592000 seconds);
- `default_git_depth` (0 to 1000);
- `delete_pipelines_in_seconds` (86400 to 31536000 seconds);
- `id_token_sub_claim_components` (`project_path` first, then only `ref_type` and `ref`);
- `group_runners_enabled`;
- `shared_runners_enabled`.

#### Scenario: Pipeline retention of one year
- **WHEN** a project sets `ci = { delete_pipelines_in_seconds = 31536000 }`
- **THEN** the plan sets `ci_delete_pipelines_in_seconds = 31536000`

#### Scenario: Unknown auto-cancel value
- **WHEN** a project sets `ci = { auto_cancel_pending_pipelines = "yes" }`
- **THEN** the plan fails with "ci.auto_cancel_pending_pipelines must be enabled or disabled."

#### Scenario: Timeout below the minimum
- **WHEN** a project sets `ci = { build_timeout = 300 }`
- **THEN** the plan fails with "ci.build_timeout must be null or between 600 and 2592000 seconds (10 minutes to 30 days)."

#### Scenario: Git depth too large
- **WHEN** a project sets `ci = { default_git_depth = 2000 }`
- **THEN** the plan fails with "ci.default_git_depth must be null or between 0 and 1000."

#### Scenario: Retention below one day
- **WHEN** a project sets `ci = { delete_pipelines_in_seconds = 3600 }`
- **THEN** the plan fails with "ci.delete_pipelines_in_seconds must be null or between 86400 and 31536000 seconds (1 day to 1 year)."

#### Scenario: OIDC sub claim without the project path
- **WHEN** a project sets `ci = { id_token_sub_claim_components = ["ref"] }`
- **THEN** the plan fails with "ci.id_token_sub_claim_components must start with project_path and otherwise contain only ref_type and ref."

### Requirement: Deploy freeze periods
Each `freeze_periods` entry of a project SHALL create a deploy freeze, keyed `"<project key>:<label>"`, from `freeze_start` to `freeze_end`. Both SHALL be cron expressions with five fields, in `cron_timezone` (default `UTC`).

#### Scenario: Weekend freeze
- **WHEN** project `platform/api` sets `freeze_periods = { weekend = { freeze_start = "0 18 * * 5", freeze_end = "0 6 * * 1" } }`
- **THEN** the plan creates `gitlab_project_freeze_period.this["platform/api:weekend"]` in UTC

#### Scenario: Malformed freeze cron
- **WHEN** a freeze period sets `freeze_start = "Friday 18:00"`
- **THEN** the plan fails with "freeze_periods[*].freeze_start and freeze_end must be cron expressions with 5 fields."

### Requirement: Secure files
Each `secure_files` entry of a project SHALL upload a CI/CD secure file named by its key, keyed `"<project key>:<name>"`, with the text content of its value. The content SHALL be redacted in plan output and is stored in state (`SECURITY.md`). Names SHALL contain no `/`, and content SHALL be non-empty.

#### Scenario: Kubeconfig for deploy jobs
- **WHEN** project `platform/api` sets `secure_files = { "kubeconfig.yaml" = var.kubeconfig }`
- **THEN** the plan creates `gitlab_project_secure_file.this["platform/api:kubeconfig.yaml"]` and shows its content as `(sensitive value)`

#### Scenario: Path as a secure file name
- **WHEN** a secure file is keyed `certs/ca.pem`
- **THEN** the plan fails with "secure_files keys must be file names without / and values non-empty text."

### Requirement: CI/CD catalog projects
A project that sets `cicd_catalog = true` SHALL be published as a CI/CD catalog resource. It SHALL have a `description`, which GitLab requires for catalog projects.

#### Scenario: Shared pipeline components
- **WHEN** project `platform/ci-components` sets `cicd_catalog = true` and a description
- **THEN** the plan creates `gitlab_project_cicd_catalog.this["platform/ci-components"]` enabled

#### Scenario: Catalog project without description
- **WHEN** a project sets `cicd_catalog = true` and no `description`
- **THEN** the plan fails with "projects[*].cicd_catalog requires a description (GitLab lists catalog projects by it)."
