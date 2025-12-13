terraform {
  required_version = ">= 1.10.7"
}

module "gitlab_variables" {
  source = "../"

  group_variables = {
    group_key_1 = {
      groups        = ["group_1", "group_2", "group_3"]
      value         = "group_value_1"
      variable_type = "env_var"
      protected     = false
      masked        = false
    }
  }

  project_variables = {
    project_key_1 = {
      projects      = ["project_1"]
      value         = "project_value_1"
      variable_type = "env_var"
      protected     = false
      masked        = false
    }
    project_key_2 = {
      projects      = ["project_1"]
      value         = "project_value_2"
      variable_type = "env_var"
      protected     = false
      masked        = true
    }
  }

  deploy_tokens = {

    token_1 = {
      groups     = ["group-id_1", "group-id_2", "group-id_3"]
      name       = "Example deploy token"
      username   = "example-username"
      expires_at = "2020-03-14T00:00:00.000Z"
      scopes     = ["read_repository", "read_registry"] // https://docs.gitlab.com/ee/user/project/deploy_tokens/#scope
    }

    token_2 = {
      groups = ["group-id_4"]
      name   = "Charts group deploy token"
      scopes = ["read_repository"] // https://docs.gitlab.com/ee/user/project/deploy_tokens/#scope
    }
  }
  gitlab_runners = {
    runner-group-1 = {
      runner_type     = "group_type"
      description     = "Runners for test"
      group_id        = "85956775"
      access_level    = "not_protected"
      tag_list        = ["runner1", "test"]
      maximum_timeout = 600 // at least 600 (10 minutes)
      paused          = false
      untagged        = false
      locked          = false
    }
    runner-group-2 = {
      runner_type     = "group_type"
      description     = "Runners for test"
      group_id        = "85969076"
      access_level    = "not_protected"
      tag_list        = ["runner2", "test"]
      maximum_timeout = 600 // at least 600 (10 minutes)
      paused          = false
      untagged        = false
      locked          = false
    }
    runner-project-1 = {
      runner_type     = "project_type"
      description     = "Runners for test"
      project_id      = "57045045"
      access_level    = "not_protected"
      tag_list        = ["runner3", "test"]
      maximum_timeout = 600 // at least 600 (10 minutes)
      paused          = false
      untagged        = false
      locked          = false
    }
  }

  gitlab_group_access_token = {
    gitlab-access-group-1 = {
      groups       = ["71068927", "71068928", "71068929"]
      name         = "cloud-group"
      expires_at   = "2025-12-12" //YYYY-MM-DD
      access_level = "maintainer"

      scopes = ["api", "read_api", "read_registry", "write_registry", "read_repository", "write_repository", "create_runner"]
    }
  }

  gitlab_project_access_token = {
    gitlab-access-project-1 = {
      projects     = ["71068927", "71068930", "71068931"]
      name         = "cloud-project"
      expires_at   = "2025-12-12" //YYYY-MM-DD
      access_level = "maintainer"

      scopes = ["api", "read_api", "read_registry", "write_registry", "read_repository", "write_repository", "create_runner"]
    }
  }
}
