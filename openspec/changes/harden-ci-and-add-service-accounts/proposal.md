# Proposal

## Why

v13 creates the group and project tree, but offers no way to harden its projects' CI settings: on the sandbox, jobs are public and maintainers can override pipeline variables. On gitlab.com Free the module also cannot issue any automation identity, because access tokens need Premium. The release of v13.0.0 had to put a maintainer's personal token in CI for that reason, and the least-privilege run never ran.

GitLab 18 now offers service accounts on Free, in top-level groups, subgroups and projects. Provider `gitlabhq/gitlab` 19.5 also exposes cross-project runner and deploy-key sharing, registry protection rules, repository files and Kubernetes agents. None of these need a new provider.

## What Changes

Opt-in CI hardening on created projects (semver **minor**: v13.1.0):
- A new `projects[*].ci` object. Its `hardening_enabled` flag defaults to `false`, which leaves GitLab's CI settings untouched, so existing v13 projects do not change. With `hardening_enabled = true` the project gets safe defaults:
  - `public_jobs = false`;
  - pipeline variable overrides by no one (`no_one_allowed`);
  - merge request pipelines protected;
  - separate caches for protected branches;
  - forward deployment on;
  - job-token pushes to the repository off;
  - skipped pipelines do not count as successful.
- Each of these settings can also be set on its own, with or without hardening; an explicit value always wins.
- The other CI settings default to `null`, which leaves GitLab's value: CI config path, job timeout, Git depth, pipeline retention, OIDC `sub` claim components, group and instance runners.

Identities and tokens:
- **Service accounts** at three levels, each with nested tokens:
  - standalone `service_accounts` on an existing top-level group or intermediate subgroup;
  - `groups[*].service_accounts` on a created subgroup;
  - `projects[*].service_accounts` on a created project.
- `members[*].service_account` grants a service account access by key, so a bot's scope is explicit and checked at plan against GitLab's rule: a subgroup account only within its subgroup, a project account only in its project.
- `rotation_configuration` (rotate at apply) on group and project access tokens, standalone and nested, and on service-account tokens. It replaces `expires_at`; exactly one of the two is required.

Pipelines and runners:
- Deploy freeze periods, secure files (text content) and the CI/CD catalog flag on created projects.
- `shared_runners_setting` on created groups.
- Cross-project sharing:
  - `projects[*].enabled_runners` enables another created project's runner, or an existing runner by ID;
  - `projects[*].enabled_deploy_keys` enables another created project's deploy key, or an existing key by ID, read-only.

Supply chain: package protection rules, container repository protection rules, protected container tags, and an opt-in container cleanup policy on created projects.

Repository content:
- `projects[*].files` commits files on the default branch. Each file is either managed (Terraform owns the content and reverts edits) or seeded once (developers own it after creation).
- `projects[*].kubernetes_agents` registers GitLab agents for Kubernetes. Each gets a token and a managed `config.yaml` whose `ci_access` names created or existing groups and projects.

Premium and Ultimate, off by default (`null` or empty):
- merge pipelines and merge trains;
- target branch rules;
- the pipeline cancellation role;
- deployment approval by the pipeline triggerer;
- immutable container tags (Ultimate).

Guardrails: new warnings `public_jobs` and `job_token_push`. `token_lifetime` also reads service-account tokens and the `expiration_days` of every `rotation_configuration`.

Contract:
- Inputs:
  - new `service_accounts`;
  - new object attributes on `groups` and `projects`;
  - `members[*].user_id` becomes optional;
  - access-token `expires_at` becomes optional, since `rotation_configuration` can replace it.
- New outputs: `service_accounts`, `service_account_tokens` (sensitive) and `kubernetes_agent_tokens` (sensitive).
- New themed files `service_accounts.tf`, `registry.tf` and `files.tf`.

Not possible with provider 19.5: fine-grained CI/CD job token permissions (GitLab 18.3). The provider has no argument for them, and the module makes no API calls, so this is documented as a limitation.

What lands in state (the provider has no write-only argument for any of them):
- service-account tokens;
- Kubernetes agent tokens;
- secure file content.

Each gets a `SECURITY.md` row with its rotation procedure.

## Capabilities

### New Capabilities
- `service-accounts`: service accounts in existing groups, created subgroups and created projects; their tokens and outputs.
- `registry-protection`: package and container repository protection rules, protected container tags and the container cleanup policy of created projects.
- `repository-files`: files committed to created projects, managed or seeded once.
- `kubernetes-agents`: GitLab agents for Kubernetes registered in created projects, their tokens and their `ci_access` configuration.

### Modified Capabilities
- `project-ci-settings`: opt-in CI hardening (`ci` object), deploy freeze periods, secure files and the CI/CD catalog flag.
- `access-tokens`: `rotation_configuration` as an alternative to `expires_at`, standalone and nested.
- `access-management`: members may name a service account instead of a user ID, within GitLab's invitation scope.
- `runners`: `shared_runners_setting` on created groups; project runners enabled in other projects.
- `deploy-keys`: deploy keys enabled read-only in other projects.
- `premium-features`: merge trains, target branch rules, cancellation role, deployment approval by triggerer, immutable container tags; all off by default.
- `security-guardrails`: `public_jobs` and `job_token_push` warnings; `token_lifetime` covers service-account tokens and rotation.
- `module-contract`: file layout, output set, what lands in state, and `service_accounts` keys without colon.

## Impact

- **Provider:** `gitlabhq/gitlab ~> 19.5`, unchanged. Every resource used exists in 19.5.0.
- **GitLab server:**
  - subgroup and project service accounts need GitLab 18 or later (gitlab.com qualifies);
  - `ci_pipeline_variables_minimum_override_role` needs 17.1 or later;
  - `ci_id_token_sub_claim_components` needs 17.10 or later;
  - an older self-managed GitLab rejects these at apply.
- **Code:**
  - `variables.tf`, `locals.tf`, `projects.tf`, `groups.tf`, `access.tf`, `ci.tf`, `premium.tf`, `checks.tf` and `outputs.tf` change;
  - `service_accounts.tf`, `registry.tf` and `files.tf` are new;
  - new unit test files, the integration fixture, `examples/complete`, README, `SECURITY.md`, `TESTING.md` and `CHANGELOG.md` are updated.
- **Semver:** minor (v13.1.0). Every new input has a default that changes nothing (hardening off, collections empty, Premium fields `null`). Two attributes become optional: `members[*].user_id` and access-token `expires_at`. A v13.0.0 state plans with no change.
- **Integration sandbox (`leminnov/test`):** the owner run gains subgroup, project and standalone (existing intermediate subgroup) service accounts, the CI settings, freeze periods, a secure file, runner and deploy-key enablement, registry protection, managed and seeded files and a Kubernetes agent. Top-level service accounts are unit-tested only, by maintainer decision: they would be created in the `leminnov` organisation group.
