# Plan-level tests for the gitlab-management module.
#
# These tests exercise the module's expansion and validation logic without
# contacting GitLab: the provider is mocked and every `run` uses
# `command = plan`.

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
}

run "deploy_token_expands_across_groups" {
  command = plan

  variables {
    deploy_tokens = {
      read_only = {
        groups = ["org/a", "org/b"]
        name   = "read-only"
        scopes = ["read_repository"]
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
}

run "pipeline_schedule_variables_expand" {
  command = plan

  variables {
    pipeline_schedules = {
      nightly = {
        project     = "org/web"
        description = "Nightly"
        ref         = "main"
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
# Validation rejection
# ---------------------------------------------------------------------------

run "invalid_variable_type_is_rejected" {
  command = plan

  variables {
    group_variables = {
      bad = {
        key           = "BAD"
        groups        = ["org/a"]
        value         = "v"
        variable_type = "not_a_valid_type"
      }
    }
  }

  expect_failures = [
    var.group_variables,
  ]
}

run "invalid_runner_type_is_rejected" {
  command = plan

  variables {
    gitlab_runners = {
      bad = {
        runner_type  = "bogus_type"
        description  = "bad runner"
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

run "invalid_runner_access_level_is_rejected" {
  command = plan

  variables {
    gitlab_runners = {
      bad = {
        runner_type  = "instance_type"
        description  = "bad access level"
        access_level = "super_admin"
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

run "invalid_group_access_token_level_is_rejected" {
  command = plan

  variables {
    gitlab_group_access_token = {
      bad = {
        groups       = ["org/a"]
        name         = "bad"
        expires_at   = "2099-12-31"
        access_level = "archmage"
        scopes       = ["api"]
      }
    }
  }

  expect_failures = [
    var.gitlab_group_access_token,
  ]
}

# ---------------------------------------------------------------------------
# Tighter production validations added in Phase 2
# ---------------------------------------------------------------------------

run "empty_groups_list_is_rejected" {
  command = plan

  variables {
    group_variables = {
      bad = {
        key           = "K"
        groups        = []
        value         = "v"
        variable_type = "env_var"
      }
    }
  }

  expect_failures = [
    var.group_variables,
  ]
}

run "invalid_variable_key_is_rejected" {
  command = plan

  variables {
    group_variables = {
      bad = {
        key           = "123-invalid"
        groups        = ["org/a"]
        value         = "v"
        variable_type = "env_var"
      }
    }
  }

  expect_failures = [
    var.group_variables,
  ]
}

run "invalid_deploy_token_scope_is_rejected" {
  command = plan

  variables {
    deploy_tokens = {
      bad = {
        groups = ["org/a"]
        name   = "bad"
        scopes = ["make_coffee"]
      }
    }
  }

  expect_failures = [
    var.deploy_tokens,
  ]
}

run "invalid_access_token_scope_is_rejected" {
  command = plan

  variables {
    gitlab_group_access_token = {
      bad = {
        groups       = ["org/a"]
        name         = "bad"
        expires_at   = "2099-12-31"
        access_level = "developer"
        scopes       = ["root_on_the_server"]
      }
    }
  }

  expect_failures = [
    var.gitlab_group_access_token,
  ]
}

run "invalid_expires_at_format_is_rejected" {
  command = plan

  variables {
    gitlab_project_access_token = {
      bad = {
        projects     = ["org/a/web"]
        name         = "bad"
        expires_at   = "not-a-date"
        access_level = "developer"
        scopes       = ["api"]
      }
    }
  }

  expect_failures = [
    var.gitlab_project_access_token,
  ]
}

run "invalid_cron_is_rejected" {
  command = plan

  variables {
    pipeline_schedules = {
      bad = {
        project     = "org/a/web"
        description = "bad"
        ref         = "main"
        cron        = "0 2 * *" # only 4 fields
        active      = true
      }
    }
  }

  expect_failures = [
    var.pipeline_schedules,
  ]
}

run "tagged_runner_with_empty_tag_list_is_rejected" {
  command = plan

  variables {
    gitlab_runners = {
      bad = {
        runner_type  = "group_type"
        description  = "tagged runner with no tags"
        group_id     = "1"
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

run "group_runner_without_group_id_is_rejected" {
  command = plan

  variables {
    gitlab_runners = {
      bad = {
        runner_type  = "group_type"
        description  = "missing group_id"
        access_level = "not_protected"
        tag_list     = ["x"]
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

run "maximum_timeout_below_600_is_rejected" {
  command = plan

  variables {
    gitlab_runners = {
      bad = {
        runner_type     = "instance_type"
        description     = "timeout too short"
        access_level    = "not_protected"
        tag_list        = []
        maximum_timeout = 120
        paused          = false
        untagged        = true
        locked          = false
      }
    }
  }

  expect_failures = [
    var.gitlab_runners,
  ]
}
