terraform {
  required_version = ">= 1.11.0"

  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 18.11"
    }
  }
}

provider "gitlab" {
  # Expects GITLAB_TOKEN (or GITLAB_BASE_URL + GITLAB_TOKEN) in environment.
}

module "gitlab_management" {
  source = "../../"

  group_variables = {
    pipeline_log_level = {
      key           = "PIPELINE_LOG_LEVEL"
      groups        = ["my-org/platform"]
      value         = "info"
      variable_type = "env_var"
      protected     = false
      masked        = false
    }
  }
}
