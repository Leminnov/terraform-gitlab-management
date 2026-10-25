# Spec Delta

## ADDED Requirements

### Requirement: Deploy keys shared with other projects
Each project's `enabled_deploy_keys` SHALL enable, read-only, the deploy keys of other created projects, given as `"<project key>:<title>"`. Its `enabled_deploy_key_ids` SHALL do the same for existing deploy keys given by ID. Each enablement is keyed `"<project key>:<deploy key key or ID>"`, so one machine key can read several repositories.

#### Scenario: GitOps key reading two repositories
- **WHEN** project `platform/api` declares the deploy key `argocd` and project `platform/config` sets `enabled_deploy_keys = ["platform/api:argocd"]`
- **THEN** the plan creates `gitlab_deploy_key_enable.this["platform/config:platform/api:argocd"]` with `can_push = false`

#### Scenario: Unknown deploy key
- **WHEN** `enabled_deploy_keys` names the project's own key or an undeclared key
- **THEN** the plan fails with "enabled_deploy_keys entries must name a deploy key of another created project, as \"<project key>:<title>\"."
