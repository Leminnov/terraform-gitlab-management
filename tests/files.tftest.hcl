# Repository files and Kubernetes agents (repository-files and
# kubernetes-agents specs): managed and seeded files, the agent configuration
# file, agent tokens, and one rejected-input run per validation.

mock_provider "gitlab" {
  mock_resource "gitlab_group" {
    defaults = { id = "1000", full_path = "parent/mocked" }
  }
  mock_resource "gitlab_project" {
    defaults = { id = "2000", path_with_namespace = "parent/mocked/api" }
  }
  mock_resource "gitlab_cluster_agent" {
    defaults = { agent_id = 7000 }
  }
}

variables {
  parent_group_id = 42
  groups          = { platform = {} }
  projects        = { "platform/api" = {} }
}

run "managed_and_seeded_files" {
  command = plan

  variables {
    projects = {
      "platform/api" = {
        files = {
          CODEOWNERS               = { content = "* @leminnov/platform\n" }
          "README.md"              = { content = "# API\n" }
          "docs/README.md"         = { content = "Seed\n", managed = false }
          "scripts/check.sh"       = { content = "IyEvYmluL3NoCg==", encoding = "base64", executable = true }
          ".gitlab/ci/include.yml" = { content = "include: []\n", managed = false }
        }
      }
    }
  }

  assert {
    condition = alltrue([
      toset(keys(gitlab_repository_file.managed)) == toset(["platform/api:CODEOWNERS", "platform/api:README.md", "platform/api:scripts/check.sh"]),
      toset(keys(gitlab_repository_file.seeded)) == toset(["platform/api:docs/README.md", "platform/api:.gitlab/ci/include.yml"]),
    ])
    error_message = "Files must be keyed \"<project key>:<path>\", managed by default and seeded when managed = false."
  }
  assert {
    condition = alltrue([
      gitlab_repository_file.managed["platform/api:CODEOWNERS"].branch == "main",
      gitlab_repository_file.managed["platform/api:CODEOWNERS"].file_path == "CODEOWNERS",
      gitlab_repository_file.managed["platform/api:CODEOWNERS"].encoding == "text",
      gitlab_repository_file.managed["platform/api:CODEOWNERS"].execute_filemode == false,
      gitlab_repository_file.managed["platform/api:README.md"].overwrite_on_create == true,
      gitlab_repository_file.managed["platform/api:scripts/check.sh"].encoding == "base64",
      gitlab_repository_file.managed["platform/api:scripts/check.sh"].execute_filemode == true,
      gitlab_repository_file.seeded["platform/api:docs/README.md"].branch == "main",
      gitlab_repository_file.seeded["platform/api:docs/README.md"].project == "2000",
    ])
    error_message = "Files must be committed to the default branch with their encoding and mode, replacing the initial README when listed."
  }
}

run "agent_with_ci_access" {
  command = plan

  variables {
    projects = {
      "platform/api" = {
        kubernetes_agents = {
          prod = { ci_access = { groups = ["platform"], projects = ["platform/api"], group_paths = ["leminnov/other"] } }
          dev  = {}
        }
      }
    }
  }

  assert {
    condition = alltrue([
      toset(keys(gitlab_cluster_agent.this)) == toset(["platform/api:prod", "platform/api:dev"]),
      gitlab_cluster_agent.this["platform/api:prod"].name == "prod",
      gitlab_cluster_agent_token.this["platform/api:prod"].agent_id == 7000,
      gitlab_cluster_agent_token.this["platform/api:prod"].name == "prod",
    ])
    error_message = "Each agent must be registered with one token of its name."
  }
  assert {
    condition = alltrue([
      keys(gitlab_repository_file.managed) == ["platform/api:.gitlab/agents/prod/config.yaml"],
      gitlab_repository_file.managed["platform/api:.gitlab/agents/prod/config.yaml"].file_path == ".gitlab/agents/prod/config.yaml",
      yamldecode(gitlab_repository_file.managed["platform/api:.gitlab/agents/prod/config.yaml"].content) == {
        ci_access = {
          groups   = [{ id = "leminnov/other" }, { id = "parent/mocked" }]
          projects = [{ id = "parent/mocked/api" }]
        }
      },
    ])
    error_message = "An agent with ci_access must get a managed config.yaml listing its groups and projects by full path; an agent without gets none."
  }
  assert {
    condition     = issensitive(output.kubernetes_agent_tokens) && toset(keys(nonsensitive(output.kubernetes_agent_tokens))) == toset(["platform/api:prod", "platform/api:dev"])
    error_message = "The agent tokens must be in the sensitive kubernetes_agent_tokens output."
  }
}

# ---------------------------------------------------------------------------
# Rejected inputs: one run per validation
# ---------------------------------------------------------------------------

run "absolute_file_path_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { files = { "/CODEOWNERS" = { content = "x" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "unknown_file_encoding_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { files = { CODEOWNERS = { content = "x", encoding = "gzip" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "files_without_default_branch_are_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { initialize_with_readme = false, branches = {}, files = { CODEOWNERS = { content = "x" } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "agent_name_with_capitals_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { kubernetes_agents = { Prod_Cluster = {} } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "agent_access_to_unknown_group_is_rejected" {
  command = plan

  variables {
    projects = { "platform/api" = { kubernetes_agents = { prod = { ci_access = { groups = ["teams/missing"] } } } } }
  }

  expect_failures = [
    var.projects,
  ]
}

run "hand_written_agent_config_is_rejected" {
  command = plan

  variables {
    projects = {
      "platform/api" = {
        kubernetes_agents = { prod = {} }
        files             = { ".gitlab/agents/prod/config.yaml" = { content = "ci_access: {}\n" } }
      }
    }
  }

  expect_failures = [
    var.projects,
  ]
}
