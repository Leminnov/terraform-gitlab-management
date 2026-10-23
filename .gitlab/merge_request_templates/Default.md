## What changes

## Why

## How it was tested

<!-- Commands run and their output: mise run test, pre-commit run -a, mise run spec-validate, and mise run test-integration when the change talks to GitLab. Redact any token or real group/project ID. -->

## Linked issue

Closes #

## Checklist

- [ ] `CHANGELOG.md` entry under `## [Unreleased]`, with the edit consumers must make when the change is breaking
- [ ] Docs and examples updated (`examples/complete/`, README outside the terraform-docs markers, `SECURITY.md` when what lands in state, a default or a required role changes)
- [ ] Unit test added or updated in `tests/main.tftest.hcl` (a rejected-input run for every new validation, a run for every new check)
- [ ] OpenSpec change proposed and its specs updated when the module contract changes (`openspec/`)
- [ ] Security impact stated: who can read or write what in GitLab, token scopes, access levels, protected and masked flags
- [ ] Rebased on the target branch, pipeline green, all threads resolved
