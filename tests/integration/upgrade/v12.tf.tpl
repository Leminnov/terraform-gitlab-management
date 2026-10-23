# Upgrade fixture, step 1: the module as consumers run it today (v12.0.0 on
# provider 18.11), with v12-valid inputs. run.sh copies it to a work directory
# as main.tf; it is a template so pre-commit and tflint never fetch v12.
# No runner: v12 cannot plan one (its outputs read attributes the provider
# does not have).
terraform {
  required_version = ">= 1.11.0"

  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 18.11"
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

variable "access_tokens" {
  description = "Create the project access token; run.sh sets false on a gitlab.com Free namespace, where access tokens need Premium."
  type        = bool
  default     = true
}

variable "expires_on" {
  description = "Token expiry date, YYYY-MM-DD."
  type        = string
}

module "gitlab_management" {
  source = "git::https://gitlab.com/leminnov/terraform/modules/gitlab-management.git?ref=v12.0.0"

  group_variables = {
    plain = {
      key    = "IT_UPGRADE_${upper(replace(var.suffix, "-", "_"))}"
      groups = [var.group_id]
      value  = "plain"
    }
  }

  deploy_tokens = {
    # Already dated in v12: must migrate as a pure move.
    dated = {
      groups     = [var.group_id]
      name       = "it-dated-${var.suffix}"
      expires_at = "${var.expires_on}T00:00:00Z"
      scopes     = ["read_repository"]
    }
    # Never expiring, which v12 allowed: v13 requires an expiry, so it is replaced.
    undated = {
      groups = [var.group_id]
      name   = "it-undated-${var.suffix}"
      scopes = ["read_repository"]
    }
  }

  pipeline_schedules = {
    nightly = {
      project     = var.project_id
      description = "it-upgrade-${var.suffix}"
      # gitlab.com reads a short ref back as refs/heads/main, which provider
      # 18.11 rejects as an inconsistent result; v12 accepts the full ref.
      ref    = "refs/heads/main"
      cron   = "0 3 * * *"
      active = false
    }
  }

  gitlab_project_access_token = {
    for k, v in {
      bot = {
        projects     = [var.project_id]
        name         = "it-upgrade-${var.suffix}"
        expires_at   = var.expires_on
        access_level = "reporter"
        scopes       = ["read_api"]
      }
    } : k => v if var.access_tokens
  }
}
