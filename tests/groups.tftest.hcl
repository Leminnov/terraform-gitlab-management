# Group tree (groups spec): levels, parents, defaults and every validation of
# var.groups / var.parent_group_id. Mocked IDs are numeric so the tonumber()
# on parent IDs resolves at plan time.

mock_provider "gitlab" {
  mock_resource "gitlab_group" {
    defaults = {
      id        = "1000"
      full_path = "parent/mocked"
      web_url   = "https://gitlab.example.com/parent/mocked"
    }
  }
}

variables {
  parent_group_id = 42
}

run "seven_levels_get_one_block_each" {
  command = plan

  variables {
    groups = {
      "a"             = {}
      "a/b"           = {}
      "a/b/c"         = {}
      "a/b/c/d"       = {}
      "a/b/c/d/e"     = {}
      "a/b/c/d/e/f"   = {}
      "a/b/c/d/e/f/g" = {}
    }
  }

  assert {
    condition     = gitlab_group.level_1["a"].parent_id == 42 && gitlab_group.level_1["a"].path == "a"
    error_message = "Level 1 must be created under parent_group_id."
  }
  assert {
    condition = alltrue([
      gitlab_group.level_2["a/b"].parent_id == 1000,
      gitlab_group.level_3["a/b/c"].parent_id == 1000,
      gitlab_group.level_4["a/b/c/d"].parent_id == 1000,
      gitlab_group.level_5["a/b/c/d/e"].parent_id == 1000,
      gitlab_group.level_6["a/b/c/d/e/f"].parent_id == 1000,
      gitlab_group.level_7["a/b/c/d/e/f/g"].parent_id == 1000,
    ])
    error_message = "Every level must take its parent from the level above."
  }
  assert {
    condition = alltrue([
      for n in [length(gitlab_group.level_1), length(gitlab_group.level_2), length(gitlab_group.level_3), length(gitlab_group.level_4), length(gitlab_group.level_5), length(gitlab_group.level_6), length(gitlab_group.level_7)] : n == 1
    ])
    error_message = "Each level block must hold exactly the group of its depth."
  }
  assert {
    condition     = gitlab_group.level_7["a/b/c/d/e/f/g"].path == "g" && length(output.groups) == 7
    error_message = "The deepest group must be created, and every group must be in the groups output."
  }
}

run "several_roots_and_siblings" {
  command = plan

  variables {
    groups = {
      platform         = {}
      data             = {}
      "platform/infra" = {}
      "platform/web"   = {}
    }
  }

  assert {
    condition     = toset(keys(gitlab_group.level_1)) == toset(["platform", "data"]) && toset(keys(gitlab_group.level_2)) == toset(["platform/infra", "platform/web"])
    error_message = "Roots and siblings must land in the blocks of their depth."
  }
  assert {
    condition     = toset(keys(output.groups)) == toset(["platform", "data", "platform/infra", "platform/web"]) && output.groups["platform/web"].full_path == "parent/mocked"
    error_message = "The groups output must be keyed like the input and carry full_path."
  }
}

run "name_defaults_to_the_last_segment" {
  command = plan

  variables {
    groups = {
      platform         = { name = "Platform Engineering" }
      "platform/infra" = {}
    }
  }

  assert {
    condition     = gitlab_group.level_2["platform/infra"].name == "infra" && gitlab_group.level_2["platform/infra"].path == "infra"
    error_message = "name must default to the last path segment."
  }
  assert {
    condition     = gitlab_group.level_1["platform"].name == "Platform Engineering" && gitlab_group.level_1["platform"].path == "platform"
    error_message = "An explicit name must be kept, with the path from the key."
  }
}

run "safe_group_defaults" {
  command = plan

  variables {
    groups = { platform = {} }
  }

  assert {
    condition = alltrue([
      gitlab_group.level_1["platform"].visibility_level == "private",
      gitlab_group.level_1["platform"].request_access_enabled == false,
      gitlab_group.level_1["platform"].project_creation_level == "maintainer",
      gitlab_group.level_1["platform"].subgroup_creation_level == "owner",
      gitlab_group.level_1["platform"].default_branch == "main",
    ])
    error_message = "Groups must default to private, no access requests, maintainer project creation, owner subgroup creation and main."
  }
  assert {
    condition = alltrue([
      gitlab_group.level_1["platform"].archive_on_destroy == true,
      gitlab_group.level_1["platform"].permanently_remove_on_delete == null,
    ])
    error_message = "Groups must be archived on destroy by default."
  }
  assert {
    condition = alltrue([
      gitlab_group.level_1["platform"].default_branch_protection_defaults[0].allowed_to_push == tolist(["maintainer"]),
      gitlab_group.level_1["platform"].default_branch_protection_defaults[0].allowed_to_merge == tolist(["maintainer"]),
      gitlab_group.level_1["platform"].default_branch_protection_defaults[0].allow_force_push == false,
    ])
    error_message = "New projects in the group must start with main protected for maintainers."
  }
}

run "throwaway_group_is_removed_for_good" {
  command = plan

  variables {
    groups = { tmp = { archive_on_destroy = false, permanently_remove_on_delete = true } }
  }

  assert {
    condition     = gitlab_group.level_1["tmp"].archive_on_destroy == null && gitlab_group.level_1["tmp"].permanently_remove_on_delete == true
    error_message = "Opting out of archiving must send permanently_remove_on_delete only."
  }
}

run "less_open_subgroup_is_accepted" {
  command = plan

  variables {
    groups = {
      shared           = { visibility = "internal" }
      "shared/private" = { visibility = "private" }
    }
  }

  assert {
    condition     = gitlab_group.level_2["shared/private"].visibility_level == "private" && gitlab_group.level_1["shared"].visibility_level == "internal"
    error_message = "A subgroup less open than its parent must be accepted."
  }
}

# ---------------------------------------------------------------------------
# Rejected inputs: one run per validation of parent_group_id and groups
# ---------------------------------------------------------------------------

run "groups_without_parent_are_rejected" {
  command = plan

  variables {
    parent_group_id = null
    groups          = { platform = {} }
  }

  expect_failures = [
    var.parent_group_id,
  ]
}

run "eight_levels_are_rejected" {
  command = plan

  variables {
    groups = {
      "a"               = {}
      "a/b"             = {}
      "a/b/c"           = {}
      "a/b/c/d"         = {}
      "a/b/c/d/e"       = {}
      "a/b/c/d/e/f"     = {}
      "a/b/c/d/e/f/g"   = {}
      "a/b/c/d/e/f/g/h" = {}
    }
  }

  expect_failures = [
    var.groups,
  ]
}

run "invalid_path_segment_is_rejected" {
  command = plan

  variables {
    groups = { platform = {}, "platform/my team" = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "missing_intermediate_group_is_rejected" {
  command = plan

  variables {
    groups = { "platform/infra" = {} }
  }

  expect_failures = [
    var.groups,
  ]
}

run "unknown_group_visibility_is_rejected" {
  command = plan

  variables {
    groups = { platform = { visibility = "secret" } }
  }

  expect_failures = [
    var.groups,
  ]
}

run "public_subgroup_of_private_group_is_rejected" {
  command = plan

  variables {
    groups = {
      platform       = {}
      "platform/web" = { visibility = "public" }
    }
  }

  expect_failures = [
    var.groups,
  ]
}

run "unknown_project_creation_level_is_rejected" {
  command = plan

  variables {
    groups = { platform = { project_creation_level = "guest" } }
  }

  expect_failures = [
    var.groups,
  ]
}

run "unknown_subgroup_creation_level_is_rejected" {
  command = plan

  variables {
    groups = { platform = { subgroup_creation_level = "developer" } }
  }

  expect_failures = [
    var.groups,
  ]
}

run "permanent_removal_while_archiving_is_rejected" {
  command = plan

  variables {
    groups = { platform = { permanently_remove_on_delete = true } }
  }

  expect_failures = [
    var.groups,
  ]
}
