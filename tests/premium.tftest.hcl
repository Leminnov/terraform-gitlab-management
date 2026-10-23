# Premium features (premium-features spec): nothing planned unless set, the
# defaults of each feature when set, and one rejected-input run per validation.

mock_provider "gitlab" {
  mock_resource "gitlab_group" {
    defaults = { id = "1000" }
  }
  mock_resource "gitlab_project" {
    defaults = { id = "2000" }
  }
}

variables {
  parent_group_id = 42
  groups          = { platform = {} }
  projects        = { "platform/api" = { environments = { production = {} } } }
}

run "premium_is_off_by_default" {
  command = plan

  variables {
    projects = {
      "platform/api" = {
        environments       = { production = {} }
        protected_branches = { main = {}, "release/*" = {} }
      }
      tools = {}
    }
  }

  assert {
    condition = alltrue([
      length(gitlab_project_approval_rule.this) == 0,
      length(gitlab_project_level_mr_approvals.this) == 0,
      length(gitlab_project_push_rules.this) == 0,
      length(gitlab_project_protected_environment.this) == 0,
      length(gitlab_group_hook.this) == 0,
    ])
    error_message = "No Premium resource may be planned unless the caller sets it."
  }
  assert {
    # The argument is optional and computed, so the mock fills it in the planned
    # resource: what the module sends is the local the argument reads.
    condition     = length(local.project_protected_branches) == 4 && alltrue([for b in values(local.project_protected_branches) : b.code_owner_approval_required == null])
    error_message = "code_owner_approval_required must not be sent unless set."
  }
}

run "approval_rule_defaults" {
  command = plan

  variables {
    projects = { "platform/api" = { approval_rules = { review = { approvals_required = 2, group_ids = [123] } } } }
  }

  assert {
    condition = alltrue([
      keys(gitlab_project_approval_rule.this) == ["platform/api:review"],
      gitlab_project_approval_rule.this["platform/api:review"].name == "review",
      gitlab_project_approval_rule.this["platform/api:review"].project == "2000",
      gitlab_project_approval_rule.this["platform/api:review"].approvals_required == 2,
      gitlab_project_approval_rule.this["platform/api:review"].group_ids == toset([123]),
      gitlab_project_approval_rule.this["platform/api:review"].applies_to_all_protected_branches == true,
    ])
    error_message = "An approval rule must require its approvals from its approvers on all protected branches."
  }
}

run "merge_request_approval_defaults" {
  command = plan

  variables {
    projects = { "platform/api" = { merge_request_approvals = {} } }
  }

  assert {
    condition = alltrue([
      keys(gitlab_project_level_mr_approvals.this) == ["platform/api"],
      gitlab_project_level_mr_approvals.this["platform/api"].reset_approvals_on_push == true,
      gitlab_project_level_mr_approvals.this["platform/api"].merge_requests_author_approval == false,
      gitlab_project_level_mr_approvals.this["platform/api"].merge_requests_disable_committers_approval == true,
      gitlab_project_level_mr_approvals.this["platform/api"].disable_overriding_approvers_per_merge_request == true,
    ])
    error_message = "Approval settings must reset on push, forbid self-approval and keep approvers fixed by default."
  }
}

run "push_rule_defaults" {
  command = plan

  variables {
    projects = { "platform/api" = { push_rules = {} } }
  }

  assert {
    condition = alltrue([
      keys(gitlab_project_push_rules.this) == ["platform/api"],
      gitlab_project_push_rules.this["platform/api"].prevent_secrets == true,
      gitlab_project_push_rules.this["platform/api"].deny_delete_tag == true,
      gitlab_project_push_rules.this["platform/api"].member_check == true,
      local.project_push_rules["platform/api"].reject_unsigned_commits == null, # optional and computed: see above
    ])
    error_message = "Push rules must reject secrets, tag deletion and non-members by default, and send the optional rules only when set."
  }
}

run "protected_environment_defaults" {
  command = plan

  variables {
    projects = {
      "platform/api" = {
        environments           = { production = {}, staging = {} }
        protected_environments = { production = {}, staging = { deploy_access_level = "developer", required_approvals = 1 } }
      }
    }
  }

  assert {
    condition = alltrue([
      toset(keys(gitlab_project_protected_environment.this)) == toset(["platform/api:production", "platform/api:staging"]),
      [for a in gitlab_project_protected_environment.this["platform/api:production"].deploy_access_levels_attribute : a.access_level] == ["maintainer"],
      local.project_protected_environments["platform/api:production"].required_approvals == null, # approval_rules is optional and computed
      [for a in gitlab_project_protected_environment.this["platform/api:staging"].deploy_access_levels_attribute : a.access_level] == ["developer"],
      [for r in gitlab_project_protected_environment.this["platform/api:staging"].approval_rules : r.required_approvals] == [1],
    ])
    error_message = "Protected environments must let maintainers deploy by default, with approvals only when set."
  }
}

run "code_owner_approval_when_set" {
  command = plan

  variables {
    projects = { "platform/api" = { protected_branches = { main = { code_owner_approval_required = true } } } }
  }

  assert {
    condition     = gitlab_branch_protection.this["platform/api:main"].code_owner_approval_required == true
    error_message = "code_owner_approval_required must be sent when set."
  }
}

run "group_hook_defaults" {
  command = plan

  variables {
    groups = { platform = { hooks = { audit = { url = "https://audit.example.com/hook", project_events = true, token = "dummy" } } } }
  }

  assert {
    condition = alltrue([
      keys(gitlab_group_hook.this) == ["platform:audit"],
      gitlab_group_hook.this["platform:audit"].group == "1000",
      gitlab_group_hook.this["platform:audit"].name == "audit",
      gitlab_group_hook.this["platform:audit"].enable_ssl_verification == true,
      gitlab_group_hook.this["platform:audit"].push_events == true,
      gitlab_group_hook.this["platform:audit"].project_events == true,
      gitlab_group_hook.this["platform:audit"].subgroup_events == false,
      issensitive(gitlab_group_hook.this["platform:audit"].token),
    ])
    error_message = "A group hook must verify TLS, send push events by default and redact its token."
  }
}

# ---------------------------------------------------------------------------
# Rejected inputs: one run per validation
# ---------------------------------------------------------------------------

run "negative_approvals_are_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { approval_rules = { review = { approvals_required = -1 } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "undeclared_protected_environment_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { environments = { production = {} }, protected_environments = { staging = {} } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "unknown_deploy_access_level_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { environments = { production = {} }, protected_environments = { production = { deploy_access_level = "owner" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "group_hook_url_without_scheme_is_rejected" {
  command = plan

  variables {
    groups = { platform = { hooks = { audit = { url = "audit.example.com/hook" } } } }
  }

  expect_failures = [
    var.groups,
  ]
}
