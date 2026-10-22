# AGENTS.md — terraform-modules-gitlab-management

## Project
OpenTofu/Terraform module that manages GitLab CI/CD settings: group and project
CI/CD variables, group deploy tokens, pipeline schedules and their variables,
runners, and group and project access tokens. Published at
`gitlab.com/leminnov/terraform/modules/gitlab-management`; consumers pin a git tag.
Planning uses OpenSpec (`openspec/`; `openspec/specs/` is the current contract).
Engineering standards live in the `quality`, `repository`, `terraform`, `git`,
`gitlab`, `secrets` and `openspec` stores (pinned to a tag in
`openspec/config.yaml`), the single source of truth; this file only routes to them.

## Non-negotiables (apply to EVERY change, no fetch needed)
Every request targets simple, efficient, secure, production-level code:
- Simple: the smallest change that solves the task; no speculative abstraction,
  unused option, dead code or placeholder left behind.
- Efficient: no redundant call, loop, resource or step the tooling already performs.
- Secure: no secret in source, logs or state; least privilege; inputs validated;
  safe defaults; no control weakened silently.
- Production-level: errors handled, idempotent, tested, documented, verified with the
  repository commands before reporting, and reported as-is.
The checkable form of each line is the `quality` store (`quality-simplicity`,
`quality-efficiency`, `quality-security`, `quality-production-readiness`).
- No `provider {}` or `backend {}` blocks in the module; the caller configures the
  gitlab provider. No `local-exec`, no calls to `glab` or the GitLab REST API.
- `description` on every variable and output; `type` on every variable; no `any`.
- Secrets: a new secret-bearing input is `sensitive = true` + `ephemeral = true`, has no
  default, and reaches the provider through a write-only `*_wo` argument with a
  `*_wo_version` companion. Where the provider has no write-only argument, say so and
  list the value in `SECURITY.md` (what lands in state). Known exceptions today:
  variable and schedule-variable values (not sensitive, `for_each` iterates them) and
  every token GitLab creates. Every output surfacing a token or a value is `sensitive`.
- `for_each` over `count`; resource label `this`; snake_case everywhere; fan-out
  keys stay `"<entry>_<target>"` (changing them replaces resources: needs `moved` blocks).
- Send values in the form GitLab reads back: a second plan after apply must be empty.
- Every behaviour change ships with a unit test in `tests/main.tftest.hcl` (a
  rejected-input run for each new validation), an update to `examples/complete/` (and
  any example it affects), and a commit message fit for the git-cliff changelog.
- Never edit the README between `BEGIN_TF_DOCS` / `END_TF_DOCS`; terraform-docs owns it.
  Never edit `CHANGELOG.md` by hand; `mise run changelog` generates it.

## Standards lookup
Engineering standards are OpenSpec specs in the stores listed under `references:`
in `openspec/config.yaml` (`quality`, `repository`, `terraform`, `git`, `gitlab`,
`secrets`, `openspec`). Inside the OpenSpec skills the index of every spec, with a one-line
summary, is already in the instructions: fetch the specs whose id matches what
you touch, follow them and cite them in your summary. Outside the skills:

    openspec list --specs --store <store>
    openspec show <spec-id> --type spec --store <store>

Easy to miss: for a repository file read the `repository-<topic>` base spec, then
its `terraform-repo-<topic>` extension; `terraform-versioning` for every
major/minor/patch call; `terraform-security` for anything secret-bearing or a
`check` block; `git-*` for branches and commit messages, `gitlab-*` for
`.gitlab-ci.yml`, merge requests and releases, `secrets-*` for how a secret is
stored, injected or rotated; `openspec-*` for how specs, changes and this
configuration are written.

If a store is not registered on this machine, stop and say so; `mise run
spec-setup` registers them. Do not guess the standard.

## Standards index
One line per spec (its Purpose), to pick what to fetch with `openspec show <spec-id> --type spec --store <store>`. Regenerate from the stores when a pin changes.

### quality
- `quality-efficiency`: Code and pipelines do no redundant work: no repeated calls, needless loops, oversized resources or steps the tooling already performs.
- `quality-production-readiness`: Delivered code is complete: errors handled, idempotent, tested, documented, verified, and honestly reported.
- `quality-security`: No secret in source, logs or state; least privilege everywhere; inputs validated; safe defaults; nothing weakened silently.
- `quality-simplicity`: Every change is the smallest one that solves the stated task, with no speculative abstraction, unused option or dead code.

### repository
- `repository-changelog`: Canonical `.cliff.toml` of a repository: how git-cliff produces `CHANGELOG.md` from git history and which commits it skips.
- `repository-editorconfig`: Canonical `.editorconfig` of a repository, enforcing consistent coding styles across editors and IDEs.
- `repository-gitignore`: Canonical `.gitignore` of a repository, excluding secrets, IDE files, OS-specific files, caches and local overrides from version control.
- `repository-gitlab-ci`: Canonical GitLab CI layout of a repository: modular includes for pre-commit validation, changelog verification and release automation.
- `repository-license`: The `LICENSE` file a repository ships: Apache License 2.0 with the organisation's copyright line.
- `repository-mise`: Canonical `mise.toml` for a repository: settings, `min_version`, exact pins for every tool the repository invokes, and the changelog-draft, changelog-verify, release and spec-validate tasks.
- `repository-precommit`: Canonical `.pre-commit-config.yaml` for a repository: registered hook types and the general hooks every repository runs, whatever its stack.
- `repository-readme`: Required structure of the `README.md` of a repository: section order, license and release badges, and link references.
- `repository-versioning`: Every published repository follows semver, releases an annotated `vX.Y.Z` tag on `main` equal to its declared version, records each change in the changelog, and is consumed only by pinned tag.

### terraform
- `terraform-code-style`: Formatting, attribute ordering, expression, comment and lifecycle rules for HCL.
- `terraform-documentation`: README structure, terraform-docs generation, variable descriptions, example READMEs and changelog.
- `terraform-module-structure`: Standard file layout, provider placement, examples and tooling for every Terraform module.
- `terraform-naming`: Naming rules for resources, data sources, locals, tags and cloud resource names.
- `terraform-outputs`: What a module exposes, how outputs are named, declared and ordered.
- `terraform-providers`: Version pinning and provider placement rules for reusable and root modules.
- `terraform-repo-editorconfig`: Terraform-module additions to `repository-editorconfig` from the `repository` store: the `*.tf` and `*.hcl` indentation sections.
- `terraform-repo-gitignore`: Terraform-module additions to `repository-gitignore` from the `repository` store: Terraform artifacts, the provider-file workaround and `secrets.auto.tfvars`.
- `terraform-repo-gitlab-ci`: Terraform-module additions to `repository-gitlab-ci` from the `repository` store: the `validate:opentofu`, `validate:tflint`, `validate:examples` and `security:trivy` jobs, the optional `integration.yml` include, and their place in the release chain.
- `terraform-repo-mise`: Terraform-module additions to `repository-mise` from the `repository` store: exact pins for the Terraform toolchain, the `rm-*` cleanup tasks and the `test` and `scan` tasks.
- `terraform-repo-precommit`: Terraform-module additions to `repository-precommit` from the `repository` store: the `antonbabenko/pre-commit-terraform` hooks (format, docs, lint, validate, checkov, trivy) appended after the general hooks.
- `terraform-repo-readme`: Terraform-module additions to `repository-readme` from the `repository` store: the module title, Terraform and provider badges, the usage example set and the terraform-docs block.
- `terraform-repo-terraform-docs`: Terraform-only file on top of the `repository` store base set: the `.terraform-docs.yml` that generates the README tables between the terraform-docs markers.
- `terraform-repo-tflint`: Canonical `.tflint.hcl` of a Terraform module repository, a Terraform-only file added on top of the `repository` store's base configuration files.
- `terraform-security`: Secrets handling, state exposure, least privilege, network defaults, plan-time guardrails and static analysis.
- `terraform-state`: Remote backend, locking, key layout, cross-state references and state hygiene rules.
- `terraform-testing`: Native `.tftest.hcl` unit tests, the integration fixture against a real server, CI validation and examples as tests.
- `terraform-variables`: Naming, typing, validation, secrecy and ordering rules for module input variables.
- `terraform-versioning`: What counts as a breaking change for a module, how module sources are pinned, and the Terraform-specific breaking-change checklist, on top of `repository-versioning`.

### git
- `git-branching`: `main` is the protected release line, `develop` the integration line; contributor work lands through short-lived branches merged by request, and maintainers may commit to `main` directly for releases, hotfixes and small fixes.
- `git-commits`: Every commit is atomic and its message says what changed in an imperative subject and why in the body, with the issue it addresses.
- `git-history`: Shared history is linear, never rewritten, and every release is an annotated `vX.Y.Z` tag on `main`.
- `git-hygiene`: The repository tracks only source: no secrets, binaries or generated files, with per-stack ignores, LFS for large assets, normalised line endings and pre-commit installed.
- `git-identity`: Every commit and tag is attributed to a real person with an organisation address and is signed where the platform verifies signatures.

### gitlab
- `gitlab-ci-pipeline`: Pipelines are modular, cheapest-first, driven by `rules:`, fully pinned, cached and interruptible, with `needs:` expressing the real dependency graph.
- `gitlab-ci-security`: CI uses protected masked variables and file variables for keys, prefers `CI_JOB_TOKEN` to personal tokens, never prints a secret, and gates destructive jobs behind manual approval and explicit flags.
- `gitlab-merge-requests`: A merge request says what changed, why and how it was tested, links its issue, stays draft until ready, and is approved by someone other than its author before merging.
- `gitlab-project-settings`: Every project is private by default with `main` protected for maintainer-only pushes and merges, `develop` protected from force-push, and merges gated on a green pipeline.
- `gitlab-releases`: A release exists only for a protected `vX.Y.Z` tag on `main`, is created by the pipeline with the matching changelog section as notes, and links its assets.

### secrets
- `secrets-access`: Each environment and each consumer can decrypt only its own secrets, with separate keys per environment, an auditable recipient list and no personal keys in automation.
- `secrets-detection`: Leaks are caught before commit and in CI, and an exposure triggers rotation, history purge and a record.
- `secrets-injection`: Secrets reach a process only at runtime, through the environment or a 0600 file, and never through arguments, logs, plans, state or images.
- `secrets-rotation`: Secrets and encryption recipients are rotated on a schedule, on personnel change and on exposure, by a documented add-then-remove procedure that never locks anyone out.
- `secrets-storage`: Secrets at rest are encrypted with SOPS and age (or held in a vault), committed only in encrypted form under a fixed naming pattern, with private keys outside the repository.

### openspec
- `openspec-change-flow`: A standard changes through a proposal in its store, is validated strictly, is archived after merge and reaches consumers only through a semver release.
- `openspec-config`: A store's `openspec/config.yaml` gives an agent planning a change in that store the context, the referenced standards and the rules it must apply, in one predictable shape.
- `openspec-consumption`: A repository consumes a store by reference and by pinned tag, so every agent working in it sees the same index of standards and fetches the same text.
- `openspec-naming`: Store and spec identifiers are predictable enough that an agent can guess where a rule lives and never finds the same rule under two names.
- `openspec-spec-format`: A spec is written so an agent can fetch it, audit a repository against it and cite the exact rule that failed.
- `openspec-store-layout`: A store is a standalone repository that holds standards, and at most the kit that implements its own contract, with a fixed layout so any consumer or agent can register it and find its specs without reading its README.

## Workflow
- Behaviour changes, new inputs/outputs, new resources: OpenSpec workflow
  (`/openspec-propose`, then `/openspec-apply-change`, then `/openspec-archive-change`). Do not code directly.
- The `openspec-*` skills are installed for Claude Code (`.claude/skills/`) and OpenCode
  (`.opencode/skills/`, which reads this file natively); after bumping `openspec` in
  `mise.toml`, run `openspec update` so both sets stay identical.
- Small fixes (typos, description wording, obvious bugs, tool bumps): code directly,
  still applying the non-negotiables and the relevant standard.

## Precedence and deviations
1. An approved OpenSpec change (proposal/design) for this task
2. This file's non-negotiables
3. The referenced store standards (`quality`, `repository`, `terraform`, `git`, `gitlab`, `secrets`, `openspec`)
4. Existing patterns in this repository (`openspec/specs/` describes the current contract)

Never deviate silently: add a `# DEVIATION(<spec-id>): <reason>` comment and list it
in your summary.

## Commands
- Format / validate: `tofu fmt -recursive`, `tofu init -backend=false && tofu validate`, `tflint --recursive`
- Tests: `tofu test` (unit, `command = plan`, no server; see TESTING.md)
- Hooks and scanners, incl. README regeneration: `pre-commit run -a`
- Changelog: `mise run changelog` (git-cliff)
- Specs: `mise run spec-validate`; standards stores: `mise run spec-setup`
