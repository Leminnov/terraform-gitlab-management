locals {
  # Regex shared across validation blocks.
  date_regex = "^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])(T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2}))?$"

  # Canonical enum sets — kept in one place so token-style validations stay
  # in sync if GitLab adds new values.
  access_token_levels = [
    "no_one", "minimal", "guest", "reporter",
    "developer", "maintainer", "owner",
  ]

  access_token_scopes = [
    "api", "read_api", "read_user", "read_repository", "write_repository",
    "read_registry", "write_registry", "sudo", "admin_mode",
    "create_runner", "manage_runner", "ai_features", "k8s_proxy", "self_rotate",
  ]

  deploy_token_scopes = [
    "read_repository", "read_registry", "write_registry",
    "read_package_registry", "write_package_registry",
    "read_virtual_registry", "write_virtual_registry",
  ]
}

variable "group_variables" {
  description = <<-EOT
    Map of GitLab group CI/CD variables. Each entry is expanded across its `groups` list, producing one `gitlab_group_variable` per (entry, group). Fields:
      - key            : Variable key as it appears in GitLab.
      - groups         : Group paths or IDs to create this variable in. Must be non-empty.
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

  validation {
    condition = alltrue([
      for v in values(var.group_variables) :
      length(v.groups) > 0
    ])
    error_message = "group_variables[*].groups must be a non-empty list."
  }

  validation {
    condition = alltrue([
      for v in values(var.group_variables) :
      length(v.key) > 0 && can(regex("^[A-Za-z_][A-Za-z0-9_]*$", v.key))
    ])
    error_message = "group_variables[*].key must match [A-Za-z_][A-Za-z0-9_]* (GitLab CI variable naming rule)."
  }
}

variable "project_variables" {
  description = <<-EOT
    Map of GitLab project CI/CD variables. Each entry is expanded across its `projects` list. Fields:
      - key            : Variable key as it appears in GitLab.
      - projects       : Project paths or IDs to create this variable in. Must be non-empty.
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

  validation {
    condition = alltrue([
      for v in values(var.project_variables) :
      length(v.projects) > 0
    ])
    error_message = "project_variables[*].projects must be a non-empty list."
  }

  validation {
    condition = alltrue([
      for v in values(var.project_variables) :
      length(v.key) > 0 && can(regex("^[A-Za-z_][A-Za-z0-9_]*$", v.key))
    ])
    error_message = "project_variables[*].key must match [A-Za-z_][A-Za-z0-9_]* (GitLab CI variable naming rule)."
  }
}

variable "deploy_tokens" {
  description = <<-EOT
    Map of GitLab group deploy tokens. Each entry is expanded across its `groups` list. Fields:
      - groups      : Group paths or IDs to create the token in. Must be non-empty.
      - name        : Human-readable token name.
      - username    : Optional token username.
      - expires_at  : Optional expiration timestamp (YYYY-MM-DD or ISO-8601).
      - scopes      : Token scopes. Must be non-empty; see `_deploy_token_scopes` in locals for allowed values.
  EOT
  type = map(object({
    groups     = list(string)
    name       = string
    username   = optional(string)
    expires_at = optional(string)
    scopes     = list(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for v in values(var.deploy_tokens) :
      length(v.groups) > 0
    ])
    error_message = "deploy_tokens[*].groups must be a non-empty list."
  }

  validation {
    condition = alltrue([
      for v in values(var.deploy_tokens) :
      length(v.scopes) > 0
    ])
    error_message = "deploy_tokens[*].scopes must be a non-empty list."
  }

  validation {
    condition = alltrue([
      for v in values(var.deploy_tokens) :
      v.expires_at == null || can(regex(local.date_regex, v.expires_at))
    ])
    error_message = "deploy_tokens[*].expires_at must be in YYYY-MM-DD or ISO-8601 format."
  }

  validation {
    condition = alltrue(flatten([
      for v in values(var.deploy_tokens) : [
        for s in v.scopes : contains(local.deploy_token_scopes, s)
      ]
    ]))
    error_message = "deploy_tokens[*].scopes entries must be one of: read_repository, read_registry, write_registry, read_package_registry, write_package_registry, read_virtual_registry, write_virtual_registry."
  }

  validation {
    condition = alltrue([
      for v in values(var.deploy_tokens) :
      length(v.name) > 0
    ])
    error_message = "deploy_tokens[*].name must be non-empty."
  }
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

  validation {
    condition = alltrue([
      for v in values(var.pipeline_schedules) :
      length(v.project) > 0 && length(v.ref) > 0 && length(v.cron) > 0
    ])
    error_message = "pipeline_schedules[*].project, ref, and cron must all be non-empty."
  }

  validation {
    # Loose cron sanity: five whitespace-separated fields.
    condition = alltrue([
      for v in values(var.pipeline_schedules) :
      length(split(" ", trimspace(v.cron))) == 5
    ])
    error_message = "pipeline_schedules[*].cron must have exactly 5 whitespace-separated fields (minute hour day month weekday)."
  }
}

variable "gitlab_runners" {
  description = <<-EOT
    Map of GitLab runner registrations (gitlab_user_runner). Fields:
      - runner_type     : "group_type", "project_type", or "instance_type".
      - description     : Human-readable description.
      - group_id        : Group ID (required when runner_type == "group_type").
      - project_id      : Project ID (required when runner_type == "project_type").
      - access_level    : "not_protected" or "ref_protected".
      - tag_list        : Runner tags. Required to be non-empty when `untagged = false`.
      - maximum_timeout : Optional max job timeout in seconds (min 600).
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

  validation {
    condition = alltrue([
      for v in values(var.gitlab_runners) :
      v.runner_type != "group_type" || v.group_id != null
    ])
    error_message = "gitlab_runners[*].group_id is required when runner_type == group_type."
  }

  validation {
    condition = alltrue([
      for v in values(var.gitlab_runners) :
      v.runner_type != "project_type" || v.project_id != null
    ])
    error_message = "gitlab_runners[*].project_id is required when runner_type == project_type."
  }

  validation {
    condition = alltrue([
      for v in values(var.gitlab_runners) :
      v.untagged == true || length(v.tag_list) > 0
    ])
    error_message = "gitlab_runners[*].tag_list must be non-empty unless untagged == true."
  }

  validation {
    condition = alltrue([
      for v in values(var.gitlab_runners) :
      v.maximum_timeout == null || v.maximum_timeout >= 600
    ])
    error_message = "gitlab_runners[*].maximum_timeout must be null or >= 600 (GitLab minimum)."
  }
}

variable "gitlab_group_access_token" {
  description = <<-EOT
    Map of GitLab group access tokens. Each entry is expanded across its `groups` list. Fields:
      - groups        : Group paths or IDs to create the token in. Must be non-empty.
      - name          : Human-readable token name.
      - expires_at    : Required expiration date (YYYY-MM-DD or ISO-8601). GitLab disallows perpetual tokens.
      - access_level  : One of no_one, minimal, guest, reporter, developer, maintainer, owner.
      - scopes        : Token scopes. Must be non-empty.
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
      v.access_level == null || contains(local.access_token_levels, v.access_level)
    ])
    error_message = "gitlab_group_access_token[*].access_level must be one of: no_one, minimal, guest, reporter, developer, maintainer, owner."
  }

  validation {
    condition = alltrue([
      for v in values(var.gitlab_group_access_token) :
      can(regex(local.date_regex, v.expires_at))
    ])
    error_message = "gitlab_group_access_token[*].expires_at must be in YYYY-MM-DD or ISO-8601 format."
  }

  validation {
    condition = alltrue([
      for v in values(var.gitlab_group_access_token) :
      length(v.groups) > 0 && length(v.scopes) > 0 && length(v.name) > 0
    ])
    error_message = "gitlab_group_access_token[*] must have non-empty groups, scopes, and name."
  }

  validation {
    condition = alltrue(flatten([
      for v in values(var.gitlab_group_access_token) : [
        for s in v.scopes : contains(local.access_token_scopes, s)
      ]
    ]))
    error_message = "gitlab_group_access_token[*].scopes entries must be one of the known GitLab access token scopes."
  }
}

variable "gitlab_project_access_token" {
  description = <<-EOT
    Map of GitLab project access tokens. Each entry is expanded across its `projects` list. Fields:
      - projects      : Project paths or IDs to create the token in. Must be non-empty.
      - name          : Human-readable token name.
      - expires_at    : Required expiration date (YYYY-MM-DD or ISO-8601).
      - access_level  : One of no_one, minimal, guest, reporter, developer, maintainer, owner.
      - scopes        : Token scopes. Must be non-empty.
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
      v.access_level == null || contains(local.access_token_levels, v.access_level)
    ])
    error_message = "gitlab_project_access_token[*].access_level must be one of: no_one, minimal, guest, reporter, developer, maintainer, owner."
  }

  validation {
    condition = alltrue([
      for v in values(var.gitlab_project_access_token) :
      can(regex(local.date_regex, v.expires_at))
    ])
    error_message = "gitlab_project_access_token[*].expires_at must be in YYYY-MM-DD or ISO-8601 format."
  }

  validation {
    condition = alltrue([
      for v in values(var.gitlab_project_access_token) :
      length(v.projects) > 0 && length(v.scopes) > 0 && length(v.name) > 0
    ])
    error_message = "gitlab_project_access_token[*] must have non-empty projects, scopes, and name."
  }

  validation {
    condition = alltrue(flatten([
      for v in values(var.gitlab_project_access_token) : [
        for s in v.scopes : contains(local.access_token_scopes, s)
      ]
    ]))
    error_message = "gitlab_project_access_token[*].scopes entries must be one of the known GitLab access token scopes."
  }
}
