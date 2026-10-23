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
      - protected_branches      : Protected branches or wildcards keyed by name, with push_access_level and merge_access_level (no one, developer, maintainer (default), admin) and allow_force_push (default false). Default: the default branch for maintainers, plus develop for developers when it is in branches.
      - protected_tags          : Protected tags or wildcards keyed by name, with create_access_level (no one, developer, maintainer (default), admin); default { "v*" = {} }.
      - merge_method            : merge (default), rebase_merge or ff.
      - squash_option           : never, always, default_on (default) or default_off.
      - only_allow_merge_if_pipeline_succeeds            : Merge only on a green pipeline; default true.
      - only_allow_merge_if_all_discussions_are_resolved : Merge only with every thread resolved; default true.
      - remove_source_branch_after_merge                 : Delete the source branch on merge by default; default true.
      - archive_on_destroy            : Archive the project instead of deleting it on destroy; default true.
      - permanently_delete_on_destroy : With archive_on_destroy = false, delete the project at once instead of scheduling the deletion; default false.
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
}
