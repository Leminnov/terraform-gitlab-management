# Spec Delta

## ADDED Requirements

### Requirement: Runners of created groups and projects
Each `runners` entry of a `groups` or `projects` entry SHALL register a group or project runner in it, keyed `"<owner key>:<name>"`, with `description` (default the name), `access_level` (default `ref_protected`), `tag_list`, `untagged`, `paused`, `locked` and `maximum_timeout` under the same rules as the standalone input.

#### Scenario: Group runner on a created group
- **WHEN** group `platform` sets `runners = { docker = { tag_list = ["docker"] } }`
- **THEN** the plan creates `gitlab_user_runner.this["platform:docker"]` as a `group_type` runner limited to protected refs

#### Scenario: Nested runner without tags
- **WHEN** a nested runner sets `tag_list = []` and `untagged = false`
- **THEN** the plan fails with "runners[*].tag_list must be non-empty unless untagged == true."

## MODIFIED Requirements

### Requirement: Runner outputs
The output `gitlab_runners` SHALL map each runner key, the `gitlab_runners` key for the standalone input and `"<owner key>:<name>"` for created groups and projects, to its runner's `id` (the GitLab runner ID), type, owning group or project and settings, and the sensitive output `gitlab_runner_tokens` SHALL map the same keys to the authentication tokens. Neither SHALL read an attribute the provider does not expose.

#### Scenario: Plan with a runner
- **WHEN** a call declares one runner
- **THEN** the plan succeeds and `gitlab_runners` has that entry's key (v12 read the non-existent `runner_id` and `status` attributes and failed)

#### Scenario: Registering the runner manager
- **WHEN** a runner is created
- **THEN** `gitlab_runner_tokens["<entry>"]` holds a `glrt-` token and is shown as `<sensitive>` by `tofu output`
