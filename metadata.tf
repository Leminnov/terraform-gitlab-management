# Labels and badges of created groups and projects, and project webhooks.

resource "gitlab_group_label" "this" {
  for_each = local.group_labels

  group       = each.value.group
  name        = each.value.name
  color       = each.value.color
  description = each.value.description
}

resource "gitlab_project_label" "this" {
  for_each = local.project_labels

  project     = each.value.project
  name        = each.value.name
  color       = each.value.color
  description = each.value.description
  priority    = each.value.priority
}

resource "gitlab_group_badge" "this" {
  for_each = local.group_badges

  group     = each.value.group
  name      = each.value.name
  link_url  = each.value.link_url
  image_url = each.value.image_url
}

resource "gitlab_project_badge" "this" {
  for_each = local.project_badges

  project   = each.value.project
  name      = each.value.name
  link_url  = each.value.link_url
  image_url = each.value.image_url
}

# DEVIATION(terraform-variables): token and signing_token cannot come from a
# sensitive = true input because for_each iterates it, and the provider has no
# write-only argument for them; sensitive() keeps them out of plan output. They
# still land in state (SECURITY.md).
resource "gitlab_project_hook" "this" {
  for_each = local.project_hooks

  project                 = each.value.project
  name                    = each.value.name
  url                     = each.value.url
  push_events             = each.value.push_events
  tag_push_events         = each.value.tag_push_events
  merge_requests_events   = each.value.merge_requests_events
  pipeline_events         = each.value.pipeline_events
  job_events              = each.value.job_events
  deployment_events       = each.value.deployment_events
  releases_events         = each.value.releases_events
  issues_events           = each.value.issues_events
  note_events             = each.value.note_events
  enable_ssl_verification = each.value.enable_ssl_verification
  token                   = sensitive(each.value.token)
  signing_token           = sensitive(each.value.signing_token)
}
