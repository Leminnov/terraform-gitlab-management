# Spec Delta

## Purpose

SSH deploy keys on created projects: the public key of a machine that needs repository access, read-only unless write access is asked for, always with an expiry.

## ADDED Requirements

### Requirement: Deploy keys on projects
Each `deploy_keys` entry of a project SHALL add the public SSH `key` titled by the entry key, keyed `"<project key>:<title>"`, with `can_push` defaulting to `false`.

#### Scenario: Read-only deploy key
- **WHEN** project `platform/api` sets `deploy_keys = { argocd = { key = "ssh-ed25519 AAAA...", expires_at = "2027-06-30T00:00:00Z" } }`
- **THEN** the plan creates `gitlab_deploy_key.this["platform/api:argocd"]` with `can_push = false`

### Requirement: Deploy key format and expiry
`key` SHALL be an OpenSSH public key (`ssh-ed25519`, `ssh-rsa`, `ecdsa-sha2-*` or `sk-*`) and `expires_at` SHALL be set as an RFC 3339 timestamp (`secrets-rotation`: no credential without expiry).

#### Scenario: Private key pasted
- **WHEN** a deploy key sets `key` to the content of a private key file instead of the `.pub` file
- **THEN** the plan fails with "deploy_keys[*].key must be an OpenSSH public key (ssh-ed25519, ssh-rsa, ecdsa-sha2-*, sk-*)."

#### Scenario: Deploy key without expiry
- **WHEN** a deploy key omits `expires_at`
- **THEN** the plan fails with "deploy_keys[*].expires_at is required, as an RFC 3339 timestamp."
