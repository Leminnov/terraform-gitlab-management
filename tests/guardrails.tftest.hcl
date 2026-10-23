# Guardrails on the group and project tree (security-guardrails spec): one run
# per check, each triggering exactly that check. The standalone guardrails are
# tested in main.tftest.hcl.

mock_provider "gitlab" {
  mock_resource "gitlab_group" {
    defaults = { id = "1000" }
  }
}

variables {
  parent_group_id = 42
}

run "force_push_on_a_protected_branch_warns" {
  command = plan

  variables {
    projects = { tools = { protected_branches = { main = { allow_force_push = true } } } }
  }

  expect_failures = [
    check.protected_branch_force_push,
  ]
}

run "default_tree_raises_no_warning" {
  command = plan

  variables {
    groups   = { platform = {} }
    projects = { "platform/api" = {}, tools = { branches = {} } }
  }
}
