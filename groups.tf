# Group tree under parent_group_id: one resource block per depth, because a
# group cannot take another instance of its own block as parent. Every block
# reads the same arguments from local.group_args; only parent_id differs.

resource "gitlab_group" "level_1" {
  for_each = local.groups_by_level[1]

  name                              = each.value.name
  path                              = each.value.path
  parent_id                         = var.parent_group_id
  description                       = each.value.description
  visibility_level                  = each.value.visibility
  default_branch                    = each.value.default_branch
  project_creation_level            = each.value.project_creation_level
  subgroup_creation_level           = each.value.subgroup_creation_level
  request_access_enabled            = each.value.request_access_enabled
  require_two_factor_authentication = each.value.require_two_factor_authentication
  archive_on_destroy                = each.value.archive_on_destroy
  permanently_remove_on_delete      = each.value.permanently_remove_on_delete

  # Projects created later in the group start with main protected for
  # maintainers (gitlab-project-settings).
  default_branch_protection_defaults {
    allowed_to_push            = ["maintainer"]
    allowed_to_merge           = ["maintainer"]
    allow_force_push           = false
    developer_can_initial_push = false
  }
}

resource "gitlab_group" "level_2" {
  for_each = local.groups_by_level[2]

  name                              = each.value.name
  path                              = each.value.path
  parent_id                         = tonumber(gitlab_group.level_1[each.value.parent].id)
  description                       = each.value.description
  visibility_level                  = each.value.visibility
  default_branch                    = each.value.default_branch
  project_creation_level            = each.value.project_creation_level
  subgroup_creation_level           = each.value.subgroup_creation_level
  request_access_enabled            = each.value.request_access_enabled
  require_two_factor_authentication = each.value.require_two_factor_authentication
  archive_on_destroy                = each.value.archive_on_destroy
  permanently_remove_on_delete      = each.value.permanently_remove_on_delete

  # Projects created later in the group start with main protected for
  # maintainers (gitlab-project-settings).
  default_branch_protection_defaults {
    allowed_to_push            = ["maintainer"]
    allowed_to_merge           = ["maintainer"]
    allow_force_push           = false
    developer_can_initial_push = false
  }
}

resource "gitlab_group" "level_3" {
  for_each = local.groups_by_level[3]

  name                              = each.value.name
  path                              = each.value.path
  parent_id                         = tonumber(gitlab_group.level_2[each.value.parent].id)
  description                       = each.value.description
  visibility_level                  = each.value.visibility
  default_branch                    = each.value.default_branch
  project_creation_level            = each.value.project_creation_level
  subgroup_creation_level           = each.value.subgroup_creation_level
  request_access_enabled            = each.value.request_access_enabled
  require_two_factor_authentication = each.value.require_two_factor_authentication
  archive_on_destroy                = each.value.archive_on_destroy
  permanently_remove_on_delete      = each.value.permanently_remove_on_delete

  # Projects created later in the group start with main protected for
  # maintainers (gitlab-project-settings).
  default_branch_protection_defaults {
    allowed_to_push            = ["maintainer"]
    allowed_to_merge           = ["maintainer"]
    allow_force_push           = false
    developer_can_initial_push = false
  }
}

resource "gitlab_group" "level_4" {
  for_each = local.groups_by_level[4]

  name                              = each.value.name
  path                              = each.value.path
  parent_id                         = tonumber(gitlab_group.level_3[each.value.parent].id)
  description                       = each.value.description
  visibility_level                  = each.value.visibility
  default_branch                    = each.value.default_branch
  project_creation_level            = each.value.project_creation_level
  subgroup_creation_level           = each.value.subgroup_creation_level
  request_access_enabled            = each.value.request_access_enabled
  require_two_factor_authentication = each.value.require_two_factor_authentication
  archive_on_destroy                = each.value.archive_on_destroy
  permanently_remove_on_delete      = each.value.permanently_remove_on_delete

  # Projects created later in the group start with main protected for
  # maintainers (gitlab-project-settings).
  default_branch_protection_defaults {
    allowed_to_push            = ["maintainer"]
    allowed_to_merge           = ["maintainer"]
    allow_force_push           = false
    developer_can_initial_push = false
  }
}

resource "gitlab_group" "level_5" {
  for_each = local.groups_by_level[5]

  name                              = each.value.name
  path                              = each.value.path
  parent_id                         = tonumber(gitlab_group.level_4[each.value.parent].id)
  description                       = each.value.description
  visibility_level                  = each.value.visibility
  default_branch                    = each.value.default_branch
  project_creation_level            = each.value.project_creation_level
  subgroup_creation_level           = each.value.subgroup_creation_level
  request_access_enabled            = each.value.request_access_enabled
  require_two_factor_authentication = each.value.require_two_factor_authentication
  archive_on_destroy                = each.value.archive_on_destroy
  permanently_remove_on_delete      = each.value.permanently_remove_on_delete

  # Projects created later in the group start with main protected for
  # maintainers (gitlab-project-settings).
  default_branch_protection_defaults {
    allowed_to_push            = ["maintainer"]
    allowed_to_merge           = ["maintainer"]
    allow_force_push           = false
    developer_can_initial_push = false
  }
}

resource "gitlab_group" "level_6" {
  for_each = local.groups_by_level[6]

  name                              = each.value.name
  path                              = each.value.path
  parent_id                         = tonumber(gitlab_group.level_5[each.value.parent].id)
  description                       = each.value.description
  visibility_level                  = each.value.visibility
  default_branch                    = each.value.default_branch
  project_creation_level            = each.value.project_creation_level
  subgroup_creation_level           = each.value.subgroup_creation_level
  request_access_enabled            = each.value.request_access_enabled
  require_two_factor_authentication = each.value.require_two_factor_authentication
  archive_on_destroy                = each.value.archive_on_destroy
  permanently_remove_on_delete      = each.value.permanently_remove_on_delete

  # Projects created later in the group start with main protected for
  # maintainers (gitlab-project-settings).
  default_branch_protection_defaults {
    allowed_to_push            = ["maintainer"]
    allowed_to_merge           = ["maintainer"]
    allow_force_push           = false
    developer_can_initial_push = false
  }
}

resource "gitlab_group" "level_7" {
  for_each = local.groups_by_level[7]

  name                              = each.value.name
  path                              = each.value.path
  parent_id                         = tonumber(gitlab_group.level_6[each.value.parent].id)
  description                       = each.value.description
  visibility_level                  = each.value.visibility
  default_branch                    = each.value.default_branch
  project_creation_level            = each.value.project_creation_level
  subgroup_creation_level           = each.value.subgroup_creation_level
  request_access_enabled            = each.value.request_access_enabled
  require_two_factor_authentication = each.value.require_two_factor_authentication
  archive_on_destroy                = each.value.archive_on_destroy
  permanently_remove_on_delete      = each.value.permanently_remove_on_delete

  # Projects created later in the group start with main protected for
  # maintainers (gitlab-project-settings).
  default_branch_protection_defaults {
    allowed_to_push            = ["maintainer"]
    allowed_to_merge           = ["maintainer"]
    allow_force_push           = false
    developer_can_initial_push = false
  }
}
