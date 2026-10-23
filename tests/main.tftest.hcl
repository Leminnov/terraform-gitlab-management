# Plan-level tests for the gitlab-management module.
#
# These tests exercise the module's expansion and validation logic without
# contacting GitLab: the provider is mocked and every `run` uses
# `command = plan`. The integration fixture in tests/integration/ covers the
# real server.

mock_provider "gitlab" {}

# ---------------------------------------------------------------------------
# Expansion logic
# ---------------------------------------------------------------------------

run "empty_inputs_produces_no_resources" {
  command = plan

  assert {
    condition     = length(local.group_variables) == 0
    error_message = "Expected 0 expanded group variables with empty input."
  }
  assert {
    condition     = length(local.project_variables) == 0
    error_message = "Expected 0 expanded project variables with empty input."
  }
  assert {
    condition     = length(local.deploy_tokens) == 0
    error_message = "Expected 0 expanded deploy tokens with empty input."
  }
}

run "group_variable_expands_across_groups" {
  command = plan

  variables {
    group_variables = {
      log_level = {
        key           = "LOG_LEVEL"
        groups        = ["org/a", "org/b", "org/c"]
        value         = "info"
        variable_type = "env_var"
        protected     = false
        masked        = false
      }
    }
  }

  assert {
    condition     = length(local.group_variables) == 3
    error_message = "Expected 3 expanded entries (one per group), got ${length(local.group_variables)}."
  }
  assert {
    condition     = local.group_variables["log_level_org/a"].group == "org/a"
    error_message = "Expansion key/group mapping is wrong for group 'org/a'."
  }
  assert {
    condition     = local.group_variables["log_level_org/b"].key == "LOG_LEVEL"
    error_message = "Expanded entry lost its original key."
  }
  assert {
    condition     = issensitive(gitlab_group_variable.this["log_level_org/a"].value) && nonsensitive(gitlab_group_variable.this["log_level_org/a"].value) == "info"
    error_message = "Group variable values must reach the provider unchanged and marked sensitive, so plans redact them."
  }
}

run "project_variable_expands_across_projects" {
  command = plan

  variables {
    project_variables = {
      deploy_env = {
        key           = "DEPLOY_ENV"
        projects      = ["org/a/web", "org/a/api"]
        value         = "staging"
        variable_type = "env_var"
        protected     = false
        masked        = false
      }
    }
  }

  assert {
    condition     = length(local.project_variables) == 2
    error_message = "Expected 2 expanded project variables, got ${length(local.project_variables)}."
  }
  assert {
    condition     = local.project_variables["deploy_env_org/a/web"].project == "org/a/web"
    error_message = "Expansion lost its project mapping."
  }
  assert {
    condition     = issensitive(gitlab_project_variable.this["deploy_env_org/a/web"].value) && nonsensitive(gitlab_project_variable.this["deploy_env_org/a/web"].value) == "staging"
    error_message = "Project variable values must reach the provider unchanged and marked sensitive, so plans redact them."
  }
}

run "deploy_token_expands_across_groups" {
  command = plan

  variables {
    deploy_tokens = {
      read_only = {
        groups     = ["org/a", "org/b"]
        name       = "read-only"
        expires_at = timeadd(timestamp(), "720h")
        scopes     = ["read_repository"]
      }
    }
  }

  assert {
    condition     = length(local.deploy_tokens) == 2
    error_message = "Expected 2 expanded deploy tokens, got ${length(local.deploy_tokens)}."
  }
  assert {
    condition     = local.deploy_tokens["read_only_org/a"].username == null
    error_message = "Optional username should default to null."
  }
  # Same "<entry>_<group>" keys as gitlab_deploy_token in v12, so the moved
  # block maps every instance one to one.
  assert {
    condition     = toset(keys(gitlab_group_deploy_token.this)) == toset(["read_only_org/a", "read_only_org/b"])
    error_message = "Deploy tokens must be planned as gitlab_group_deploy_token keyed \"<entry>_<group>\"."
  }
  assert {
    condition     = nonsensitive(toset(keys(output.deploy_tokens))) == toset(["read_only_org/a", "read_only_org/b"])
    error_message = "Output deploy_tokens must be keyed like the planned tokens."
  }
}

run "pipeline_schedule_variables_expand" {
  command = plan

  variables {
    pipeline_schedules = {
      nightly = {
        project     = "org/web"
        description = "Nightly"
        ref         = "refs/heads/main"
        cron        = "0 2 * * *"
        active      = true
        variables = {
          BUILD_MODE = "full"
          REGION     = "eu"
        }
      }
    }
  }

  assert {
    condition     = length(local.pipeline_schedule_variables) == 2
    error_message = "Expected 2 pipeline schedule variables, got ${length(local.pipeline_schedule_variables)}."
  }
  assert {
    condition     = local.pipeline_schedule_variables["nightly-BUILD_MODE"].pipeline_schedule == "nightly"
    error_message = "Pipeline schedule variable lost its parent schedule reference."
  }
  assert {
    condition     = issensitive(gitlab_pipeline_schedule_variable.this["nightly-BUILD_MODE"].value) && nonsensitive(gitlab_pipeline_schedule_variable.this["nightly-BUILD_MODE"].value) == "full"
    error_message = "Schedule variable values must reach the provider unchanged and marked sensitive, so plans redact them."
  }
}

# ---------------------------------------------------------------------------
# Output set: every kept output keyed like its input (module-contract spec)
# ---------------------------------------------------------------------------

run "outputs_are_keyed_like_inputs" {
  command = plan

  variables {
    group_variables = {
      log_level = { key = "LOG_LEVEL", groups = ["org/a"], value = "info" }
    }
    project_variables = {
      env = { key = "DEPLOY_ENV", projects = ["org/app"], value = "staging" }
    }
    deploy_tokens = {
      registry = {
        groups     = ["org/a"]
        name       = "registry"
        expires_at = timeadd(timestamp(), "720h")
        scopes     = ["read_registry"]
      }
    }
    pipeline_schedules = {
      nightly = {
        project     = "org/app"
        description = "nightly"
        ref         = "refs/heads/main"
        cron        = "0 2 * * *"
        active      = true
      }
    }
    gitlab_runners = {
      ci = {
        runner_type  = "group_type"
        description  = "ci"
        group_id     = "123"
        access_level = "ref_protected"
        tag_list     = ["docker"]
        paused       = false
        untagged     = false
        locked       = false
      }
    }
    gitlab_group_access_token = {
      bot = {
        groups       = ["org/a"]
        name         = "bot"
        expires_at   = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h"))
        access_level = "developer"
        scopes       = ["read_api"]
      }
    }
    gitlab_project_access_token = {
      bot = {
        projects     = ["org/app"]
        name         = "bot"
        expires_at   = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h"))
        access_level = "developer"
        scopes       = ["read_api"]
      }
    }
  }

  assert {
    condition     = length(gitlab_group_variable.this) == 1 && length(gitlab_project_variable.this) == 1
    error_message = "Expected one group and one project variable (their ID lists are known only after apply)."
  }
  assert {
    condition     = nonsensitive(keys(output.deploy_tokens)) == ["registry_org/a"]
    error_message = "deploy_tokens must be keyed \"<entry>_<group>\"."
  }
  assert {
    condition     = keys(output.pipeline_schedule_ids) == ["nightly"]
    error_message = "pipeline_schedule_ids must be keyed like pipeline_schedules."
  }
  assert {
    condition     = keys(output.gitlab_runners) == ["ci"] && output.gitlab_runners["ci"].group_id == 123
    error_message = "gitlab_runners must be keyed like the input and carry the runner settings."
  }
  assert {
    condition     = nonsensitive(keys(output.gitlab_runner_tokens)) == ["ci"]
    error_message = "gitlab_runner_tokens must be keyed like gitlab_runners."
  }
  assert {
    condition     = nonsensitive(keys(output.group_access_tokens)) == ["bot_org/a"]
    error_message = "group_access_tokens must be keyed \"<entry>_<group>\"."
  }
  assert {
    condition     = nonsensitive(keys(output.project_access_tokens)) == ["bot_org/app"]
    error_message = "project_access_tokens must be keyed \"<entry>_<project>\"."
  }
}

# ---------------------------------------------------------------------------
# Optional-field defaults
# ---------------------------------------------------------------------------

run "variable_type_defaults_to_env_var" {
  command = plan

  variables {
    group_variables = {
      defaults = {
        key    = "KEY"
        groups = ["org/a"]
        value  = "v"
      }
    }
  }

  assert {
    condition     = local.group_variables["defaults_org/a"].variable_type == "env_var"
    error_message = "variable_type should default to env_var when omitted."
  }
  assert {
    condition     = local.group_variables["defaults_org/a"].protected == false
    error_message = "protected should default to false when omitted."
  }
  assert {
    condition     = local.group_variables["defaults_org/a"].masked == false
    error_message = "masked should default to false when omitted."
  }
}

# ---------------------------------------------------------------------------
# Validation rejection: one run per validation block in variables.tf, each
# input valid except for the rule under test, so the run fails if that rule
# is removed.
# ---------------------------------------------------------------------------

run "group_variable_type_is_rejected" {
  command = plan

  # variable_type must be env_var or file
  variables {
    group_variables = {
      bad = {
        key           = "K"
        groups        = ["org/a"]
        value         = "v"
        variable_type = "secret"
      }
    }
  }

  expect_failures = [
    var.group_variables,
  ]
}

run "group_variable_empty_groups_is_rejected" {
  command = plan

  # groups must be non-empty
  variables {
    group_variables = {
      bad = {
        key    = "K"
        groups = []
        value  = "v"
      }
    }
  }

  expect_failures = [
    var.group_variables,
  ]
}

run "group_variable_key_with_dash_is_rejected" {
  command = plan

  # key must match [A-Za-z_][A-Za-z0-9_]*
  variables {
    group_variables = {
      bad = {
        key    = "MY-VAR"
        groups = ["org/a"]
        value  = "v"
      }
    }
  }

  expect_failures = [
    var.group_variables,
  ]
}

run "project_variable_type_is_rejected" {
  command = plan

  # variable_type must be env_var or file
  variables {
    project_variables = {
      bad = {
        key           = "K"
        projects      = ["org/app"]
        value         = "v"
        variable_type = "secret"
      }
    }
  }

  expect_failures = [
    var.project_variables,
  ]
}

run "project_variable_empty_projects_is_rejected" {
  command = plan

  # projects must be non-empty
  variables {
    project_variables = {
      bad = {
        key      = "K"
        projects = []
        value    = "v"
      }
    }
  }

  expect_failures = [
    var.project_variables,
  ]
}

run "project_variable_key_starting_with_digit_is_rejected" {
  command = plan

  # key must match [A-Za-z_][A-Za-z0-9_]*
  variables {
    project_variables = {
      bad = {
        key      = "1VAR"
        projects = ["org/app"]
        value    = "v"
      }
    }
  }

  expect_failures = [
    var.project_variables,
  ]
}

run "deploy_token_empty_groups_is_rejected" {
  command = plan

  # groups must be non-empty
  variables {
    deploy_tokens = {
      bad = {
        groups     = []
        name       = "registry"
        expires_at = timeadd(timestamp(), "720h")
        scopes     = ["read_registry"]
      }
    }
  }

  expect_failures = [
    var.deploy_tokens,
  ]
}

run "deploy_token_empty_scopes_is_rejected" {
  command = plan

  # scopes must be non-empty
  variables {
    deploy_tokens = {
      bad = {
        groups     = ["org/a"]
        name       = "registry"
        expires_at = timeadd(timestamp(), "720h")
        scopes     = []
      }
    }
  }

  expect_failures = [
    var.deploy_tokens,
  ]
}

run "deploy_token_without_expiry_is_rejected" {
  command = plan

  # an expiry is required (secrets-rotation)
  variables {
    deploy_tokens = {
      bad = {
        groups = ["org/a"]
        name   = "registry"
        scopes = ["read_registry"]
      }
    }
  }

  expect_failures = [
    var.deploy_tokens,
  ]
}

run "deploy_token_malformed_expiry_is_rejected" {
  command = plan

  # expiry must be YYYY-MM-DD or RFC 3339
  variables {
    deploy_tokens = {
      bad = {
        groups     = ["org/a"]
        name       = "registry"
        expires_at = "next year"
        scopes     = ["read_registry"]
      }
    }
  }

  expect_failures = [
    var.deploy_tokens,
  ]
}

run "deploy_token_bare_date_expiry_is_rejected" {
  command = plan

  # the provider only parses RFC 3339 timestamps on deploy tokens
  variables {
    deploy_tokens = {
      bad = {
        groups     = ["org/a"]
        name       = "registry"
        expires_at = "2027-06-30"
        scopes     = ["read_registry"]
      }
    }
  }

  expect_failures = [
    var.deploy_tokens,
  ]
}

run "deploy_token_api_scope_is_rejected" {
  command = plan

  # api is an access-token scope, not a deploy-token one
  variables {
    deploy_tokens = {
      bad = {
        groups     = ["org/a"]
        name       = "registry"
        expires_at = timeadd(timestamp(), "720h")
        scopes     = ["api"]
      }
    }
  }

  expect_failures = [
    var.deploy_tokens,
  ]
}

run "deploy_token_empty_name_is_rejected" {
  command = plan

  # name must be non-empty
  variables {
    deploy_tokens = {
      bad = {
        groups     = ["org/a"]
        name       = ""
        expires_at = timeadd(timestamp(), "720h")
        scopes     = ["read_registry"]
      }
    }
  }

  expect_failures = [
    var.deploy_tokens,
  ]
}

run "pipeline_schedule_empty_project_is_rejected" {
  command = plan

  # project, ref and cron must be non-empty
  variables {
    pipeline_schedules = {
      bad = {
        project     = ""
        description = "nightly"
        ref         = "refs/heads/main"
        cron        = "0 2 * * *"
        active      = true
      }
    }
  }

  expect_failures = [
    var.pipeline_schedules,
  ]
}

run "pipeline_schedule_six_field_cron_is_rejected" {
  command = plan

  # cron must have exactly 5 fields
  variables {
    pipeline_schedules = {
      bad = {
        project     = "org/app"
        description = "nightly"
        ref         = "refs/heads/main"
        cron        = "0 0 2 * * *"
        active      = true
      }
    }
  }

  expect_failures = [
    var.pipeline_schedules,
  ]
}

run "pipeline_schedule_short_ref_is_rejected" {
  command = plan

  # ref must be a full git ref (provider 19.4+)
  variables {
    pipeline_schedules = {
      bad = {
        project     = "org/app"
        description = "nightly"
        ref         = "main"
        cron        = "0 2 * * *"
        active      = true
      }
    }
  }

  expect_failures = [
    var.pipeline_schedules,
  ]
}

run "runner_unknown_type_is_rejected" {
  command = plan

  # runner_type must be group_type, project_type or instance_type
  variables {
    gitlab_runners = {
      bad = {
        runner_type  = "shared"
        description  = "ci"
        group_id     = "123"
        access_level = "not_protected"
        tag_list     = ["docker"]
        paused       = false
        untagged     = false
        locked       = false
      }
    }
  }

  expect_failures = [
    var.gitlab_runners,
  ]
}

run "runner_unknown_access_level_is_rejected" {
  command = plan

  # access_level must be not_protected or ref_protected
  variables {
    gitlab_runners = {
      bad = {
        runner_type  = "group_type"
        description  = "ci"
        group_id     = "123"
        access_level = "protected"
        tag_list     = ["docker"]
        paused       = false
        untagged     = false
        locked       = false
      }
    }
  }

  expect_failures = [
    var.gitlab_runners,
  ]
}

run "group_runner_without_group_id_is_rejected" {
  command = plan

  # group_type needs group_id
  variables {
    gitlab_runners = {
      bad = {
        runner_type  = "group_type"
        description  = "ci"
        access_level = "not_protected"
        tag_list     = ["docker"]
        paused       = false
        untagged     = false
        locked       = false
      }
    }
  }

  expect_failures = [
    var.gitlab_runners,
  ]
}

run "project_runner_without_project_id_is_rejected" {
  command = plan

  # project_type needs project_id
  variables {
    gitlab_runners = {
      bad = {
        runner_type  = "project_type"
        description  = "ci"
        access_level = "not_protected"
        tag_list     = ["docker"]
        paused       = false
        untagged     = false
        locked       = false
      }
    }
  }

  expect_failures = [
    var.gitlab_runners,
  ]
}

run "runner_group_path_is_rejected" {
  command = plan

  # group_id must be a numeric ID
  variables {
    gitlab_runners = {
      bad = {
        runner_type  = "group_type"
        description  = "ci"
        group_id     = "org/platform"
        access_level = "not_protected"
        tag_list     = ["docker"]
        paused       = false
        untagged     = false
        locked       = false
      }
    }
  }

  expect_failures = [
    var.gitlab_runners,
  ]
}

run "tagged_runner_without_tags_is_rejected" {
  command = plan

  # tag_list must be non-empty unless untagged
  variables {
    gitlab_runners = {
      bad = {
        runner_type  = "group_type"
        description  = "ci"
        group_id     = "123"
        access_level = "not_protected"
        tag_list     = []
        paused       = false
        untagged     = false
        locked       = false
      }
    }
  }

  expect_failures = [
    var.gitlab_runners,
  ]
}

run "runner_timeout_below_600_is_rejected" {
  command = plan

  # maximum_timeout must be null or >= 600
  variables {
    gitlab_runners = {
      bad = {
        runner_type     = "group_type"
        description     = "ci"
        group_id        = "123"
        access_level    = "not_protected"
        tag_list        = ["docker"]
        paused          = false
        untagged        = false
        locked          = false
        maximum_timeout = 300
      }
    }
  }

  expect_failures = [
    var.gitlab_runners,
  ]
}

run "group_access_token_underscore_level_is_rejected" {
  command = plan

  # the provider spells it "no one"
  variables {
    gitlab_group_access_token = {
      bad = {
        groups       = ["org/a"]
        name         = "bot"
        expires_at   = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h"))
        access_level = "no_one"
        scopes       = ["read_api"]
      }
    }
  }

  expect_failures = [
    var.gitlab_group_access_token,
  ]
}

run "group_access_token_timestamp_expiry_is_rejected" {
  command = plan

  # access-token expiry is a date only
  variables {
    gitlab_group_access_token = {
      bad = {
        groups       = ["org/a"]
        name         = "bot"
        expires_at   = "2027-01-01T00:00:00Z"
        access_level = "developer"
        scopes       = ["read_api"]
      }
    }
  }

  expect_failures = [
    var.gitlab_group_access_token,
  ]
}

run "group_access_token_empty_scopes_is_rejected" {
  command = plan

  # groups, scopes and name must be non-empty
  variables {
    gitlab_group_access_token = {
      bad = {
        groups       = ["org/a"]
        name         = "bot"
        expires_at   = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h"))
        access_level = "developer"
        scopes       = []
      }
    }
  }

  expect_failures = [
    var.gitlab_group_access_token,
  ]
}

run "group_access_token_sudo_scope_is_rejected" {
  command = plan

  # sudo is a personal-token scope
  variables {
    gitlab_group_access_token = {
      bad = {
        groups       = ["org/a"]
        name         = "bot"
        expires_at   = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h"))
        access_level = "developer"
        scopes       = ["sudo"]
      }
    }
  }

  expect_failures = [
    var.gitlab_group_access_token,
  ]
}

run "project_access_token_unknown_level_is_rejected" {
  command = plan

  # access_level must be one of the provider's levels
  variables {
    gitlab_project_access_token = {
      bad = {
        projects     = ["org/app"]
        name         = "bot"
        expires_at   = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h"))
        access_level = "admin"
        scopes       = ["read_api"]
      }
    }
  }

  expect_failures = [
    var.gitlab_project_access_token,
  ]
}

run "project_access_token_malformed_expiry_is_rejected" {
  command = plan

  # access-token expiry must be YYYY-MM-DD
  variables {
    gitlab_project_access_token = {
      bad = {
        projects     = ["org/app"]
        name         = "bot"
        expires_at   = "01/01/2027"
        access_level = "developer"
        scopes       = ["read_api"]
      }
    }
  }

  expect_failures = [
    var.gitlab_project_access_token,
  ]
}

run "project_access_token_empty_projects_is_rejected" {
  command = plan

  # projects, scopes and name must be non-empty
  variables {
    gitlab_project_access_token = {
      bad = {
        projects     = []
        name         = "bot"
        expires_at   = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h"))
        access_level = "developer"
        scopes       = ["read_api"]
      }
    }
  }

  expect_failures = [
    var.gitlab_project_access_token,
  ]
}

run "project_access_token_virtual_registry_scope_is_rejected" {
  command = plan

  # virtual registry scopes exist on group tokens only
  variables {
    gitlab_project_access_token = {
      bad = {
        projects     = ["org/app"]
        name         = "bot"
        expires_at   = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h"))
        access_level = "developer"
        scopes       = ["read_virtual_registry"]
      }
    }
  }

  expect_failures = [
    var.gitlab_project_access_token,
  ]
}

run "project_access_token_read_user_scope_is_rejected" {
  command = plan

  # read_user is not a project-token scope
  variables {
    gitlab_project_access_token = {
      bad = {
        projects     = ["org/app"]
        name         = "bot"
        expires_at   = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h"))
        access_level = "developer"
        scopes       = ["read_user"]
      }
    }
  }

  expect_failures = [
    var.gitlab_project_access_token,
  ]
}

# ---------------------------------------------------------------------------
# Accepted forms at the edge of the validations
# ---------------------------------------------------------------------------

run "group_access_token_no_one_level_is_accepted" {
  command = plan

  # the provider's spelling of the lowest level
  variables {
    gitlab_group_access_token = {
      bad = {
        groups       = ["org/a"]
        name         = "bot"
        expires_at   = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h"))
        access_level = "no one"
        scopes       = ["read_api"]
      }
    }
  }
}

run "project_access_token_planner_level_is_accepted" {
  command = plan

  # level added by GitLab 18
  variables {
    gitlab_project_access_token = {
      bad = {
        projects     = ["org/app"]
        name         = "bot"
        expires_at   = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h"))
        access_level = "planner"
        scopes       = ["read_api"]
      }
    }
  }
}

run "group_access_token_virtual_registry_scope_is_accepted" {
  command = plan

  # group tokens reach virtual registries
  variables {
    gitlab_group_access_token = {
      bad = {
        groups       = ["org/a"]
        name         = "bot"
        expires_at   = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h"))
        access_level = "developer"
        scopes       = ["read_virtual_registry"]
      }
    }
  }
}


run "tag_ref_schedule_is_accepted" {
  command = plan

  # a tag ref is a full ref too
  variables {
    pipeline_schedules = {
      bad = {
        project     = "org/app"
        description = "nightly"
        ref         = "refs/tags/v1.0.0"
        cron        = "0 2 * * *"
        active      = true
      }
    }
  }
}

run "project_runner_with_numeric_id_is_accepted" {
  command = plan

  # numeric project ID
  variables {
    gitlab_runners = {
      bad = {
        runner_type  = "project_type"
        description  = "ci"
        access_level = "not_protected"
        tag_list     = ["docker"]
        paused       = false
        untagged     = false
        locked       = false
        project_id   = "456"
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Security guardrails (checks.tf): each run triggers exactly one check
# ---------------------------------------------------------------------------

run "unmasked_password_variable_warns" {
  command = plan

  variables {
    group_variables = {
      registry_password = {
        key       = "REGISTRY_PASSWORD"
        groups    = ["org/a"]
        value     = "s3cr3t"
        protected = true
        masked    = false
      }
    }
  }

  expect_failures = [
    check.secret_variables_masked_and_protected,
  ]
}

run "unprotected_token_variable_warns" {
  command = plan

  # case-insensitive match on the key
  variables {
    project_variables = {
      deploy = {
        key       = "deploy_token"
        projects  = ["org/app"]
        value     = "s3cr3t-token-value"
        protected = false
        masked    = true
      }
    }
  }

  expect_failures = [
    check.secret_variables_masked_and_protected,
  ]
}

run "two_year_deploy_token_warns" {
  command = plan

  variables {
    deploy_tokens = {
      registry = {
        groups     = ["org/a"]
        name       = "registry"
        expires_at = timeadd(timestamp(), "17520h")
        scopes     = ["read_registry"]
      }
    }
  }

  expect_failures = [
    check.token_lifetime,
  ]
}

run "owner_group_access_token_warns" {
  command = plan

  variables {
    gitlab_group_access_token = {
      bot = {
        groups       = ["org/a"]
        name         = "bot"
        expires_at   = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h"))
        access_level = "owner"
        scopes       = ["api"]
      }
    }
  }

  expect_failures = [
    check.access_token_privilege,
  ]
}

run "unset_project_access_token_level_warns" {
  command = plan

  # GitLab grants maintainer when access_level is omitted
  variables {
    gitlab_project_access_token = {
      bot = {
        projects   = ["org/app"]
        name       = "bot"
        expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h"))
        scopes     = ["read_api"]
      }
    }
  }

  expect_failures = [
    check.access_token_privilege,
  ]
}

run "clean_configuration_raises_no_warning" {
  command = plan

  variables {
    group_variables = {
      log_level = { key = "LOG_LEVEL", groups = ["org/a"], value = "info" }
      registry_password = {
        key       = "REGISTRY_PASSWORD"
        groups    = ["org/a"]
        value     = "s3cr3t"
        protected = true
        masked    = true
      }
    }
    deploy_tokens = {
      registry = {
        groups     = ["org/a"]
        name       = "registry"
        expires_at = timeadd(timestamp(), "4380h")
        scopes     = ["read_registry"]
      }
    }
    gitlab_group_access_token = {
      bot = {
        groups       = ["org/a"]
        name         = "bot"
        expires_at   = formatdate("YYYY-MM-DD", timeadd(timestamp(), "4380h"))
        access_level = "developer"
        scopes       = ["read_api"]
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Standalone keys must not contain ":" (module-contract): they share resources
# and outputs with the objects nested in groups and projects.
# ---------------------------------------------------------------------------

run "group_variables_key_with_colon_is_rejected" {
  command = plan

  variables {
    group_variables = {
      "bad:key" = { key = "K", groups = ["org/a"], value = "v" }
    }
  }

  expect_failures = [
    var.group_variables,
  ]
}

run "project_variables_key_with_colon_is_rejected" {
  command = plan

  variables {
    project_variables = {
      "bad:key" = { key = "K", projects = ["org/app"], value = "v" }
    }
  }

  expect_failures = [
    var.project_variables,
  ]
}

run "deploy_tokens_key_with_colon_is_rejected" {
  command = plan

  variables {
    deploy_tokens = {
      "bad:key" = { groups = ["org/a"], name = "registry", expires_at = timeadd(timestamp(), "720h"), scopes = ["read_registry"] }
    }
  }

  expect_failures = [
    var.deploy_tokens,
  ]
}

run "pipeline_schedules_key_with_colon_is_rejected" {
  command = plan

  variables {
    pipeline_schedules = {
      "bad:key" = { project = "org/app", description = "nightly", ref = "refs/heads/main", cron = "0 2 * * *", active = true }
    }
  }

  expect_failures = [
    var.pipeline_schedules,
  ]
}

run "gitlab_runners_key_with_colon_is_rejected" {
  command = plan

  variables {
    gitlab_runners = {
      "bad:key" = { runner_type = "group_type", description = "ci", group_id = "123", access_level = "not_protected", tag_list = ["docker"], paused = false, untagged = false, locked = false }
    }
  }

  expect_failures = [
    var.gitlab_runners,
  ]
}

run "gitlab_group_access_token_key_with_colon_is_rejected" {
  command = plan

  variables {
    gitlab_group_access_token = {
      "bad:key" = { groups = ["org/a"], name = "bot", expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h")), access_level = "developer", scopes = ["read_api"] }
    }
  }

  expect_failures = [
    var.gitlab_group_access_token,
  ]
}

run "gitlab_project_access_token_key_with_colon_is_rejected" {
  command = plan

  variables {
    gitlab_project_access_token = {
      "bad:key" = { projects = ["org/app"], name = "bot", expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "720h")), access_level = "developer", scopes = ["read_api"] }
    }
  }

  expect_failures = [
    var.gitlab_project_access_token,
  ]
}
