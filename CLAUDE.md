@AGENTS.md

## Claude Code specifics
- Use the OpenSpec skills for planning (`/openspec-propose`, `/openspec-apply-change`, `/openspec-archive-change`, `/openspec-explore`, `/openspec-sync-specs`, `/openspec-update-change`); they live in `.claude/skills/` and also trigger from plain requests such as "openspec apply". The legacy `.claude/commands/opsx/` set is not installed here; keep the global `openspec config set delivery skills` so `openspec update` does not recreate it.
- Run `tofu fmt -recursive`, `tofu validate` and `tofu test` yourself after each task group and report the output as-is.
- Prefer the mise-pinned tools (`mise install`, `mise run <task>`) so CI and local runs use the same versions.
