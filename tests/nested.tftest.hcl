# Objects nested in groups and projects (module-contract, ci-variables,
# deploy-tokens, access-tokens, pipeline-schedules, runners, deploy-keys,
# access-management and project-ci-settings specs): "<owner>:<item>" keys,
# redaction, the outputs shared with the standalone inputs, key resolution, and
# one rejected-input run per nested validation.

mock_provider "gitlab" {
  mock_resource "gitlab_group" {
    defaults = { id = "1000" }
  }
  mock_resource "gitlab_project" {
    defaults = { id = "2000" }
  }
  mock_resource "gitlab_user_runner" {
    defaults = { id = "5000" }
  }
  mock_resource "gitlab_deploy_key" {
    defaults = { deploy_key_id = 6000 }
  }
}

variables {
  parent_group_id = 42
  groups = {
    platform = {}
    teams    = {}
  }
  projects = { "platform/api" = {} }
}

run "nested_objects_are_keyed_by_owner" {
  command = plan

  variables {
    groups = {
      platform = {
        variables     = { LOG_LEVEL = { value = "info" } }
        deploy_tokens = { registry = { expires_at = timeadd(timestamp(), "720h"), scopes = ["read_registry"] } }
        access_tokens = { bot = { expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h")), access_level = "developer", scopes = ["read_api"] } }
        members       = { alice = { user_id = 7, access_level = "developer" } }
        shared_with   = { team = { group = "teams", access_level = "developer" } }
        runners       = { docker = { tag_list = ["docker"] } }
      }
      teams = {}
    }
    projects = {
      "platform/api" = {
        variables           = { DEPLOY_ENV = { value = "staging" } }
        deploy_tokens       = { pull = { expires_at = timeadd(timestamp(), "720h"), scopes = ["read_repository"] } }
        access_tokens       = { release_bot = { expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h")), access_level = "developer", scopes = ["write_repository"] } }
        members             = { bob = { user_id = 8, access_level = "reporter" } }
        shared_with         = { ext = { group_id = 555, access_level = "reporter" } }
        runners             = { build = { tag_list = ["build"] } }
        deploy_keys         = { argocd = { key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINotARealKeyOnlyForUnitTests ci@example", expires_at = timeadd(timestamp(), "720h") } }
        pipeline_schedules  = { nightly = { cron = "0 2 * * *", variables = { MODE = "full" } } }
        pipeline_triggers   = ["release from platform/sdk"]
        environments        = { production = { tier = "production" } }
        job_token_allowlist = { projects = ["platform/sdk"], groups = ["teams"], project_ids = [77], group_ids = [88] }
      }
      "platform/sdk" = {}
    }

    # Standalone entries sharing resources and outputs with the nested ones.
    deploy_tokens = {
      ci = { groups = ["org/a"], name = "ci", expires_at = timeadd(timestamp(), "720h"), scopes = ["read_registry"] }
    }
    gitlab_group_access_token = {
      bot = { groups = ["org/a"], name = "bot", expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h")), access_level = "developer", scopes = ["read_api"] }
    }
    gitlab_project_access_token = {
      bot = { projects = ["org/app"], name = "bot", expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h")), access_level = "developer", scopes = ["read_api"] }
    }
    pipeline_schedules = {
      weekly = { project = "org/app", description = "weekly", ref = "refs/heads/main", cron = "0 3 * * 1", active = true }
    }
    gitlab_runners = {
      shared = { runner_type = "group_type", description = "shared", group_id = "123", access_level = "ref_protected", tag_list = ["docker"], paused = false, untagged = false, locked = false }
    }
  }

  assert {
    condition = alltrue([
      keys(gitlab_group_variable.this) == ["platform:LOG_LEVEL"],
      keys(gitlab_project_variable.this) == ["platform/api:DEPLOY_ENV"],
      toset(keys(gitlab_group_deploy_token.this)) == toset(["ci_org/a", "platform:registry"]),
      keys(gitlab_project_deploy_token.this) == ["platform/api:pull"],
      toset(keys(gitlab_group_access_token.this)) == toset(["bot_org/a", "platform:bot"]),
      toset(keys(gitlab_project_access_token.this)) == toset(["bot_org/app", "platform/api:release_bot"]),
      keys(gitlab_group_membership.this) == ["platform:alice"],
      keys(gitlab_project_membership.this) == ["platform/api:bob"],
      keys(gitlab_group_share_group.this) == ["platform:team"],
      keys(gitlab_project_share_group.this) == ["platform/api:ext"],
      toset(keys(gitlab_user_runner.this)) == toset(["shared", "platform:docker", "platform/api:build"]),
      keys(gitlab_deploy_key.this) == ["platform/api:argocd"],
      toset(keys(gitlab_pipeline_schedule.this)) == toset(["weekly", "platform/api:nightly"]),
      keys(gitlab_pipeline_schedule_variable.this) == ["platform/api:nightly-MODE"],
      keys(gitlab_pipeline_trigger.this) == ["platform/api:release from platform/sdk"],
      keys(gitlab_project_environment.this) == ["platform/api:production"],
      keys(gitlab_project_job_token_scopes.this) == ["platform/api"],
    ])
    error_message = "Every nested object must be keyed \"<owner key>:<item key>\" next to the standalone keys."
  }
  assert {
    condition = alltrue([
      issensitive(gitlab_group_variable.this["platform:LOG_LEVEL"].value),
      issensitive(gitlab_project_variable.this["platform/api:DEPLOY_ENV"].value),
      issensitive(gitlab_pipeline_schedule_variable.this["platform/api:nightly-MODE"].value),
    ])
    error_message = "Nested variable and schedule variable values must be redacted in plans."
  }
  assert {
    condition = alltrue([
      toset(keys(nonsensitive(output.deploy_tokens))) == toset(["ci_org/a", "platform:registry"]),
      keys(nonsensitive(output.project_deploy_tokens)) == ["platform/api:pull"],
      toset(keys(nonsensitive(output.group_access_tokens))) == toset(["bot_org/a", "platform:bot"]),
      toset(keys(nonsensitive(output.project_access_tokens))) == toset(["bot_org/app", "platform/api:release_bot"]),
      toset(keys(output.pipeline_schedule_ids)) == toset(["weekly", "platform/api:nightly"]),
      keys(nonsensitive(output.pipeline_trigger_tokens)) == ["platform/api:release from platform/sdk"],
      toset(keys(output.gitlab_runners)) == toset(["shared", "platform:docker", "platform/api:build"]),
      toset(keys(nonsensitive(output.gitlab_runner_tokens))) == toset(["shared", "platform:docker", "platform/api:build"]),
    ])
    error_message = "The shared outputs must hold the standalone and the nested keys."
  }
  assert {
    condition = alltrue([
      issensitive(output.project_deploy_tokens),
      issensitive(output.pipeline_trigger_tokens),
    ])
    error_message = "The new token outputs must be sensitive."
  }
  assert {
    condition = alltrue([
      gitlab_group_variable.this["platform:LOG_LEVEL"].group == "1000",
      gitlab_project_variable.this["platform/api:DEPLOY_ENV"].project == "2000",
      gitlab_group_deploy_token.this["platform:registry"].name == "registry",
      gitlab_project_deploy_token.this["platform/api:pull"].project == "2000",
      gitlab_group_membership.this["platform:alice"].group_id == 1000,
      gitlab_project_membership.this["platform/api:bob"].access_level == "reporter",
    ])
    error_message = "Nested objects must target the created group or project."
  }
  assert {
    condition = alltrue([
      gitlab_user_runner.this["platform:docker"].runner_type == "group_type",
      gitlab_user_runner.this["platform:docker"].group_id == 1000,
      gitlab_user_runner.this["platform:docker"].description == "docker",
      gitlab_user_runner.this["platform:docker"].access_level == "ref_protected",
      gitlab_user_runner.this["platform/api:build"].runner_type == "project_type",
      gitlab_user_runner.this["platform/api:build"].project_id == 2000,
    ])
    error_message = "Nested runners must be registered in their group or project, limited to protected refs."
  }
  assert {
    condition = alltrue([
      gitlab_pipeline_schedule.this["platform/api:nightly"].ref == "refs/heads/main",
      gitlab_pipeline_schedule.this["platform/api:nightly"].description == "nightly",
      gitlab_pipeline_schedule.this["platform/api:nightly"].active == true,
      gitlab_deploy_key.this["platform/api:argocd"].can_push == false,
      gitlab_project_environment.this["platform/api:production"].tier == "production",
      gitlab_project_environment.this["platform/api:production"].stop_before_destroy == true,
    ])
    error_message = "Nested schedules, deploy keys and environments must get their defaults."
  }
  assert {
    condition = alltrue([
      gitlab_group_share_group.this["platform:team"].group_id == "1000",
      gitlab_group_share_group.this["platform:team"].share_group_id == 1000,
      gitlab_group_share_group.this["platform:team"].group_access == "developer",
      gitlab_project_share_group.this["platform/api:ext"].group_id == 555,
      gitlab_project_job_token_scopes.this["platform/api"].enabled == true,
      gitlab_project_job_token_scopes.this["platform/api"].target_project_ids == toset([2000, 77]),
      gitlab_project_job_token_scopes.this["platform/api"].target_group_ids == toset([1000, 88]),
    ])
    error_message = "shared_with and job_token_allowlist must resolve created keys and keep existing IDs."
  }
}

run "job_token_allowlist_never_sends_the_project_itself" {
  command = plan

  variables {
    projects = { "platform/api" = { job_token_allowlist = { projects = ["platform/api"] } } }
  }

  assert {
    condition     = length(gitlab_project_job_token_scopes.this["platform/api"].target_project_ids) == 0
    error_message = "The project itself must not be sent: the provider never reads it back."
  }
}

# ---------------------------------------------------------------------------
# Rejected inputs: one run per nested validation of groups and projects
# ---------------------------------------------------------------------------

run "group_variable_key_is_rejected" {
  command = plan

  variables {
    groups = { platform = { variables = { "MY-VAR" = { value = "x" } } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_variable_type_is_rejected" {
  command = plan

  variables {
    groups = { platform = { variables = { X = { value = "x", variable_type = "secret" } } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_deploy_token_without_expiry_is_rejected" {
  command = plan

  variables {
    groups = { platform = { deploy_tokens = { registry = { scopes = ["read_registry"] } } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_deploy_token_scope_is_rejected" {
  command = plan

  variables {
    groups = { platform = { deploy_tokens = { registry = { expires_at = timeadd(timestamp(), "720h"), scopes = ["api"] } } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_access_token_timestamp_is_rejected" {
  command = plan

  variables {
    groups = { platform = { access_tokens = { bot = { expires_at = "2027-06-30T00:00:00Z", access_level = "developer", scopes = ["read_api"] } } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_access_token_level_is_rejected" {
  command = plan

  variables {
    groups = { platform = { access_tokens = { bot = { expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h")), access_level = "admin", scopes = ["read_api"] } } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_access_token_scope_is_rejected" {
  command = plan

  variables {
    groups = { platform = { access_tokens = { bot = { expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h")), access_level = "developer", scopes = ["not_a_scope"] } } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_member_level_is_rejected" {
  command = plan

  variables {
    groups = { platform = { members = { alice = { user_id = 7, access_level = "admin" } } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_member_expiry_is_rejected" {
  command = plan

  variables {
    groups = { platform = { members = { alice = { user_id = 7, access_level = "developer", expires_at = "2027-06-30T00:00:00Z" } } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_share_with_group_and_group_id_is_rejected" {
  command = plan

  variables {
    groups = { platform = { shared_with = { team = { group = "teams", group_id = 5, access_level = "developer" } } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_share_with_unknown_group_key_is_rejected" {
  command = plan

  variables {
    groups = { platform = { shared_with = { team = { group = "teams/missing", access_level = "developer" } } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_share_level_is_rejected" {
  command = plan

  variables {
    groups = { platform = { shared_with = { team = { group = "teams", access_level = "admin" } } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_runner_access_level_is_rejected" {
  command = plan

  variables {
    groups = { platform = { runners = { docker = { tag_list = ["docker"], access_level = "protected" } } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_runner_without_tags_is_rejected" {
  command = plan

  variables {
    groups = { platform = { runners = { docker = {} } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_runner_timeout_is_rejected" {
  command = plan

  variables {
    groups = { platform = { runners = { docker = { tag_list = ["docker"], maximum_timeout = 300 } } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "project_variable_key_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { variables = { "MY-VAR" = { value = "x" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_variable_type_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { variables = { X = { value = "x", variable_type = "secret" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_deploy_token_without_expiry_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { deploy_tokens = { registry = { scopes = ["read_registry"] } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_deploy_token_scope_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { deploy_tokens = { registry = { expires_at = timeadd(timestamp(), "720h"), scopes = ["api"] } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_access_token_timestamp_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { access_tokens = { bot = { expires_at = "2027-06-30T00:00:00Z", access_level = "developer", scopes = ["read_api"] } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_access_token_level_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { access_tokens = { bot = { expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h")), access_level = "admin", scopes = ["read_api"] } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_access_token_scope_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { access_tokens = { bot = { expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h")), access_level = "developer", scopes = ["not_a_scope"] } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_member_level_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { members = { alice = { user_id = 7, access_level = "admin" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_member_expiry_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { members = { alice = { user_id = 7, access_level = "developer", expires_at = "2027-06-30T00:00:00Z" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_share_with_group_and_group_id_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { shared_with = { team = { group = "teams", group_id = 5, access_level = "developer" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_share_with_unknown_group_key_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { shared_with = { team = { group = "teams/missing", access_level = "developer" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_share_level_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { shared_with = { team = { group = "teams", access_level = "admin" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_runner_access_level_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { runners = { docker = { tag_list = ["docker"], access_level = "protected" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_runner_without_tags_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { runners = { docker = {} } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_runner_timeout_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { runners = { docker = { tag_list = ["docker"], maximum_timeout = 300 } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_deploy_key_format_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { deploy_keys = { argocd = { key = "not-a-public-key", expires_at = timeadd(timestamp(), "720h") } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_deploy_key_without_expiry_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { deploy_keys = { argocd = { key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINotARealKeyOnlyForUnitTests ci@example" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_schedule_short_ref_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { pipeline_schedules = { nightly = { cron = "0 2 * * *", ref = "develop" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_schedule_four_field_cron_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { pipeline_schedules = { nightly = { cron = "0 2 * *" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_empty_trigger_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { pipeline_triggers = [""] } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_environment_tier_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { environments = { production = { tier = "prod" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_job_token_unknown_project_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { job_token_allowlist = { projects = ["platform/missing"] } } }
  }

  expect_failures = [
    var.projects,
  ]
}

# ---------------------------------------------------------------------------
# Rotation of nested access tokens (access-tokens spec)
# ---------------------------------------------------------------------------

run "nested_rotating_access_token" {
  command = plan

  variables {
    projects = {
      "platform/api" = {
        access_tokens = { bot = { access_level = "developer", scopes = ["read_api"], rotation_configuration = { expiration_days = 60, rotate_before_days = 7 } } }
      }
    }
  }

  assert {
    condition     = gitlab_project_access_token.this["platform/api:bot"].rotation_configuration.expiration_days == 60 && local.project_access_tokens["platform/api:bot"].expires_at == null
    error_message = "A nested rotating token must send its rotation and no expiry."
  }
}

run "group_nested_token_without_expiry_or_rotation_is_rejected" {
  command = plan

  variables {
    groups = { platform = { access_tokens = { bot = { access_level = "developer", scopes = ["read_api"] } } }, teams = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "project_nested_token_rotation_window_as_long_as_lifetime_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { access_tokens = { bot = { access_level = "developer", scopes = ["read_api"], rotation_configuration = { expiration_days = 30, rotate_before_days = 30 } } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

# ---------------------------------------------------------------------------
# Runners and deploy keys shared with other projects (runners and deploy-keys
# specs)
# ---------------------------------------------------------------------------

run "runner_and_deploy_key_shared_with_another_project" {
  command = plan

  variables {
    projects = {
      "platform/api" = {
        runners     = { build = { tag_list = ["build"] }, private = { tag_list = ["private"], locked = true } }
        deploy_keys = { argocd = { key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINotARealKeyOnlyForUnitTests ci@example", expires_at = timeadd(timestamp(), "720h") } }
      }
      tools = {
        enabled_runners        = ["platform/api:build"]
        enabled_runner_ids     = [77]
        enabled_deploy_keys    = ["platform/api:argocd"]
        enabled_deploy_key_ids = [88]
      }
    }
  }

  assert {
    condition = alltrue([
      toset(keys(gitlab_project_runner_enablement.this)) == toset(["tools:platform/api:build", "tools:77"]),
      gitlab_project_runner_enablement.this["tools:platform/api:build"].runner_id == 5000,
      gitlab_project_runner_enablement.this["tools:77"].runner_id == 77,
      gitlab_project_runner_enablement.this["tools:77"].project == "2000",
      output.gitlab_runners["platform/api:build"].project_id == 2000,
    ])
    error_message = "Runner enablements must be keyed \"<project key>:<runner key or ID>\" and resolve the runner ID."
  }
  assert {
    condition = alltrue([
      toset(keys(gitlab_deploy_key_enable.this)) == toset(["tools:platform/api:argocd", "tools:88"]),
      gitlab_deploy_key_enable.this["tools:platform/api:argocd"].key_id == "6000",
      gitlab_deploy_key_enable.this["tools:88"].key_id == "88",
      gitlab_deploy_key_enable.this["tools:platform/api:argocd"].can_push == false,
    ])
    error_message = "Deploy key enablements must be read-only, keyed like runner enablements."
  }
}

run "own_runner_enabled_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = {
      runners         = { build = { tag_list = ["build"] }, private = { tag_list = ["private"], locked = true } }
      enabled_runners = ["platform/api:build"]
      deploy_keys     = { argocd = { key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINotARealKeyOnlyForUnitTests ci@example", expires_at = timeadd(timestamp(), "720h") } }
    } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "locked_runner_enabled_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = {
      runners     = { build = { tag_list = ["build"] }, private = { tag_list = ["private"], locked = true } }
      deploy_keys = { argocd = { key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINotARealKeyOnlyForUnitTests ci@example", expires_at = timeadd(timestamp(), "720h") } }
    }, tools = { enabled_runners = ["platform/api:private"] } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "group_runner_enabled_is_rejected" {
  command = plan

  variables {
    groups = { platform = { runners = { docker = { tag_list = ["docker"] } } }, teams = {} }
    projects = { "platform/api" = {
      runners     = { build = { tag_list = ["build"] }, private = { tag_list = ["private"], locked = true } }
      deploy_keys = { argocd = { key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINotARealKeyOnlyForUnitTests ci@example", expires_at = timeadd(timestamp(), "720h") } }
    }, tools = { enabled_runners = ["platform:docker"] } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "own_deploy_key_enabled_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = {
      runners             = { build = { tag_list = ["build"] }, private = { tag_list = ["private"], locked = true } }
      enabled_deploy_keys = ["platform/api:argocd"]
      deploy_keys         = { argocd = { key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINotARealKeyOnlyForUnitTests ci@example", expires_at = timeadd(timestamp(), "720h") } }
    } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "unknown_deploy_key_enabled_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = {
      runners     = { build = { tag_list = ["build"] }, private = { tag_list = ["private"], locked = true } }
      deploy_keys = { argocd = { key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINotARealKeyOnlyForUnitTests ci@example", expires_at = timeadd(timestamp(), "720h") } }
    }, tools = { enabled_deploy_keys = ["platform/api:missing"] } }
  }

  expect_failures = [
    var.projects,
  ]
}
