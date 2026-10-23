# Plan-time guardrails (terraform-security): configurations GitLab accepts but
# that weaken security. They warn and never block the apply, and their messages
# name the offending entries, never a value or a token.

locals {
  # Variable keys that usually hold a credential.
  secret_key_regex = "(?i)(TOKEN|PASSWORD|PASSWD|SECRET|PRIVATE_KEY|API_KEY|CREDENTIAL)"

  unprotected_secret_variables = sort(concat(
    [for k, v in local.group_variables : "group_variables[\"${k}\"] (${v.key})" if can(regex(local.secret_key_regex, v.key)) && !(v.masked && v.protected)],
    [for k, v in local.project_variables : "project_variables[\"${k}\"] (${v.key})" if can(regex(local.secret_key_regex, v.key)) && !(v.masked && v.protected)],
  ))

  # Token expiries as RFC 3339; entries with a malformed expiry are already
  # rejected by the validations in variables.tf and skipped here.
  token_expiries = merge(
    { for k, v in local.deploy_tokens : "deploy_tokens[\"${k}\"]" => v.expires_at if can(regex(local.rfc3339_regex, v.expires_at)) },
    { for k, v in local.project_deploy_tokens : "project_deploy_tokens[\"${k}\"]" => v.expires_at if can(regex(local.rfc3339_regex, v.expires_at)) },
    { for k, v in local.deploy_keys : "deploy_keys[\"${k}\"]" => v.expires_at if can(regex(local.rfc3339_regex, v.expires_at)) },
    { for k, v in local.group_access_tokens : "gitlab_group_access_token[\"${k}\"]" => "${v.expires_at}T00:00:00Z" if can(regex(local.day_regex, v.expires_at)) },
    { for k, v in local.project_access_tokens : "gitlab_project_access_token[\"${k}\"]" => "${v.expires_at}T00:00:00Z" if can(regex(local.day_regex, v.expires_at)) },
  )

  # 8784h = 366 days: one year (secrets-rotation) plus date granularity.
  long_lived_tokens = sort([for k, expiry in local.token_expiries : k if timecmp(expiry, timeadd(plantimestamp(), "8784h")) > 0])

  public_entries = sort(concat(
    [for k, v in var.groups : "groups[\"${k}\"]" if v.visibility == "public"],
    [for k, v in var.projects : "projects[\"${k}\"]" if v.visibility == "public"],
  ))

  hooks_without_tls_verification = sort(concat(
    [for k, h in local.project_hooks : "projects[\"${h.project_key}\"].hooks[\"${h.name}\"]" if !h.enable_ssl_verification],
    [for k, h in local.group_hooks : "groups[\"${h.group_key}\"].hooks[\"${h.name}\"]" if !h.enable_ssl_verification],
  ))

  writable_deploy_keys = sort([for k, d in local.deploy_keys : "projects[\"${d.project_key}\"].deploy_keys[\"${d.title}\"]" if d.can_push])

  protected_branches_with_force_push = sort([
    for b in values(local.project_protected_branches) : "projects[\"${b.project}\"].protected_branches[\"${b.branch}\"]" if b.allow_force_push
  ])

  # GitLab grants maintainer when access_level is unset.
  privileged_access_tokens = sort(concat(
    [for k, v in local.group_access_tokens : "gitlab_group_access_token[\"${k}\"]" if v.access_level == null || v.access_level == "owner"],
    [for k, v in local.project_access_tokens : "gitlab_project_access_token[\"${k}\"]" if v.access_level == null || v.access_level == "owner"],
  ))
}

check "secret_variables_masked_and_protected" {
  assert {
    condition     = length(local.unprotected_secret_variables) == 0
    error_message = "CI variables whose key looks like a secret are not both masked and protected: ${join(", ", local.unprotected_secret_variables)}. Set masked = true and protected = true."
  }
}

check "token_lifetime" {
  assert {
    condition     = length(local.long_lived_tokens) == 0
    error_message = "Tokens expiring more than one year after this plan: ${join(", ", local.long_lived_tokens)}. Set expires_at at most one year ahead and rotate before it."
  }
}

check "access_token_privilege" {
  assert {
    condition     = length(local.privileged_access_tokens) == 0
    error_message = "Access tokens with access_level owner, or unset so that GitLab grants maintainer: ${join(", ", local.privileged_access_tokens)}. Set the lowest access_level that works."
  }
}

check "protected_branch_force_push" {
  assert {
    condition     = length(local.protected_branches_with_force_push) == 0
    error_message = "Protected branches allowing force push: ${join(", ", local.protected_branches_with_force_push)}. Set allow_force_push = false; history on shared branches is never rewritten (git-history)."
  }
}

check "public_visibility" {
  assert {
    condition     = length(local.public_entries) == 0
    error_message = "Public groups or projects: ${join(", ", local.public_entries)}. Public visibility exposes the code and CI configuration to everyone; keep it only after an explicit review (gitlab-project-settings)."
  }
}

check "webhook_ssl_verification" {
  assert {
    condition     = length(local.hooks_without_tls_verification) == 0
    error_message = "Webhooks without TLS verification: ${join(", ", local.hooks_without_tls_verification)}. Set enable_ssl_verification = true and give the endpoint a valid certificate."
  }
}

check "deploy_key_write_access" {
  assert {
    condition     = length(local.writable_deploy_keys) == 0
    error_message = "Deploy keys with write access: ${join(", ", local.writable_deploy_keys)}. Set can_push = false unless the machine must push, and protect the branches it pushes to."
  }
}
