locals {
  # Expiry formats, as the provider parses them: deploy tokens take an RFC 3339
  # timestamp only, access tokens a YYYY-MM-DD date only.
  day_regex     = "^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$"
  rfc3339_regex = "^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$"

  # Enum sets copied from the gitlabhq/gitlab 19.5 schema, kept in one place so
  # the validations follow the provider when GitLab adds values.
  access_token_levels = [
    "no one", "minimal", "guest", "planner", "reporter",
    "security_manager", "developer", "maintainer", "owner",
  ]

  project_access_token_scopes = [
    "api", "read_api", "read_registry", "write_registry",
    "read_repository", "write_repository", "create_runner", "manage_runner",
    "ai_features", "k8s_proxy", "read_observability", "write_observability",
    "self_rotate",
  ]

  # Group tokens also reach the group's virtual registries.
  group_access_token_scopes = concat(local.project_access_token_scopes, [
    "read_virtual_registry", "write_virtual_registry",
  ])

  # GitLab path rule for one segment of a group or project path; the endings
  # ., .git and .atom are rejected separately.
  path_segment_regex = "^[A-Za-z0-9_][A-Za-z0-9_.-]*$"
  visibility_order   = ["private", "internal", "public"]

  # Who may push, merge or create tags on a protected branch or tag.
  protection_access_levels = ["no one", "developer", "maintainer", "admin"]

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
      - value          : Variable value. Redacted in plan output but stored in state (SECURITY.md); pass secrets from TF_VAR_* or a secret store, never from a committed file.
      - variable_type  : "env_var" (default) or "file".
      - protected      : Expose only to protected refs. Default false.
      - masked         : Mask the value in job logs. Default false; the check secret_variables_masked_and_protected warns when a secret-looking key is not masked and protected.
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

  validation {
    condition     = alltrue([for k in keys(var.group_variables) : !strcontains(k, ":")])
    error_message = "group_variables keys must not contain \":\" (reserved for objects nested in groups and projects)."
  }
}

variable "project_variables" {
  description = <<-EOT
    Map of GitLab project CI/CD variables. Each entry is expanded across its `projects` list. Fields:
      - key            : Variable key as it appears in GitLab.
      - projects       : Project paths or IDs to create this variable in. Must be non-empty.
      - value          : Variable value. Redacted in plan output but stored in state (SECURITY.md); pass secrets from TF_VAR_* or a secret store, never from a committed file.
      - variable_type  : "env_var" (default) or "file".
      - protected      : Expose only to protected refs. Default false.
      - masked         : Mask the value in job logs. Default false; the check secret_variables_masked_and_protected warns when a secret-looking key is not masked and protected.
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

  validation {
    condition     = alltrue([for k in keys(var.project_variables) : !strcontains(k, ":")])
    error_message = "project_variables keys must not contain \":\" (reserved for objects nested in groups and projects)."
  }
}

variable "deploy_tokens" {
  description = <<-EOT
    Map of GitLab group deploy tokens. Each entry is expanded across its `groups` list. Fields:
      - groups      : Group paths or IDs to create the token in. Must be non-empty.
      - name        : Human-readable token name.
      - username    : Optional token username; null lets GitLab generate gitlab+deploy-token-<n>.
      - expires_at  : Required expiry, an RFC 3339 timestamp such as 2027-06-30T00:00:00Z (the provider rejects a bare date), at most one year ahead (see the token_lifetime check); without one the token would never expire.
      - scopes      : Token scopes, non-empty: read_repository, read_registry, write_registry, read_package_registry, write_package_registry, read_virtual_registry, write_virtual_registry.
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
      can(regex(local.rfc3339_regex, v.expires_at)) # false for null too: an expiry is required
    ])
    error_message = "deploy_tokens[*].expires_at is required, as an RFC 3339 timestamp (for example 2027-06-30T00:00:00Z)."
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

  validation {
    condition     = alltrue([for k in keys(var.deploy_tokens) : !strcontains(k, ":")])
    error_message = "deploy_tokens keys must not contain \":\" (reserved for objects nested in groups and projects)."
  }
}

variable "pipeline_schedules" {
  description = <<-EOT
    Map of GitLab pipeline schedules. Fields:
      - project      : Project path or ID.
      - description  : Schedule description.
      - ref          : Full git ref to run against: refs/heads/<branch> or refs/tags/<tag> (provider 19.4+ rejects a short name such as main).
      - cron         : Cron expression with 5 fields (e.g. "0 2 * * *"), in the schedule's time zone (GitLab default UTC).
      - active       : Whether the schedule is active.
      - variables    : Optional map of pipeline variables keyed by variable name. Values are redacted in plan output but stored in state (SECURITY.md).
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
    condition = alltrue([
      for v in values(var.pipeline_schedules) :
      can(regex("^refs/(heads|tags)/.+", v.ref))
    ])
    error_message = "pipeline_schedules[*].ref must be a full git ref: refs/heads/<branch> or refs/tags/<tag>."
  }

  validation {
    # Loose cron sanity: five whitespace-separated fields.
    condition = alltrue([
      for v in values(var.pipeline_schedules) :
      length(split(" ", trimspace(v.cron))) == 5
    ])
    error_message = "pipeline_schedules[*].cron must have exactly 5 whitespace-separated fields (minute hour day month weekday)."
  }

  validation {
    condition     = alltrue([for k in keys(var.pipeline_schedules) : !strcontains(k, ":")])
    error_message = "pipeline_schedules keys must not contain \":\" (reserved for objects nested in groups and projects)."
  }
}

variable "gitlab_runners" {
  description = <<-EOT
    Map of GitLab runner registrations (gitlab_user_runner). Fields:
      - runner_type     : "group_type", "project_type", or "instance_type".
      - description     : Human-readable description.
      - group_id        : Numeric group ID, not a path (required when runner_type == "group_type").
      - project_id      : Numeric project ID, not a path (required when runner_type == "project_type").
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
      (v.group_id == null || can(regex("^[0-9]+$", v.group_id))) && (v.project_id == null || can(regex("^[0-9]+$", v.project_id)))
    ])
    error_message = "gitlab_runners[*].group_id and project_id must be numeric IDs, not paths."
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

  validation {
    condition     = alltrue([for k in keys(var.gitlab_runners) : !strcontains(k, ":")])
    error_message = "gitlab_runners keys must not contain \":\" (reserved for objects nested in groups and projects)."
  }
}

variable "gitlab_group_access_token" {
  description = <<-EOT
    Map of GitLab group access tokens. Each entry is expanded across its `groups` list. Fields:
      - groups        : Group paths or IDs to create the token in. Must be non-empty.
      - name          : Human-readable token name.
      - expires_at    : Required expiry date, YYYY-MM-DD, within the instance's maximum token lifetime.
      - access_level  : One of no one, minimal, guest, planner, reporter, security_manager, developer, maintainer, owner; null lets GitLab grant maintainer.
      - scopes        : Token scopes, non-empty: api, read_api, read_registry, write_registry, read_virtual_registry, write_virtual_registry, read_repository, write_repository, create_runner, manage_runner, ai_features, k8s_proxy, read_observability, write_observability, self_rotate.
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
    error_message = "gitlab_group_access_token[*].access_level must be one of: ${join(", ", local.access_token_levels)}."
  }

  validation {
    condition = alltrue([
      for v in values(var.gitlab_group_access_token) :
      can(regex(local.day_regex, v.expires_at))
    ])
    error_message = "gitlab_group_access_token[*].expires_at must be a date in YYYY-MM-DD format."
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
        for s in v.scopes : contains(local.group_access_token_scopes, s)
      ]
    ]))
    error_message = "gitlab_group_access_token[*].scopes entries must be one of: ${join(", ", local.group_access_token_scopes)}."
  }

  validation {
    condition     = alltrue([for k in keys(var.gitlab_group_access_token) : !strcontains(k, ":")])
    error_message = "gitlab_group_access_token keys must not contain \":\" (reserved for objects nested in groups and projects)."
  }
}

variable "gitlab_project_access_token" {
  description = <<-EOT
    Map of GitLab project access tokens. Each entry is expanded across its `projects` list. Fields:
      - projects      : Project paths or IDs to create the token in. Must be non-empty.
      - name          : Human-readable token name.
      - expires_at    : Required expiry date, YYYY-MM-DD, within the instance's maximum token lifetime.
      - access_level  : One of no one, minimal, guest, planner, reporter, security_manager, developer, maintainer, owner; null lets GitLab grant maintainer.
      - scopes        : Token scopes, non-empty: api, read_api, read_registry, write_registry, read_repository, write_repository, create_runner, manage_runner, ai_features, k8s_proxy, read_observability, write_observability, self_rotate.
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
    error_message = "gitlab_project_access_token[*].access_level must be one of: ${join(", ", local.access_token_levels)}."
  }

  validation {
    condition = alltrue([
      for v in values(var.gitlab_project_access_token) :
      can(regex(local.day_regex, v.expires_at))
    ])
    error_message = "gitlab_project_access_token[*].expires_at must be a date in YYYY-MM-DD format."
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
        for s in v.scopes : contains(local.project_access_token_scopes, s)
      ]
    ]))
    error_message = "gitlab_project_access_token[*].scopes entries must be one of: ${join(", ", local.project_access_token_scopes)}."
  }

  validation {
    condition     = alltrue([for k in keys(var.gitlab_project_access_token) : !strcontains(k, ":")])
    error_message = "gitlab_project_access_token keys must not contain \":\" (reserved for objects nested in groups and projects)."
  }
}

# -----------------------------------------------------------------------------
# Group and project tree created under parent_group_id
# -----------------------------------------------------------------------------

variable "parent_group_id" {
  description = "Numeric ID of the existing group under which groups and projects are created (gitlab.com does not let the provider create top-level groups). Required when either is declared."
  type        = number
  default     = null

  validation {
    condition     = var.parent_group_id != null || (length(var.groups) == 0 && length(var.projects) == 0)
    error_message = "parent_group_id is required when groups or projects are declared."
  }
}

variable "groups" {
  description = <<-EOT
    Groups to create under parent_group_id, keyed by their path relative to it: "platform", "platform/infra", ... up to 7 levels. The parent of a key (all segments but the last) must be declared too. Fields:
      - name                              : Display name; default the last path segment.
      - description                       : Optional description.
      - visibility                        : private (default), internal or public; never more open than the parent group's.
      - default_branch                    : Initial default branch of new projects in the group; default main.
      - project_creation_level            : Who can create projects: noone, owner, maintainer (default), developer, administrator.
      - subgroup_creation_level           : Who can create subgroups: owner (default) or maintainer.
      - request_access_enabled            : Let users request access; default false.
      - require_two_factor_authentication : Require two-factor authentication for members; null keeps the GitLab default.
      - archive_on_destroy                : Archive the group instead of deleting it on destroy; default true.
      - permanently_remove_on_delete      : With archive_on_destroy = false, remove the group at once instead of scheduling the deletion; default false.
      - variables     : CI/CD variables keyed by variable key: value, variable_type (env_var default, file), protected and masked (default false). Values are redacted in plans and stored in state (SECURITY.md).
      - deploy_tokens : Deploy tokens keyed by name: username (null: GitLab generates one), expires_at (required, RFC 3339), scopes (read_repository, read_registry, write_registry, read_package_registry, write_package_registry, read_virtual_registry, write_virtual_registry).
      - access_tokens : Access tokens keyed by name: expires_at (required, YYYY-MM-DD), access_level (null lets GitLab grant maintainer), scopes.
      - members       : User memberships keyed by any label: user_id, access_level (no one, minimal, guest, planner, reporter, security_manager, developer, maintainer, owner), expires_at (YYYY-MM-DD; null: no expiry).
      - shared_with   : Shares keyed by any label: exactly one of group (a groups key) or group_id (an existing group ID), access_level, expires_at (YYYY-MM-DD; null: no expiry).
      - runners       : Runners keyed by name: description (default the name), access_level (ref_protected default, not_protected), tag_list (required unless untagged), untagged, paused, locked, maximum_timeout (seconds, >= 600; null: no runner limit).
      - labels        : Labels keyed by name: color (#RRGGBB or a CSS colour name), description.
      - badges        : Badges keyed by name: link_url and image_url (http(s); GitLab placeholders such as %%{project_path} allowed, written with a doubled % in HCL strings).
      - hooks         : Premium. Group webhooks keyed by name, with the fields of projects[*].hooks plus subgroup_events and project_events (default false).
  EOT
  type = map(object({
    name                              = optional(string)
    description                       = optional(string)
    visibility                        = optional(string, "private")
    default_branch                    = optional(string, "main")
    project_creation_level            = optional(string, "maintainer")
    subgroup_creation_level           = optional(string, "owner")
    request_access_enabled            = optional(bool, false)
    require_two_factor_authentication = optional(bool)
    archive_on_destroy                = optional(bool, true)
    permanently_remove_on_delete      = optional(bool, false)
    variables = optional(map(object({
      value         = string
      variable_type = optional(string, "env_var")
      protected     = optional(bool, false)
      masked        = optional(bool, false)
    })), {})
    deploy_tokens = optional(map(object({
      username   = optional(string)
      expires_at = optional(string)
      scopes     = list(string)
    })), {})
    access_tokens = optional(map(object({
      expires_at   = string
      access_level = optional(string)
      scopes       = list(string)
    })), {})
    members = optional(map(object({
      user_id      = number
      access_level = string
      expires_at   = optional(string)
    })), {})
    shared_with = optional(map(object({
      group        = optional(string)
      group_id     = optional(number)
      access_level = string
      expires_at   = optional(string)
    })), {})
    runners = optional(map(object({
      description     = optional(string)
      access_level    = optional(string, "ref_protected")
      tag_list        = optional(list(string), [])
      untagged        = optional(bool, false)
      paused          = optional(bool, false)
      locked          = optional(bool, false)
      maximum_timeout = optional(number)
    })), {})
    labels = optional(map(object({
      color       = string
      description = optional(string)
    })), {})
    badges = optional(map(object({
      link_url  = string
      image_url = string
    })), {})
    # Premium
    hooks = optional(map(object({
      url                     = string
      push_events             = optional(bool, true)
      tag_push_events         = optional(bool, false)
      merge_requests_events   = optional(bool, false)
      pipeline_events         = optional(bool, false)
      job_events              = optional(bool, false)
      deployment_events       = optional(bool, false)
      releases_events         = optional(bool, false)
      issues_events           = optional(bool, false)
      note_events             = optional(bool, false)
      enable_ssl_verification = optional(bool, true)
      token                   = optional(string)
      signing_token           = optional(string)
      subgroup_events         = optional(bool, false)
      project_events          = optional(bool, false)
    })), {})
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for k in keys(var.groups) : [
        length(split("/", k)) <= 7,
        [for seg in split("/", k) : can(regex(local.path_segment_regex, seg)) && !endswith(seg, ".") && !endswith(seg, ".git") && !endswith(seg, ".atom")],
      ]
    ]))
    error_message = "groups keys must have 1 to 7 segments of letters, digits, _, - and ., not starting with - or . and not ending with ., .git or .atom."
  }

  validation {
    condition = alltrue([
      for k in keys(var.groups) :
      length(split("/", k)) == 1 || contains(keys(var.groups), join("/", slice(split("/", k), 0, length(split("/", k)) - 1)))
    ])
    error_message = "Every groups key with a parent path needs that parent in groups: declare each intermediate group."
  }

  validation {
    condition = alltrue([
      for v in values(var.groups) : contains(["private", "internal", "public"], v.visibility)
    ])
    error_message = "groups[*].visibility must be one of: private, internal, public."
  }

  validation {
    # p binds the parent key; compared only when both visibilities are valid
    # (another rule reports the others).
    condition = alltrue(flatten([
      for k, v in var.groups : [
        for p in [join("/", slice(split("/", k), 0, length(split("/", k)) - 1))] :
        !contains(keys(var.groups), p) ? true : (
          contains(local.visibility_order, v.visibility) && contains(local.visibility_order, var.groups[p].visibility)
          ? index(local.visibility_order, v.visibility) <= index(local.visibility_order, var.groups[p].visibility)
          : true
        )
      ]
    ]))
    error_message = "A group's visibility cannot be more open than its parent's (private < internal < public)."
  }

  validation {
    condition = alltrue([
      for v in values(var.groups) : contains(["noone", "owner", "maintainer", "developer", "administrator"], v.project_creation_level)
    ])
    error_message = "groups[*].project_creation_level must be one of: noone, owner, maintainer, developer, administrator."
  }

  validation {
    condition = alltrue([
      for v in values(var.groups) : contains(["owner", "maintainer"], v.subgroup_creation_level)
    ])
    error_message = "groups[*].subgroup_creation_level must be one of: owner, maintainer."
  }

  validation {
    condition     = alltrue([for v in values(var.groups) : !(v.archive_on_destroy && v.permanently_remove_on_delete)])
    error_message = "groups[*].permanently_remove_on_delete requires archive_on_destroy = false."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for k in keys(o.variables) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k))]]))
    error_message = "variables keys must match [A-Za-z_][A-Za-z0-9_]* (GitLab CI variable naming rule)."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for v in values(o.variables) : contains(["env_var", "file"], v.variable_type)]]))
    error_message = "variables[*].variable_type must be one of: env_var, file."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for t in values(o.deploy_tokens) : can(regex(local.rfc3339_regex, t.expires_at))]]))
    error_message = "deploy_tokens[*].expires_at is required, as an RFC 3339 timestamp (for example 2027-06-30T00:00:00Z)."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for t in values(o.deploy_tokens) : length(t.scopes) > 0 && alltrue([for sc in t.scopes : contains(local.deploy_token_scopes, sc)])]]))
    error_message = "deploy_tokens[*].scopes must be non-empty, each one of: ${join(", ", local.deploy_token_scopes)}."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for t in values(o.access_tokens) : can(regex(local.day_regex, t.expires_at))]]))
    error_message = "access_tokens[*].expires_at must be a date in YYYY-MM-DD format."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for t in values(o.access_tokens) : t.access_level == null || contains(local.access_token_levels, t.access_level)]]))
    error_message = "access_tokens[*].access_level must be one of: ${join(", ", local.access_token_levels)}."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for t in values(o.access_tokens) : length(t.scopes) > 0 && alltrue([for sc in t.scopes : contains(local.group_access_token_scopes, sc)])]]))
    error_message = "access_tokens[*].scopes of group tokens must be non-empty, each one of: ${join(", ", local.group_access_token_scopes)}."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for m in values(o.members) : contains(local.access_token_levels, m.access_level)]]))
    error_message = "members[*].access_level must be one of: ${join(", ", local.access_token_levels)}."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for m in values(o.members) : m.expires_at == null || can(regex(local.day_regex, m.expires_at))]]))
    error_message = "members[*].expires_at must be a date in YYYY-MM-DD format."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for sh in values(o.shared_with) : (sh.group == null) != (sh.group_id == null) && (sh.group == null || contains(keys(var.groups), coalesce(sh.group, "-")))]]))
    error_message = "shared_with[*] must set exactly one of group (a groups key) or group_id."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for sh in values(o.shared_with) : contains(local.access_token_levels, sh.access_level) && (sh.expires_at == null || can(regex(local.day_regex, sh.expires_at)))]]))
    error_message = "shared_with[*].access_level must be one of: ${join(", ", local.access_token_levels)}, and expires_at a YYYY-MM-DD date."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for r in values(o.runners) : contains(["not_protected", "ref_protected"], r.access_level)]]))
    error_message = "runners[*].access_level must be one of: not_protected, ref_protected."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for r in values(o.runners) : r.untagged || length(r.tag_list) > 0]]))
    error_message = "runners[*].tag_list must be non-empty unless untagged == true."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for r in values(o.runners) : r.maximum_timeout == null || coalesce(r.maximum_timeout, 0) >= 600]]))
    error_message = "runners[*].maximum_timeout must be null or >= 600 (GitLab minimum)."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for l in values(o.labels) : can(regex("^(#[0-9A-Fa-f]{6}|[A-Za-z]+)$", l.color))]]))
    error_message = "labels[*].color must be #RRGGBB or a CSS colour name."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for b in values(o.badges) : can(regex("^https?://", b.link_url)) && can(regex("^https?://", b.image_url))]]))
    error_message = "badges[*] link_url and image_url must start with http:// or https://."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.groups) : [for h in values(o.hooks) : can(regex("^https?://", h.url))]]))
    error_message = "hooks[*].url must start with http:// or https://."
  }
}

variable "projects" {
  description = <<-EOT
    Projects to create, keyed by their path relative to parent_group_id: "tools" is created directly under it, "platform/infra/api" in the created group "platform/infra". Fields:
      - name                    : Display name; default the last path segment.
      - description             : Optional description.
      - visibility              : private (default), internal or public; never more open than its group's.
      - topics                  : Optional set of topics.
      - default_branch          : Default branch, created with a README commit; default main.
      - initialize_with_readme  : Create the default branch with a README commit; default true. Must stay true for branches to be created.
      - branches                : Extra branches keyed by name, each from ref (default: the default branch); default { develop = {} }.
      - protected_branches      : Protected branches or wildcards keyed by name, with push_access_level and merge_access_level (no one, developer, maintainer (default), admin) and allow_force_push (default false). Default: the default branch for maintainers, plus develop for developers when it is in branches. Premium: code_owner_approval_required, not sent unless set.
      - protected_tags          : Protected tags or wildcards keyed by name, with create_access_level (no one, developer, maintainer (default), admin); default { "v*" = {} }.
      - merge_method            : merge (default), rebase_merge or ff.
      - squash_option           : never, always, default_on (default) or default_off.
      - only_allow_merge_if_pipeline_succeeds            : Merge only on a green pipeline; default true.
      - only_allow_merge_if_all_discussions_are_resolved : Merge only with every thread resolved; default true.
      - remove_source_branch_after_merge                 : Delete the source branch on merge by default; default true.
      - archive_on_destroy            : Archive the project instead of deleting it on destroy; default true.
      - permanently_delete_on_destroy : With archive_on_destroy = false, delete the project at once instead of scheduling the deletion; default false.
      - variables     : CI/CD variables keyed by variable key: value, variable_type (env_var default, file), protected and masked (default false). Values are redacted in plans and stored in state (SECURITY.md).
      - deploy_tokens : Deploy tokens keyed by name: username (null: GitLab generates one), expires_at (required, RFC 3339), scopes (read_repository, read_registry, write_registry, read_package_registry, write_package_registry, read_virtual_registry, write_virtual_registry).
      - access_tokens : Access tokens keyed by name: expires_at (required, YYYY-MM-DD), access_level (null lets GitLab grant maintainer), scopes.
      - members       : User memberships keyed by any label: user_id, access_level (no one, minimal, guest, planner, reporter, security_manager, developer, maintainer, owner), expires_at (YYYY-MM-DD; null: no expiry).
      - shared_with   : Shares keyed by any label: exactly one of group (a groups key) or group_id (an existing group ID), access_level, expires_at (YYYY-MM-DD; null: no expiry).
      - runners       : Runners keyed by name: description (default the name), access_level (ref_protected default, not_protected), tag_list (required unless untagged), untagged, paused, locked, maximum_timeout (seconds, >= 600; null: no runner limit).
      - deploy_keys         : SSH deploy keys keyed by title: key (OpenSSH public key), expires_at (required, RFC 3339), can_push (default false).
      - pipeline_schedules  : Schedules keyed by description: ref (full ref, default refs/heads/<default_branch>), cron (5 fields), active (default true), variables (redacted in plans).
      - pipeline_triggers   : Set of pipeline trigger descriptions; their tokens are in the pipeline_trigger_tokens output.
      - environments        : Environments keyed by name: tier (production, staging, testing, development, other; null: GitLab infers it from the name), external_url, description.
      - labels              : Labels keyed by name: color (#RRGGBB or a CSS colour name), description, priority (>= 0).
      - badges              : Badges keyed by name: link_url and image_url (http(s); GitLab placeholders such as %%{project_path} allowed, written with a doubled % in HCL strings).
      - hooks               : Webhooks keyed by name: url (http(s)), push_events (default true), tag_push_events, merge_requests_events, pipeline_events, job_events, deployment_events, releases_events, issues_events, note_events (default false), enable_ssl_verification (default true), token and signing_token (redacted in plans, stored in state).
      - approval_rules          : Premium. Approval rules keyed by name: approvals_required (>= 0), user_ids, group_ids, applies_to_all_protected_branches (default true).
      - merge_request_approvals : Premium. When set: reset_approvals_on_push (default true), merge_requests_author_approval (default false), merge_requests_disable_committers_approval and disable_overriding_approvers_per_merge_request (default true).
      - push_rules              : Premium. When set: prevent_secrets, deny_delete_tag and member_check (default true), reject_unsigned_commits, commit_message_regex, branch_name_regex, author_email_regex, max_file_size (MB); null keeps GitLab's default (off, no limit).
      - protected_environments  : Premium. Protected environments keyed by a name declared in environments: deploy_access_level (developer or maintainer (default)), required_approvals (null: deploys need no approval).
      - job_token_allowlist : When set, only the job tokens of this project and of the listed projects and groups (keys of projects / groups, or existing project_ids / group_ids) may access the project; null leaves GitLab's default.
  EOT
  type = map(object({
    name                   = optional(string)
    description            = optional(string)
    visibility             = optional(string, "private")
    topics                 = optional(set(string))
    default_branch         = optional(string, "main")
    initialize_with_readme = optional(bool, true)
    branches = optional(map(object({
      ref = optional(string)
    })), { develop = {} })
    protected_branches = optional(map(object({
      push_access_level  = optional(string, "maintainer")
      merge_access_level = optional(string, "maintainer")
      allow_force_push   = optional(bool, false)
      # Premium
      code_owner_approval_required = optional(bool)
    })))
    protected_tags = optional(map(object({
      create_access_level = optional(string, "maintainer")
    })), { "v*" = {} })
    merge_method                                     = optional(string, "merge")
    squash_option                                    = optional(string, "default_on")
    only_allow_merge_if_pipeline_succeeds            = optional(bool, true)
    only_allow_merge_if_all_discussions_are_resolved = optional(bool, true)
    remove_source_branch_after_merge                 = optional(bool, true)
    archive_on_destroy                               = optional(bool, true)
    permanently_delete_on_destroy                    = optional(bool, false)
    variables = optional(map(object({
      value         = string
      variable_type = optional(string, "env_var")
      protected     = optional(bool, false)
      masked        = optional(bool, false)
    })), {})
    deploy_tokens = optional(map(object({
      username   = optional(string)
      expires_at = optional(string)
      scopes     = list(string)
    })), {})
    access_tokens = optional(map(object({
      expires_at   = string
      access_level = optional(string)
      scopes       = list(string)
    })), {})
    members = optional(map(object({
      user_id      = number
      access_level = string
      expires_at   = optional(string)
    })), {})
    shared_with = optional(map(object({
      group        = optional(string)
      group_id     = optional(number)
      access_level = string
      expires_at   = optional(string)
    })), {})
    runners = optional(map(object({
      description     = optional(string)
      access_level    = optional(string, "ref_protected")
      tag_list        = optional(list(string), [])
      untagged        = optional(bool, false)
      paused          = optional(bool, false)
      locked          = optional(bool, false)
      maximum_timeout = optional(number)
    })), {})
    labels = optional(map(object({
      color       = string
      description = optional(string)
      priority    = optional(number)
    })), {})
    badges = optional(map(object({
      link_url  = string
      image_url = string
    })), {})
    hooks = optional(map(object({
      url                     = string
      push_events             = optional(bool, true)
      tag_push_events         = optional(bool, false)
      merge_requests_events   = optional(bool, false)
      pipeline_events         = optional(bool, false)
      job_events              = optional(bool, false)
      deployment_events       = optional(bool, false)
      releases_events         = optional(bool, false)
      issues_events           = optional(bool, false)
      note_events             = optional(bool, false)
      enable_ssl_verification = optional(bool, true)
      token                   = optional(string)
      signing_token           = optional(string)
    })), {})
    # Premium
    approval_rules = optional(map(object({
      approvals_required                = number
      user_ids                          = optional(set(number), [])
      group_ids                         = optional(set(number), [])
      applies_to_all_protected_branches = optional(bool, true)
    })), {})
    merge_request_approvals = optional(object({
      reset_approvals_on_push                        = optional(bool, true)
      merge_requests_author_approval                 = optional(bool, false)
      merge_requests_disable_committers_approval     = optional(bool, true)
      disable_overriding_approvers_per_merge_request = optional(bool, true)
    }))
    push_rules = optional(object({
      prevent_secrets         = optional(bool, true)
      deny_delete_tag         = optional(bool, true)
      member_check            = optional(bool, true)
      reject_unsigned_commits = optional(bool)
      commit_message_regex    = optional(string)
      branch_name_regex       = optional(string)
      author_email_regex      = optional(string)
      max_file_size           = optional(number)
    }))
    protected_environments = optional(map(object({
      deploy_access_level = optional(string, "maintainer")
      required_approvals  = optional(number)
    })), {})
    deploy_keys = optional(map(object({
      key        = string
      expires_at = optional(string)
      can_push   = optional(bool, false)
    })), {})
    pipeline_schedules = optional(map(object({
      ref       = optional(string)
      cron      = string
      active    = optional(bool, true)
      variables = optional(map(string), {})
    })), {})
    pipeline_triggers = optional(set(string), [])
    environments = optional(map(object({
      tier         = optional(string)
      external_url = optional(string)
      description  = optional(string)
    })), {})
    job_token_allowlist = optional(object({
      projects    = optional(set(string), [])
      groups      = optional(set(string), [])
      project_ids = optional(set(number), [])
      group_ids   = optional(set(number), [])
    }))
  }))
  default = {}

  validation {
    # ns binds the namespace part of the key ("" directly under parent_group_id).
    condition = alltrue(flatten([
      for k in keys(var.projects) : [
        for ns in [join("/", slice(split("/", k), 0, length(split("/", k)) - 1))] : [
          length(split("/", k)) <= 8,
          ns == "" || contains(keys(var.groups), ns),
          [for seg in [element(split("/", k), length(split("/", k)) - 1)] : can(regex(local.path_segment_regex, seg)) && !endswith(seg, ".") && !endswith(seg, ".git") && !endswith(seg, ".atom")],
        ]
      ]
    ]))
    error_message = "projects keys must be <group key>/<path> with the group declared in groups, or a single <path> under parent_group_id."
  }

  validation {
    condition     = alltrue([for v in values(var.projects) : contains(["private", "internal", "public"], v.visibility)])
    error_message = "projects[*].visibility must be one of: private, internal, public."
  }

  validation {
    # Compared only when the group is declared and both visibilities are valid.
    condition = alltrue(flatten([
      for k, v in var.projects : [
        for ns in [join("/", slice(split("/", k), 0, length(split("/", k)) - 1))] :
        !contains(keys(var.groups), ns) ? true : (
          contains(local.visibility_order, v.visibility) && contains(local.visibility_order, var.groups[ns].visibility)
          ? index(local.visibility_order, v.visibility) <= index(local.visibility_order, var.groups[ns].visibility)
          : true
        )
      ]
    ]))
    error_message = "A project's visibility cannot be more open than its group's (private < internal < public)."
  }

  validation {
    condition     = alltrue([for v in values(var.projects) : contains(["merge", "rebase_merge", "ff"], v.merge_method)])
    error_message = "projects[*].merge_method must be one of: merge, rebase_merge, ff."
  }

  validation {
    condition     = alltrue([for v in values(var.projects) : contains(["never", "always", "default_on", "default_off"], v.squash_option)])
    error_message = "projects[*].squash_option must be one of: never, always, default_on, default_off."
  }

  validation {
    condition     = alltrue([for v in values(var.projects) : v.initialize_with_readme || length(v.branches) == 0])
    error_message = "projects[*].branches must be empty when initialize_with_readme = false (no commit to branch from)."
  }

  validation {
    condition = alltrue(flatten([
      for v in values(var.projects) : [
        for b in values(coalesce(v.protected_branches, {})) : [
          contains(local.protection_access_levels, b.push_access_level),
          contains(local.protection_access_levels, b.merge_access_level),
        ]
      ]
    ]))
    error_message = "projects[*].protected_branches[*] access levels must be one of: no one, developer, maintainer, admin."
  }

  validation {
    condition = alltrue(flatten([
      for v in values(var.projects) : [for t in values(v.protected_tags) : contains(local.protection_access_levels, t.create_access_level)]
    ]))
    error_message = "projects[*].protected_tags[*].create_access_level must be one of: no one, developer, maintainer, admin."
  }

  validation {
    condition     = alltrue([for v in values(var.projects) : !(v.archive_on_destroy && v.permanently_delete_on_destroy)])
    error_message = "projects[*].permanently_delete_on_destroy requires archive_on_destroy = false."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for k in keys(o.variables) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k))]]))
    error_message = "variables keys must match [A-Za-z_][A-Za-z0-9_]* (GitLab CI variable naming rule)."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for v in values(o.variables) : contains(["env_var", "file"], v.variable_type)]]))
    error_message = "variables[*].variable_type must be one of: env_var, file."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for t in values(o.deploy_tokens) : can(regex(local.rfc3339_regex, t.expires_at))]]))
    error_message = "deploy_tokens[*].expires_at is required, as an RFC 3339 timestamp (for example 2027-06-30T00:00:00Z)."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for t in values(o.deploy_tokens) : length(t.scopes) > 0 && alltrue([for sc in t.scopes : contains(local.deploy_token_scopes, sc)])]]))
    error_message = "deploy_tokens[*].scopes must be non-empty, each one of: ${join(", ", local.deploy_token_scopes)}."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for t in values(o.access_tokens) : can(regex(local.day_regex, t.expires_at))]]))
    error_message = "access_tokens[*].expires_at must be a date in YYYY-MM-DD format."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for t in values(o.access_tokens) : t.access_level == null || contains(local.access_token_levels, t.access_level)]]))
    error_message = "access_tokens[*].access_level must be one of: ${join(", ", local.access_token_levels)}."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for t in values(o.access_tokens) : length(t.scopes) > 0 && alltrue([for sc in t.scopes : contains(local.project_access_token_scopes, sc)])]]))
    error_message = "access_tokens[*].scopes of project tokens must be non-empty, each one of: ${join(", ", local.project_access_token_scopes)}."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for m in values(o.members) : contains(local.access_token_levels, m.access_level)]]))
    error_message = "members[*].access_level must be one of: ${join(", ", local.access_token_levels)}."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for m in values(o.members) : m.expires_at == null || can(regex(local.day_regex, m.expires_at))]]))
    error_message = "members[*].expires_at must be a date in YYYY-MM-DD format."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for sh in values(o.shared_with) : (sh.group == null) != (sh.group_id == null) && (sh.group == null || contains(keys(var.groups), coalesce(sh.group, "-")))]]))
    error_message = "shared_with[*] must set exactly one of group (a groups key) or group_id."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for sh in values(o.shared_with) : contains(local.access_token_levels, sh.access_level) && (sh.expires_at == null || can(regex(local.day_regex, sh.expires_at)))]]))
    error_message = "shared_with[*].access_level must be one of: ${join(", ", local.access_token_levels)}, and expires_at a YYYY-MM-DD date."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for r in values(o.runners) : contains(["not_protected", "ref_protected"], r.access_level)]]))
    error_message = "runners[*].access_level must be one of: not_protected, ref_protected."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for r in values(o.runners) : r.untagged || length(r.tag_list) > 0]]))
    error_message = "runners[*].tag_list must be non-empty unless untagged == true."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for r in values(o.runners) : r.maximum_timeout == null || coalesce(r.maximum_timeout, 0) >= 600]]))
    error_message = "runners[*].maximum_timeout must be null or >= 600 (GitLab minimum)."
  }
  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for d in values(o.deploy_keys) : can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-[a-z0-9-]+|sk-[a-z0-9@.-]+) [A-Za-z0-9+/=]+", d.key))]]))
    error_message = "deploy_keys[*].key must be an OpenSSH public key (ssh-ed25519, ssh-rsa, ecdsa-sha2-*, sk-*)."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for d in values(o.deploy_keys) : can(regex(local.rfc3339_regex, d.expires_at))]]))
    error_message = "deploy_keys[*].expires_at is required, as an RFC 3339 timestamp."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for sc in values(o.pipeline_schedules) : sc.ref == null || can(regex("^refs/(heads|tags)/.+", coalesce(sc.ref, "-")))]]))
    error_message = "pipeline_schedules[*].ref must be a full git ref: refs/heads/<branch> or refs/tags/<tag>."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for sc in values(o.pipeline_schedules) : length(split(" ", trimspace(sc.cron))) == 5]]))
    error_message = "pipeline_schedules[*].cron must have exactly 5 whitespace-separated fields (minute hour day month weekday)."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for d in o.pipeline_triggers : trimspace(d) != ""]]))
    error_message = "pipeline_triggers entries must be non-empty descriptions."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for e in values(o.environments) : e.tier == null || contains(["production", "staging", "testing", "development", "other"], coalesce(e.tier, "-"))]]))
    error_message = "environments[*].tier must be one of: production, staging, testing, development, other."
  }

  validation {
    condition = alltrue(flatten([
      for o in values(var.projects) : o.job_token_allowlist == null ? [true] : concat(
        [for p in o.job_token_allowlist.projects : contains(keys(var.projects), p)],
        [for g in o.job_token_allowlist.groups : contains(keys(var.groups), g)],
      )
    ]))
    error_message = "job_token_allowlist projects and groups must be keys of projects and groups."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for l in values(o.labels) : can(regex("^(#[0-9A-Fa-f]{6}|[A-Za-z]+)$", l.color))]]))
    error_message = "labels[*].color must be #RRGGBB or a CSS colour name."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for b in values(o.badges) : can(regex("^https?://", b.link_url)) && can(regex("^https?://", b.image_url))]]))
    error_message = "badges[*] link_url and image_url must start with http:// or https://."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for l in values(o.labels) : l.priority == null || coalesce(l.priority, 0) >= 0]]))
    error_message = "labels[*].priority must be null or >= 0."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for h in values(o.hooks) : can(regex("^https?://", h.url))]]))
    error_message = "hooks[*].url must start with http:// or https://."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for r in values(o.approval_rules) : r.approvals_required >= 0]]))
    error_message = "approval_rules[*].approvals_required must be >= 0."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for e in keys(o.protected_environments) : contains(keys(o.environments), e)]]))
    error_message = "protected_environments keys must be declared in the project's environments."
  }

  validation {
    condition     = alltrue(flatten([for o in values(var.projects) : [for e in values(o.protected_environments) : contains(["developer", "maintainer"], e.deploy_access_level) && (e.required_approvals == null || coalesce(e.required_approvals, 0) >= 0)]]))
    error_message = "protected_environments[*].deploy_access_level must be developer or maintainer, and required_approvals null or >= 0."
  }
}
