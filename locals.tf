locals {
  # Expand each group_variables entry across its list of groups, producing
  # one map entry per (variable, group) pair keyed "<var>_<group>".
  group_variables = merge([
    for k, v in var.group_variables : {
      for g in v.groups : "${k}_${g}" => {
        key           = v.key
        group         = g
        value         = v.value
        variable_type = v.variable_type
        protected     = v.protected
        masked        = v.masked
      }
    }
  ]...)

  project_variables = merge([
    for k, v in var.project_variables : {
      for p in v.projects : "${k}_${p}" => {
        key           = v.key
        project       = p
        value         = v.value
        variable_type = v.variable_type
        protected     = v.protected
        masked        = v.masked
      }
    }
  ]...)

  deploy_tokens = merge([
    for k, v in var.deploy_tokens : {
      for g in v.groups : "${k}_${g}" => {
        group      = g
        name       = v.name
        username   = v.username
        expires_at = v.expires_at
        scopes     = v.scopes
      }
    }
  ]...)

  group_access_tokens = merge([
    for k, v in var.gitlab_group_access_token : {
      for g in v.groups : "${k}_${g}" => {
        group        = g
        name         = v.name
        expires_at   = v.expires_at
        access_level = v.access_level
        scopes       = v.scopes
      }
    }
  ]...)

  project_access_tokens = merge([
    for k, v in var.gitlab_project_access_token : {
      for p in v.projects : "${k}_${p}" => {
        project      = p
        name         = v.name
        expires_at   = v.expires_at
        access_level = v.access_level
        scopes       = v.scopes
      }
    }
  ]...)

  pipeline_schedule_variables = merge([
    for k, v in var.pipeline_schedules : {
      for variable, val in v.variables :
      "${k}-${variable}" => {
        key               = variable
        value             = val
        pipeline_schedule = k
      }
    }
  ]...)
}
