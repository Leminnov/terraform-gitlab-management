# Credentials and access: deploy tokens, deploy keys, access tokens, user
# memberships and group shares.

# gitlab_deploy_token was removed in provider 19.0; since 19.1 the provider
# moves its state to gitlab_group_deploy_token, so existing tokens are kept.
moved {
  from = gitlab_deploy_token.this
  to   = gitlab_group_deploy_token.this
}

resource "gitlab_group_deploy_token" "this" {
  for_each = local.deploy_tokens

  group      = each.value.group
  name       = each.value.name
  username   = each.value.username
  expires_at = each.value.expires_at
  scopes     = each.value.scopes
}

resource "gitlab_group_access_token" "this" {
  for_each = local.group_access_tokens

  group        = each.value.group
  name         = each.value.name
  expires_at   = each.value.expires_at
  access_level = each.value.access_level
  scopes       = each.value.scopes
  # Exactly one of expires_at and rotation_configuration is set (variables.tf).
  rotation_configuration = each.value.rotation_configuration
}

resource "gitlab_project_access_token" "this" {
  for_each = local.project_access_tokens

  project      = each.value.project
  name         = each.value.name
  expires_at   = each.value.expires_at
  access_level = each.value.access_level
  scopes       = each.value.scopes
  # Exactly one of expires_at and rotation_configuration is set (variables.tf).
  rotation_configuration = each.value.rotation_configuration
}

resource "gitlab_project_deploy_token" "this" {
  for_each = local.project_deploy_tokens

  project    = each.value.project
  name       = each.value.name
  username   = each.value.username
  expires_at = each.value.expires_at
  scopes     = each.value.scopes
}

resource "gitlab_deploy_key" "this" {
  for_each = local.deploy_keys

  project    = each.value.project
  title      = each.value.title
  key        = each.value.key
  expires_at = each.value.expires_at
  can_push   = each.value.can_push
}

resource "gitlab_group_membership" "this" {
  for_each = local.group_memberships

  group_id     = each.value.group_id
  user_id      = each.value.user_id
  access_level = each.value.access_level
  expires_at   = each.value.expires_at
}

resource "gitlab_project_membership" "this" {
  for_each = local.project_memberships

  project      = each.value.project
  user_id      = each.value.user_id
  access_level = each.value.access_level
  expires_at   = each.value.expires_at
}

resource "gitlab_group_share_group" "this" {
  for_each = local.group_shares

  group_id       = each.value.group_id
  share_group_id = each.value.share_group_id
  group_access   = each.value.access_level
  expires_at     = each.value.expires_at
}

resource "gitlab_project_share_group" "this" {
  for_each = local.project_shares

  project      = each.value.project
  group_id     = each.value.group_id
  group_access = each.value.access_level
  expires_at   = each.value.expires_at
}
