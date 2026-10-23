# Spec Delta

## Purpose

GitLab Premium and Ultimate settings on created groups and projects: approval rules, merge request approval settings, push rules, protected environments, code-owner approval and group webhooks, available but never sent unless the caller sets them, so a Free namespace keeps working.

## ADDED Requirements

### Requirement: Off by default
A call that sets none of `approval_rules`, `merge_request_approvals`, `push_rules`, `protected_environments`, `protected_branches[*].code_owner_approval_required` or group `hooks` SHALL plan no Premium-only resource or argument.

#### Scenario: Free namespace
- **WHEN** the complete example is planned without any Premium setting
- **THEN** the plan contains no `gitlab_project_approval_rule`, `gitlab_project_level_mr_approvals`, `gitlab_project_push_rules`, `gitlab_project_protected_environment` or `gitlab_group_hook`, and no `code_owner_approval_required`

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

### Requirement: Group webhooks
Each `hooks` entry of a group SHALL create a group webhook with the same arguments, defaults and validation as project webhooks, plus `subgroup_events` and `project_events`.

#### Scenario: Group hook on a Premium namespace
- **WHEN** group `platform` sets `hooks = { audit = { url = "https://audit.example.com/hook", project_events = true } }`
- **THEN** the plan creates `gitlab_group_hook.this["platform:audit"]` with SSL verification on
