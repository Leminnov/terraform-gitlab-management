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
}

resource "gitlab_branch" "this" {
  for_each = local.project_branches

  project = gitlab_project.this[each.value.project].id
  name    = each.value.name
  ref     = each.value.ref
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
