# Service accounts (GitLab 18+, Free tier included): in an existing group,
# top-level or intermediate, in a created subgroup or in a created project,
# with their personal access tokens. They reach nothing until granted through
# members[*].service_account.

resource "gitlab_group_service_account" "this" {
  for_each = local.group_service_accounts

  group    = each.value.group
  name     = each.value.name
  username = each.value.username
  email    = each.value.email
  # gitlab.com deletes users asynchronously: waiting would hold destroy until
  # the timeout.
  skip_wait_for_deletion = true
}

resource "gitlab_project_service_account" "this" {
  for_each = local.project_service_accounts

  project                = each.value.project
  name                   = each.value.name
  username               = each.value.username
  email                  = each.value.email
  skip_wait_for_deletion = true
}

# Provider 19.5 crashes validating a service account token whose
# rotation_configuration is unknown, as every for_each value is under
# `tofu validate`: dated and rotating tokens therefore live in separate
# blocks, the rotating ones built from a literal whose fields may be unknown.
resource "gitlab_group_service_account_access_token" "this" {
  for_each = { for k, t in local.group_service_account_tokens : k => t if t.rotation_configuration == null }

  group      = gitlab_group_service_account.this[each.value.account].group
  user_id    = tonumber(gitlab_group_service_account.this[each.value.account].service_account_id)
  name       = each.value.name
  scopes     = each.value.scopes
  expires_at = each.value.expires_at
}

resource "gitlab_group_service_account_access_token" "rotating" {
  for_each = { for k, t in local.group_service_account_tokens : k => t if t.rotation_configuration != null }

  group   = gitlab_group_service_account.this[each.value.account].group
  user_id = tonumber(gitlab_group_service_account.this[each.value.account].service_account_id)
  name    = each.value.name
  scopes  = each.value.scopes
  rotation_configuration = {
    expiration_days    = each.value.rotation_configuration.expiration_days
    rotate_before_days = each.value.rotation_configuration.rotate_before_days
  }
}

resource "gitlab_project_service_account_access_token" "this" {
  for_each = { for k, t in local.project_service_account_tokens : k => t if t.rotation_configuration == null }

  project    = gitlab_project_service_account.this[each.value.account].project
  user_id    = tonumber(gitlab_project_service_account.this[each.value.account].service_account_id)
  name       = each.value.name
  scopes     = each.value.scopes
  expires_at = each.value.expires_at
}

resource "gitlab_project_service_account_access_token" "rotating" {
  for_each = { for k, t in local.project_service_account_tokens : k => t if t.rotation_configuration != null }

  project = gitlab_project_service_account.this[each.value.account].project
  user_id = tonumber(gitlab_project_service_account.this[each.value.account].service_account_id)
  name    = each.value.name
  scopes  = each.value.scopes
  rotation_configuration = {
    expiration_days    = each.value.rotation_configuration.expiration_days
    rotate_before_days = each.value.rotation_configuration.rotate_before_days
  }
}
