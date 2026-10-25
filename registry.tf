# Package and container registry protection of created projects. The
# cleanup policy is a block of gitlab_project (projects.tf).

resource "gitlab_project_package_protection_rule" "this" {
  for_each = local.package_protection_rules

  project                         = each.value.project
  package_type                    = each.value.package_type
  package_name_pattern            = each.value.package_name_pattern
  minimum_access_level_for_push   = each.value.minimum_access_level_for_push
  minimum_access_level_for_delete = each.value.minimum_access_level_for_delete
}

# GitLab requires the pattern to start with the project's full path, known
# only after the project is created; callers give the rest of it.
resource "gitlab_project_container_repository_protection" "this" {
  for_each = local.container_protection_rules

  project                         = each.value.project
  repository_path_pattern         = "${gitlab_project.this[each.value.project_key].path_with_namespace}${each.value.path_pattern}"
  minimum_access_level_for_push   = each.value.minimum_access_level_for_push
  minimum_access_level_for_delete = each.value.minimum_access_level_for_delete
}

# The provider validates upper-case levels. An immutable rule (Ultimate)
# takes no level, and immutable is sent only when true.
resource "gitlab_project_container_tag_protection" "this" {
  for_each = local.container_tag_protection_rules

  project                         = each.value.project
  tag_name_regex                  = each.value.tag_name_pattern
  minimum_access_level_for_push   = each.value.immutable ? null : upper(each.value.minimum_access_level_for_push)
  minimum_access_level_for_delete = each.value.immutable ? null : upper(each.value.minimum_access_level_for_delete)
  immutable                       = each.value.immutable ? true : null
}
