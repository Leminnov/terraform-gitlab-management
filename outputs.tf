# =============================================================================
# GROUP VARIABLES OUTPUTS
# =============================================================================

output "group_variables" {
  description = "Map of all created group variables with their configurations"
  value = {
    for k, v in gitlab_group_variable.this : k => {
      id            = v.id
      key           = v.key
      group         = v.group
      value         = v.value
      variable_type = v.variable_type
      protected     = v.protected
      masked        = v.masked
    }
  }
  sensitive = true
}

output "group_variables_ids" {
  description = "List of all group variable IDs"
  value       = [for k, v in gitlab_group_variable.this : v.id]
}

# =============================================================================
# PROJECT VARIABLES OUTPUTS
# =============================================================================

output "project_variables" {
  description = "Map of all created project variables with their configurations"
  value = {
    for k, v in gitlab_project_variable.this : k => {
      id            = v.id
      key           = v.key
      project       = v.project
      value         = v.value
      variable_type = v.variable_type
      protected     = v.protected
      masked        = v.masked
    }
  }
  sensitive = true
}

output "project_variables_ids" {
  description = "List of all project variable IDs"
  value       = [for k, v in gitlab_project_variable.this : v.id]
}

# =============================================================================
# DEPLOY TOKENS OUTPUTS
# =============================================================================

output "deploy_tokens" {
  description = "Map of all deploy tokens with comprehensive details"
  value = {
    for k, v in gitlab_deploy_token.this : k => {
      id         = v.id
      group      = v.group
      name       = v.name
      username   = v.username
      token      = v.token
      expires_at = v.expires_at
      scopes     = v.scopes
    }
  }
  sensitive = true
}

output "deploy_tokens_by_group" {
  description = "Deploy tokens organized by group ID"
  value = {
    for k, v in gitlab_deploy_token.this : v.group => {
      token_name = v.name
      username   = v.username
      token      = v.token
      expires_at = v.expires_at
      scopes     = v.scopes
    }...
  }
  sensitive = true
}

output "deploy_tokens_summary" {
  description = "Summary of deploy tokens (non-sensitive metadata)"
  value = {
    for k, v in gitlab_deploy_token.this : k => {
      group      = v.group
      name       = v.name
      username   = v.username
      expires_at = v.expires_at
      scopes     = v.scopes
    }
  }
}

# =============================================================================
# PIPELINE SCHEDULES OUTPUTS
# =============================================================================

output "pipeline_schedules" {
  description = "Map of all pipeline schedules with their details"
  value = {
    for k, v in gitlab_pipeline_schedule.this : k => {
      id                   = v.id
      pipeline_schedule_id = v.pipeline_schedule_id
      project              = v.project
      description          = v.description
      ref                  = v.ref
      cron                 = v.cron
      cron_timezone        = v.cron_timezone
      active               = v.active
      owner                = v.owner
    }
  }
}

output "pipeline_schedule_ids" {
  description = "Map of pipeline schedule names to their IDs"
  value       = { for k, v in gitlab_pipeline_schedule.this : k => v.pipeline_schedule_id }
}

output "pipeline_schedule_variables" {
  description = "Map of all pipeline schedule variables"
  value = {
    for k, v in gitlab_pipeline_schedule_variable.this : k => {
      id                   = v.id
      key                  = v.key
      value                = v.value
      pipeline_schedule_id = v.pipeline_schedule_id
      project              = v.project
    }
  }
  sensitive = true
}

# =============================================================================
# GITLAB RUNNERS OUTPUTS
# =============================================================================

output "gitlab_runners" {
  description = "Map of all GitLab runners with their configurations"
  value = {
    for k, v in gitlab_user_runner.this : k => {
      id              = v.id
      runner_id       = v.runner_id
      runner_type     = v.runner_type
      description     = v.description
      group_id        = v.group_id
      project_id      = v.project_id
      access_level    = v.access_level
      tag_list        = v.tag_list
      maximum_timeout = v.maximum_timeout
      paused          = v.paused
      untagged        = v.untagged
      locked          = v.locked
      status          = v.status
    }
  }
}

output "gitlab_runner_tokens" {
  description = "Map of runner authentication tokens"
  value       = { for k, v in gitlab_user_runner.this : k => v.token }
  sensitive   = true
}

output "gitlab_runners_by_type" {
  description = "Runners organized by type (group_type or project_type)"
  value = {
    group_runners = {
      for k, v in gitlab_user_runner.this : k => {
        runner_id   = v.runner_id
        group_id    = v.group_id
        description = v.description
        status      = v.status
      } if v.runner_type == "group_type"
    }
    project_runners = {
      for k, v in gitlab_user_runner.this : k => {
        runner_id   = v.runner_id
        project_id  = v.project_id
        description = v.description
        status      = v.status
      } if v.runner_type == "project_type"
    }
  }
}

# =============================================================================
# GROUP ACCESS TOKENS OUTPUTS
# =============================================================================

output "group_access_tokens" {
  description = "Map of all group access tokens with comprehensive details"
  value = {
    for k, v in gitlab_group_access_token.this : k => {
      id           = v.id
      group        = v.group
      name         = v.name
      token        = v.token
      expires_at   = v.expires_at
      access_level = v.access_level
      scopes       = v.scopes
    }
  }
  sensitive = true
}

output "group_access_tokens_by_group" {
  description = "Group access tokens organized by group ID"
  value = {
    for k, v in gitlab_group_access_token.this : v.group => {
      name         = v.name
      token        = v.token
      expires_at   = v.expires_at
      access_level = v.access_level
      scopes       = v.scopes
    }...
  }
  sensitive = true
}

output "group_access_tokens_summary" {
  description = "Summary of group access tokens (non-sensitive metadata)"
  value = {
    for k, v in gitlab_group_access_token.this : k => {
      group        = v.group
      name         = v.name
      expires_at   = v.expires_at
      access_level = v.access_level
      scopes       = v.scopes
    }
  }
}

# =============================================================================
# PROJECT ACCESS TOKENS OUTPUTS
# =============================================================================

output "project_access_tokens" {
  description = "Map of all project access tokens with comprehensive details"
  value = {
    for k, v in gitlab_project_access_token.this : k => {
      id           = v.id
      project      = v.project
      name         = v.name
      token        = v.token
      expires_at   = v.expires_at
      access_level = v.access_level
      scopes       = v.scopes
    }
  }
  sensitive = true
}

output "project_access_tokens_by_project" {
  description = "Project access tokens organized by project ID"
  value = {
    for k, v in gitlab_project_access_token.this : v.project => {
      name         = v.name
      token        = v.token
      expires_at   = v.expires_at
      access_level = v.access_level
      scopes       = v.scopes
    }...
  }
  sensitive = true
}

output "project_access_tokens_summary" {
  description = "Summary of project access tokens (non-sensitive metadata)"
  value = {
    for k, v in gitlab_project_access_token.this : k => {
      project      = v.project
      name         = v.name
      expires_at   = v.expires_at
      access_level = v.access_level
      scopes       = v.scopes
    }
  }
}

# =============================================================================
# HELPER/COMPUTED OUTPUTS
# =============================================================================

output "all_tokens" {
  description = "Consolidated map of all tokens (deploy, group access, project access)"
  value = {
    deploy_tokens = {
      for k, v in gitlab_deploy_token.this : k => {
        type  = "deploy_token"
        token = v.token
        scope = "group:${v.group}"
      }
    }
    group_access_tokens = {
      for k, v in gitlab_group_access_token.this : k => {
        type  = "group_access_token"
        token = v.token
        scope = "group:${v.group}"
      }
    }
    project_access_tokens = {
      for k, v in gitlab_project_access_token.this : k => {
        type  = "project_access_token"
        token = v.token
        scope = "project:${v.project}"
      }
    }
  }
  sensitive = true
}

output "resource_counts" {
  description = "Count of all created resources by type"
  value = {
    group_variables        = length(gitlab_group_variable.this)
    project_variables      = length(gitlab_project_variable.this)
    deploy_tokens          = length(gitlab_deploy_token.this)
    pipeline_schedules     = length(gitlab_pipeline_schedule.this)
    pipeline_schedule_vars = length(gitlab_pipeline_schedule_variable.this)
    gitlab_runners         = length(gitlab_user_runner.this)
    group_access_tokens    = length(gitlab_group_access_token.this)
    project_access_tokens  = length(gitlab_project_access_token.this)
  }
}
