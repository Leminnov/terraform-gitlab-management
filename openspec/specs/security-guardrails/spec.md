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
The module SHALL warn when a group or project variable, standalone or nested in a created group or project, whose key contains, case-insensitively, `TOKEN`, `PASSWORD`, `PASSWD`, `SECRET`, `PRIVATE_KEY`, `API_KEY` or `CREDENTIAL` is not both `masked = true` and `protected = true`.

#### Scenario: Unmasked password
- **WHEN** a `group_variables` entry sets `key = "REGISTRY_PASSWORD"` and `masked = false`
- **THEN** the plan succeeds with a warning naming `REGISTRY_PASSWORD` and its group and asking for `masked = true` and `protected = true`

#### Scenario: Unprotected project token variable
- **WHEN** a `project_variables` entry sets `key = "deploy_token"`, `masked = true` and `protected = false`
- **THEN** the plan warns for that variable

#### Scenario: Non-secret key
- **WHEN** a variable sets `key = "LOG_LEVEL"` with the default flags
- **THEN** no guardrail warning is emitted

#### Scenario: Nested secret variable
- **WHEN** project `platform/api` declares the variable `API_KEY` with the default flags
- **THEN** the plan warns naming `platform/api:API_KEY`

### Requirement: Token lifetime at most one year
The module SHALL warn when a credential's lifetime exceeds 366 days (`secrets-rotation`):
- a group or project deploy token, a group or project access token (standalone or nested), a service-account token or a deploy key, whose `expires_at` is more than 366 days after the plan time;
- a token whose `rotation_configuration.expiration_days` is above 366.

#### Scenario: Two-year deploy token
- **WHEN** a deploy token sets `expires_at` two years after today
- **THEN** the plan succeeds with a warning naming the token and the one-year limit

#### Scenario: Six-month access token
- **WHEN** a group access token expires six months after today
- **THEN** no lifetime warning is emitted

#### Scenario: Two-year deploy key
- **WHEN** a deploy key expires two years after today
- **THEN** the plan warns naming the deploy key

#### Scenario: Two-year service account token
- **WHEN** a service-account token expires two years after today
- **THEN** the plan warns naming `service_accounts["<key>"].tokens["<name>"]`

#### Scenario: Rotation with a long lifetime
- **WHEN** a project access token sets `rotation_configuration = { expiration_days = 400, rotate_before_days = 30 }`
- **THEN** the plan warns naming the token

### Requirement: Access token privilege
The module SHALL warn when a group or project access token, standalone or nested, sets `access_level = "owner"` or leaves it `null`, in which case GitLab grants `maintainer`.

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
A call that sets only the following SHALL produce no guardrail warning:
- non-secret variables;
- tokens, deploy keys and service-account tokens expiring or rotating within a year;
- explicit non-owner access levels;
- private groups and projects with the default protections, with or without CI hardening;
- read-only deploy keys and hooks with TLS verification.

#### Scenario: Clean configuration
- **WHEN** the unit suite plans the clean configuration
- **THEN** the run passes with no `expect_failures` and no check warning

#### Scenario: Complete example
- **WHEN** `examples/complete` is planned
- **THEN** no guardrail warning is emitted

### Requirement: Public visibility
The module SHALL warn when a created group or project sets `visibility = "public"`, since a public group or project is an explicit, reviewed decision (`gitlab-project-settings`).

#### Scenario: Public project
- **WHEN** project `tools/site` sets `visibility = "public"`
- **THEN** the plan succeeds with a warning naming `projects["tools/site"]`

### Requirement: Force push on protected branches
The module SHALL warn when a protected branch of a created project sets `allow_force_push = true`.

#### Scenario: Force push allowed on main
- **WHEN** a project sets `protected_branches = { main = { allow_force_push = true } }`
- **THEN** the plan warns naming the project and the branch

### Requirement: Webhook TLS verification
The module SHALL warn when a project or group webhook sets `enable_ssl_verification = false`.

#### Scenario: Hook without TLS verification
- **WHEN** a project hook sets `enable_ssl_verification = false`
- **THEN** the plan warns naming the hook

### Requirement: Deploy key write access
The module SHALL warn when a deploy key sets `can_push = true`.

#### Scenario: Writable deploy key
- **WHEN** a deploy key sets `can_push = true`
- **THEN** the plan warns naming the deploy key

### Requirement: Public job logs
The module SHALL warn when a created project explicitly sets `ci.public_jobs = true`: job logs and artifacts of an internal or public project then become readable by non-members.

#### Scenario: Public jobs turned on
- **WHEN** project `tools/site` sets `ci = { public_jobs = true }`
- **THEN** the plan warns naming `projects["tools/site"].ci.public_jobs`

### Requirement: Job token pushes
The module SHALL warn when a created project sets `ci.push_repository_for_job_token_allowed = true`: any pipeline allowed by the job token allowlist can then push to the repository.

#### Scenario: Pipelines pushing with the job token
- **WHEN** project `platform/api` sets `ci = { push_repository_for_job_token_allowed = true }`
- **THEN** the plan warns naming `projects["platform/api"].ci.push_repository_for_job_token_allowed`
