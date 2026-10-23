# Credentials: group deploy tokens and group and project access tokens.

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
}

resource "gitlab_project_access_token" "this" {
  for_each = local.project_access_tokens

  project      = each.value.project
  name         = each.value.name
  expires_at   = each.value.expires_at
  access_level = each.value.access_level
  scopes       = each.value.scopes
}
