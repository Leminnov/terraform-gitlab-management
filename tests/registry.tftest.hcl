# Registry protection (registry-protection and premium-features specs):
# package rules, container repository rules, protected container tags,
# immutable tags (Ultimate), the cleanup policy, and one rejected-input run
# per validation.

mock_provider "gitlab" {
  mock_resource "gitlab_group" {
    defaults = { id = "1000" }
  }
  mock_resource "gitlab_project" {
    defaults = { id = "2000", path_with_namespace = "parent/mocked/api" }
  }
}

variables {
  parent_group_id = 42
  groups          = { platform = {} }
  projects        = { "platform/api" = {} }
}

run "registry_rules" {
  command = plan

  variables {
    projects = {
      "platform/api" = {
        package_protection_rules = {
          npm     = { package_type = "npm", package_name_pattern = "@leminnov/*" }
          release = { package_type = "generic", package_name_pattern = "release-*", minimum_access_level_for_push = "owner", minimum_access_level_for_delete = "admin" }
        }
        container_protection_rules     = { all = { path_pattern = "*" } }
        container_tag_protection_rules = { release = { tag_name_pattern = "^v[0-9]+" } }
      }
    }
  }

  assert {
    condition = alltrue([
      toset(keys(gitlab_project_package_protection_rule.this)) == toset(["platform/api:npm", "platform/api:release"]),
      gitlab_project_package_protection_rule.this["platform/api:npm"].minimum_access_level_for_push == "maintainer",
      gitlab_project_package_protection_rule.this["platform/api:npm"].minimum_access_level_for_delete == null,
      gitlab_project_package_protection_rule.this["platform/api:release"].minimum_access_level_for_delete == "admin",
      gitlab_project_package_protection_rule.this["platform/api:npm"].project == "2000",
    ])
    error_message = "Package rules must default to maintainer pushes and send a delete level only when set."
  }
  assert {
    condition = alltrue([
      keys(gitlab_project_container_repository_protection.this) == ["platform/api:all"],
      gitlab_project_container_repository_protection.this["platform/api:all"].repository_path_pattern == "parent/mocked/api*",
      gitlab_project_container_repository_protection.this["platform/api:all"].minimum_access_level_for_push == "maintainer",
      gitlab_project_container_repository_protection.this["platform/api:all"].minimum_access_level_for_delete == "maintainer",
    ])
    error_message = "Container rules must prefix the pattern with the project's full path and default to maintainers."
  }
  assert {
    condition = alltrue([
      keys(gitlab_project_container_tag_protection.this) == ["platform/api:release"],
      gitlab_project_container_tag_protection.this["platform/api:release"].tag_name_regex == "^v[0-9]+",
      gitlab_project_container_tag_protection.this["platform/api:release"].minimum_access_level_for_push == "MAINTAINER",
      gitlab_project_container_tag_protection.this["platform/api:release"].minimum_access_level_for_delete == "MAINTAINER",
    ])
    error_message = "Tag rules must send upper-case levels."
  }
  assert {
    condition     = length(gitlab_project.this["platform/api"].container_expiration_policy) == 0
    error_message = "Without a policy, no cleanup block may be sent."
  }
}

run "cleanup_policy_defaults" {
  command = plan

  variables {
    projects = { "platform/api" = { container_expiration_policy = {} } }
  }

  assert {
    condition = alltrue([
      gitlab_project.this["platform/api"].container_expiration_policy[0].enabled == true,
      gitlab_project.this["platform/api"].container_expiration_policy[0].cadence == "7d",
      gitlab_project.this["platform/api"].container_expiration_policy[0].keep_n == 10,
      gitlab_project.this["platform/api"].container_expiration_policy[0].older_than == "90d",
      gitlab_project.this["platform/api"].container_expiration_policy[0].name_regex_delete == ".*",
    ])
    error_message = "A policy must enable cleanup every 7 days, keeping 10 tags and deleting tags older than 90 days."
  }
}

run "immutable_release_images" {
  command = plan

  variables {
    projects = { "platform/api" = { container_tag_protection_rules = { release = { tag_name_pattern = "^v[0-9]+", immutable = true } } } }
  }

  assert {
    condition = alltrue([
      gitlab_project_container_tag_protection.this["platform/api:release"].immutable == true,
      local.container_tag_protection_rules["platform/api:release"].immutable == true,
    ])
    error_message = "An immutable rule must send immutable = true."
  }
}

# ---------------------------------------------------------------------------
# Rejected inputs: one run per validation
# ---------------------------------------------------------------------------

run "unknown_package_type_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { package_protection_rules = { img = { package_type = "docker", package_name_pattern = "*" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "developer_package_push_level_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { package_protection_rules = { npm = { package_type = "npm", package_name_pattern = "@leminnov/*", minimum_access_level_for_push = "developer" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "developer_container_delete_level_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { container_protection_rules = { all = { path_pattern = "*", minimum_access_level_for_delete = "developer" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "empty_tag_pattern_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { container_tag_protection_rules = { release = { tag_name_pattern = "" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "unsupported_cleanup_cadence_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { container_expiration_policy = { cadence = "2d" } } }
  }

  expect_failures = [
    var.projects,
  ]
}
