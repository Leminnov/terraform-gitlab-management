# Premium and Ultimate settings of created groups and projects. Every input
# defaults to {} or null, so a Free namespace plans none of these resources
# (premium-features spec); on Free, setting one fails at apply with GitLab's
# error naming the feature.

resource "gitlab_project_approval_rule" "this" {
  for_each = local.project_approval_rules

  project                           = each.value.project
  name                              = each.value.name
  approvals_required                = each.value.approvals_required
  user_ids                          = each.value.user_ids
  group_ids                         = each.value.group_ids
  applies_to_all_protected_branches = each.value.applies_to_all_protected_branches
}

resource "gitlab_project_level_mr_approvals" "this" {
  for_each = local.project_mr_approvals

  project                                        = each.value.project
  reset_approvals_on_push                        = each.value.reset_approvals_on_push
  merge_requests_author_approval                 = each.value.merge_requests_author_approval
  merge_requests_disable_committers_approval     = each.value.merge_requests_disable_committers_approval
  disable_overriding_approvers_per_merge_request = each.value.disable_overriding_approvers_per_merge_request
}

resource "gitlab_project_push_rules" "this" {
  for_each = local.project_push_rules

  project                 = each.value.project
  prevent_secrets         = each.value.prevent_secrets
  deny_delete_tag         = each.value.deny_delete_tag
  member_check            = each.value.member_check
  reject_unsigned_commits = each.value.reject_unsigned_commits
  commit_message_regex    = each.value.commit_message_regex
  branch_name_regex       = each.value.branch_name_regex
  author_email_regex      = each.value.author_email_regex
  max_file_size           = each.value.max_file_size
}

resource "gitlab_project_protected_environment" "this" {
  for_each = local.project_protected_environments

  project = each.value.project
  # Read from the environment resource so it exists before it is protected.
  environment                    = gitlab_project_environment.this[each.value.environment].name
  deploy_access_levels_attribute = [{ access_level = each.value.deploy_access_level }]
  approval_rules                 = each.value.required_approvals == null ? null : [{ access_level = each.value.deploy_access_level, required_approvals = each.value.required_approvals }]
}

# DEVIATION(terraform-variables): token and signing_token cannot come from a
# sensitive = true input because for_each iterates it, and the provider has no
# write-only argument for them; sensitive() keeps them out of plan output. They
# still land in state (SECURITY.md).
resource "gitlab_group_hook" "this" {
  for_each = local.group_hooks

  group                   = each.value.group
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
  subgroup_events         = each.value.subgroup_events
  project_events          = each.value.project_events
  enable_ssl_verification = each.value.enable_ssl_verification
  token                   = sensitive(each.value.token)
  signing_token           = sensitive(each.value.signing_token)
}

resource "gitlab_project_target_branch_rule" "this" {
  for_each = local.project_target_branch_rules

  project               = each.value.project
  source_branch_pattern = each.value.source_branch_pattern
  target_branch_name    = each.value.target_branch_name
}
