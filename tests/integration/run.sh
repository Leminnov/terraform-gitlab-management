#!/usr/bin/env bash
# Integration test of the module against a real GitLab (terraform-testing).
#
#   MODE=owner   tests/integration/run.sh   every resource type, owner token
#   MODE=least   tests/integration/run.sh   the Maintainer subset, least-privilege token
#   MODE=upgrade tests/integration/run.sh   v12.0.0 state upgraded to this module
#
# Environment:
#   GITLAB_TOKEN         token of the mode (owner, or Maintainer for MODE=least)
#   GITLAB_BASE_URL      API URL, default https://gitlab.com/api/v4/
#   SANDBOX_GROUP_ID     numeric ID of the sandbox group
#   SANDBOX_PROJECT_ID   numeric ID of a project in it, with a main branch
#   RUN_SUFFIX           optional, default CI_PIPELINE_ID or the epoch
#
# owner/least: plan (the secret sentinel must not appear in the output), apply,
# server-side assertions with the created tokens, empty second plan, destroy,
# then the destroyed deploy token must be revoked. upgrade: apply v12.0.0 on
# provider 18.11, plan this module on 19.5 and require the deploy token that
# already had an expiry to be moved without replacement and the undated one to
# be replaced once, apply, empty second plan, destroy. Everything is destroyed
# on exit, also on failure. No token is ever printed or passed as an argument.
set -euo pipefail

mode=${MODE:?set MODE to owner, least or upgrade}
: "${GITLAB_TOKEN:?set GITLAB_TOKEN (see TESTING.md)}"
group_id=${SANDBOX_GROUP_ID:?set SANDBOX_GROUP_ID}
project_id=${SANDBOX_PROJECT_ID:?set SANDBOX_PROJECT_ID}
export GITLAB_BASE_URL=${GITLAB_BASE_URL:-https://gitlab.com/api/v4/}
api_url=${GITLAB_BASE_URL%/}
suffix=$(printf '%s' "${RUN_SUFFIX:-${CI_PIPELINE_ID:-$(date +%s)}}" | tr -c 'a-zA-Z0-9-' '-')
suffix="$mode-${suffix%-}"

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$root/tests/integration
work=$(mktemp -d)
export TF_IN_AUTOMATION=1 TF_INPUT=0 TF_DATA_DIR=$work/.terraform
# Same value for every plan of the run, about a month ahead (token_lifetime).
expires_on=$(date -u -d '+30 days' +%Y-%m-%d 2>/dev/null || date -u -v+30d +%Y-%m-%d)
sentinel="it-sentinel-$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')"
export TF_VAR_sentinel=$sentinel TF_VAR_group_id=$group_id TF_VAR_project_id=$project_id \
  TF_VAR_suffix=$suffix TF_VAR_expires_on=$expires_on

log() { echo "integration[$mode]: $*"; }
fail() {
  echo "integration[$mode]: FAIL: $*" >&2
  exit 1
}

# GET on the API with the token held in the variable named $1; the header is
# read from stdin, so the token is never in an argument list.
api_as() {
  local var=$1 path=$2
  printf 'header = "PRIVATE-TOKEN: %s"\n' "${!var}" | curl --config - -fsS "$api_url/$path"
}
api() { api_as GITLAB_TOKEN "$1"; }

# Reads field $2 of key $3 of the sensitive output $1 into stdout, for capture.
output_field() {
  tofu -chdir="$dir" output -json "$1" | python3 -I -c '
import json, sys
print(json.load(sys.stdin)[sys.argv[2]][sys.argv[1]])' "$2" "$3"
}

dir=$fixture
state=$work/terraform.tfstate
destroyed=false
cleanup() {
  local rc=$?
  if ! $destroyed && [ -f "$state" ]; then
    log "destroying"
    tofu -chdir="$dir" destroy -auto-approve -no-color >/dev/null || {
      echo "integration[$mode]: destroy failed, clean up resources suffixed $suffix by hand" >&2
      rc=1
    }
  fi
  rm -rf "$work"
  exit "$rc"
}
trap cleanup EXIT

init() { tofu -chdir="$dir" init -no-color -backend-config="path=$state" >/dev/null; }

# Plans to $work/plan.bin; the human-readable output must not contain the sentinel.
plan_redacted() {
  tofu -chdir="$dir" plan -no-color -out="$work/plan.bin" "$@" >"$work/plan.txt"
  ! grep -qF "$sentinel" "$work/plan.txt" || fail "a secret value appears in plan output"
  ! tofu -chdir="$dir" show -no-color "$work/plan.bin" | grep -qF "$sentinel" || fail "a secret value appears in tofu show"
}

second_plan_empty() {
  local rc=0
  tofu -chdir="$dir" plan -no-color -detailed-exitcode >"$work/plan2.txt" || rc=$?
  [ "$rc" -eq 0 ] || {
    sed -n '/will be\|must be/,+12p' "$work/plan2.txt" | grep -vF "$sentinel" >&2 || true
    fail "second plan is not empty (exit $rc)"
  }
  log "second plan empty"
}

run_apply_modes() {
  init
  plan_redacted -var "mode=$mode"
  log "plan redacts every secret value"
  tofu -chdir="$dir" apply -no-color -auto-approve "$work/plan.bin" >/dev/null
  log "applied"

  local key
  key=IT_SECRET_$(printf '%s' "$suffix" | tr 'a-z-' 'A-Z_')
  api "groups/$group_id/variables/$key" | python3 -I -c '
import json, sys
v = json.load(sys.stdin)
assert v["masked"] and v["protected"], "group variable is not masked and protected"
assert v["value"] == sys.argv[1], "group variable value differs from the input"' "$sentinel" ||
    fail "group variable check"
  log "group variable is masked, protected and holds the value"

  local schedule_id
  schedule_id=$(tofu -chdir="$dir" output -json pipeline_schedule_ids | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["nightly"])')
  api "projects/$project_id/pipeline_schedules/$schedule_id" | python3 -I -c '
import json, sys
s = json.load(sys.stdin)
assert s["ref"] == "refs/heads/main" and not s["active"], "schedule ref or state"
assert [v["key"] for v in s["variables"]] == ["IT_SCHEDULE_SECRET"], "schedule variables"' ||
    fail "pipeline schedule check"
  log "pipeline schedule and its variable exist"

  local repo_url k_dt
  repo_url=$(api "projects/$project_id" | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["http_url_to_repo"])')
  k_dt=registry_$group_id
  DEPLOY_USER=$(output_field deploy_tokens "$k_dt" username)
  DEPLOY_TOKEN=$(output_field deploy_tokens "$k_dt" token)
  export DEPLOY_USER DEPLOY_TOKEN
  deploy_ls() {
    # shellcheck disable=SC2016 # git expands the helper at run time, so the token stays out of argv
    git -c credential.helper= \
      -c 'credential.helper=!f() { echo "username=$DEPLOY_USER"; echo "password=$DEPLOY_TOKEN"; }; f' \
      ls-remote --heads "$repo_url" main >/dev/null 2>&1
  }
  deploy_ls || fail "the deploy token cannot read the sandbox project"
  log "deploy token reads the project"

  # shellcheck disable=SC2034 # read by api_as through ${!var}
  PROJECT_TOKEN=$(output_field project_access_tokens "bot_$project_id" token)
  api_as PROJECT_TOKEN "projects/$project_id" >/dev/null || fail "the project access token cannot read its project"
  log "project access token reads its project"
  if [ "$mode" = owner ]; then
    # shellcheck disable=SC2034 # read by api_as through ${!var}
    GROUP_TOKEN=$(output_field group_access_tokens "bot_$group_id" token)
    api_as GROUP_TOKEN "groups/$group_id" >/dev/null || fail "the group access token cannot read its group"
    log "group access token reads its group"
  fi

  tofu -chdir="$dir" output -json gitlab_runner_tokens | python3 -I -c '
import json, sys
assert json.load(sys.stdin)["runner"].startswith("glrt-"), "runner token"' || fail "runner token check"
  log "runner token issued"

  second_plan_empty

  tofu -chdir="$dir" destroy -auto-approve -no-color >/dev/null
  destroyed=true
  log "destroyed"
  # A rotation is complete only when the old value no longer works (secrets-rotation).
  sleep 5
  ! deploy_ls || fail "the deploy token still works after destroy"
  log "destroyed deploy token is revoked"
}

run_upgrade() {
  dir=$work/upgrade
  mkdir -p "$dir"
  cp "$fixture/upgrade/v12.tf.tpl" "$dir/main.tf"
  init
  tofu -chdir="$dir" apply -no-color -auto-approve >/dev/null
  log "applied v12.0.0 on provider 18.11"

  sed "s#@MODULE_DIR@#$root#" "$fixture/upgrade/v13.tf.tpl" >"$dir/main.tf"
  tofu -chdir="$dir" init -no-color -upgrade -backend-config="path=$state" >/dev/null
  tofu -chdir="$dir" plan -no-color -out="$work/plan.bin" >"$work/plan.txt"
  tofu -chdir="$dir" show -json "$work/plan.bin" | python3 -I -c '
import json, sys
group = sys.argv[1]
changes = {c["address"]: c for c in json.load(sys.stdin)["resource_changes"]}
base = "module.gitlab_management."
dated = changes[base + "gitlab_group_deploy_token.this[\"dated_%s\"]" % group]
undated = changes[base + "gitlab_group_deploy_token.this[\"undated_%s\"]" % group]
assert dated.get("previous_address") == base + "gitlab_deploy_token.this[\"dated_%s\"]" % group, "dated token not moved"
assert dated["change"]["actions"] in (["no-op"], ["update"]), "dated token: %s" % dated["change"]["actions"]
assert sorted(undated["change"]["actions"]) == ["create", "delete"], "undated token: %s" % undated["change"]["actions"]
others = [a for a, c in changes.items() if "delete" in c["change"]["actions"] and "undated_" not in a]
assert not others, "unexpected destroy: %s" % others
print("deploy token id after the move: " + str(dated["change"]["after"].get("id")))' "$group_id" ||
    fail "upgrade plan"
  log "upgrade plan: dated deploy token moved without replacement, undated one replaced"
  tofu -chdir="$dir" apply -no-color -auto-approve "$work/plan.bin" >/dev/null
  log "applied the upgrade"
  second_plan_empty
}

case $mode in
  owner | least) run_apply_modes ;;
  upgrade) run_upgrade ;;
  *) fail "MODE must be owner, least or upgrade" ;;
esac
log "PASS"
