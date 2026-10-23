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

# -----------------------------------------------------------------------------
# Group and project tree
# -----------------------------------------------------------------------------

locals {
  # Arguments of every created group, keyed by its path relative to
  # parent_group_id; parent is "" for a group directly under it.
  group_args = {
    for k, v in var.groups : k => merge(v, {
      path   = element(split("/", k), length(split("/", k)) - 1)
      name   = coalesce(v.name, element(split("/", k), length(split("/", k)) - 1))
      level  = length(split("/", k))
      parent = join("/", slice(split("/", k), 0, length(split("/", k)) - 1))
      # The provider rejects both arguments together, even when one is false.
      archive_on_destroy           = v.archive_on_destroy ? true : null
      permanently_remove_on_delete = v.archive_on_destroy ? null : v.permanently_remove_on_delete
    })
  }

  # A group cannot depend on another instance of its own resource block, so
  # each depth has its own block in groups.tf.
  groups_by_level = { for n in range(1, 8) : n => { for k, v in local.group_args : k => v if v.level == n } }

  # Only the attributes the module reads: whole objects would carry the
  # provider's deprecated default_branch_protection into every reference.
  created_groups = merge([
    for level in [
      gitlab_group.level_1, gitlab_group.level_2, gitlab_group.level_3, gitlab_group.level_4,
      gitlab_group.level_5, gitlab_group.level_6, gitlab_group.level_7,
      ] : {
      for k, g in level : k => { id = g.id, full_path = g.full_path, web_url = g.web_url }
    }
  ]...)
}

locals {
  group_ids = { for k, g in local.created_groups : k => g.id }

  # Arguments of every created project; namespace is "" for a project directly
  # under parent_group_id.
  project_args = {
    for k, v in var.projects : k => merge(v, {
      path      = element(split("/", k), length(split("/", k)) - 1)
      name      = coalesce(v.name, element(split("/", k), length(split("/", k)) - 1))
      namespace = join("/", slice(split("/", k), 0, length(split("/", k)) - 1))
      # The provider rejects both arguments together, even when one is false.
      archive_on_destroy            = v.archive_on_destroy ? true : null
      permanently_delete_on_destroy = v.archive_on_destroy ? null : v.permanently_delete_on_destroy
    })
  }

  project_branches = merge([
    for pk, v in var.projects : {
      for name, b in v.branches : "${pk}:${name}" => {
        project = pk
        name    = name
        ref     = coalesce(b.ref, v.default_branch)
      }
    }
  ]...)

  # Without protected_branches: the default branch for maintainers, plus
  # develop for developers when it is created (gitlab-project-settings).
  project_protected_branches = merge([
    for pk, v in var.projects : {
      for name, b in(v.protected_branches != null ? v.protected_branches : merge(
        { (v.default_branch) = { push_access_level = "maintainer", merge_access_level = "maintainer", allow_force_push = false } },
        contains(keys(v.branches), "develop") ? { develop = { push_access_level = "developer", merge_access_level = "developer", allow_force_push = false } } : {},
      )) : "${pk}:${name}" => merge(b, { project = pk, branch = name })
    }
  ]...)

  project_protected_tags = merge([
    for pk, v in var.projects : {
      for tag, t in v.protected_tags : "${pk}:${tag}" => merge(t, { project = pk, tag = tag })
    }
  ]...)
}
