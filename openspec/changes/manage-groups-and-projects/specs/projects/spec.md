# Spec Delta

## Purpose

Projects created in the group tree, or directly under the parent group, from a map keyed by path, with private visibility and the merge request settings of the gitlab-project-settings standard by default, archived rather than deleted on destroy.

## ADDED Requirements

### Requirement: Projects keyed by relative path
Each `projects` entry SHALL create one project whose path is the last segment of its key and whose namespace is the group named by the rest of the key, or `parent_group_id` when the key has one segment. `name` SHALL default to the last segment.

#### Scenario: Project in a created group
- **WHEN** `groups` has `platform/infra` and `projects` has `platform/infra/api`
- **THEN** the plan creates project `api` in group `platform/infra`

#### Scenario: Project under the parent
- **WHEN** `projects` has `tools`
- **THEN** the project is created directly in `parent_group_id`

### Requirement: Project path and namespace
A `projects` key SHALL have 1 to 8 segments, its last segment SHALL be a valid GitLab path, and its namespace part, when present, SHALL be a key of `groups`.

#### Scenario: Unknown namespace
- **WHEN** `projects` has `platform/web/app` and `groups` has no `platform/web`
- **THEN** the plan fails with "projects keys must be <group key>/<path> with the group declared in groups, or a single <path> under parent_group_id."

#### Scenario: Invalid project path
- **WHEN** a key ends with `app.git`
- **THEN** the plan fails with the same message

### Requirement: Safe project defaults
Unless set, a project SHALL be `private`, initialised with a README on default branch `main`, and SHALL only merge when the pipeline succeeds and all threads are resolved, with merge commits, squash encouraged (`default_on`) and the source branch deleted on merge.

#### Scenario: Project with defaults
- **WHEN** an entry sets no setting
- **THEN** the planned project has `visibility_level = "private"`, `default_branch = "main"`, `initialize_with_readme = true`, `only_allow_merge_if_pipeline_succeeds = true`, `only_allow_merge_if_all_discussions_are_resolved = true`, `merge_method = "merge"`, `squash_option = "default_on"` and `remove_source_branch_after_merge = true`

#### Scenario: Pipelines not required
- **WHEN** an entry sets `only_allow_merge_if_pipeline_succeeds = false`
- **THEN** the project allows merging without a pipeline

### Requirement: Project settings validated
`visibility` SHALL be `private`, `internal` or `public` and no more open than its group's when the group is in `groups`; `merge_method` SHALL be `merge`, `rebase_merge` or `ff`; `squash_option` SHALL be `never`, `always`, `default_on` or `default_off`.

#### Scenario: Public project in a private group
- **WHEN** group `platform` is `private` and project `platform/site` sets `visibility = "public"`
- **THEN** the plan fails with "A project's visibility cannot be more open than its group's (private < internal < public)."

#### Scenario: Unknown merge method
- **WHEN** an entry sets `merge_method = "squash"`
- **THEN** the plan fails with "projects[*].merge_method must be one of: merge, rebase_merge, ff."

#### Scenario: Unknown squash option
- **WHEN** an entry sets `squash_option = "sometimes"`
- **THEN** the plan fails with "projects[*].squash_option must be one of: never, always, default_on, default_off."

### Requirement: Archive on destroy
A project SHALL be archived instead of deleted when the module destroys it, unless the entry sets `archive_on_destroy = false`; `permanently_delete_on_destroy = true` then deletes it immediately instead of scheduling the deletion.

#### Scenario: Default destroy
- **WHEN** an entry without `archive_on_destroy` is removed from `projects`
- **THEN** the project is archived on GitLab with its repository intact

### Requirement: Project outputs
The output `projects` SHALL map each `projects` key to its `id`, `path_with_namespace`, `web_url`, `http_url_to_repo`, `ssh_url_to_repo` and `default_branch`.

#### Scenario: Clone URL after apply
- **WHEN** `platform/infra/api` is created
- **THEN** `projects["platform/infra/api"].http_url_to_repo` ends with `/platform/infra/api.git`
