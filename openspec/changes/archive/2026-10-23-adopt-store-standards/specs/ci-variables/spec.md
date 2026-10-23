# Spec Delta

## Purpose

Group and project CI/CD variables declared once and created in every group or project of their target list, with the GitLab key rule and variable type enforced at plan time.

## ADDED Requirements

### Requirement: Group variables fan out across groups
Each `group_variables` entry SHALL create one `gitlab_group_variable` per group in its `groups` list, with the entry's `key`, `value`, `variable_type` (default `env_var`), `protected` (default `false`) and `masked` (default `false`).

#### Scenario: Entry with two groups
- **WHEN** an entry `log_level` sets `groups = ["org/a", "org/b"]` and `key = "LOG_LEVEL"`
- **THEN** the plan creates `gitlab_group_variable.this["log_level_org/a"]` and `["log_level_org/b"]`, both with key `LOG_LEVEL`

#### Scenario: Defaults applied
- **WHEN** an entry sets only `key`, `groups` and `value`
- **THEN** the planned variable has `variable_type = "env_var"`, `protected = false` and `masked = false`

### Requirement: Project variables fan out across projects
Each `project_variables` entry SHALL create one `gitlab_project_variable` per project in its `projects` list, with the same attributes and defaults as group variables.

#### Scenario: Entry with two projects
- **WHEN** an entry `env` sets `projects = ["org/app", "org/api"]`
- **THEN** the plan creates `gitlab_project_variable.this["env_org/app"]` and `["env_org/api"]`

### Requirement: Non-empty target list
`groups` (group variables) and `projects` (project variables) SHALL contain at least one element.

#### Scenario: Empty groups list
- **WHEN** a `group_variables` entry sets `groups = []`
- **THEN** the plan fails with "group_variables[*].groups must be a non-empty list."

#### Scenario: Empty projects list
- **WHEN** a `project_variables` entry sets `projects = []`
- **THEN** the plan fails with "project_variables[*].projects must be a non-empty list."

### Requirement: Key format
`key` SHALL match `^[A-Za-z_][A-Za-z0-9_]*$`, the GitLab CI variable naming rule.

#### Scenario: Key with a dash
- **WHEN** a `group_variables` entry sets `key = "MY-VAR"`
- **THEN** the plan fails with the message naming `[A-Za-z_][A-Za-z0-9_]*`

#### Scenario: Project variable key starting with a digit
- **WHEN** a `project_variables` entry sets `key = "1VAR"`
- **THEN** the plan fails with the message naming `[A-Za-z_][A-Za-z0-9_]*`

### Requirement: Variable type
`variable_type` SHALL be `env_var` or `file`.

#### Scenario: Unknown group variable type
- **WHEN** a `group_variables` entry sets `variable_type = "secret"`
- **THEN** the plan fails with "group_variables[*].variable_type must be one of: env_var, file."

#### Scenario: Unknown project variable type
- **WHEN** a `project_variables` entry sets `variable_type = "secret"`
- **THEN** the plan fails with "project_variables[*].variable_type must be one of: env_var, file."

### Requirement: Variable IDs exposed
The outputs `group_variables_ids` and `project_variables_ids` SHALL list the IDs of the created group and project variables, and no output SHALL return a variable value.

#### Scenario: IDs after apply
- **WHEN** two group variables are created
- **THEN** `group_variables_ids` lists two IDs of the form `<group>:<key>:<environment_scope>`
