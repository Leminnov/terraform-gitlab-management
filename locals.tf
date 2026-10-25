locals {
  # Expand each group_variables entry across its list of groups, producing
  # one map entry per (variable, group) pair keyed "<var>_<group>"; the
  # variables of created groups follow, keyed "<group key>:<variable key>".
  # Standalone keys never contain ":", so the two key spaces cannot collide.
  group_variables = merge(concat([
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
    ], [
    for gk, g in var.groups : {
      for key, v in g.variables : "${gk}:${key}" => merge(v, { key = key, group = local.group_ids[gk] })
    }
  ])...)

  project_variables = merge(concat([
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
    ], [
    for pk, pr in var.projects : {
      for key, v in pr.variables : "${pk}:${key}" => merge(v, { key = key, project = local.project_ids[pk] })
    }
  ])...)

  deploy_tokens = merge(concat([
    for k, v in var.deploy_tokens : {
      for g in v.groups : "${k}_${g}" => {
        group      = g
        name       = v.name
        username   = v.username
        expires_at = v.expires_at
        scopes     = v.scopes
      }
    }
    ], [
    for gk, g in var.groups : {
      for name, t in g.deploy_tokens : "${gk}:${name}" => merge(t, { group = local.group_ids[gk], name = name })
    }
  ])...)

  group_access_tokens = merge(concat([
    for k, v in var.gitlab_group_access_token : {
      for g in v.groups : "${k}_${g}" => {
        group        = g
        name         = v.name
        expires_at   = v.expires_at
        access_level = v.access_level
        scopes       = v.scopes
        # Rotated tokens get their expiry from GitLab.
        rotation_configuration = v.rotation_configuration
      }
    }
    ], [
    for gk, g in var.groups : {
      for name, t in g.access_tokens : "${gk}:${name}" => merge(t, { group = local.group_ids[gk], name = name })
    }
  ])...)

  project_access_tokens = merge(concat([
    for k, v in var.gitlab_project_access_token : {
      for p in v.projects : "${k}_${p}" => {
        project      = p
        name         = v.name
        expires_at   = v.expires_at
        access_level = v.access_level
        scopes       = v.scopes
        # Rotated tokens get their expiry from GitLab.
        rotation_configuration = v.rotation_configuration
      }
    }
    ], [
    for pk, pr in var.projects : {
      for name, t in pr.access_tokens : "${pk}:${name}" => merge(t, { project = local.project_ids[pk], name = name })
    }
  ])...)

  # Standalone schedules keep their keys; those of created projects are keyed
  # "<project key>:<description>" and default to the project's default branch.
  pipeline_schedules = merge(var.pipeline_schedules, merge([
    for pk, pr in var.projects : {
      for desc, sc in pr.pipeline_schedules : "${pk}:${desc}" => {
        project     = local.project_ids[pk]
        description = desc
        ref         = coalesce(sc.ref, "refs/heads/${pr.default_branch}")
        cron        = sc.cron
        active      = sc.active
        variables   = sc.variables
      }
    }
  ]...))

  pipeline_schedule_variables = merge([
    for k, v in local.pipeline_schedules : {
      for variable, val in v.variables :
      "${k}-${variable}" => {
        key               = variable
        value             = val
        pipeline_schedule = k
      }
    }
  ]...)

  # Standalone runners keep their keys; those of created groups and projects
  # are keyed "<owner key>:<name>".
  runners = merge(var.gitlab_runners, merge(concat([
    for gk, g in var.groups : {
      for name, r in g.runners : "${gk}:${name}" => merge(r, {
        runner_type = "group_type"
        description = coalesce(r.description, name)
        group_id    = tonumber(local.group_ids[gk])
        project_id  = null
      })
    }
    ], [
    for pk, pr in var.projects : {
      for name, r in pr.runners : "${pk}:${name}" => merge(r, {
        runner_type = "project_type"
        description = coalesce(r.description, name)
        group_id    = null
        project_id  = tonumber(local.project_ids[pk])
      })
    }
  ])...))
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
      # Each security setting: the explicit value, else the hardened one when
      # hardening is on, else null (nothing sent, GitLab's value kept).
      ci = merge(v.ci, {
        public_jobs                              = v.ci.public_jobs != null ? v.ci.public_jobs : (v.ci.hardening_enabled ? false : null)
        pipeline_variables_minimum_override_role = v.ci.pipeline_variables_minimum_override_role != null ? v.ci.pipeline_variables_minimum_override_role : (v.ci.hardening_enabled ? "no_one_allowed" : null)
        protect_merge_request_pipelines          = v.ci.protect_merge_request_pipelines != null ? v.ci.protect_merge_request_pipelines : (v.ci.hardening_enabled ? true : null)
        separated_caches                         = v.ci.separated_caches != null ? v.ci.separated_caches : (v.ci.hardening_enabled ? true : null)
        forward_deployment_enabled               = v.ci.forward_deployment_enabled != null ? v.ci.forward_deployment_enabled : (v.ci.hardening_enabled ? true : null)
        push_repository_for_job_token_allowed    = v.ci.push_repository_for_job_token_allowed != null ? v.ci.push_repository_for_job_token_allowed : (v.ci.hardening_enabled ? false : null)
        allow_merge_on_skipped_pipeline          = v.ci.allow_merge_on_skipped_pipeline != null ? v.ci.allow_merge_on_skipped_pipeline : (v.ci.hardening_enabled ? false : null)
      })
    })
  }

  project_ids = { for k, p in gitlab_project.this : k => p.id }

  project_deploy_tokens = merge([
    for pk, pr in var.projects : {
      for name, t in pr.deploy_tokens : "${pk}:${name}" => merge(t, { project = local.project_ids[pk], name = name })
    }
  ]...)

  deploy_keys = merge([
    for pk, pr in var.projects : {
      for title, d in pr.deploy_keys : "${pk}:${title}" => merge(d, { project = local.project_ids[pk], project_key = pk, title = title })
    }
  ]...)

  # Service accounts: standalone ones in an existing group keyed "<name>",
  # those of created groups and projects keyed "<owner key>:<name>".
  group_service_accounts = merge(
    { for k, sa in var.service_accounts : k => { group = sa.group, name = coalesce(sa.name, k), username = sa.username, email = sa.email } },
    merge([
      for gk, g in var.groups : {
        for n, sa in g.service_accounts : "${gk}:${n}" => { group = local.group_ids[gk], name = coalesce(sa.name, n), username = sa.username, email = sa.email }
      }
    ]...),
  )

  project_service_accounts = merge([
    for pk, pr in var.projects : {
      for n, sa in pr.service_accounts : "${pk}:${n}" => { project = local.project_ids[pk], name = coalesce(sa.name, n), username = sa.username, email = sa.email }
    }
  ]...)

  # Tokens keyed "<service account key>:<token name>".
  group_service_account_tokens = merge(concat(
    [for k, sa in var.service_accounts : { for t, tok in sa.tokens : "${k}:${t}" => merge(tok, { account = k, name = t }) }],
    flatten([
      for gk, g in var.groups : [
        for n, sa in g.service_accounts : { for t, tok in sa.tokens : "${gk}:${n}:${t}" => merge(tok, { account = "${gk}:${n}", name = t }) }
      ]
    ]),
  )...)

  project_service_account_tokens = merge(flatten([
    for pk, pr in var.projects : [
      for n, sa in pr.service_accounts : { for t, tok in sa.tokens : "${pk}:${n}:${t}" => merge(tok, { account = "${pk}:${n}", name = t }) }
    ]
  ])...)

  service_account_user_ids = merge(
    { for k, sa in gitlab_group_service_account.this : k => tonumber(sa.service_account_id) },
    { for k, sa in gitlab_project_service_account.this : k => tonumber(sa.service_account_id) },
  )

  # A member is a user ID or a service account managed here (validated in
  # variables.tf against GitLab's invitation scope).
  group_memberships = merge([
    for gk, g in var.groups : {
      for name, m in g.members : "${gk}:${name}" => merge(m, {
        group_id = tonumber(local.group_ids[gk])
        user_id  = m.service_account == null ? m.user_id : local.service_account_user_ids[m.service_account]
      })
    }
  ]...)

  project_memberships = merge([
    for pk, pr in var.projects : {
      for name, m in pr.members : "${pk}:${name}" => merge(m, {
        project = local.project_ids[pk]
        user_id = m.service_account == null ? m.user_id : local.service_account_user_ids[m.service_account]
      })
    }
  ]...)

  group_shares = merge([
    for gk, g in var.groups : {
      for name, sh in g.shared_with : "${gk}:${name}" => merge(sh, {
        group_id       = local.group_ids[gk]
        share_group_id = sh.group != null ? tonumber(local.group_ids[sh.group]) : sh.group_id
      })
    }
  ]...)

  project_shares = merge([
    for pk, pr in var.projects : {
      for name, sh in pr.shared_with : "${pk}:${name}" => merge(sh, {
        project  = local.project_ids[pk]
        group_id = sh.group != null ? tonumber(local.group_ids[sh.group]) : sh.group_id
      })
    }
  ]...)

  project_freeze_periods = merge([
    for pk, pr in var.projects : {
      for label, f in pr.freeze_periods : "${pk}:${label}" => merge(f, { project = local.project_ids[pk] })
    }
  ]...)

  project_secure_files = merge([
    for pk, pr in var.projects : {
      for name, content in pr.secure_files : "${pk}:${name}" => { project = local.project_ids[pk], name = name, content = content }
    }
  ]...)

  project_environments = merge([
    for pk, pr in var.projects : {
      for name, e in pr.environments : "${pk}:${name}" => merge(e, { project = local.project_ids[pk], name = name })
    }
  ]...)

  pipeline_triggers = merge([
    for pk, pr in var.projects : {
      for desc in pr.pipeline_triggers : "${pk}:${desc}" => { project = local.project_ids[pk], description = desc }
    }
  ]...)

  # The provider leaves the project itself out of the allowlist it reads back
  # (GitLab always allows it), so it is never sent.
  job_token_allowlists = {
    for pk, pr in var.projects : pk => {
      project            = local.project_ids[pk]
      target_project_ids = setunion([for p in pr.job_token_allowlist.projects : tonumber(local.project_ids[p]) if p != pk], pr.job_token_allowlist.project_ids)
      target_group_ids   = setunion([for g in pr.job_token_allowlist.groups : tonumber(local.group_ids[g])], pr.job_token_allowlist.group_ids)
    } if pr.job_token_allowlist != null
  }

  group_labels = merge([
    for gk, g in var.groups : {
      for name, l in g.labels : "${gk}:${name}" => merge(l, { group = local.group_ids[gk], name = name })
    }
  ]...)

  project_labels = merge([
    for pk, pr in var.projects : {
      for name, l in pr.labels : "${pk}:${name}" => merge(l, { project = local.project_ids[pk], name = name })
    }
  ]...)

  group_badges = merge([
    for gk, g in var.groups : {
      for name, b in g.badges : "${gk}:${name}" => merge(b, { group = local.group_ids[gk], name = name })
    }
  ]...)

  project_badges = merge([
    for pk, pr in var.projects : {
      for name, b in pr.badges : "${pk}:${name}" => merge(b, { project = local.project_ids[pk], name = name })
    }
  ]...)

  project_hooks = merge([
    for pk, pr in var.projects : {
      for name, h in pr.hooks : "${pk}:${name}" => merge(h, { project = local.project_ids[pk], project_key = pk, name = name })
    }
  ]...)

  # Premium objects: empty unless the caller sets them.
  group_hooks = merge([
    for gk, g in var.groups : {
      for name, h in g.hooks : "${gk}:${name}" => merge(h, { group = local.group_ids[gk], group_key = gk, name = name })
    }
  ]...)

  project_approval_rules = merge([
    for pk, pr in var.projects : {
      for name, r in pr.approval_rules : "${pk}:${name}" => merge(r, { project = local.project_ids[pk], name = name })
    }
  ]...)

  project_mr_approvals = { for pk, pr in var.projects : pk => merge(pr.merge_request_approvals, { project = local.project_ids[pk] }) if pr.merge_request_approvals != null }
  project_push_rules   = { for pk, pr in var.projects : pk => merge(pr.push_rules, { project = local.project_ids[pk] }) if pr.push_rules != null }

  project_protected_environments = merge([
    for pk, pr in var.projects : {
      for name, e in pr.protected_environments : "${pk}:${name}" => merge(e, { project = local.project_ids[pk], environment = "${pk}:${name}" })
    }
  ]...)

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
        { (v.default_branch) = { push_access_level = "maintainer", merge_access_level = "maintainer", allow_force_push = false, code_owner_approval_required = null } },
        contains(keys(v.branches), "develop") ? { develop = { push_access_level = "developer", merge_access_level = "developer", allow_force_push = false, code_owner_approval_required = null } } : {},
      )) : "${pk}:${name}" => merge(b, { project = pk, branch = name })
    }
  ]...)

  project_protected_tags = merge([
    for pk, v in var.projects : {
      for tag, t in v.protected_tags : "${pk}:${tag}" => merge(t, { project = pk, tag = tag })
    }
  ]...)
}
