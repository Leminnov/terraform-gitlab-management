# Agent-OS Profile: Terraform Module

This profile defines the standard configuration files that form the development environment ("agent operating system") for Terraform module projects. Each section describes a configuration file, its purpose, and its canonical content.

Use this profile to bootstrap new projects or audit existing ones for compliance.

---

## Pre-commit

**File**: `.pre-commit-config.yaml`
**Purpose**: Git hook framework that enforces code quality checks before commits reach the repository.
**Tool version**: `pre-commit 4.3` (managed by mise)

### Hook Types

All standard hook types are registered:

- `pre-commit`
- `pre-merge-commit`
- `pre-push`
- `prepare-commit-msg`
- `commit-msg`
- `post-checkout`
- `post-commit`
- `post-merge`
- `post-rewrite`

### Hooks

**General hooks** (`pre-commit/pre-commit-hooks` v6.0.0):

| Hook | Purpose | Notes |
|------|---------|-------|
| `check-yaml` | Validate YAML syntax | `--allow-multiple-documents` |
| `check-json` | Validate JSON syntax | |
| `detect-private-key` | Block accidental key commits | |
| `trailing-whitespace` | Trim trailing whitespace | |
| `no-commit-to-branch` | Protect master branch | `--branch=master` |
| `check-merge-conflict` | Detect conflict markers | `--assume-in-merge` |
| `end-of-file-fixer` | Ensure newline at EOF | Excludes `CHANGELOG.md` |

**Terraform hooks** (`antonbabenko/pre-commit-terraform` v1.103.0):

| Hook | Purpose |
|------|---------|
| `terraform_fmt` | Enforce canonical formatting |
| `terraform_docs` | Auto-generate documentation |
| `terraform_tflint` | Run linter checks |

### Reference

```yaml
default_install_hook_types:
    - pre-commit
    - pre-merge-commit
    - pre-push
    - prepare-commit-msg
    - commit-msg
    - post-checkout
    - post-commit
    - post-merge
    - post-rewrite

repos:
-   repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
    -   id: check-yaml
        name: "Check YAML"
        description: "Verify YAML syntax"
        args:
        - --allow-multiple-documents
    - id: check-json
    - id: detect-private-key
    -   id: trailing-whitespace
        name: "Trailing Whitespaces"
        description: "Trims trailing whitespaces"
    -   id: no-commit-to-branch
        name: "No Commits to Master"
        description: "Protect Master from direct checkins"
        args:
        - --branch=master
    -   id: check-merge-conflict
        name: "MergeRequests conflicts"
        description: "Check for files that contain merge conflict strings."
        args:
        - --assume-in-merge
    - id: end-of-file-fixer
      exclude: ^CHANGELOG\.md$

-   repo: https://github.com/antonbabenko/pre-commit-terraform.git
    rev: v1.103.0
    hooks:
    - id: terraform_fmt
    - id: terraform_docs
    - id: terraform_tflint
```

---

## License

**File**: `LICENSE`
**Purpose**: Legal terms under which the module is distributed.
**License type**: Apache License 2.0

### Key attributes

- **SPDX identifier**: `Apache-2.0`
- **Copyright holder**: `LEMINNOV`
- **Copyright year**: Year of creation (e.g. `2026`)
- **Permissive**: Allows commercial use, modification, distribution, patent use
- **Conditions**: License and copyright notice must be included with distributions

### Copyright line

```
Copyright <YEAR> LEMINNOV
```

---

## Mise

**File**: `mise.toml`
**Purpose**: Tool version manager that ensures consistent development tool versions across environments.
**Sensitive companion**: `mise.local.toml` (gitignored, holds secrets like API keys and tokens)

### Settings

```toml
[settings]
auto_install = true
```

### Tool versions

| Tool | Version | Purpose |
|------|---------|---------|
| `pre-commit` | `4.3` | Git hooks framework |
| `git-cliff` | `2.7.0` | Changelog generator |
| `age` | `1.2` | Encryption tool |
| `sops` | `3.11` | Secret management |
| `shfmt` | `3.12` | Shell formatter |
| `yamlfmt` | `0.20` | YAML formatter |
| `opentofu` | `1.11` | Terraform-compatible IaC |
| `terraform-docs` | `0.21.0` | Module documentation generator |
| `tflint` | `0.56.0` | Terraform linter |
| `python` | `3.13` | Required by pre-commit |

### Standard tasks

| Task | Description |
|------|-------------|
| `rm-cache` | Remove `.terramate-cache` directories |
| `rm-terraform` | Remove `.terraform` directories |
| `rm-lock` | Remove `.terraform.lock.hcl` files |
| `rm-all` | Remove all generated/cached terraform artifacts (cache, .terraform, lock files, state files) |
| `changelog` | Generate `CHANGELOG.md` using git-cliff |

### Reference

```toml
[settings]
auto_install = true

[tools]
pre-commit = '4.3'
git-cliff = '2.7.0'
age = '1.2'
sops = '3.11'
shfmt = '3.12'
yamlfmt = '0.20'
opentofu = '1.11'
terraform-docs = '0.21.0'
tflint = '0.56.0'
python = '3.13'

[tasks.rm-cache]
run = 'find . -type d -name ".terramate-cache" -prune -exec rm -rf {} \;'

[tasks.rm-terraform]
run = 'find . -type d -name ".terraform" -prune -exec rm -rf {} \;'

[tasks.rm-lock]
run = 'find . -type f -name ".terraform.lock.hcl" -prune -exec rm -rf {} \;'

[tasks.rm-all]
run = '''
find . -type d -name ".terramate-cache" -prune -exec rm -rf {} \;
find . -type d -name ".terraform" -prune -exec rm -rf {} \;
find . -type f -name ".terraform.lock.hcl" -prune -exec rm -rf {} \;
find . -type f -name "terraform.tfstate*" -prune -exec rm -rf {} \;
'''

[tasks.changelog]
description = "Update CHANGELOG.md (fetches all tags first)"
run = '''
git-cliff --config .cliff.toml --output CHANGELOG.md
'''
```

---

## README

**File**: `README.md`
**Purpose**: Primary documentation entry point for the module.
**Auto-generated section**: terraform-docs populates between `BEGIN_TF_DOCS` / `END_TF_DOCS` markers.

### Required structure

1. **Title**: `# <Provider> <Domain> Terraform Module`
2. **Badges**: License, Terraform version, Provider version, Latest release
3. **Description**: One-sentence summary of the module
4. **Features**: Bullet list of capabilities
5. **Requirements**: Table with terraform and provider version constraints
6. **Usage**: Code examples
   - Basic Example
   - Complete Example (with all features)
   - Conditional Creation example
7. **Security Considerations**: Numbered list of key security items (link to `SECURITY.md`)
8. **Known Limitations**: Numbered list of provider/API limitations
9. **terraform-docs block**: `<!-- BEGIN_TF_DOCS -->` ... `<!-- END_TF_DOCS -->`
10. **Documentation table**: Links to README, SECURITY.md, TESTING.md, CHANGELOG.md
11. **Contributing**: Guidelines for contributors
12. **License**: Short reference with link to LICENSE file
13. **Disclaimer**: Provided "as is" notice
14. **Badge link references**: At the end of the file

### Badge format

```markdown
[![Apache 2.0][apache-shield]][apache]
[![Terraform][terraform-badge]][terraform-url]
[![<Provider> Provider][provider-badge]][provider-url]
[![Latest Release][release-badge]][release-url]
```

### Link references (at bottom)

```markdown
[apache]: https://opensource.org/licenses/Apache-2.0
[apache-shield]: https://img.shields.io/badge/License-Apache%202.0-blue.svg

[terraform-badge]: https://img.shields.io/badge/Terraform-%3E%3D1.10-623CE4
[terraform-url]: https://www.terraform.io

[provider-badge]: https://img.shields.io/badge/<provider>%20Provider-~%3E<version>-<color>
[provider-url]: <registry-url>

[release-badge]: https://img.shields.io/gitlab/v/release/<group>/<project>?include_prereleases&sort=semver
[release-url]: https://gitlab.com/<group>/<project>/-/releases
```

---

## Gitignore

**File**: `.gitignore`
**Purpose**: Exclude build artifacts, secrets, IDE files, and OS-specific files from version control.

### Categories

| Category | Patterns | Notes |
|----------|----------|-------|
| **Terraform** | `.terraform`, `.terragrunt-cache`, `*.tfstate*`, `*.tfplan`, `*.tfvars`, `.terraform.lock.hcl` | `!example.tfvars` is excluded from ignore |
| **Provider workaround** | `main_providers.tf` | Except `terraform/common/main_providers.tf` |
| **Secrets** | `*.key`, `*.pem`, `secrets.auto.tfvars` | `!secrets/*` allows encrypted secrets |
| **OS X** | `.history`, `.DS_Store` | |
| **IntelliJ** | `.idea_modules`, `*.iml`, `*.iws`, `*.ipr`, `.idea/`, `build/`, `*/build/`, `out/` | |
| **VS Code** | `.vscode/` | |
| **Pre-commit** | `.cache/` | |
| **Temp files** | `*.tmp`, `*.bak`, `*~` | |
| **Env/secrets** | `.envrc`, `mise.local.toml` | |

### Reference

```gitignore
# Terraform
.terraform
.terragrunt-cache
*.tfstate*
*.tfplan
*.tfvars
!example.tfvars
.terraform.lock.hcl

# Copies of main_providers.tf
main_providers.tf

# Except original (see related issue - https://github.com/gruntwork-io/terragrunt/issues/785)
!terraform/common/main_providers.tf

# Secrets are not allowed in general
*.key
*.pem
secrets.auto.tfvars

# Secrets are encrypted using git-crypt
!secrets/*

# OS X
.history
.DS_Store

# IntelliJ
.idea_modules
*.iml
*.iws
*.ipr
.idea/
build/
*/build/
out/

# VS Code
.vscode/

# Pre-commit cache
.cache/

# Temporary files
*.tmp
*.bak
*~

.envrc

mise.local.toml
```

---

## TFLint

**File**: `.tflint.hcl`
**Purpose**: Terraform linter configuration enforcing code quality and naming conventions.

### Plugin

- **Plugin**: `terraform` (built-in)
- **Preset**: `recommended`

### Rules

| Rule | Enabled | Purpose |
|------|---------|---------|
| `terraform_deprecated_interpolation` | yes | Flag deprecated `"${var.x}"` syntax |
| `terraform_documented_outputs` | yes | All outputs must have descriptions |
| `terraform_documented_variables` | yes | All variables must have descriptions |
| `terraform_naming_convention` | yes | Enforce `snake_case` naming |
| `terraform_required_providers` | yes | Require provider version constraints |
| `terraform_required_version` | yes | Require terraform version constraint |
| `terraform_standard_module_structure` | yes | Enforce standard file structure |
| `terraform_typed_variables` | yes | All variables must have type constraints |
| `terraform_unused_declarations` | yes | Flag unused variables/locals |
| `terraform_unused_required_providers` | yes | Flag unused provider declarations |

### Reference

```hcl
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_unused_required_providers" {
  enabled = true
}
```

---

## Cliff (git-cliff)

**File**: `.cliff.toml`
**Purpose**: Changelog generator configuration. Produces `CHANGELOG.md` from git history.
**Tool version**: `git-cliff 2.7.0` (managed by mise)

### Changelog format

- **Header**: Standard changelog title with description
- **Body template**: Groups commits by version tag with date
- **Conventional commits**: Disabled (plain commit messages)
- **Sort order**: Newest first

### Skipped commits

Commits matching any of these patterns are excluded from the changelog:

| Pattern | Reason |
|---------|--------|
| `^Merge.*` | Merge commits |
| `.*CHANGELOG.*` | Changelog-related |
| `.*[Cc]hangelog.*` | Changelog-related (case variants) |
| `.*chglog.*` | Changelog tool references |
| `.*\[skip ci\].*` | CI skip markers |
| `.*\[ci skip\].*` | CI skip markers (alt format) |
| `^Updated CHANGELOG.*` | Changelog update commits |

### Reference

```toml
[changelog]
header = """
# Changelog

All notable changes to this project will be documented in this file.\n
"""
body = """
{% if version %}\
## [{{ version | trim_start_matches(pat="v") }}] - {{ timestamp | date(format="%Y-%m-%d") }}
{% for commit in commits -%}
- {{ commit.message }}
{% endfor -%}

{% endif %}\
"""
trim = true
footer = ""

[git]
conventional_commits = false
filter_unconventional = false
split_commits = false
commit_preprocessors = []
filter_commits = false
topo_order = false
sort_commits = "newest"

[[git.commit_parsers]]
message = "^Merge.*"
skip = true

[[git.commit_parsers]]
message = ".*CHANGELOG.*"
skip = true

[[git.commit_parsers]]
message = ".*[Cc]hangelog.*"
skip = true

[[git.commit_parsers]]
message = ".*chglog.*"
skip = true

[[git.commit_parsers]]
message = ".*\\[skip ci\\].*"
skip = true

[[git.commit_parsers]]
message = ".*\\[ci skip\\].*"
skip = true

[[git.commit_parsers]]
message = "^Updated CHANGELOG.*"
skip = true
```

---

## EditorConfig

**File**: `.editorconfig`
**Purpose**: Enforce consistent coding styles across editors and IDEs.

### Global defaults

| Setting | Value |
|---------|-------|
| `root` | `true` |
| `end_of_line` | `lf` |
| `insert_final_newline` | `true` |
| `charset` | `utf-8` |
| `trim_trailing_whitespace` | `true` |

### Per-file-type overrides

| Pattern | Indent style | Indent size | Trailing whitespace |
|---------|-------------|-------------|---------------------|
| `*.tf` | space | 2 | trim |
| `*.hcl` | space | 2 | trim |
| `*.{yml,yaml}` | space | 2 | trim |
| `*.md` | space | 2 | **preserve** |
| `Makefile` | tab | (default) | trim |

### Reference

```editorconfig
root = true

[*]
end_of_line = lf
insert_final_newline = true
charset = utf-8
trim_trailing_whitespace = true

[*.tf]
indent_style = space
indent_size = 2

[*.hcl]
indent_style = space
indent_size = 2

[*.{yml,yaml}]
indent_style = space
indent_size = 2

[*.md]
trim_trailing_whitespace = false
indent_style = space
indent_size = 2

[Makefile]
indent_style = tab
```

---

## GitLab CI

**Files**: `.gitlab-ci.yml`, `.gitlab/global.yml`, `.gitlab/pre-commit.yml`, `.gitlab/release.yml`
**Purpose**: CI/CD pipeline for validation, changelog verification, and release automation.

### Structure

The pipeline is split into modular includes:

```yaml
# .gitlab-ci.yml
include:
  - local: '.gitlab/global.yml'
  - local: '.gitlab/pre-commit.yml'
  - local: '.gitlab/release.yml'
```

### Global configuration (`.gitlab/global.yml`)

| Variable | Value | Purpose |
|----------|-------|---------|
| `GIT_DEPTH` | `0` | Full git history for tag detection |
| `MISE_VERSION` | `2024.12.14` | Mise installer version |
| `OSV_SCANNER_VERSION` | `1.9.1` | Vulnerability scanner version |

**Stages**: `validate`, `release`

### Pre-commit job (`.gitlab/pre-commit.yml`)

- **Stage**: `validate`
- **Image**: `ubuntu:24.04`
- **Condition**: Runs when `.pre-commit-config.yaml` exists
- **Cache**: Pre-commit and mise caches keyed by branch
- **Steps**:
  1. Install git, curl, ca-certificates, python3
  2. Install mise and all tools from `mise.toml`
  3. Install osv-scanner for vulnerability scanning
  4. Create initial git tag if none exist (required by git-cliff)
  5. Run osv-scanner (skippable via `SKIP_OSV_SCAN=true`)
  6. Run `pre-commit run -a -v`

### Validation jobs (`.gitlab/release.yml`)

**validate:opentofu**:
- **Image**: `ghcr.io/opentofu/opentofu:1.11`
- **Runs**: `tofu init -backend=false`, `tofu validate`, `tofu fmt -check -recursive`

**validate:tflint**:
- **Image**: `ghcr.io/terraform-linters/tflint:v0.56.0`
- **Runs**: `tflint --init`, `tflint --recursive`

### Changelog verification (`.gitlab/release.yml`)

**verify:changelog**:
- **Trigger**: Only on semantic version tags (`v*.*.*`)
- **Action**: Regenerates changelog and compares with committed version
- **Blocking**: Fails if changelog is outdated

### Release job (`.gitlab/release.yml`)

**create:release**:
- **Trigger**: Only on semantic version tags (`v*.*.*`)
- **Needs**: `pre-commit`, `validate:opentofu`, `validate:tflint`, `verify:changelog`
- **Action**: Generates release notes with git-cliff, creates GitLab release
- **Assets**: Source archives (tar.gz, zip) and CHANGELOG link
