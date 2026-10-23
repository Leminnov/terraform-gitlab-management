# Spec Delta

## Purpose

A tree of GitLab groups, up to seven levels deep, created under one existing parent group from a map keyed by path, with safe settings by default and archived rather than deleted on destroy.

## ADDED Requirements

### Requirement: Groups keyed by relative path
Each `groups` entry SHALL create one group whose path is the last segment of its key and whose parent is the group named by the rest of the key, or `parent_group_id` when the key has one segment. `name` SHALL default to the last segment.

#### Scenario: Three-level tree
- **WHEN** `parent_group_id = 6055239` and `groups` has the keys `platform`, `platform/infra` and `platform/infra/terraform`
- **THEN** the plan creates `platform` in group 6055239, `infra` in `platform` and `terraform` in `platform/infra`

#### Scenario: Several roots
- **WHEN** `groups` has the keys `platform` and `data`
- **THEN** both are created directly in `parent_group_id`

#### Scenario: Name defaulted
- **WHEN** the entry `platform/infra` sets no `name`
- **THEN** the group is named `infra`

### Requirement: Parent group required
`parent_group_id` SHALL be set whenever `groups` or `projects` is not empty, since gitlab.com does not let the provider create top-level groups.

#### Scenario: Groups without a parent
- **WHEN** `groups = { platform = {} }` and `parent_group_id` is unset
- **THEN** the plan fails with "parent_group_id is required when groups or projects are declared."

### Requirement: Depth and path format
A `groups` key SHALL have 1 to 7 segments separated by `/`. Each segment SHALL be a valid GitLab path: letters, digits, `_`, `-` and `.`, starting with a letter, digit or `_`, not ending with `.`, `.git` or `.atom`.

#### Scenario: Eight levels
- **WHEN** a key has 8 segments
- **THEN** the plan fails with "groups keys must have 1 to 7 segments of letters, digits, _, - and ., not starting with - or . and not ending with ., .git or .atom."

#### Scenario: Invalid segment
- **WHEN** a key is `platform/my team`
- **THEN** the plan fails with the same message

#### Scenario: Seven levels
- **WHEN** keys `a`, `a/b`, ..., `a/b/c/d/e/f/g` are declared
- **THEN** the plan creates seven nested groups

### Requirement: Parent declared
Every key with more than one segment SHALL have its parent key (all segments but the last) in `groups`.

#### Scenario: Missing intermediate group
- **WHEN** `groups` has `platform/infra` but not `platform`
- **THEN** the plan fails with "Every groups key with a parent path needs that parent in groups: declare each intermediate group."

### Requirement: Safe group defaults
Unless set, a group SHALL be `private`, with access requests off, project creation by maintainers, subgroup creation by owners, initial default branch `main`, and default branch protection for new projects allowing push and merge to maintainers only, without force push.

#### Scenario: Group with defaults
- **WHEN** an entry sets no setting
- **THEN** the planned group has `visibility_level = "private"`, `request_access_enabled = false`, `project_creation_level = "maintainer"`, `subgroup_creation_level = "owner"` and `default_branch = "main"`

### Requirement: Group settings validated
`visibility` SHALL be `private`, `internal` or `public` and no more open than the parent group's when that parent is declared in `groups`; `project_creation_level` SHALL be `noone`, `owner`, `maintainer`, `developer` or `administrator`; `subgroup_creation_level` SHALL be `owner` or `maintainer`.

#### Scenario: Public subgroup of a private group
- **WHEN** `platform` is `private` and `platform/web` sets `visibility = "public"`
- **THEN** the plan fails with "A group's visibility cannot be more open than its parent's (private < internal < public)."

#### Scenario: Unknown visibility
- **WHEN** an entry sets `visibility = "secret"`
- **THEN** the plan fails with "groups[*].visibility must be one of: private, internal, public."

#### Scenario: Unknown creation level
- **WHEN** an entry sets `subgroup_creation_level = "developer"`
- **THEN** the plan fails with the message naming `owner` and `maintainer`

### Requirement: Archive on destroy
A group SHALL be archived instead of deleted when the module destroys it, unless the entry sets `archive_on_destroy = false`; `permanently_remove_on_delete = true` then removes it immediately instead of scheduling the deletion.

#### Scenario: Default destroy
- **WHEN** an entry without `archive_on_destroy` is removed from `groups`
- **THEN** the group is archived on GitLab and its projects are kept

#### Scenario: Throwaway group
- **WHEN** the integration fixture sets `archive_on_destroy = false` and `permanently_remove_on_delete = true`
- **THEN** destroy removes the group for good

#### Scenario: Permanent removal while archiving
- **WHEN** an entry sets `permanently_remove_on_delete = true` and keeps `archive_on_destroy = true`
- **THEN** the plan fails with "groups[*].permanently_remove_on_delete requires archive_on_destroy = false."

### Requirement: Group outputs
The output `groups` SHALL map each `groups` key to its `id`, `full_path` and `web_url`.

#### Scenario: Reading a created group
- **WHEN** `platform/infra` is created under `leminnov`
- **THEN** `groups["platform/infra"].full_path` is `leminnov/platform/infra`
