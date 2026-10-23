# Spec Delta

## Purpose

Labels and badges declared on created groups and projects, so issue and merge request triage and the project overview links are the same everywhere in the tree.

## ADDED Requirements

### Requirement: Labels
Each `labels` entry of a group or project SHALL create a label named by its key, keyed `"<owner key>:<name>"`, with `color` (`#RRGGBB` or a CSS colour name), optional `description` and, on projects, optional `priority` (zero or more).

#### Scenario: Group label
- **WHEN** group `platform` sets `labels = { bug = { color = "#d9534f" } }`
- **THEN** the plan creates `gitlab_group_label.this["platform:bug"]`

#### Scenario: Malformed colour
- **WHEN** a label sets `color = "#12345"`
- **THEN** the plan fails with "labels[*].color must be #RRGGBB or a CSS colour name."

#### Scenario: Negative priority
- **WHEN** a project label sets `priority = -1`
- **THEN** the plan fails with "labels[*].priority must be null or >= 0."

### Requirement: Badges
Each `badges` entry of a group or project SHALL create a badge named by its key, keyed `"<owner key>:<name>"`, with `link_url` and `image_url`, both `http(s)` URLs that may use GitLab placeholders such as `%{project_path}`.

#### Scenario: Pipeline badge on a group
- **WHEN** group `platform` sets `badges = { pipeline = { link_url = "https://gitlab.com/%{project_path}/-/pipelines", image_url = "https://gitlab.com/%{project_path}/badges/%{default_branch}/pipeline.svg" } }`
- **THEN** every project of `platform` shows the pipeline badge

#### Scenario: Badge without a URL scheme
- **WHEN** a badge sets `link_url = "gitlab.com/x"`
- **THEN** the plan fails with "badges[*] link_url and image_url must start with http:// or https://."
