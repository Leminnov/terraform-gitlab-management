# Guardrails on the group and project tree (security-guardrails spec): one run
# per check, each triggering exactly that check. The standalone guardrails are
# tested in main.tftest.hcl.

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

run "public_project_warns" {
  command = plan

  variables {
    projects = { tools = { visibility = "public" } }
  }

  expect_failures = [
    check.public_visibility,
  ]
}

run "public_group_warns" {
  command = plan

  variables {
    groups = { site = { visibility = "public" } }
  }

  expect_failures = [
    check.public_visibility,
  ]
}

run "project_hook_without_tls_verification_warns" {
  command = plan

  variables {
    projects = { tools = { hooks = { ci = { url = "https://ci.example.com/hook", enable_ssl_verification = false } } } }
  }

  expect_failures = [
    check.webhook_ssl_verification,
  ]
}

run "group_hook_without_tls_verification_warns" {
  command = plan

  variables {
    groups = { platform = { hooks = { audit = { url = "https://audit.example.com/hook", enable_ssl_verification = false } } } }
  }

  expect_failures = [
    check.webhook_ssl_verification,
  ]
}

run "writable_deploy_key_warns" {
  command = plan

  variables {
    projects = { tools = { deploy_keys = { gitops = { key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINotARealKeyOnlyForUnitTests ci@example", expires_at = timeadd(timestamp(), "720h"), can_push = true } } } }
  }

  expect_failures = [
    check.deploy_key_write_access,
  ]
}

run "two_year_deploy_key_warns" {
  command = plan

  variables {
    projects = { tools = { deploy_keys = { gitops = { key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINotARealKeyOnlyForUnitTests ci@example", expires_at = timeadd(timestamp(), "17520h") } } } }
  }

  expect_failures = [
    check.token_lifetime,
  ]
}

run "two_year_project_deploy_token_warns" {
  command = plan

  variables {
    projects = { tools = { deploy_tokens = { pull = { expires_at = timeadd(timestamp(), "17520h"), scopes = ["read_repository"] } } } }
  }

  expect_failures = [
    check.token_lifetime,
  ]
}

# Nested cases of the guardrails that predate the tree.

run "nested_secret_variable_warns" {
  command = plan

  variables {
    projects = { tools = { variables = { API_KEY = { value = "x" } } } }
  }

  expect_failures = [
    check.secret_variables_masked_and_protected,
  ]
}

run "nested_two_year_group_deploy_token_warns" {
  command = plan

  variables {
    groups = { platform = { deploy_tokens = { registry = { expires_at = timeadd(timestamp(), "17520h"), scopes = ["read_registry"] } } } }
  }

  expect_failures = [
    check.token_lifetime,
  ]
}

run "nested_access_token_without_level_warns" {
  command = plan

  variables {
    projects = { tools = { access_tokens = { bot = { expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h")), scopes = ["read_api"] } } } }
  }

  expect_failures = [
    check.access_token_privilege,
  ]
}

run "nested_owner_group_access_token_warns" {
  command = plan

  variables {
    groups = { platform = { access_tokens = { bot = { expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h")), access_level = "owner", scopes = ["read_api"] } } } }
  }

  expect_failures = [
    check.access_token_privilege,
  ]
}

run "nested_two_year_group_access_token_warns" {
  command = plan

  variables {
    groups = { platform = { access_tokens = { bot = { expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "17520h")), access_level = "developer", scopes = ["read_api"] } } } }
  }

  expect_failures = [
    check.token_lifetime,
  ]
}

run "nested_two_year_project_access_token_warns" {
  command = plan

  variables {
    projects = { tools = { access_tokens = { bot = { expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "17520h")), access_level = "developer", scopes = ["read_api"] } } } }
  }

  expect_failures = [
    check.token_lifetime,
  ]
}

# Every guardrail-relevant setting at its safe value: no check may warn.
run "clean_tree_raises_no_warning" {
  command = plan

  variables {
    groups = {
      platform = {
        variables     = { LOG_LEVEL = { value = "info" }, REGISTRY_TOKEN = { value = "x", masked = true, protected = true } }
        deploy_tokens = { registry = { expires_at = timeadd(timestamp(), "720h"), scopes = ["read_registry"] } }
        access_tokens = { bot = { expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h")), access_level = "developer", scopes = ["read_api"] } }
        hooks         = { audit = { url = "https://audit.example.com/hook" } }
      }
    }
    projects = {
      "platform/api" = {
        deploy_tokens = { pull = { expires_at = timeadd(timestamp(), "720h"), scopes = ["read_repository"] } }
        deploy_keys   = { gitops = { key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINotARealKeyOnlyForUnitTests ci@example", expires_at = timeadd(timestamp(), "720h") } }
        hooks         = { ci = { url = "https://ci.example.com/hook" } }
      }
      tools = { branches = {}, visibility = "internal" }
    }
  }
}
