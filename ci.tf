# CI/CD objects: group and project variables, pipeline schedules and their
# variables, runners.

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
  for_each = var.pipeline_schedules

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
  for_each = var.gitlab_runners

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
}
