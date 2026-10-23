# Outputs follow the resource order of main.tf. Tokens are sensitive and land
# in state (SECURITY.md); no output returns a CI variable value, which the
# caller already holds.
# DEVIATION(terraform-outputs): the kept outputs keep their v12 names
# (group_access_tokens, pipeline_schedule_ids, ...) rather than the plural of
# their input, to avoid renaming outputs that consumers read; input renames are
# out of scope of this release.

output "groups" {
  description = "Created groups keyed like the groups input (path relative to parent_group_id): id, full_path and web_url"
  value       = local.created_groups
}

output "projects" {
  description = "Created projects keyed like the projects input (path relative to parent_group_id): id, path_with_namespace, web_url, http_url_to_repo, ssh_url_to_repo and default_branch"
  value = {
    for k, p in gitlab_project.this : k => {
      id                  = p.id
      path_with_namespace = p.path_with_namespace
      web_url             = p.web_url
      http_url_to_repo    = p.http_url_to_repo
      ssh_url_to_repo     = p.ssh_url_to_repo
      default_branch      = p.default_branch
    }
  }
}

output "group_variables_ids" {
  description = "IDs of the group CI/CD variables, in the form <group>:<key>:<environment_scope>"
  value       = [for k, v in gitlab_group_variable.this : v.id]
}

output "project_variables_ids" {
  description = "IDs of the project CI/CD variables, in the form <project>:<key>:<environment_scope>"
  value       = [for k, v in gitlab_project_variable.this : v.id]
}

output "deploy_tokens" {
  description = "Group deploy tokens keyed \"<entry>_<group>\": id, group, name, username, token, expires_at and scopes. Sensitive; username and token log in to the group's repositories and registries."
  value = {
    for k, v in gitlab_group_deploy_token.this : k => {
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

output "pipeline_schedule_ids" {
  description = "GitLab pipeline schedule IDs keyed like the pipeline_schedules input"
  value       = { for k, v in gitlab_pipeline_schedule.this : k => v.pipeline_schedule_id }
}

output "gitlab_runners" {
  description = "Runners keyed like the gitlab_runners input: id (the GitLab runner ID), runner_type, description, group_id, project_id, access_level, tag_list, maximum_timeout, paused, untagged and locked"
  value = {
    for k, v in gitlab_user_runner.this : k => {
      id              = v.id
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
    }
  }
}

output "gitlab_runner_tokens" {
  description = "Runner authentication tokens (glrt-...) keyed like the gitlab_runners input, for registering the runner manager. Sensitive."
  value       = { for k, v in gitlab_user_runner.this : k => v.token }
  sensitive   = true
}

output "group_access_tokens" {
  description = "Group access tokens keyed \"<entry>_<group>\": id, group, name, token, expires_at, access_level and scopes. Sensitive."
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

output "project_access_tokens" {
  description = "Project access tokens keyed \"<entry>_<project>\": id, project, name, token, expires_at, access_level and scopes. Sensitive."
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
