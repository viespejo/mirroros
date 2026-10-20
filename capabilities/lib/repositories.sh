#!/usr/bin/bash
# shellcheck disable=SC2034 # The selected commit is consumed by capability steps.
declare -A CFG_REPOSITORIES=()

# shellcheck disable=SC2016 # HOME and Git paths belong to the selected user's Bash.
cfg_repository_sync() {
  local name="$1" remote="$2" branch="$3" relative="$4" key result commit outcome extra
  cfg_context
  [[ "$name" == nvim || "$name" == pi-config ]] || exit 6
  [[ "$remote" =~ ^https://github\.com/viespejo/[a-zA-Z0-9_-]+$ && "$branch" == master &&
    "$relative" =~ ^code/[a-zA-Z0-9_-]+$ ]] || exit 6
  key="$name:$remote:$branch:$relative"
  result="$(cfg_exec runuser -u "$TARGET_USER" -- env -u BASH_ENV -u ENV bash --noprofile --norc -s -- \
    "$name" "$remote" "$branch" "$relative" "${CFG_REPOSITORIES[$key]:-}" <<'BASH'
set -Eeuo pipefail
name=$1 remote=$2 branch=$3 relative=$4 selected=$5
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
fail() { printf '%s: %s; preserve local work and resolve manually before rerunning.\n' "$name" "$*" >&2; exit 4; }
git_at() { git --no-optional-locks -C "$dest" "$@"; }
dest="$HOME/$relative"
parent="$HOME"
IFS=/ read -r -a components <<< "$relative"
for component in "${components[@]}"; do
  parent="$parent/$component"
  [[ ! -L "$parent" ]] || fail "symbolic-link repository path"
  [[ ! -e "$parent" || -d "$parent" ]] || fail "conflicting repository path"
done
check_existing() {
  [[ -d "$dest/.git" && ! -L "$dest/.git" ]] || fail "expected a standalone Git clone"
  [[ "$(git_at rev-parse --show-toplevel)" == "$dest" ]] || fail "unexpected Git root"
  [[ "$(git_at remote get-url origin)" == "$remote" ]] || fail "unexpected origin remote"
  [[ "$(git_at symbolic-ref --short HEAD)" == "$branch" ]] || fail "unexpected branch; select $branch manually"
  local status
  status=$(git_at status --porcelain=v1 --untracked-files=all) || fail "cannot query repository status"
  [[ -z "$status" ]] || fail "modified or untracked repository files"
}
existing=0
if [[ -e "$dest" ]]; then
  check_existing
  existing=1
fi
if [[ -z "$selected" ]]; then
  resolved=$(git ls-remote --exit-code --heads "$remote" "refs/heads/$branch")
  IFS=$'\t' read -r selected ref <<< "$resolved"
  [[ "$ref" == "refs/heads/$branch" && "$selected" =~ ^[0-9a-f]{40}$ && "$resolved" != *$'\n'* ]] || fail "invalid selected branch identity"
fi
[[ "$selected" =~ ^[0-9a-f]{40}$ ]] || fail "invalid cached source identity"
outcome=unchanged
if (( existing )); then
  head=$(git_at rev-parse HEAD)
  if [[ "$head" != "$selected" ]]; then
    git_at fetch --no-tags origin "$selected" >&2
    git_at merge-base --is-ancestor "$head" "$selected" || fail "divergent or local-only history"
    check_existing
    [[ "$(git_at rev-parse HEAD)" == "$head" ]] || fail "repository changed during synchronization"
    git_at -c core.hooksPath=/dev/null merge --ff-only --no-edit --no-stat "$selected" >&2
    outcome=changed
  fi
else
  parent="$(dirname -- "$dest")"
  mkdir -p -- "$parent"
  staging=$(mktemp -d "$parent/.mirroros-$name.XXXXXXXX")
  printf '%s: preparing source in %s (retained on failure).\n' "$name" "$staging" >&2
  git init --quiet "$staging/repository" >&2
  git -C "$staging/repository" remote add origin "$remote" >&2
  git -C "$staging/repository" fetch --no-tags origin "$selected" >&2
  git -C "$staging/repository" -c core.hooksPath=/dev/null checkout -b "$branch" "$selected" >&2
  git -C "$staging/repository" config "branch.$branch.remote" origin
  git -C "$staging/repository" config "branch.$branch.merge" "refs/heads/$branch"
  [[ ! -e "$dest" && ! -L "$dest" ]] || fail "destination appeared during source preparation"
  mv -T --no-clobber -- "$staging/repository" "$dest"
  [[ ! -e "$staging/repository" ]] || fail "destination appeared during source publication"
  rmdir -- "$staging"
  outcome=changed
fi
check_existing
[[ "$(git_at rev-parse HEAD)" == "$selected" ]] || fail "selected commit postcondition failed"
printf '%s\t%s\n' "$selected" "$outcome"
BASH
  )"
  read -r commit outcome extra <<< "$result"
  [[ "$commit" =~ ^[0-9a-f]{40}$ && "$outcome" =~ ^(changed|unchanged)$ && -z "$extra" ]] || exit 6
  CFG_REPOSITORIES["$key"]="$commit"
  CFG_REPOSITORY_COMMIT="$commit"
  cfg_source_record "$name" "$remote" "$branch" "$commit" ''
  if [[ "$outcome" == changed ]]; then cfg_changed; fi
}
