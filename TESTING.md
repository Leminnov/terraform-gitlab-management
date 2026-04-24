# Testing

## Local

### Format, lint, validate

```sh
tofu fmt -check -recursive
tflint --recursive
tofu init -backend=false
tofu validate
```

### Native Terraform tests

Plan-level unit tests live in `tests/`. They do not hit GitLab — `command = plan` is enough to exercise the module's expansion and validation logic.

```sh
tofu init -backend=false
tofu test
```

### Examples as smoke tests

Each directory under `examples/` is a runnable root module. At minimum, run:

```sh
cd examples/basic && tofu init -backend=false && tofu validate
cd examples/complete && tofu init -backend=false && tofu validate
```

To actually apply an example, export a GitLab token and replace the placeholder group/project:

```sh
export GITLAB_TOKEN=<token-with-api-scope>
cd examples/basic
tofu init
tofu plan
```

## CI

The GitLab CI pipeline runs on every commit:

- `validate:opentofu` — `tofu init -backend=false`, `tofu validate`, `tofu fmt -check -recursive`
- `validate:tflint` — `tflint --recursive`
- `validate:tftest` — `tofu test` (plan-level, no GitLab calls)
- `pre-commit` — all hooks including `terraform_fmt`, `terraform_docs`, `terraform_tflint`
- `scan:trivy` — IaC misconfiguration scan

On semantic version tags (`vX.Y.Z`):

- `verify:changelog` — ensures `CHANGELOG.md` matches the git-cliff regeneration
- `create:release` — cuts the GitLab release with release notes

## What the tests cover

- Expansion of `groups` / `projects` lists into per-entity resources
- Default values for optional fields (`variable_type`, `protected`, `masked`)
- Validation rejection of invalid enum values
- Empty-input case (all defaults → zero resources planned)
