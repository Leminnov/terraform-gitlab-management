#!/usr/bin/env bash
# Release helper. Two entry points:
#
#   scripts/release.sh prepare <major|minor|patch|X.Y.Z> [--push] [--skip-checks]
#       Run on main, which may carry local commits not yet pushed. Turns
#       "## [Unreleased]" in CHANGELOG.md into "## [X.Y.Z] - <today>", commits
#       "Release vX.Y.Z" and creates an annotated tag whose message is
#       the release notes. It also points every "?ref=vX.Y.Z" in README.md and
#       examples/*.md at the new tag. With --push it pushes main (including any
#       local commits) and the tag atomically, then merges main back into
#       develop when that branch exists on the remote.
#
#   scripts/release.sh check <vX.Y.Z>
#       Used by the tag pipeline (verify:changelog): the tag is on main and
#       CHANGELOG.md has a dated non-empty section for it. Any annotated tag
#       meeting both is releasable, whether or not `prepare` created it; a
#       README example still pinning an older tag is reported as a warning.
#
# Environment: RELEASE_BRANCH (default main), DEVELOP_BRANCH (default develop),
# RELEASE_REMOTE (default: the release branch's upstream remote, else origin).
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

RELEASE_BRANCH=${RELEASE_BRANCH:-main}
DEVELOP_BRANCH=${DEVELOP_BRANCH:-develop}
SEMVER='^[0-9]+\.[0-9]+\.[0-9]+$'

die() {
  echo "release: error: $*" >&2
  exit 1
}
info() { echo "release: $*"; }
warn() { echo "release: warning: $*" >&2; }

remote() {
  if [ -n "${RELEASE_REMOTE:-}" ]; then
    echo "$RELEASE_REMOTE"
    return
  fi
  local up
  up=$(git rev-parse --abbrev-ref "$RELEASE_BRANCH@{upstream}" 2>/dev/null || true)
  echo "${up%%/*}" | grep . || echo origin
}

# Prints nothing (and succeeds) when the repository has no vX.Y.Z tag yet:
# under pipefail the failing grep would otherwise abort the first release.
latest_tag() { git tag -l 'v*.*.*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1 || true; }

next_version() { # $1 = major|minor|patch|X.Y.Z, $2 = latest tag
  local bump=$1 cur=${2#v} ma mi pa
  if [[ $bump =~ $SEMVER ]]; then
    echo "$bump"
    return
  fi
  [ -n "$cur" ] || die "no previous vX.Y.Z tag: pass an explicit version"
  IFS=. read -r ma mi pa <<<"$cur"
  case $bump in
    major) echo "$((ma + 1)).0.0" ;;
    minor) echo "$ma.$((mi + 1)).0" ;;
    patch) echo "$ma.$mi.$((pa + 1))" ;;
    *) die "version must be major, minor, patch or X.Y.Z (got '$bump')" ;;
  esac
}

readme_refs_ok() { # every "?ref=vX.Y.Z" in the READMEs of revision $2 (default: working tree) points to $1
  local bad
  bad=$(git grep -hoE '\?ref=v[0-9]+\.[0-9]+\.[0-9]+' ${2:+"$2"} -- README.md 'examples/*.md' | sed 's/^[^:]*://' | sort -u | grep -vxF "?ref=$1" || true)
  [ -z "$bad" ] || { echo "$bad" | sed 's/^/  /' >&2; return 1; }
}

cmd_check() {
  local tag=${1:?usage: release.sh check vX.Y.Z}
  [[ $tag =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "tag '$tag' is not vX.Y.Z"
  local sha
  sha=$(git rev-list -n1 "$tag")

  # On a CI checkout only the tag is present: fetch the release branch.
  git fetch -q "$(remote)" "$RELEASE_BRANCH" 2>/dev/null || die "cannot fetch $RELEASE_BRANCH"
  git merge-base --is-ancestor "$sha" FETCH_HEAD ||
    die "$tag ($sha) is not on $RELEASE_BRANCH. Tag the release on $RELEASE_BRANCH (scripts/release.sh prepare)."

  # Judge the tagged content, not the working tree.
  local changelog
  changelog=$(mktemp)
  trap 'rm -f "$changelog"' RETURN
  git show "$tag:CHANGELOG.md" >"$changelog"
  CHANGELOG=$changelog CHANGELOG_LABEL="CHANGELOG.md@$tag" scripts/changelog.sh verify "$tag"
  readme_refs_ok "$tag" "$tag" || warn "README examples at $tag still reference another tag (see above); the release proceeds"
  info "$tag is releasable"
}

# Merge the release branch back into develop so the two lines do not diverge.
# Skipped when the remote has no develop branch; a conflict is left to a human.
back_merge() {
  local rem=$1
  if ! git ls-remote --exit-code --heads "$rem" "$DEVELOP_BRANCH" >/dev/null 2>&1; then
    info "no $DEVELOP_BRANCH branch on $rem: skipping the back-merge"
    return
  fi
  info "back-merging $RELEASE_BRANCH into $DEVELOP_BRANCH"
  git fetch -q "$rem" "$DEVELOP_BRANCH"
  if git show-ref -q --verify "refs/heads/$DEVELOP_BRANCH"; then
    git checkout -q "$DEVELOP_BRANCH"
    git merge -q --ff-only "$rem/$DEVELOP_BRANCH" ||
      die "local $DEVELOP_BRANCH has diverged from $rem/$DEVELOP_BRANCH: reconcile it, then merge $RELEASE_BRANCH into it by hand"
  else
    git checkout -q --track "$rem/$DEVELOP_BRANCH"
  fi
  if git merge -q --no-edit "$RELEASE_BRANCH"; then
    git push -q "$rem" "$DEVELOP_BRANCH"
  else
    git merge --abort
    git checkout -q "$RELEASE_BRANCH"
    warn "$RELEASE_BRANCH does not merge cleanly into $DEVELOP_BRANCH: resolve it by hand (the release itself is published)"
    return
  fi
  git checkout -q "$RELEASE_BRANCH"
}

cmd_prepare() {
  local want="" push=false checks=true
  for a in "$@"; do
    case $a in
      --push) push=true ;;
      --skip-checks) checks=false ;;
      -*) die "unknown option $a" ;;
      *) want=$a ;;
    esac
  done
  [ -n "$want" ] || die "usage: release.sh prepare <major|minor|patch|X.Y.Z> [--push] [--skip-checks]"

  local rem branch
  rem=$(remote)
  branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
  [ "$branch" = "$RELEASE_BRANCH" ] || die "run on $RELEASE_BRANCH (currently on '${branch:-detached HEAD}'): the tag must be on $RELEASE_BRANCH"
  git diff --quiet && git diff --cached --quiet || die "working tree has uncommitted changes"

  # The release commit is made on the release branch, so a local
  # protected-branch hook must not stand in the way.
  export SKIP="${SKIP:+$SKIP,}no-commit-to-branch"

  info "fetching $rem"
  git fetch -q --tags "$rem"
  if git rev-parse -q --verify "refs/remotes/$rem/$RELEASE_BRANCH" >/dev/null; then
    git merge-base --is-ancestor "$rem/$RELEASE_BRANCH" HEAD ||
      die "$RELEASE_BRANCH is behind $rem/$RELEASE_BRANCH: pull first"
    local ahead
    ahead=$(git rev-list --count "$rem/$RELEASE_BRANCH..HEAD")
    [ "$ahead" -eq 0 ] || info "$ahead local commit(s) on $RELEASE_BRANCH will be pushed with the tag"
  else
    info "$rem has no $RELEASE_BRANCH yet: it will be created on push"
  fi

  local last version tag
  last=$(latest_tag)
  version=$(next_version "$want" "$last")
  tag="v$version"
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null && die "$tag already exists"
  if [ -n "$last" ] && [ "$(printf '%s\n%s\n' "${last#v}" "$version" | sort -V | tail -n1)" != "$version" ]; then
    die "$tag is not greater than the latest tag $last"
  fi

  grep -qxF '## [Unreleased]' CHANGELOG.md || die "CHANGELOG.md has no '## [Unreleased]' section"
  local unreleased
  unreleased=$(awk 'index($0,"## [Unreleased]")==1{f=1;next} f&&/^## \[/{exit} f' CHANGELOG.md)
  printf '%s' "$unreleased" | grep -q '[^[:space:]]' || die "the Unreleased section of CHANGELOG.md is empty: nothing to release"

  info "releasing $tag (previous: ${last:-none})"
  if $checks; then
    info "running local gates: pre-commit + unit tests + spec validation (skip with --skip-checks)"
    pre-commit run -a
    tofu test
    openspec validate --all --strict
  fi

  local today
  today=$(date +%Y-%m-%d)
  awk -v v="$version" -v d="$today" '
    $0 == "## [Unreleased]" && !done { print; print ""; print "## [" v "] - " d; done = 1; next }
    { print }' CHANGELOG.md >CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
  git ls-files -z README.md 'examples/*.md' | xargs -0 sed -i -E "s/\?ref=v[0-9]+\.[0-9]+\.[0-9]+/?ref=$tag/g"

  scripts/changelog.sh verify "$tag"
  readme_refs_ok "$tag" || die "README reference update failed"

  git add CHANGELOG.md README.md examples
  git commit -q -m "Release $tag"
  # verbatim: the default cleanup would strip the "### ..." Markdown headings as comments.
  scripts/changelog.sh notes "$tag" | git tag -s --cleanup=verbatim "$tag" -F -
  info "created commit $(git rev-parse --short HEAD) and annotated tag $tag"

  if $push; then
    info "pushing $RELEASE_BRANCH and $tag to $rem"
    git push --atomic "$rem" "$RELEASE_BRANCH" "$tag"
    back_merge "$rem"
    info "done: the tag pipeline will verify and publish $tag"
  else
    cat <<MSG
release: review with:  git show --stat HEAD && git tag -n20 -l $tag
release: then publish: git push --atomic $rem $RELEASE_BRANCH $tag
release:        and:   git checkout $DEVELOP_BRANCH && git merge $RELEASE_BRANCH && git push $rem $DEVELOP_BRANCH
release: to undo before pushing: git tag -d $tag && git reset --hard HEAD~1
MSG
  fi
}

case ${1:-} in
  prepare)
    shift
    cmd_prepare "$@"
    ;;
  check)
    shift
    cmd_check "$@"
    ;;
  *)
    echo "usage: $0 prepare <major|minor|patch|X.Y.Z> [--push] [--skip-checks] | check <vX.Y.Z>" >&2
    exit 2
    ;;
esac
