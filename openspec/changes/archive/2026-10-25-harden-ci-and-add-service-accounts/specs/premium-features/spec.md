# Spec Delta

## MODIFIED Requirements

### Requirement: Off by default
A call that sets none of the following SHALL plan no Premium-only resource or argument:
- `approval_rules`, `merge_request_approvals`, `push_rules`, `protected_environments`;
- `protected_branches[*].code_owner_approval_required`;
- group `hooks`;
- `target_branch_rules`;
- `ci.merge_pipelines_enabled`, `ci.merge_trains_enabled`, `ci.restrict_pipeline_cancellation_role`, `ci.allow_pipeline_trigger_approve_deployment`;
- `container_tag_protection_rules[*].immutable`.

#### Scenario: Free namespace
- **WHEN** the complete example is planned without any Premium setting
- **THEN** the plan contains:
  - no `gitlab_project_approval_rule`, `gitlab_project_level_mr_approvals`, `gitlab_project_push_rules`, `gitlab_project_protected_environment`, `gitlab_group_hook` or `gitlab_project_target_branch_rule`;
  - no `code_owner_approval_required`, `merge_pipelines_enabled`, `merge_trains_enabled`, `ci_restrict_pipeline_cancellation_role` or `allow_pipeline_trigger_approve_deployment`;
  - no immutable container tag rule.

## ADDED Requirements

### Requirement: Merge trains
A project's `ci.merge_pipelines_enabled` and `ci.merge_trains_enabled` SHALL default to `null`, which sends nothing. When set, they are sent as given, and `merge_trains_enabled = true` SHALL require `merge_pipelines_enabled = true`.

#### Scenario: Merge train on main
- **WHEN** a project sets `ci = { merge_pipelines_enabled = true, merge_trains_enabled = true }`
- **THEN** the plan sends both arguments as `true`

#### Scenario: Train without merge pipelines
- **WHEN** a project sets `ci = { merge_trains_enabled = true }`
- **THEN** the plan fails with "ci.merge_trains_enabled requires ci.merge_pipelines_enabled = true."

### Requirement: Target branch rules
Each `target_branch_rules` entry of a project SHALL make merge requests from branches matching its key (a branch name pattern) target the branch named by its value, keyed `"<project key>:<pattern>"`. The value SHALL be a non-empty branch name.

#### Scenario: Feature branches into develop
- **WHEN** a project sets `target_branch_rules = { "feature/*" = "develop" }`
- **THEN** the plan creates `gitlab_project_target_branch_rule.this["<project key>:feature/*"]` targeting `develop` (`git-branching`)

#### Scenario: Empty target
- **WHEN** a rule maps `"bug/*"` to `""`
- **THEN** the plan fails with "target_branch_rules values must be non-empty branch names."

### Requirement: Pipeline cancellation and deployment approval
A project's `ci.restrict_pipeline_cancellation_role` (`developer`, `maintainer` or `no_one`) and `ci.allow_pipeline_trigger_approve_deployment` SHALL default to `null`, which sends nothing, and SHALL be sent as given when set.

#### Scenario: Only maintainers cancel pipelines
- **WHEN** a project sets `ci = { restrict_pipeline_cancellation_role = "maintainer" }`
- **THEN** the plan sets `ci_restrict_pipeline_cancellation_role = "maintainer"`

#### Scenario: Unknown cancellation role
- **WHEN** a project sets `ci = { restrict_pipeline_cancellation_role = "owner" }`
- **THEN** the plan fails with "ci.restrict_pipeline_cancellation_role must be one of: developer, maintainer, no_one."

### Requirement: Immutable container tags
A protected container tag rule with `immutable = true` (Ultimate) SHALL make matching tags impossible to overwrite or delete, and SHALL send no access level, since GitLab rejects both together.

#### Scenario: Immutable release images
- **WHEN** a project sets `container_tag_protection_rules = { release = { tag_name_pattern = "^v[0-9]+", immutable = true } }`
- **THEN** the plan sends `immutable = true` and no `minimum_access_level_for_push` or `minimum_access_level_for_delete`
