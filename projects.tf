# Projects created in the group tree or directly under parent_group_id, with
# their extra branches, protected branches and protected tags.

resource "gitlab_project" "this" {
  # Premium-only controls, offered as optional inputs (premium-features spec);
  # a Free namespace cannot enable them:
  #checkov:skip=CKV_GLB_1:Required approvals are Premium; Premium namespaces set approval_rules, Free namespaces cannot require them
  #checkov:skip=CKV_GLB_3:Push rule prevent_secrets is Premium; Premium namespaces set push_rules (prevent_secrets defaults to true there)
  #checkov:skip=CKV_GLB_4:Signed-commit push rule is Premium; Premium namespaces set push_rules.reject_unsigned_commits
  for_each = local.project_args

  name                                             = each.value.name
  path                                             = each.value.path
  namespace_id                                     = each.value.namespace == "" ? var.parent_group_id : tonumber(local.group_ids[each.value.namespace])
  description                                      = each.value.description
  visibility_level                                 = each.value.visibility
  topics                                           = each.value.topics
  default_branch                                   = each.value.default_branch
  initialize_with_readme                           = each.value.initialize_with_readme
  merge_method                                     = each.value.merge_method
  squash_option                                    = each.value.squash_option
  only_allow_merge_if_pipeline_succeeds            = each.value.only_allow_merge_if_pipeline_succeeds
  only_allow_merge_if_all_discussions_are_resolved = each.value.only_allow_merge_if_all_discussions_are_resolved
  remove_source_branch_after_merge                 = each.value.remove_source_branch_after_merge
  archive_on_destroy                               = each.value.archive_on_destroy
  permanently_delete_on_destroy                    = each.value.permanently_delete_on_destroy

  # CI/CD settings: null sends nothing and keeps GitLab's value (all
  # Optional+Computed in the provider, ci_config_path Optional only).
  public_jobs                                 = each.value.ci.public_jobs
  ci_pipeline_variables_minimum_override_role = each.value.ci.pipeline_variables_minimum_override_role
  protect_merge_request_pipelines             = each.value.ci.protect_merge_request_pipelines
  ci_separated_caches                         = each.value.ci.separated_caches
  ci_forward_deployment_enabled               = each.value.ci.forward_deployment_enabled
  ci_push_repository_for_job_token_allowed    = each.value.ci.push_repository_for_job_token_allowed
  allow_merge_on_skipped_pipeline             = each.value.ci.allow_merge_on_skipped_pipeline
  ci_config_path                              = each.value.ci.config_path
  auto_cancel_pending_pipelines               = each.value.ci.auto_cancel_pending_pipelines
  build_timeout                               = each.value.ci.build_timeout
  ci_default_git_depth                        = each.value.ci.default_git_depth
  ci_delete_pipelines_in_seconds              = each.value.ci.delete_pipelines_in_seconds
  ci_id_token_sub_claim_components            = each.value.ci.id_token_sub_claim_components
  group_runners_enabled                       = each.value.ci.group_runners_enabled
  shared_runners_enabled                      = each.value.ci.shared_runners_enabled

  # Container cleanup, only when the caller sets a policy: deleting images is
  # never a default.
  dynamic "container_expiration_policy" {
    for_each = each.value.container_expiration_policy == null ? [] : [each.value.container_expiration_policy]

    content {
      enabled           = true
      cadence           = container_expiration_policy.value.cadence
      keep_n            = container_expiration_policy.value.keep_n
      older_than        = container_expiration_policy.value.older_than
      name_regex_delete = container_expiration_policy.value.name_regex_delete
      name_regex_keep   = container_expiration_policy.value.name_regex_keep
    }
  }
}

resource "gitlab_branch" "this" {
  for_each = local.project_branches

  project = gitlab_project.this[each.value.project].id
  name    = each.value.name
  ref     = each.value.ref

  # Branches start from the default branch once its files are committed, so
  # develop holds them too.
  depends_on = [gitlab_repository_file.managed, gitlab_repository_file.seeded]
}

# One protection per branch: the provider takes over the default-branch
# protection GitLab creates with the project, and two resources on one branch
# would override each other. gitlab.com is an EE instance, where the provider
# documents allowed_to_push / allowed_to_merge.
resource "gitlab_branch_protection" "this" {
  #checkov:skip=CKV_GLB_2:allow_force_push defaults to false; checkov cannot resolve the per-branch input, and check.protected_branch_force_push warns when a caller enables it
  for_each = local.project_protected_branches

  project          = gitlab_project.this[each.value.project].id
  branch           = each.value.branch
  allow_force_push = each.value.allow_force_push
  allowed_to_push  = [{ access_level = each.value.push_access_level }]
  allowed_to_merge = [{ access_level = each.value.merge_access_level }]
  # Premium; null sends nothing.
  code_owner_approval_required = each.value.code_owner_approval_required
}

resource "gitlab_tag_protection" "this" {
  for_each = local.project_protected_tags

  project             = gitlab_project.this[each.value.project].id
  tag                 = each.value.tag
  create_access_level = each.value.create_access_level
}
