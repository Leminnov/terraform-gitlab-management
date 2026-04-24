terraform {
  required_version = ">= 1.10.7"

  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 18.6"
    }
  }
}

provider "gitlab" {
  # Expects GITLAB_TOKEN (or GITLAB_BASE_URL + GITLAB_TOKEN) in environment.
}

variable "demo_group" {
  description = "Group path or ID used by this example (replace with one you can manage)."
  type        = string
  default     = "my-org/platform"
}

variable "demo_project" {
  description = "Project path or ID used by this example (replace with one you can manage)."
  type        = string
  default     = "my-org/platform/web"
}

locals {
  # Expires at end of next year to keep the example copy-pasteable for a while.
  token_expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "8760h")) # ~1 year
}

module "gitlab_management" {
  source = "../../"

  group_variables = {
    pipeline_log_level = {
      key           = "PIPELINE_LOG_LEVEL"
      groups        = [var.demo_group]
      value         = "info"
      variable_type = "env_var"
      protected     = false
      masked        = false
    }
    registry_password = {
      key           = "REGISTRY_PASSWORD"
      groups        = [var.demo_group]
      value         = "change-me"
      variable_type = "env_var"
      protected     = true
      masked        = true
    }
  }

  project_variables = {
    deploy_env = {
      key           = "DEPLOY_ENV"
      projects      = [var.demo_project]
      value         = "staging"
      variable_type = "env_var"
      protected     = false
      masked        = false
    }
  }

  deploy_tokens = {
    read_registry = {
      groups = [var.demo_group]
      name   = "read-registry"
      scopes = ["read_repository", "read_registry"]
    }
  }

  pipeline_schedules = {
    nightly_build = {
      project     = var.demo_project
      description = "Nightly build"
      ref         = "main"
      cron        = "0 2 * * *"
      active      = true
      variables = {
        BUILD_MODE = "full"
      }
    }
  }

  gitlab_runners = {
    ci_runner = {
      runner_type     = "group_type"
      description     = "CI runner for platform group"
      group_id        = "1"
      access_level    = "not_protected"
      tag_list        = ["docker", "linux"]
      maximum_timeout = 3600
      paused          = false
      untagged        = false
      locked          = false
    }
  }

  gitlab_group_access_token = {
    ci_bot = {
      groups       = [var.demo_group]
      name         = "ci-bot"
      expires_at   = local.token_expires_at
      access_level = "maintainer"
      scopes       = ["api", "read_repository", "write_repository"]
    }
  }

  gitlab_project_access_token = {
    release_bot = {
      projects     = [var.demo_project]
      name         = "release-bot"
      expires_at   = local.token_expires_at
      access_level = "developer"
      scopes       = ["api", "read_repository", "write_repository"]
    }
  }
}
