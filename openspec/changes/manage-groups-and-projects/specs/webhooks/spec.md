# Spec Delta

## Purpose

Project webhooks declared on created projects, with the events to send, SSL verification on by default and their secret and signing tokens kept out of plan output.

## ADDED Requirements

### Requirement: Project webhooks
Each `hooks` entry of a project SHALL create a webhook named by its key, keyed `"<project key>:<name>"`, calling `url` (an `http(s)` URL) for the events set to `true`: `push_events` (default `true`), `tag_push_events`, `merge_requests_events`, `pipeline_events`, `job_events`, `deployment_events`, `releases_events`, `issues_events` and `note_events` (default `false`).

#### Scenario: Merge request hook
- **WHEN** project `platform/api` sets `hooks = { ci = { url = "https://ci.example.com/hook", merge_requests_events = true } }`
- **THEN** the plan creates `gitlab_project_hook.this["platform/api:ci"]` for push and merge request events

#### Scenario: Hook URL without a scheme
- **WHEN** a hook sets `url = "ci.example.com/hook"`
- **THEN** the plan fails with "hooks[*].url must start with http:// or https://."

### Requirement: Hook security defaults
A hook SHALL verify the endpoint's TLS certificate unless `enable_ssl_verification = false`, and its optional `token` and `signing_token` SHALL reach the provider as sensitive values, never shown in plan output. `signing_token` SHALL be `whsec_` followed by the base64 of a 32-byte key, the only form GitLab accepts.

#### Scenario: Signing token redacted
- **WHEN** a hook sets `signing_token = "whsec_<base64 of 32 bytes>"` and the plan is rendered
- **THEN** the plan shows `signing_token = (sensitive value)`

#### Scenario: Malformed signing token
- **WHEN** a hook sets `signing_token = "s3cr3t"`
- **THEN** the plan fails with "hooks[*].signing_token must be whsec_ followed by the base64 of a 32-byte key."
