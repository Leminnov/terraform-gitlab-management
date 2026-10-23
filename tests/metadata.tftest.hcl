# Labels, badges and webhooks (labels-and-badges and webhooks specs): keys,
# hook defaults, token redaction and one rejected-input run per validation.

mock_provider "gitlab" {
  mock_resource "gitlab_group" {
    defaults = { id = "1000" }
  }
  mock_resource "gitlab_project" {
    defaults = { id = "2000" }
  }
}

variables {
  parent_group_id = 42
  groups          = { platform = {} }
  projects        = { "platform/api" = {} }
}

run "labels_badges_and_hooks_are_keyed_by_owner" {
  command = plan

  variables {
    groups = {
      platform = {
        labels = { bug = { color = "#d9534f" } }
        badges = {
          pipeline = {
            link_url  = "https://gitlab.com/%%{project_path}/-/pipelines"
            image_url = "https://gitlab.com/%%{project_path}/badges/%%{default_branch}/pipeline.svg"
          }
        }
      }
    }
    projects = {
      "platform/api" = {
        labels = { triage = { color = "orange", description = "Needs triage", priority = 1 } }
        badges = { docs = { link_url = "https://docs.example.com", image_url = "https://img.example.com/docs.svg" } }
        hooks = {
          ci = {
            url                   = "https://ci.example.com/hook"
            merge_requests_events = true
            token                 = "dummy"
            signing_token         = "whsec_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
          }
        }
      }
    }
  }

  assert {
    condition = alltrue([
      keys(gitlab_group_label.this) == ["platform:bug"],
      keys(gitlab_project_label.this) == ["platform/api:triage"],
      keys(gitlab_group_badge.this) == ["platform:pipeline"],
      keys(gitlab_project_badge.this) == ["platform/api:docs"],
      keys(gitlab_project_hook.this) == ["platform/api:ci"],
    ])
    error_message = "Labels, badges and hooks must be keyed \"<owner key>:<name>\"."
  }
  assert {
    condition = alltrue([
      gitlab_group_label.this["platform:bug"].group == "1000",
      gitlab_group_label.this["platform:bug"].name == "bug",
      gitlab_project_label.this["platform/api:triage"].priority == 1,
      gitlab_group_badge.this["platform:pipeline"].name == "pipeline",
      gitlab_group_badge.this["platform:pipeline"].link_url == "https://gitlab.com/%%{project_path}/-/pipelines",
      gitlab_project_badge.this["platform/api:docs"].project == "2000",
    ])
    error_message = "Labels and badges must be named by their key, on their group or project, with placeholders kept."
  }
  assert {
    condition = alltrue([
      gitlab_project_hook.this["platform/api:ci"].name == "ci",
      gitlab_project_hook.this["platform/api:ci"].push_events == true,
      gitlab_project_hook.this["platform/api:ci"].merge_requests_events == true,
      gitlab_project_hook.this["platform/api:ci"].tag_push_events == false,
      gitlab_project_hook.this["platform/api:ci"].pipeline_events == false,
      gitlab_project_hook.this["platform/api:ci"].enable_ssl_verification == true,
    ])
    error_message = "A hook must send push events and verify TLS by default, plus the events set to true."
  }
  assert {
    condition = alltrue([
      issensitive(gitlab_project_hook.this["platform/api:ci"].token),
      issensitive(gitlab_project_hook.this["platform/api:ci"].signing_token),
      nonsensitive(gitlab_project_hook.this["platform/api:ci"].signing_token) == "whsec_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
    ])
    error_message = "Hook token and signing_token must be redacted in plans."
  }
}

# ---------------------------------------------------------------------------
# Rejected inputs: one run per validation
# ---------------------------------------------------------------------------

run "group_label_colour_is_rejected" {
  command = plan

  variables {
    groups = { platform = { labels = { bug = { color = "#12345" } } } }
  }

  expect_failures = [
    var.groups,
  ]
}

run "group_badge_without_scheme_is_rejected" {
  command = plan

  variables {
    groups = { platform = { badges = { docs = { link_url = "gitlab.com/x", image_url = "https://img.example.com/x.svg" } } } }
  }

  expect_failures = [
    var.groups,
  ]
}

run "project_label_colour_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { labels = { bug = { color = "#12345" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_label_negative_priority_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { labels = { bug = { color = "#d9534f", priority = -1 } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "project_badge_without_scheme_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { badges = { docs = { link_url = "https://docs.example.com", image_url = "img.example.com/x.svg" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "hook_url_without_scheme_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { hooks = { ci = { url = "ci.example.com/hook" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "hook_signing_token_format_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { hooks = { ci = { url = "https://ci.example.com/hook", signing_token = "s3cr3t" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}
