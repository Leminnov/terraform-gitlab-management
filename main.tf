resource "gitlab_group_variable" "this" {
  for_each = local.group_variables

  key           = each.value.key
  group         = each.value.group
  value         = each.value.value
  variable_type = each.value.variable_type
  protected     = each.value.protected
  masked        = each.value.masked
}

resource "gitlab_project_variable" "this" {
  for_each = local.project_variables

  key           = each.value.key
  project       = each.value.project
  value         = each.value.value
  protected     = each.value.protected
  variable_type = each.value.variable_type
  masked        = each.value.masked
}

resource "gitlab_deploy_token" "this" {
  for_each = local.deploy_tokens

  group      = try(each.value.group, null)
  name       = each.value.name
  username   = try(each.value.username, null)
  expires_at = try(each.value.expires_at, null)

  scopes = each.value.scopes
}

resource "gitlab_pipeline_schedule" "this" {
  for_each = var.pipeline_schedules

  project     = each.value.project
  description = each.value.description
  ref         = each.value.ref
  cron        = each.value.cron
  active      = each.value.active
}

resource "gitlab_pipeline_schedule_variable" "this" {
  for_each = local.pipeline_schedule_variables

  project              = gitlab_pipeline_schedule.this[each.value.pipeline_schedule].project
  pipeline_schedule_id = gitlab_pipeline_schedule.this[each.value.pipeline_schedule].pipeline_schedule_id
  key                  = each.value.key
  value                = each.value.value
  depends_on           = [gitlab_pipeline_schedule.this]
}

resource "gitlab_user_runner" "this" {
  for_each = var.gitlab_runners

  runner_type     = each.value.runner_type
  description     = each.value.description
  group_id        = try(each.value.group_id, null)
  project_id      = try(each.value.project_id, null)
  access_level    = each.value.access_level
  tag_list        = each.value.tag_list
  maximum_timeout = try(each.value.maximum_timeout, null)
  paused          = each.value.paused
  untagged        = each.value.untagged
  locked          = each.value.locked
}

resource "gitlab_group_access_token" "this" {
  for_each = local.group_access_tokens

  group        = each.value.group
  name         = each.value.name
  expires_at   = each.value.expires_at
  access_level = try(each.value.access_level, null)

  scopes = each.value.scopes
}

resource "gitlab_project_access_token" "this" {
  for_each = local.project_access_tokens

  project      = each.value.project
  name         = each.value.name
  expires_at   = each.value.expires_at
  access_level = try(each.value.access_level, null)

  scopes = each.value.scopes
}
