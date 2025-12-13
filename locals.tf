locals {
  # Expand group_variables into map with multiple values
  group_variables = merge(values({
    for k, v in var.group_variables :
    k => {

      # Support "groups" (list of strings)
      for k_g in v.groups : format("%v_%v", k, k_g) =>

      # Replace "groups" with one "group" value
      merge({
        for k_gk, k_gv in v : k_gk => k_gv if k_gk != "groups"
        }, {
        //key   = k
        group = k_g
      })

    }
  })...)

  project_variables = merge(values({
    for k, v in var.project_variables :
    k => {

      # Support "projects" (list of strings)
      for k_g in v.projects : format("%v_%v", k, k_g) =>

      # Replace "projects" with one "project" value
      merge({
        for k_gk, k_gv in v : k_gk => k_gv if k_gk != "projects"
        }, {
        //key     = k
        project = k_g
      })

    }
  })...)

  deploy_tokens = merge(values({
    for k, v in var.deploy_tokens :
    k => {

      # Support "groups" (list of strings)
      for k_g in v.groups : format("%v_%v", k, k_g) =>

      # Replace "groups" with one "group" value
      merge({
        for k_gk, k_gv in v : k_gk => k_gv if k_gk != "groups"
        }, {
        key   = k
        group = k_g
      })

    }
  })...)

  group_access_tokens = merge(values({
    for k, v in var.gitlab_group_access_token :
    k => {

      # Support "groups" (list of strings)
      for k_g in v.groups : format("%v_%v", k, k_g) =>

      # Replace "groups" with one "group" value
      merge({
        for k_gk, k_gv in v : k_gk => k_gv if k_gk != "groups"
        }, {
        key   = k
        group = k_g
      })

    }
  })...)

  project_access_tokens = merge(values({
    for k, v in var.gitlab_project_access_token :
    k => {

      # Support "projects" (list of strings)
      for k_p in v.projects : format("%v_%v", k, k_p) =>

      # Replace "projects" with one "project" value
      merge({
        for k_pk, k_pv in v : k_pk => k_pv if k_pk != "projects"
        }, {
        key     = k
        project = k_p
      })

    }
  })...)

  pipeline_schedule_variables = merge([for k, v in var.pipeline_schedules : {
    for variable, val in v.variables :
    "${k}-${variable}" => {
      key               = variable
      value             = val
      pipeline_schedule = k
    }
  }]...)
}
