# Spec Delta

## MODIFIED Requirements

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

## ADDED Requirements

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
