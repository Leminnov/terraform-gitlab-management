# Spec Delta

## Purpose

GitLab agents for Kubernetes registered in created projects, with the token the in-cluster agent connects with, and the `ci_access` configuration that lets the CI/CD jobs of other groups and projects reach the cluster.

## ADDED Requirements

### Requirement: Agent registration
Each `kubernetes_agents` entry of a project SHALL register an agent named by its key, keyed `"<project key>:<name>"`, with one agent token of the same name. The sensitive output `kubernetes_agent_tokens` SHALL map the agent key to that token. The key SHALL be a DNS label: lowercase letters, digits and `-`, at most 63 characters, starting and ending with a letter or digit.

#### Scenario: Agent for the production cluster
- **WHEN** project `platform/infra` sets `kubernetes_agents = { prod = {} }`
- **THEN** the plan creates `gitlab_cluster_agent.this["platform/infra:prod"]` and its token, and `kubernetes_agent_tokens["platform/infra:prod"]` is shown as `<sensitive>`

#### Scenario: Agent name with capitals
- **WHEN** an agent is keyed `Prod_Cluster`
- **THEN** the plan fails with "kubernetes_agents keys must be DNS labels: lowercase letters, digits and -, at most 63 characters."

### Requirement: CI access from other groups and projects
An agent's `ci_access` SHALL authorise the CI/CD jobs of the created groups and projects it names by key (`groups`, `projects`) and of existing ones it names by full path (`group_paths`, `project_paths`). The module SHALL write the agent configuration `.gitlab/agents/<name>/config.yaml` as a managed file listing them by full path. An agent with an empty `ci_access` SHALL get no configuration file. A `files` entry SHALL NOT use the configuration path of a declared agent.

#### Scenario: Cluster reachable from a team's pipelines
- **WHEN** the agent `prod` of `platform/infra` sets `ci_access = { groups = ["platform"] }`
- **THEN** `.gitlab/agents/prod/config.yaml` on the default branch of `platform/infra` lists the full path of the created group `platform` under `ci_access.groups`

#### Scenario: Unknown group key
- **WHEN** `ci_access.groups` names `teams/missing`, which `groups` does not declare
- **THEN** the plan fails with "kubernetes_agents[*].ci_access groups and projects must be keys of groups and projects."

#### Scenario: Hand-written agent configuration
- **WHEN** project `platform/infra` declares the agent `prod` and also `files = { ".gitlab/agents/prod/config.yaml" = { content = "..." } }`
- **THEN** the plan fails with "files keys must not use .gitlab/agents/<name>/config.yaml for a declared kubernetes_agents entry (the module writes it)."
