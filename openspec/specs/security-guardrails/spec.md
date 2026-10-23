# security-guardrails Specification

## Purpose
Plan-time warnings for configurations GitLab accepts but that weaken security, so they are visible in review without blocking the apply.

## Requirements

### Requirement: Warnings name the object, never the value
Each guardrail SHALL be a `check` block whose message names the offending `"<entry>_<target>"` keys and the setting to change, and SHALL NOT include a variable value or a token.

#### Scenario: Warning text
- **WHEN** any guardrail fires for a variable holding `s3cr3t`
- **THEN** the warning lists the variable's key and target, and the string `s3cr3t` appears nowhere in the plan output

### Requirement: Secret-looking variables masked and protected
The module SHALL warn when a group or project variable whose `key` contains, case-insensitively, `TOKEN`, `PASSWORD`, `PASSWD`, `SECRET`, `PRIVATE_KEY`, `API_KEY` or `CREDENTIAL` is not both `masked = true` and `protected = true`.

#### Scenario: Unmasked password
- **WHEN** a `group_variables` entry sets `key = "REGISTRY_PASSWORD"` and `masked = false`
- **THEN** the plan succeeds with a warning naming `REGISTRY_PASSWORD` and its group and asking for `masked = true` and `protected = true`

#### Scenario: Unprotected project token variable
- **WHEN** a `project_variables` entry sets `key = "deploy_token"`, `masked = true` and `protected = false`
- **THEN** the plan warns for that variable

#### Scenario: Non-secret key
- **WHEN** a variable sets `key = "LOG_LEVEL"` with the default flags
- **THEN** no guardrail warning is emitted

### Requirement: Token lifetime at most one year
The module SHALL warn when a deploy token, group access token or project access token has an `expires_at` more than 366 days after the plan time (`secrets-rotation`).

#### Scenario: Two-year deploy token
- **WHEN** a deploy token sets `expires_at` two years after today
- **THEN** the plan succeeds with a warning naming the token and the one-year limit

#### Scenario: Six-month access token
- **WHEN** a group access token expires six months after today
- **THEN** no lifetime warning is emitted

### Requirement: Access token privilege
The module SHALL warn when a group or project access token sets `access_level = "owner"` or leaves it `null`, in which case GitLab grants `maintainer`.

#### Scenario: Owner token
- **WHEN** a group access token sets `access_level = "owner"`
- **THEN** the plan warns naming the token and asking for the lowest level that works

#### Scenario: Level left to the server default
- **WHEN** a project access token omits `access_level`
- **THEN** the plan warns that GitLab will grant `maintainer`

#### Scenario: Developer token
- **WHEN** a project access token sets `access_level = "developer"`
- **THEN** no privilege warning is emitted

### Requirement: No warning on defaults
A call that sets only non-secret variables, tokens expiring within a year and explicit non-owner access levels SHALL produce no guardrail warning.

#### Scenario: Clean configuration
- **WHEN** the unit suite plans the clean configuration
- **THEN** the run passes with no `expect_failures` and no check warning
