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
    { for k, v in local.group_access_tokens : "gitlab_group_access_token[\"${k}\"]" => "${v.expires_at}T00:00:00Z" if can(regex(local.day_regex, v.expires_at)) },
    { for k, v in local.project_access_tokens : "gitlab_project_access_token[\"${k}\"]" => "${v.expires_at}T00:00:00Z" if can(regex(local.day_regex, v.expires_at)) },
  )

  # 8784h = 366 days: one year (secrets-rotation) plus date granularity.
  long_lived_tokens = sort([for k, expiry in local.token_expiries : k if timecmp(expiry, timeadd(plantimestamp(), "8784h")) > 0])

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
