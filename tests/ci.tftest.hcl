# CI/CD settings of created projects (project-ci-settings and runners specs):
# opt-in hardening, explicit settings, optional settings, the group runner
# setting, freeze periods, secure files, the CI/CD catalog flag, and one
# rejected-input run per validation. The provider arguments are
# Optional+Computed, so the mock fills those the module leaves null: "not sent"
# is asserted on local.project_args.

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
  projects        = { "platform/api" = {} }
}

run "bare_project_sends_no_hardened_setting" {
  command = plan

  assert {
    condition = alltrue([
      local.project_args["platform/api"].ci.hardening_enabled == false,
      local.project_args["platform/api"].ci.public_jobs == null,
      local.project_args["platform/api"].ci.pipeline_variables_minimum_override_role == null,
      local.project_args["platform/api"].ci.protect_merge_request_pipelines == null,
      local.project_args["platform/api"].ci.separated_caches == null,
      local.project_args["platform/api"].ci.forward_deployment_enabled == null,
      local.project_args["platform/api"].ci.push_repository_for_job_token_allowed == null,
      local.project_args["platform/api"].ci.allow_merge_on_skipped_pipeline == null,
      local.project_args["platform/api"].ci.build_timeout == null,
    ])
    error_message = "Without hardening, no CI setting may be sent."
  }
}

run "hardened_project" {
  command = plan

  variables {
    projects = { "platform/api" = { ci = { hardening_enabled = true } } }
  }

  assert {
    condition = alltrue([
      gitlab_project.this["platform/api"].public_jobs == false,
      gitlab_project.this["platform/api"].ci_pipeline_variables_minimum_override_role == "no_one_allowed",
      gitlab_project.this["platform/api"].protect_merge_request_pipelines == true,
      gitlab_project.this["platform/api"].ci_separated_caches == true,
      gitlab_project.this["platform/api"].ci_forward_deployment_enabled == true,
      gitlab_project.this["platform/api"].ci_push_repository_for_job_token_allowed == false,
      gitlab_project.this["platform/api"].allow_merge_on_skipped_pipeline == false,
    ])
    error_message = "Hardening must send the seven hardened values."
  }
}

run "hardened_project_with_one_exception" {
  command = plan

  variables {
    projects = { "platform/api" = { ci = { hardening_enabled = true, separated_caches = false } } }
  }

  assert {
    condition = alltrue([
      gitlab_project.this["platform/api"].ci_separated_caches == false,
      gitlab_project.this["platform/api"].public_jobs == false,
      gitlab_project.this["platform/api"].ci_pipeline_variables_minimum_override_role == "no_one_allowed",
    ])
    error_message = "An explicit value must win over hardening, the other hardened values stay."
  }
}

run "one_setting_without_hardening" {
  command = plan

  variables {
    projects = { "platform/api" = { ci = { pipeline_variables_minimum_override_role = "developer" } } }
  }

  assert {
    condition = alltrue([
      gitlab_project.this["platform/api"].ci_pipeline_variables_minimum_override_role == "developer",
      local.project_args["platform/api"].ci.public_jobs == null,
      local.project_args["platform/api"].ci.separated_caches == null,
    ])
    error_message = "Without hardening, only the explicit setting may be sent."
  }
}

run "optional_ci_settings" {
  command = plan

  variables {
    projects = {
      "platform/api" = {
        ci = {
          config_path                   = "ci/main.yml"
          auto_cancel_pending_pipelines = "enabled"
          build_timeout                 = 3600
          default_git_depth             = 20
          delete_pipelines_in_seconds   = 31536000
          id_token_sub_claim_components = ["project_path", "ref_type", "ref"]
          group_runners_enabled         = true
          shared_runners_enabled        = false
        }
      }
    }
  }

  assert {
    condition = alltrue([
      gitlab_project.this["platform/api"].ci_config_path == "ci/main.yml",
      gitlab_project.this["platform/api"].auto_cancel_pending_pipelines == "enabled",
      gitlab_project.this["platform/api"].build_timeout == 3600,
      gitlab_project.this["platform/api"].ci_default_git_depth == 20,
      gitlab_project.this["platform/api"].ci_delete_pipelines_in_seconds == 31536000,
      gitlab_project.this["platform/api"].ci_id_token_sub_claim_components == tolist(["project_path", "ref_type", "ref"]),
      gitlab_project.this["platform/api"].group_runners_enabled == true,
      gitlab_project.this["platform/api"].shared_runners_enabled == false,
    ])
    error_message = "Every optional CI setting must be sent as given."
  }
}

run "group_instance_runner_setting" {
  command = plan

  variables {
    groups = { platform = { shared_runners_setting = "disabled_and_unoverridable" } }
  }

  assert {
    condition     = gitlab_group.level_1["platform"].shared_runners_setting == "disabled_and_unoverridable"
    error_message = "The group's instance runner setting must be sent."
  }
}

run "freeze_period_secure_file_and_catalog" {
  command = plan

  variables {
    projects = {
      "platform/api" = {
        description    = "API"
        freeze_periods = { weekend = { freeze_start = "0 18 * * 5", freeze_end = "0 6 * * 1" } }
        secure_files   = { "kubeconfig.yaml" = "apiVersion: v1\n" }
        cicd_catalog   = true
      }
    }
  }

  assert {
    condition = alltrue([
      keys(gitlab_project_freeze_period.this) == ["platform/api:weekend"],
      gitlab_project_freeze_period.this["platform/api:weekend"].cron_timezone == "UTC",
      gitlab_project_freeze_period.this["platform/api:weekend"].freeze_start == "0 18 * * 5",
      gitlab_project_freeze_period.this["platform/api:weekend"].project == "2000",
    ])
    error_message = "A freeze period must be keyed \"<project key>:<label>\" and default to UTC."
  }
  assert {
    condition = alltrue([
      keys(gitlab_project_secure_file.this) == ["platform/api:kubeconfig.yaml"],
      gitlab_project_secure_file.this["platform/api:kubeconfig.yaml"].name == "kubeconfig.yaml",
      issensitive(gitlab_project_secure_file.this["platform/api:kubeconfig.yaml"].content),
    ])
    error_message = "A secure file must be named by its key, with its content redacted."
  }
  assert {
    condition     = keys(gitlab_project_cicd_catalog.this) == ["platform/api"] && gitlab_project_cicd_catalog.this["platform/api"].enabled == true
    error_message = "cicd_catalog = true must publish the project."
  }
}

# ---------------------------------------------------------------------------
# Rejected inputs: one run per validation
# ---------------------------------------------------------------------------

run "unknown_override_role_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { ci = { pipeline_variables_minimum_override_role = "guest" } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "unknown_auto_cancel_value_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { ci = { auto_cancel_pending_pipelines = "yes" } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "timeout_below_minimum_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { ci = { build_timeout = 300 } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "git_depth_too_large_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { ci = { default_git_depth = 2000 } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "retention_below_one_day_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { ci = { delete_pipelines_in_seconds = 3600 } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "sub_claim_without_project_path_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { ci = { id_token_sub_claim_components = ["ref"] } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "malformed_freeze_cron_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { freeze_periods = { weekend = { freeze_start = "Friday 18:00", freeze_end = "0 6 * * 1" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "secure_file_path_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { secure_files = { "certs/ca.pem" = "x" } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "catalog_project_without_description_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { cicd_catalog = true } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "unknown_group_runner_setting_is_rejected" {
  command = plan

  variables {
    groups = { platform = { shared_runners_setting = "off" } }
  }

  expect_failures = [
    var.groups,
  ]
}
