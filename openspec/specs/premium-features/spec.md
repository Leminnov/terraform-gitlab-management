# premium-features Specification

## Purpose
GitLab Premium and Ultimate settings on created groups and projects: approval rules, merge request approval settings, push rules, protected environments, code-owner approval and group webhooks, available but never sent unless the caller sets them, so a Free namespace keeps working.

## Requirements

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

### Requirement: Approval rules
Each `approval_rules` entry of a project SHALL create an approval rule named by its key requiring `approvals_required` (zero or more) approvals from `user_ids` and `group_ids`, on all protected branches unless `applies_to_all_protected_branches = false`.

#### Scenario: Two approvals from a team
- **WHEN** a project sets `approval_rules = { review = { approvals_required = 2, group_ids = [123] } }`
- **THEN** the plan creates `gitlab_project_approval_rule.this["<project key>:review"]` requiring 2 approvals from group 123

#### Scenario: Negative approvals
- **WHEN** a rule sets `approvals_required = -1`
- **THEN** the plan fails with "approval_rules[*].approvals_required must be >= 0."

### Requirement: Merge request approval settings
When a project sets `merge_request_approvals`, the module SHALL apply it with safe defaults: approvals reset on push, authors and committers cannot approve their own merge requests, and approvers cannot be overridden per merge request.

#### Scenario: Approval settings with defaults
- **WHEN** a project sets `merge_request_approvals = {}`
- **THEN** the plan sets `reset_approvals_on_push = true`, `merge_requests_author_approval = false`, `merge_requests_disable_committers_approval = true` and `disable_overriding_approvers_per_merge_request = true`

### Requirement: Push rules
When a project sets `push_rules`, the module SHALL apply them with `prevent_secrets`, `deny_delete_tag` and `member_check` on by default, plus the optional commit message, branch name and author email regexes, `reject_unsigned_commits` and `max_file_size`.

#### Scenario: Push rules with defaults
- **WHEN** a project sets `push_rules = {}`
- **THEN** the plan creates `gitlab_project_push_rules.this["<project key>"]` rejecting files that look like secrets, tag deletion and commits by non-members

### Requirement: Protected environments
Each `protected_environments` entry of a project SHALL protect the environment named by its key, which SHALL be declared in the project's `environments`, letting `deploy_access_level` (`developer` or `maintainer`, default `maintainer`) deploy, with `required_approvals` when set.

#### Scenario: Production deploys by maintainers
- **WHEN** a project declares `environments = { production = {} }` and `protected_environments = { production = {} }`
- **THEN** only maintainers can deploy to `production`

#### Scenario: Undeclared environment
- **WHEN** `protected_environments` names `staging`, which is not in `environments`
- **THEN** the plan fails with "protected_environments keys must be declared in the project's environments."

#### Scenario: Unknown deploy level
- **WHEN** a protected environment sets `deploy_access_level = "owner"`
- **THEN** the plan fails with "protected_environments[*].deploy_access_level must be developer or maintainer, and required_approvals null or >= 0."

### Requirement: Group webhooks
Each `hooks` entry of a group SHALL create a group webhook with the same arguments, defaults and validation as project webhooks, plus `subgroup_events` and `project_events`.

#### Scenario: Group hook on a Premium namespace
- **WHEN** group `platform` sets `hooks = { audit = { url = "https://audit.example.com/hook", project_events = true } }`
- **THEN** the plan creates `gitlab_group_hook.this["platform:audit"]` with SSL verification on

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
