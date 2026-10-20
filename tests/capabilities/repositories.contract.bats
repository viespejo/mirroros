load support

setup() { cfg_test_setup; }
teardown() { cfg_test_teardown; }

repository_fixture() {
  mkdir -p "$CFG_TEST_HOME/code/nvim/.git"
  printf '%s\n' "${1:-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}" > "$CFG_TEST_HOME/code/nvim/.git/fixture-head"
  printf '%s\n' https://github.com/viespejo/nvim-lua-new > "$CFG_TEST_HOME/code/nvim/.git/fixture-remote"
  printf 'master\n' > "$CFG_TEST_HOME/code/nvim/.git/fixture-branch"
}

repository_sync() {
  cfg_test_helpers '
    source "$CAPABILITIES_DIR/lib/repositories.sh"
    cfg_repository_sync nvim https://github.com/viespejo/nvim-lua-new master code/nvim
  '
}

@test "absent repository is prepared as user from one resolved commit and records provenance" {
  run repository_sync
  [ "$status" -eq 0 ]
  [ "$(< "$CFG_TEST_HOME/code/nvim/.git/fixture-head")" = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb ]
  [ "$(grep -c '^git ls-remote ' "$CFG_TEST_CALLS")" -eq 1 ]
  grep -q '^runuser -u alice' "$CFG_TEST_CALLS"
  grep -q $'nvim\thttps://github.com/viespejo/nvim-lua-new\tmaster\tbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\t' "$CFG_TEST_DIR/helper-output/sources.tsv"
  [ -e "$CFG_TEST_DIR/helper-output/.changed" ]
  [ "$(find "$CFG_TEST_HOME/code" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1 ]
  ! grep -Eq '^pacman |^systemctl ' "$CFG_TEST_CALLS"
}

@test "satisfied checkout performs no fetch merge config or file mutation" {
  repository_fixture bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  before=$(stat -c '%i:%Y:%s' "$CFG_TEST_HOME/code/nvim/.git/fixture-head")
  run repository_sync
  [ "$status" -eq 0 ]
  [ ! -e "$CFG_TEST_DIR/helper-output/.changed" ]
  [ "$(stat -c '%i:%Y:%s' "$CFG_TEST_HOME/code/nvim/.git/fixture-head")" = "$before" ]
  ! grep -Eq '^git .* (fetch|merge|config) ' "$CFG_TEST_CALLS"
}

@test "clean ancestor advances only by fast-forward to the resolved commit" {
  repository_fixture
  run repository_sync
  [ "$status" -eq 0 ]
  grep -q 'merge --ff-only --no-edit --no-stat bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb$' "$CFG_TEST_CALLS"
  [ "$(< "$CFG_TEST_HOME/code/nvim/.git/fixture-head")" = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb ]
}

@test "dirty and untracked files fail before remote lookup without changing HEAD" {
  repository_fixture
  for state in ' M tracked-file' '?? untracked-file'; do
    printf '%s\n' "$state" > "$CFG_TEST_HOME/code/nvim/.git/fixture-status"
    : > "$CFG_TEST_CALLS"
    run repository_sync
    [ "$status" -eq 4 ]
    [[ "$output" == *'modified or untracked'* ]]
    [ "$(< "$CFG_TEST_HOME/code/nvim/.git/fixture-head")" = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ]
    ! grep -q '^git ls-remote ' "$CFG_TEST_CALLS"
  done
}

@test "wrong origin or branch is preserved without network operations" {
  repository_fixture
  printf 'https://example.invalid/unrelated\n' > "$CFG_TEST_HOME/code/nvim/.git/fixture-remote"
  run repository_sync
  [ "$status" -eq 4 ]
  [[ "$output" == *'unexpected origin'* ]]
  ! grep -q '^git ls-remote ' "$CFG_TEST_CALLS"
  printf '%s\n' https://github.com/viespejo/nvim-lua-new > "$CFG_TEST_HOME/code/nvim/.git/fixture-remote"
  printf 'private-work\n' > "$CFG_TEST_HOME/code/nvim/.git/fixture-branch"
  run repository_sync
  [ "$status" -eq 4 ]
  [[ "$output" == *'unexpected branch'* ]]
  [ "$(< "$CFG_TEST_HOME/code/nvim/.git/fixture-branch")" = private-work ]
}

@test "divergent or local-only history is never merged reset stashed or deleted" {
  repository_fixture
  export CFG_TEST_GIT_DIVERGED=1
  run repository_sync
  [ "$status" -eq 4 ]
  [[ "$output" == *'divergent or local-only'* ]]
  [ "$(< "$CFG_TEST_HOME/code/nvim/.git/fixture-head")" = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ]
  ! grep -Eq ' (reset|stash|merge) ' "$CFG_TEST_CALLS"
}

@test "file conflict symlinked repository and symlinked parent are preserved" {
  mkdir -p "$CFG_TEST_HOME/code"
  printf 'unrelated\n' > "$CFG_TEST_HOME/code/nvim"
  run repository_sync
  [ "$status" -eq 4 ]
  [ "$(< "$CFG_TEST_HOME/code/nvim")" = unrelated ]
  rm "$CFG_TEST_HOME/code/nvim"
  ln -s "$CFG_TEST_DIR/missing" "$CFG_TEST_HOME/code/nvim"
  run repository_sync
  [ "$status" -eq 4 ]
  [ -L "$CFG_TEST_HOME/code/nvim" ]
  rm "$CFG_TEST_HOME/code/nvim"
  rmdir "$CFG_TEST_HOME/code"
  ln -s "$CFG_TEST_DIR/missing" "$CFG_TEST_HOME/code"
  run repository_sync
  [ "$status" -eq 4 ]
  [ -L "$CFG_TEST_HOME/code" ]
  ! grep -q '^git ls-remote ' "$CFG_TEST_CALLS"
}

@test "status query failure is not mistaken for a clean repository" {
  repository_fixture
  export CFG_TEST_GIT_STATUS_FAIL=1
  run repository_sync
  [ "$status" -eq 4 ]
  [[ "$output" == *'fixture status failure'* ]]
  [[ "$output" == *'cannot query repository status'* ]]
  ! grep -q '^git ls-remote ' "$CFG_TEST_CALLS"
}

@test "remote failure and failed postcondition remain failures" {
  repository_fixture
  export CFG_TEST_GIT_REMOTE_FAIL=1
  run repository_sync
  [ "$status" -ne 0 ]
  [[ "$output" == *'fixture remote failure'* ]]
  unset CFG_TEST_GIT_REMOTE_FAIL
  export CFG_TEST_GIT_POSTCONDITION_FAIL=1
  run repository_sync
  [ "$status" -eq 4 ]
  [[ "$output" == *'selected commit postcondition failed'* ]]
}

@test "concurrent changes before merge and concurrent creation before publication are preserved" {
  repository_fixture
  export CFG_TEST_GIT_CHANGED_DURING_FETCH=1
  run repository_sync
  [ "$status" -eq 4 ]
  [ "$(< "$CFG_TEST_HOME/code/nvim/.git/fixture-head")" = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ]
  ! grep -q ' merge --ff-only ' "$CFG_TEST_CALLS"
  unset CFG_TEST_GIT_CHANGED_DURING_FETCH
  # Remove only the disposable fake clone, never a real checkout.
  rm -rf "$CFG_TEST_HOME/code/nvim"
  export CFG_TEST_GIT_CONCURRENT=1
  run repository_sync
  [ "$status" -eq 4 ]
  [[ "$output" == *'destination appeared'* ]]
  [ "$(< "$CFG_TEST_HOME/code/nvim/untouched")" = 'concurrent content' ]
}

@test "one execution reuses the selected commit and emits one provenance row" {
  repository_fixture bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  run cfg_test_helpers '
    source "$CAPABILITIES_DIR/lib/repositories.sh"
    for repetition in 1 2; do
      cfg_repository_sync nvim https://github.com/viespejo/nvim-lua-new master code/nvim
    done
  '
  [ "$status" -eq 0 ]
  [ "$(grep -c '^git ls-remote ' "$CFG_TEST_CALLS")" -eq 1 ]
  [ "$(grep -c '^nvim' "$CFG_TEST_DIR/helper-output/sources.tsv")" -eq 1 ]
}

@test "target repository operations enter chroot before switching to the target user" {
  cfg_test_target_context
  run cfg_test_helpers '
    CONFIGURE_CONTEXT=target
    CONFIGURE_ROOT=$CFG_TEST_TARGET_ROOT
    source "$CAPABILITIES_DIR/lib/repositories.sh"
    cfg_repository_sync nvim https://github.com/viespejo/nvim-lua-new master code/nvim
  '
  [ "$status" -eq 0 ]
  grep -q "^arch-chroot $CFG_TEST_TARGET_ROOT runuser -u alice -- env " "$CFG_TEST_CALLS"
  [ -e "$CFG_TEST_TARGET_ROOT/home/alice/code/nvim/.git/fixture-head" ]
  ! grep -Eq '^pacman |^systemctl ' "$CFG_TEST_CALLS"
}
