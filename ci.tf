# CI/CD objects: group and project variables, pipeline schedules and their
# variables, runners, and the environments, pipeline triggers, job token
# allowlists, freeze periods, secure files and CI/CD catalog flag of created
# projects.

# DEVIATION(terraform-variables): the value input cannot be sensitive = true
# because for_each iterates it, and the provider has no value_wo; sensitive()
# keeps the value out of plan output. It still lands in state (SECURITY.md).
resource "gitlab_group_variable" "this" {
  for_each = local.group_variables

  key           = each.value.key
  group         = each.value.group
  value         = sensitive(each.value.value)
  variable_type = each.value.variable_type
  protected     = each.value.protected
  masked        = each.value.masked
}

# DEVIATION(terraform-variables): the value input cannot be sensitive = true
# because for_each iterates it, and the provider has no value_wo; sensitive()
# keeps the value out of plan output. It still lands in state (SECURITY.md).
resource "gitlab_project_variable" "this" {
  for_each = local.project_variables

  key           = each.value.key
  project       = each.value.project
  value         = sensitive(each.value.value)
  variable_type = each.value.variable_type
  protected     = each.value.protected
  masked        = each.value.masked
}

resource "gitlab_pipeline_schedule" "this" {
  for_each = local.pipeline_schedules

  project     = each.value.project
  description = each.value.description
  ref         = each.value.ref
  cron        = each.value.cron
  active      = each.value.active
}

# DEVIATION(terraform-variables): the value input cannot be sensitive = true
# because for_each iterates it, and the provider has no value_wo; sensitive()
# keeps the value out of plan output. It still lands in state (SECURITY.md).
resource "gitlab_pipeline_schedule_variable" "this" {
  for_each = local.pipeline_schedule_variables

  project              = gitlab_pipeline_schedule.this[each.value.pipeline_schedule].project
  pipeline_schedule_id = gitlab_pipeline_schedule.this[each.value.pipeline_schedule].pipeline_schedule_id
  key                  = each.value.key
  value                = sensitive(each.value.value)
}

resource "gitlab_user_runner" "this" {
  for_each = local.runners

  runner_type     = each.value.runner_type
  description     = each.value.description
  group_id        = each.value.group_id
  project_id      = each.value.project_id
  access_level    = each.value.access_level
  tag_list        = each.value.tag_list
  maximum_timeout = each.value.maximum_timeout
  paused          = each.value.paused
  untagged        = each.value.untagged
  locked          = each.value.locked

  # DEVIATION(terraform-code-style): ignore_changes on an attribute the module
  # owns. Provider 19.5 reads project_id back as the first project gitlab.com
  # lists for the runner, which after gitlab_project_runner_enablement can be
  # another project, and project_id forces replacement. A nested runner's
  # project is part of its key, so project_id never legitimately changes; to
  # move a standalone runner, change its key or apply -replace.
  lifecycle {
    ignore_changes = [project_id]
  }
}

resource "gitlab_project_environment" "this" {
  for_each = local.project_environments

  project      = each.value.project
  name         = each.value.name
  tier         = each.value.tier
  external_url = each.value.external_url
  description  = each.value.description
  # GitLab deletes only stopped environments; without this, destroy fails.
  stop_before_destroy = true
}

resource "gitlab_pipeline_trigger" "this" {
  for_each = local.pipeline_triggers

  project     = each.value.project
  description = each.value.description
}

resource "gitlab_project_job_token_scopes" "this" {
  for_each = local.job_token_allowlists

  project            = each.value.project
  enabled            = true
  target_project_ids = each.value.target_project_ids
  target_group_ids   = each.value.target_group_ids
}

resource "gitlab_project_freeze_period" "this" {
  for_each = local.project_freeze_periods

  project       = each.value.project
  freeze_start  = each.value.freeze_start
  freeze_end    = each.value.freeze_end
  cron_timezone = each.value.cron_timezone
}

# DEVIATION(terraform-variables): secure file contents cannot come from a
# sensitive = true input because for_each iterates it, and the provider has no
# write-only argument; sensitive() keeps them out of plan output. They still
# land in state (SECURITY.md).
resource "gitlab_project_secure_file" "this" {
  for_each = local.project_secure_files

  project = each.value.project
  name    = each.value.name
  content = sensitive(each.value.content)
}

resource "gitlab_project_cicd_catalog" "this" {
  for_each = { for pk, pr in var.projects : pk => local.project_ids[pk] if pr.cicd_catalog }

  project = each.value
  enabled = true
}

resource "gitlab_project_runner_enablement" "this" {
  for_each = local.project_runner_enablements

  project   = each.value.project
  runner_id = each.value.runner_id
}

resource "gitlab_cluster_agent" "this" {
  for_each = local.kubernetes_agents

  project = each.value.project
  name    = each.value.name
}

resource "gitlab_cluster_agent_token" "this" {
  for_each = local.kubernetes_agents

  project  = each.value.project
  agent_id = gitlab_cluster_agent.this[each.key].agent_id
  name     = each.value.name
}
