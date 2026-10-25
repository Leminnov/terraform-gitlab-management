# Service accounts (service-accounts and access-management specs): the three
# levels, token blocks, memberships resolving the account's user ID, outputs,
# and one rejected-input run per validation.

mock_provider "gitlab" {
  mock_resource "gitlab_group" {
    defaults = { id = "1000", full_path = "parent/mocked" }
  }
  mock_resource "gitlab_project" {
    defaults = { id = "2000" }
  }
  mock_resource "gitlab_group_service_account" {
    defaults = { service_account_id = "3000", username = "service_account_group_1000_x" }
  }
  mock_resource "gitlab_project_service_account" {
    defaults = { service_account_id = "4000", username = "service_account_project_2000_x" }
  }
}

variables {
  parent_group_id = 42
  groups = {
    platform = {}
    data     = {}
  }
  projects = {
    "platform/api" = {}
    tools          = {}
  }
}

run "service_accounts_at_three_levels" {
  command = plan

  variables {
    service_accounts = {
      top = { group = "leminnov", tokens = { ci = { scopes = ["read_api"], expires_at = "2027-01-01" } } }
      sub = { group = "leminnov/test", name = "Sandbox bot" }
    }
    groups = {
      platform = {
        service_accounts = {
          deployer = { tokens = { deploy = { scopes = ["write_repository"], rotation_configuration = { expiration_days = 90, rotate_before_days = 14 } } } }
        }
        members = { deployer = { service_account = "platform:deployer", access_level = "developer" } }
      }
      data = {}
    }
    projects = {
      "platform/api" = {
        service_accounts = {
          release = { tokens = { ci = { scopes = ["api"], rotation_configuration = { expiration_days = 30, rotate_before_days = 7 } } } }
        }
        members = {
          release = { service_account = "platform/api:release", access_level = "maintainer" }
          team    = { service_account = "platform:deployer", access_level = "developer" }
          bot     = { service_account = "top", access_level = "reporter" }
          alice   = { user_id = 42, access_level = "developer" }
        }
      }
      tools = {}
    }
  }

  assert {
    condition = alltrue([
      toset(keys(gitlab_group_service_account.this)) == toset(["top", "sub", "platform:deployer"]),
      keys(gitlab_project_service_account.this) == ["platform/api:release"],
      keys(gitlab_group_service_account_access_token.this) == ["top:ci"],
      keys(gitlab_group_service_account_access_token.rotating) == ["platform:deployer:deploy"],
      length(gitlab_project_service_account_access_token.this) == 0,
      keys(gitlab_project_service_account_access_token.rotating) == ["platform/api:release:ci"],
    ])
    error_message = "Accounts must be keyed \"<name>\" or \"<owner key>:<name>\", their tokens \"<account key>:<token>\", dated and rotating apart."
  }
  assert {
    condition = alltrue([
      gitlab_group_service_account.this["top"].group == "leminnov",
      gitlab_group_service_account.this["top"].name == "top",
      gitlab_group_service_account.this["sub"].name == "Sandbox bot",
      gitlab_group_service_account.this["platform:deployer"].group == "1000",
      gitlab_group_service_account.this["platform:deployer"].name == "deployer",
      gitlab_group_service_account.this["platform:deployer"].skip_wait_for_deletion == true,
      gitlab_project_service_account.this["platform/api:release"].project == "2000",
      gitlab_project_service_account.this["platform/api:release"].skip_wait_for_deletion == true,
    ])
    error_message = "Accounts must be created in their group or project, named after their key by default, without waiting for deletion."
  }
  assert {
    condition = alltrue([
      gitlab_group_service_account_access_token.this["top:ci"].user_id == 3000,
      gitlab_group_service_account_access_token.this["top:ci"].expires_at == "2027-01-01",
      gitlab_group_service_account_access_token.rotating["platform:deployer:deploy"].rotation_configuration.expiration_days == 90,
      gitlab_project_service_account_access_token.rotating["platform/api:release:ci"].user_id == 4000,
      gitlab_project_service_account_access_token.rotating["platform/api:release:ci"].rotation_configuration.rotate_before_days == 7,
      local.project_service_account_tokens["platform/api:release:ci"].expires_at == null,
    ])
    error_message = "Tokens must belong to their account, with the dated expiry or the rotation only."
  }
  assert {
    condition = alltrue([
      gitlab_group_membership.this["platform:deployer"].user_id == 3000,
      gitlab_project_membership.this["platform/api:release"].user_id == 4000,
      gitlab_project_membership.this["platform/api:team"].user_id == 3000,
      gitlab_project_membership.this["platform/api:bot"].user_id == 3000,
      gitlab_project_membership.this["platform/api:alice"].user_id == 42,
    ])
    error_message = "A service account member must resolve to the account's user ID, a user member to its user_id."
  }
  assert {
    condition = alltrue([
      toset(keys(output.service_accounts)) == toset(["top", "sub", "platform:deployer", "platform/api:release"]),
      output.service_accounts["platform/api:release"].id == "4000",
      issensitive(output.service_account_tokens),
      toset(keys(nonsensitive(output.service_account_tokens))) == toset(["top:ci", "platform:deployer:deploy", "platform/api:release:ci"]),
    ])
    error_message = "The outputs must list every account and every token, the tokens as sensitive."
  }
}

# ---------------------------------------------------------------------------
# Rejected inputs: one run per validation
# ---------------------------------------------------------------------------

run "standalone_empty_group_is_rejected" {
  command = plan

  variables {
    service_accounts = { bot = { group = "" } }
  }

  expect_failures = [
    var.service_accounts,
  ]
}

run "standalone_key_with_colon_is_rejected" {
  command = plan

  variables {
    service_accounts = { "ci:bot" = { group = "leminnov" } }
  }

  expect_failures = [
    var.service_accounts,
  ]
}

run "standalone_admin_scope_is_rejected" {
  command = plan

  variables {
    service_accounts = { bot = { group = "leminnov", tokens = { t = { scopes = ["sudo"], expires_at = "2027-01-01" } } } }
  }

  expect_failures = [
    var.service_accounts,
  ]
}

run "standalone_token_without_expiry_is_rejected" {
  command = plan

  variables {
    service_accounts = { bot = { group = "leminnov", tokens = { t = { scopes = ["read_api"] } } } }
  }

  expect_failures = [
    var.service_accounts,
  ]
}

run "standalone_token_with_expiry_and_rotation_is_rejected" {
  command = plan

  variables {
    service_accounts = { bot = { group = "leminnov", tokens = { t = { scopes = ["read_api"], expires_at = "2027-01-01", rotation_configuration = { expiration_days = 30, rotate_before_days = 7 } } } } }
  }

  expect_failures = [
    var.service_accounts,
  ]
}

run "standalone_rotation_that_never_triggers_is_rejected" {
  command = plan

  variables {
    service_accounts = { bot = { group = "leminnov", tokens = { t = { scopes = ["read_api"], rotation_configuration = { expiration_days = 7, rotate_before_days = 7 } } } } }
  }

  expect_failures = [
    var.service_accounts,
  ]
}

run "standalone_timestamp_expiry_is_rejected" {
  command = plan

  variables {
    service_accounts = { bot = { group = "leminnov", tokens = { t = { scopes = ["read_api"], expires_at = "2027-06-30T00:00:00Z" } } } }
  }

  expect_failures = [
    var.service_accounts,
  ]
}

run "group_account_admin_scope_is_rejected" {
  command = plan

  variables {
    groups = { platform = { service_accounts = { bot = { tokens = { t = { scopes = ["admin_mode"], expires_at = "2027-01-01" } } } } }, data = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_account_token_without_expiry_is_rejected" {
  command = plan

  variables {
    groups = { platform = { service_accounts = { bot = { tokens = { t = { scopes = ["read_api"] } } } } }, data = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_account_timestamp_expiry_is_rejected" {
  command = plan

  variables {
    groups = { platform = { service_accounts = { bot = { tokens = { t = { scopes = ["read_api"], expires_at = "2027-06-30T00:00:00Z" } } } } }, data = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_member_with_user_and_service_account_is_rejected" {
  command = plan

  variables {
    groups = { platform = { service_accounts = { bot = {} }, members = { bot = { user_id = 42, service_account = "platform:bot", access_level = "developer" } } }, data = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_member_outside_the_subgroup_is_rejected" {
  command = plan

  variables {
    groups = { platform = { service_accounts = { bot = {} } }, data = { members = { bot = { service_account = "platform:bot", access_level = "developer" } } } }
  }

  expect_failures = [
    var.groups,
  ]
}

run "project_account_admin_scope_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { service_accounts = { bot = { tokens = { t = { scopes = ["sudo"], expires_at = "2027-01-01" } } } } }, tools = {} }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_account_token_without_expiry_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { service_accounts = { bot = { tokens = { t = { scopes = ["read_api"] } } } } }, tools = {} }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_account_timestamp_expiry_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { service_accounts = { bot = { tokens = { t = { scopes = ["read_api"], expires_at = "2027-06-30T00:00:00Z" } } } } }, tools = {} }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_member_without_user_or_service_account_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { members = { nobody = { access_level = "developer" } } }, tools = {} }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_member_using_another_projects_account_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { service_accounts = { bot = {} } }, tools = { members = { bot = { service_account = "platform/api:bot", access_level = "developer" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}
