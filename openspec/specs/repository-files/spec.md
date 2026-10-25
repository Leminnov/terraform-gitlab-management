# repository-files Specification

## Purpose
Files committed to the default branch of created projects (`CODEOWNERS`, a `.gitlab-ci.yml` that includes a shared pipeline, `renovate.json`, ...), either owned by Terraform or seeded once and then owned by the project's developers.

## Requirements

### Requirement: Files on the default branch
Each `files` entry of a project SHALL commit the file at the path given by its key to the project's default branch, keyed `"<project key>:<path>"`.
- `content` is the file content.
- `encoding` is `text` (default) or `base64`.
- `executable` defaults to `false`.

The branches the module creates SHALL start from the default branch after its files are committed, so `develop` holds them too. A file may replace the `README.md` that `initialize_with_readme` creates.

#### Scenario: CODEOWNERS on a new project
- **WHEN** project `platform/api` sets `files = { CODEOWNERS = { content = "* @leminnov/platform\n" } }`
- **THEN** the plan commits `CODEOWNERS` to `main`, and the `develop` branch is created from a commit that contains it

#### Scenario: Absolute path
- **WHEN** a file is keyed `/CODEOWNERS` or `docs/../CODEOWNERS`
- **THEN** the plan fails with "files keys must be relative paths without a leading / or ./ and without .. segments."

#### Scenario: Unknown encoding
- **WHEN** a file sets `encoding = "gzip"`
- **THEN** the plan fails with "files[*].encoding must be text or base64."

#### Scenario: Project without a default branch
- **WHEN** a project sets `initialize_with_readme = false` and declares `files` or `kubernetes_agents`
- **THEN** the plan fails with "projects[*].files and kubernetes_agents need initialize_with_readme = true (a default branch to commit to)."

### Requirement: Managed files
A file with `managed = true` (the default) SHALL be owned by Terraform: an edit made in the repository is reverted by the next apply, and a change of `content` in the input is committed.

#### Scenario: Edited in the repository
- **WHEN** a developer edits a managed `CODEOWNERS` and the module is applied again
- **THEN** the plan updates the file back to the input's content

### Requirement: Seeded files
A file with `managed = false` SHALL be committed once, when it is created. Later changes to its content, in the repository or in the input, SHALL produce no change. Deleting the file in the repository recreates it on the next apply.

#### Scenario: Developers own the seeded pipeline
- **WHEN** a seeded `.gitlab-ci.yml` is edited in the repository and its input content also changes
- **THEN** the next plan shows no change for that file
