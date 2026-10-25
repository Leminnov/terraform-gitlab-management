# Spec Delta

## Purpose

Supply-chain controls on the package and container registries of created projects: who may push or delete packages and images, which container tags are protected, and how old images are cleaned up.

## ADDED Requirements

### Requirement: Package protection rules
Each `package_protection_rules` entry of a project SHALL protect the packages of `package_type` whose names match `package_name_pattern` (wildcard `*`), keyed `"<project key>:<label>"`.
- `package_type` is one of `cargo`, `conan`, `generic`, `helm`, `maven`, `npm`, `nuget`, `pypi` or `terraform_module`.
- `minimum_access_level_for_push` defaults to `maintainer` and is `maintainer`, `owner` or `admin`.
- `minimum_access_level_for_delete` is `null`, `owner` or `admin`.

#### Scenario: Release packages pushed by maintainers only
- **WHEN** project `platform/sdk` sets `package_protection_rules = { npm = { package_type = "npm", package_name_pattern = "@leminnov/*" } }`
- **THEN** the plan creates `gitlab_project_package_protection_rule.this["platform/sdk:npm"]` with push limited to maintainers

#### Scenario: Unknown package type
- **WHEN** a rule sets `package_type = "docker"`
- **THEN** the plan fails with "package_protection_rules[*].package_type must be one of: cargo, conan, generic, helm, maven, npm, nuget, pypi, terraform_module."

#### Scenario: Developer push level
- **WHEN** a rule sets `minimum_access_level_for_push = "developer"`
- **THEN** the plan fails with "package_protection_rules[*] needs a package_name_pattern, minimum_access_level_for_push maintainer, owner or admin, and minimum_access_level_for_delete null, owner or admin."

### Requirement: Container repository protection rules
Each `container_protection_rules` entry of a project SHALL protect the container repositories whose path matches the project's full path followed by `path_pattern` (wildcard `*`), keyed `"<project key>:<label>"`. Its `minimum_access_level_for_push` and `minimum_access_level_for_delete` default to `maintainer`, and each is `maintainer`, `owner` or `admin`.

#### Scenario: Every image of the project
- **WHEN** project `platform/api` sets `container_protection_rules = { all = { path_pattern = "*" } }`
- **THEN** the plan protects `<full path of platform/api>*` for maintainers

#### Scenario: Developer delete level
- **WHEN** a rule sets `minimum_access_level_for_delete = "developer"`
- **THEN** the plan fails with "container_protection_rules[*] access levels must be maintainer, owner or admin."

### Requirement: Protected container tags
Each `container_tag_protection_rules` entry of a project SHALL protect the container tags matching the regular expression `tag_name_pattern` (1 to 100 characters), keyed `"<project key>:<label>"`. Its `minimum_access_level_for_push` and `minimum_access_level_for_delete` default to `maintainer`, and each is `maintainer`, `owner` or `admin`.

#### Scenario: Release tags
- **WHEN** a project sets `container_tag_protection_rules = { release = { tag_name_pattern = "^v[0-9]+" } }`
- **THEN** the plan creates `gitlab_project_container_tag_protection.this["<project key>:release"]` limited to maintainers

#### Scenario: Empty tag pattern
- **WHEN** a rule sets `tag_name_pattern = ""`
- **THEN** the plan fails with "container_tag_protection_rules[*] needs a tag_name_pattern of 1 to 100 characters and access levels maintainer, owner or admin."

### Requirement: Container cleanup policy
A project's `container_expiration_policy` SHALL default to `null`, which leaves GitLab's policy untouched. When set, the module SHALL enable cleanup with `cadence` (default `7d`: one of `1d`, `7d`, `14d`, `1month`, `3month`), `keep_n` (default 10: one of 1, 5, 10, 25, 50, 100), `older_than` (default `90d`: one of `7d`, `14d`, `30d`, `90d`), `name_regex_delete` (default `.*`) and an optional `name_regex_keep`.

#### Scenario: Cleanup with defaults
- **WHEN** a project sets `container_expiration_policy = {}`
- **THEN** the plan enables cleanup every 7 days, keeping the 10 latest tags and deleting tags older than 90 days

#### Scenario: Unsupported cadence
- **WHEN** a project sets `container_expiration_policy = { cadence = "2d" }`
- **THEN** the plan fails with "container_expiration_policy cadence must be 1d, 7d, 14d, 1month or 3month, keep_n one of 1, 5, 10, 25, 50, 100, and older_than one of 7d, 14d, 30d, 90d."
