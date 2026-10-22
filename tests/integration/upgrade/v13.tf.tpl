# Upgrade fixture, step 2: the same state planned with this module on provider
# 19.5, after the upgrade-note edits (full schedule ref, an expiry on every
# deploy token). run.sh replaces @MODULE_DIR@ with the repository root.
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 19.5"
    }
  }

  backend "local" {}
}

provider "gitlab" {}

variable "group_id" {
  description = "Numeric ID of the sandbox group."
  type        = string
}

variable "project_id" {
  description = "Numeric ID of the sandbox project."
  type        = string
}

variable "suffix" {
  description = "Run suffix appended to every name and key."
  type        = string
}

variable "expires_on" {
  description = "Token expiry date, YYYY-MM-DD."
  type        = string
}

module "gitlab_management" {
  source = "@MODULE_DIR@"

  group_variables = {
    plain = {
      key    = "IT_UPGRADE_${upper(replace(var.suffix, "-", "_"))}"
      groups = [var.group_id]
      value  = "plain"
    }
  }

  deploy_tokens = {
    # Same value as in v12: the plan must show a move and nothing else.
    dated = {
      groups     = [var.group_id]
      name       = "it-dated-${var.suffix}"
      expires_at = "${var.expires_on}T00:00:00Z"
      scopes     = ["read_repository"]
    }
    # Expiry added, as the upgrade note asks: the plan must replace it once.
    undated = {
      groups     = [var.group_id]
      name       = "it-undated-${var.suffix}"
      expires_at = "${var.expires_on}T00:00:00Z"
      scopes     = ["read_repository"]
    }
  }

  pipeline_schedules = {
    nightly = {
      project     = var.project_id
      description = "it-upgrade-${var.suffix}"
      ref         = "refs/heads/main"
      cron        = "0 3 * * *"
      active      = false
    }
  }

  gitlab_project_access_token = {
    bot = {
      projects     = [var.project_id]
      name         = "it-upgrade-${var.suffix}"
      expires_at   = var.expires_on
      access_level = "reporter"
      scopes       = ["read_api"]
    }
  }
}
