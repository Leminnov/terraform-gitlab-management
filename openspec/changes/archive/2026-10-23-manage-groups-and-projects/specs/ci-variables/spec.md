# Spec Delta

## ADDED Requirements

### Requirement: Variables of created groups and projects
Each `variables` entry of a `groups` or `projects` entry SHALL create a group or project CI/CD variable whose key is the entry key, with `value`, `variable_type` (default `env_var`), `protected` and `masked` (default `false`), and the same key rule, type values and plan redaction as the standalone inputs.

#### Scenario: Variable on a created project
- **WHEN** project `platform/api` sets `variables = { DEPLOY_ENV = { value = "staging" } }`
- **THEN** the plan creates `gitlab_project_variable.this["platform/api:DEPLOY_ENV"]` and shows its value as `(sensitive value)`

#### Scenario: Invalid nested key
- **WHEN** group `platform` sets a variable keyed `MY-VAR`
- **THEN** the plan fails with "variables keys must match [A-Za-z_][A-Za-z0-9_]* (GitLab CI variable naming rule)."

#### Scenario: Invalid nested type
- **WHEN** a nested variable sets `variable_type = "secret"`
- **THEN** the plan fails with "variables[*].variable_type must be one of: env_var, file."

## MODIFIED Requirements

### Requirement: Variable IDs exposed
The outputs `group_variables_ids` and `project_variables_ids` SHALL list the IDs of every created group and project variable, standalone and nested, and no output SHALL return a variable value.

#### Scenario: IDs after apply
- **WHEN** two group variables are created
- **THEN** `group_variables_ids` lists two IDs of the form `<group>:<key>:<environment_scope>`
