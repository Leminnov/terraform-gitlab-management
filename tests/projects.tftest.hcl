# Projects and repository protection (projects and repository-protection
# specs): namespaces, defaults, branches, protections, tags and every
# validation of var.projects.

mock_provider "gitlab" {
  mock_resource "gitlab_group" {
    defaults = {
      id        = "1000"
      full_path = "parent/mocked"
      web_url   = "https://gitlab.example.com/parent/mocked"
    }
  }
  mock_resource "gitlab_project" {
    defaults = {
      id                  = "2000"
      path_with_namespace = "parent/mocked/project"
      web_url             = "https://gitlab.example.com/parent/mocked/project"
      http_url_to_repo    = "https://gitlab.example.com/parent/mocked/project.git"
      ssh_url_to_repo     = "git@gitlab.example.com:parent/mocked/project.git"
    }
  }
}

variables {
  parent_group_id = 42
  groups = {
    platform         = {}
    "platform/infra" = {}
  }
}

run "project_in_a_created_group" {
  command = plan

  variables {
    projects = { "platform/infra/api" = {} }
  }

  assert {
    condition     = gitlab_project.this["platform/infra/api"].namespace_id == 1000 && gitlab_project.this["platform/infra/api"].path == "api" && gitlab_project.this["platform/infra/api"].name == "api"
    error_message = "A project keyed <group>/<path> must be created in that group, named after its path."
  }
}

run "project_directly_under_the_parent" {
  command = plan

  variables {
    projects = { tools = { name = "Tools" } }
  }

  assert {
    condition     = gitlab_project.this["tools"].namespace_id == 42 && gitlab_project.this["tools"].name == "Tools"
    error_message = "A single-segment project must be created in parent_group_id."
  }
}

run "safe_project_defaults" {
  command = plan

  variables {
    projects = { "platform/api" = {} }
  }

  assert {
    condition = alltrue([
      gitlab_project.this["platform/api"].visibility_level == "private",
      gitlab_project.this["platform/api"].default_branch == "main",
      gitlab_project.this["platform/api"].initialize_with_readme == true,
      gitlab_project.this["platform/api"].only_allow_merge_if_pipeline_succeeds == true,
      gitlab_project.this["platform/api"].only_allow_merge_if_all_discussions_are_resolved == true,
      gitlab_project.this["platform/api"].merge_method == "merge",
      gitlab_project.this["platform/api"].squash_option == "default_on",
      gitlab_project.this["platform/api"].remove_source_branch_after_merge == true,
    ])
    error_message = "Projects must default to private, main with a README, merge only on green pipelines with threads resolved, merge commits, squash encouraged and source branch deleted."
  }
  assert {
    condition     = gitlab_project.this["platform/api"].archive_on_destroy == true && gitlab_project.this["platform/api"].permanently_delete_on_destroy == null
    error_message = "Projects must be archived on destroy by default."
  }
  assert {
    condition     = keys(gitlab_branch.this) == ["platform/api:develop"] && gitlab_branch.this["platform/api:develop"].ref == "main"
    error_message = "A develop branch must be created from the default branch by default."
  }
  assert {
    condition = alltrue([
      [for a in gitlab_branch_protection.this["platform/api:main"].allowed_to_push : a.access_level] == ["maintainer"],
      [for a in gitlab_branch_protection.this["platform/api:main"].allowed_to_merge : a.access_level] == ["maintainer"],
      gitlab_branch_protection.this["platform/api:main"].allow_force_push == false,
      [for a in gitlab_branch_protection.this["platform/api:develop"].allowed_to_push : a.access_level] == ["developer"],
      [for a in gitlab_branch_protection.this["platform/api:develop"].allowed_to_merge : a.access_level] == ["developer"],
      gitlab_branch_protection.this["platform/api:develop"].allow_force_push == false,
      length(gitlab_branch_protection.this) == 2,
    ])
    error_message = "main must be protected for maintainers and develop for developers, without force push."
  }
  assert {
    condition     = keys(gitlab_tag_protection.this) == ["platform/api:v*"] && gitlab_tag_protection.this["platform/api:v*"].create_access_level == "maintainer"
    error_message = "v* tags must be protected for maintainers by default."
  }
  assert {
    condition     = output.projects["platform/api"].http_url_to_repo == "https://gitlab.example.com/parent/mocked/project.git" && output.projects["platform/api"].default_branch == "main"
    error_message = "The projects output must carry the clone URLs and the default branch."
  }
}

run "pipelines_not_required" {
  command = plan

  variables {
    projects = { "platform/api" = { only_allow_merge_if_pipeline_succeeds = false } }
  }

  assert {
    condition     = gitlab_project.this["platform/api"].only_allow_merge_if_pipeline_succeeds == false
    error_message = "The merge setting must be overridable."
  }
}

run "declared_protections_replace_the_defaults" {
  command = plan

  variables {
    projects = {
      "platform/api" = {
        protected_branches = {
          main        = {}
          "release/*" = { push_access_level = "no one" }
        }
      }
    }
  }

  assert {
    condition     = toset(keys(gitlab_branch_protection.this)) == toset(["platform/api:main", "platform/api:release/*"])
    error_message = "protected_branches must replace the default protections, develop included."
  }
  assert {
    condition     = [for a in gitlab_branch_protection.this["platform/api:release/*"].allowed_to_push : a.access_level] == ["no one"]
    error_message = "A declared push level must be sent."
  }
}

run "trunk_based_project" {
  command = plan

  variables {
    projects = { "platform/api" = { default_branch = "trunk", branches = {} } }
  }

  assert {
    condition     = length(gitlab_branch.this) == 0 && keys(gitlab_branch_protection.this) == ["platform/api:trunk"]
    error_message = "Without branches, only the default branch must be protected."
  }
}

run "throwaway_project_is_deleted_for_good" {
  command = plan

  variables {
    projects = { tools = { archive_on_destroy = false, permanently_delete_on_destroy = true } }
  }

  assert {
    condition     = gitlab_project.this["tools"].archive_on_destroy == null && gitlab_project.this["tools"].permanently_delete_on_destroy == true
    error_message = "Opting out of archiving must send permanently_delete_on_destroy only."
  }
}

# ---------------------------------------------------------------------------
# Rejected inputs: one run per validation of var.projects
# ---------------------------------------------------------------------------

run "projects_without_parent_are_rejected" {
  command = plan

  variables {
    parent_group_id = null
    groups          = {}
    projects        = { tools = {} }
  }

  expect_failures = [
    var.parent_group_id,
  ]
}

run "project_in_unknown_group_is_rejected" {
  command = plan

  variables {
    projects = { "platform/web/app" = {} }
  }

  expect_failures = [
    var.projects,
  ]
}

run "invalid_project_path_is_rejected" {
  command = plan

  variables {
    projects = { "platform/app.git" = {} }
  }

  expect_failures = [
    var.projects,
  ]
}

run "unknown_project_visibility_is_rejected" {
  command = plan

  variables {
    projects = { tools = { visibility = "secret" } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "public_project_in_private_group_is_rejected" {
  command = plan

  variables {
    projects = { "platform/site" = { visibility = "public" } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "unknown_merge_method_is_rejected" {
  command = plan

  variables {
    projects = { tools = { merge_method = "squash" } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "unknown_squash_option_is_rejected" {
  command = plan

  variables {
    projects = { tools = { squash_option = "sometimes" } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "branches_on_an_empty_repository_are_rejected" {
  command = plan

  variables {
    projects = { tools = { initialize_with_readme = false } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "unknown_protected_branch_level_is_rejected" {
  command = plan

  variables {
    projects = { tools = { protected_branches = { main = { merge_access_level = "owner" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "unknown_protected_tag_level_is_rejected" {
  command = plan

  variables {
    projects = { tools = { protected_tags = { "v*" = { create_access_level = "guest" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "permanent_deletion_while_archiving_is_rejected" {
  command = plan

  variables {
    projects = { tools = { permanently_delete_on_destroy = true } }
  }

  expect_failures = [
    var.projects,
  ]
}
