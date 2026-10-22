variable "demo_group" {
  description = "Full path or numeric ID of a group you own, for example my-org/platform."
  type        = string
}

variable "demo_group_id" {
  description = "Numeric ID of the same group, for the group runner (GitLab shows it on the group overview page)."
  type        = string
}

variable "demo_project" {
  description = "Full path or numeric ID of a project in that group, for example my-org/platform/web."
  type        = string
}

variable "token_expires_at" {
  description = "Expiry date of the deploy and access tokens, YYYY-MM-DD, at most one year ahead and within the instance's maximum access-token lifetime."
  type        = string
}

variable "registry_password" {
  description = "Value of the REGISTRY_PASSWORD group variable. Pass via TF_VAR_registry_password from your secret store; it lands in state (see SECURITY.md)."
  type        = string
  sensitive   = true
}

module "gitlab_management" {
  source = "../.."

  group_variables = {
    pipeline_log_level = {
      key    = "PIPELINE_LOG_LEVEL"
      groups = [var.demo_group]
      value  = "info"
    }
    registry_password = {
      key           = "REGISTRY_PASSWORD"
      groups        = [var.demo_group]
      value         = var.registry_password
      variable_type = "env_var"
      protected     = true
      masked        = true
    }
  }

  project_variables = {
    deploy_env = {
      key           = "DEPLOY_CONFIG"
      projects      = [var.demo_project]
      value         = "environment: staging\n"
      variable_type = "file"
    }
  }

  deploy_tokens = {
    read_registry = {
      groups     = [var.demo_group]
      name       = "read-registry"
      username   = "read-registry"
      expires_at = "${var.token_expires_at}T00:00:00Z" # deploy tokens take RFC 3339
      scopes     = ["read_repository", "read_registry"]
    }
  }

  pipeline_schedules = {
    nightly_build = {
      project     = var.demo_project
      description = "Nightly build"
      ref         = "refs/heads/main"
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
      description     = "CI runner for the platform group"
      group_id        = var.demo_group_id
      access_level    = "ref_protected"
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
      expires_at   = var.token_expires_at
      access_level = "maintainer"
      scopes       = ["api", "read_repository", "write_repository"]
    }
  }

  gitlab_project_access_token = {
    release_bot = {
      projects     = [var.demo_project]
      name         = "release-bot"
      expires_at   = var.token_expires_at
      access_level = "developer"
      scopes       = ["read_api", "read_repository", "write_repository"]
    }
  }
}
