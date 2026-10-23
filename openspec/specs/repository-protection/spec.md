# repository-protection Specification

## Purpose
The branches and protections of every created project: the default branch, the integration branches created from it, who may push and merge to each protected branch, and who may create protected tags, following the git-branching and gitlab-project-settings standards by default.

## Requirements

### Requirement: Extra branches from the default branch
Each `branches` entry of a project SHALL create a branch of that name from `ref`, or from the project's default branch when `ref` is unset. `branches` SHALL default to `{ develop = {} }`.

#### Scenario: Default develop branch
- **WHEN** a project sets no `branches`
- **THEN** the plan creates `gitlab_branch.this["<project key>:develop"]` from `main`

#### Scenario: No extra branch
- **WHEN** a project sets `branches = {}`
- **THEN** no branch resource is planned for it

### Requirement: Branches need an initialised repository
A project with `initialize_with_readme = false` SHALL declare no `branches`, since there is no commit to branch from.

#### Scenario: Branch on an empty repository
- **WHEN** a project sets `initialize_with_readme = false` and keeps the default `branches`
- **THEN** the plan fails with "projects[*].branches must be empty when initialize_with_readme = false (no commit to branch from)."

### Requirement: Default branch protection
When `protected_branches` is unset, a project SHALL protect its default branch with push and merge for maintainers and, when `develop` is in `branches`, `develop` with push and merge for developers, neither allowing force push.

#### Scenario: Default protections
- **WHEN** a project sets neither `protected_branches` nor `branches`
- **THEN** the plan protects `main` (maintainer push, maintainer merge, no force push) and `develop` (developer push, developer merge, no force push)

#### Scenario: Trunk-based project
- **WHEN** a project sets `default_branch = "trunk"` and `branches = {}`
- **THEN** only `trunk` is protected, for maintainers

### Requirement: Declared branch protection
When `protected_branches` is set, it SHALL replace the defaults: each entry protects the branch or wildcard named by its key, with `push_access_level` and `merge_access_level` (default `maintainer`) each one of `no one`, `developer`, `maintainer` or `admin`, and `allow_force_push` (default `false`).

#### Scenario: Release branches
- **WHEN** a project sets `protected_branches = { main = {}, "release/*" = { push_access_level = "no one" } }`
- **THEN** exactly `main` and `release/*` are protected, and nobody can push directly to `release/*`

#### Scenario: Unknown access level
- **WHEN** a protected branch sets `merge_access_level = "owner"`
- **THEN** the plan fails with "projects[*].protected_branches[*] access levels must be one of: no one, developer, maintainer, admin."

### Requirement: Protected tags
Each `protected_tags` entry of a project SHALL protect the tag or wildcard named by its key, with `create_access_level` (default `maintainer`) one of `no one`, `developer`, `maintainer` or `admin`. `protected_tags` SHALL default to `{ "v*" = {} }`.

#### Scenario: Release tags protected by default
- **WHEN** a project sets no `protected_tags`
- **THEN** the plan protects `v*` so only maintainers can create release tags

#### Scenario: Unknown tag level
- **WHEN** a protected tag sets `create_access_level = "guest"`
- **THEN** the plan fails with "projects[*].protected_tags[*].create_access_level must be one of: no one, developer, maintainer, admin."

### Requirement: Protection read back unchanged
After apply, a second plan SHALL show no change for the default branch, extra branches, protected branches and protected tags, including the default-branch protection GitLab creates on its own when the project is initialised.

#### Scenario: Re-plan after creating a project
- **WHEN** the integration fixture plans again after creating a project with the default protections
- **THEN** the plan is empty
