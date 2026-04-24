variable "group_variables" {
  description = <<-EOT
    Map of GitLab group CI/CD variables. Each entry is expanded across its `groups` list, producing one `gitlab_group_variable` per (entry, group). Fields:
      - key            : Variable key as it appears in GitLab.
      - groups         : Group paths or IDs to create this variable in.
      - value          : Variable value.
      - variable_type  : "env_var" (default) or "file".
      - protected      : Expose only to protected refs. Default false.
      - masked         : Mask the value in job logs. Default false.
  EOT
  type = map(object({
    key           = string
    groups        = list(string)
    value         = string
    variable_type = optional(string, "env_var")
    protected     = optional(bool, false)
    masked        = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for v in values(var.group_variables) :
      contains(["env_var", "file"], v.variable_type)
    ])
    error_message = "group_variables[*].variable_type must be one of: env_var, file."
  }
}

variable "project_variables" {
  description = <<-EOT
    Map of GitLab project CI/CD variables. Each entry is expanded across its `projects` list. Fields:
      - key            : Variable key as it appears in GitLab.
      - projects       : Project paths or IDs to create this variable in.
      - value          : Variable value.
      - variable_type  : "env_var" (default) or "file".
      - protected      : Expose only to protected refs. Default false.
      - masked         : Mask the value in job logs. Default false.
  EOT
  type = map(object({
    key           = string
    projects      = list(string)
    value         = string
    variable_type = optional(string, "env_var")
    protected     = optional(bool, false)
    masked        = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for v in values(var.project_variables) :
      contains(["env_var", "file"], v.variable_type)
    ])
    error_message = "project_variables[*].variable_type must be one of: env_var, file."
  }
}

variable "deploy_tokens" {
  description = <<-EOT
    Map of GitLab group deploy tokens. Each entry is expanded across its `groups` list. Fields:
      - groups      : Group paths or IDs to create the token in.
      - name        : Human-readable token name.
      - username    : Optional token username.
      - expires_at  : Optional ISO-8601 expiration timestamp.
      - scopes      : Token scopes (e.g. read_repository, read_registry).
  EOT
  type = map(object({
    groups     = list(string)
    name       = string
    username   = optional(string)
    expires_at = optional(string)
    scopes     = list(string)
  }))
  default = {}
}

variable "pipeline_schedules" {
  description = <<-EOT
    Map of GitLab pipeline schedules. Fields:
      - project      : Project path or ID.
      - description  : Schedule description.
      - ref          : Git ref (branch/tag) to run against.
      - cron         : Cron expression (e.g. "0 2 * * *").
      - active       : Whether the schedule is active.
      - variables    : Optional map of pipeline variables keyed by variable name.
  EOT
  type = map(object({
    project     = string
    description = string
    ref         = string
    cron        = string
    active      = bool
    variables   = optional(map(string), {})
  }))
  default = {}
}

variable "gitlab_runners" {
  description = <<-EOT
    Map of GitLab runner registrations (gitlab_user_runner). Fields:
      - runner_type     : "group_type", "project_type", or "instance_type".
      - description     : Human-readable description.
      - group_id        : Group ID (required when runner_type == "group_type").
      - project_id      : Project ID (required when runner_type == "project_type").
      - access_level    : "not_protected" or "ref_protected".
      - tag_list        : Runner tags.
      - maximum_timeout : Optional max job timeout in seconds.
      - paused          : Whether the runner starts paused.
      - untagged        : Whether to run untagged jobs.
      - locked          : Whether the runner is locked to its project.
  EOT
  type = map(object({
    runner_type     = string
    description     = string
    group_id        = optional(string)
    project_id      = optional(string)
    access_level    = string
    tag_list        = list(string)
    maximum_timeout = optional(number)
    paused          = bool
    untagged        = bool
    locked          = bool
  }))
  default = {}

  validation {
    condition = alltrue([
      for v in values(var.gitlab_runners) :
      contains(["group_type", "project_type", "instance_type"], v.runner_type)
    ])
    error_message = "gitlab_runners[*].runner_type must be one of: group_type, project_type, instance_type."
  }

  validation {
    condition = alltrue([
      for v in values(var.gitlab_runners) :
      contains(["not_protected", "ref_protected"], v.access_level)
    ])
    error_message = "gitlab_runners[*].access_level must be one of: not_protected, ref_protected."
  }
}

variable "gitlab_group_access_token" {
  description = <<-EOT
    Map of GitLab group access tokens. Each entry is expanded across its `groups` list. Fields:
      - groups        : Group paths or IDs to create the token in.
      - name          : Human-readable token name.
      - expires_at    : ISO-8601 expiration date (required by GitLab).
      - access_level  : "no_one", "minimal", "guest", "reporter", "developer", "maintainer", "owner".
      - scopes        : Token scopes (e.g. api, read_api, read_repository).
  EOT
  type = map(object({
    groups       = list(string)
    name         = string
    expires_at   = string
    access_level = optional(string)
    scopes       = list(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for v in values(var.gitlab_group_access_token) :
      v.access_level == null || contains(
        ["no_one", "minimal", "guest", "reporter", "developer", "maintainer", "owner"],
        coalesce(v.access_level, "developer")
      )
    ])
    error_message = "gitlab_group_access_token[*].access_level must be one of: no_one, minimal, guest, reporter, developer, maintainer, owner."
  }
}

variable "gitlab_project_access_token" {
  description = <<-EOT
    Map of GitLab project access tokens. Each entry is expanded across its `projects` list. Fields:
      - projects      : Project paths or IDs to create the token in.
      - name          : Human-readable token name.
      - expires_at    : ISO-8601 expiration date (required by GitLab).
      - access_level  : "no_one", "minimal", "guest", "reporter", "developer", "maintainer", "owner".
      - scopes        : Token scopes (e.g. api, read_api, read_repository).
  EOT
  type = map(object({
    projects     = list(string)
    name         = string
    expires_at   = string
    access_level = optional(string)
    scopes       = list(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for v in values(var.gitlab_project_access_token) :
      v.access_level == null || contains(
        ["no_one", "minimal", "guest", "reporter", "developer", "maintainer", "owner"],
        coalesce(v.access_level, "developer")
      )
    ])
    error_message = "gitlab_project_access_token[*].access_level must be one of: no_one, minimal, guest, reporter, developer, maintainer, owner."
  }
}
