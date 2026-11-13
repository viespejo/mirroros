#!/usr/bin/env bats
# files-cwd with a fake /proc tree and fake hyprctl, tmux and uwsm; no compositor or terminal is used.

setup() {
  FILES_CWD="$BATS_TEST_DIRNAME/../../../../capabilities/desktop/files/files-cwd"
  TEST_DIR="$(mktemp -d)"
  export MIRROROS_FILES_CWD_ROOT="$TEST_DIR/root" HOME="$TEST_DIR/home" CALLS="$TEST_DIR/calls"
  export HYPR_PID=100 TMUX_PANE_PATH="$TEST_DIR/pane"
  mkdir -p "$MIRROROS_FILES_CWD_ROOT/etc" "$HOME" "$TEST_DIR/bin" "$TEST_DIR/exe" "$TEST_DIR/work" "$TMUX_PANE_PATH"
  : > "$CALLS"
  for name in zsh tmux firefox; do : > "$TEST_DIR/exe/$name"; done
  printf '/bin/sh\n%s\n' "$TEST_DIR/exe/zsh" > "$MIRROROS_FILES_CWD_ROOT/etc/shells"
  cat > "$TEST_DIR/bin/hyprctl" <<'EOF'
#!/usr/bin/bash
[[ "$*" == 'activewindow -j' && -n "$HYPR_PID" ]] || exit 1
printf '{\n  "address": "0x1",\n  "class": "foot",\n  "pid": %s,\n  "xwayland": false\n}\n' "$HYPR_PID"
EOF
  cat > "$TEST_DIR/bin/tmux" <<'EOF'
#!/usr/bin/bash
printf 'tmux %s\n' "$*" >> "$CALLS"
[[ "$1 $2 $4 $5" == 'display-message -c -p #{pane_current_path}' && "$3" == /dev/pts/7 ]] || exit 1
[[ "${TMUX_UNREACHABLE:-0}" != 1 ]] || exit 1
printf '%s\n' "$TMUX_PANE_PATH"
EOF
  cat > "$TEST_DIR/bin/uwsm" <<'EOF'
#!/usr/bin/bash
printf 'uwsm %s\n' "$*" >> "$CALLS"
EOF
  chmod 0755 "$TEST_DIR/bin/"*
  export PATH="$TEST_DIR/bin:$PATH"
}
teardown() { rm -rf -- "$TEST_DIR"; }

# process <pid> <exe> <session> <tty_nr> <tpgid> [cwd]: a /proc/<pid> entry with stat, exe and cwd.
process() {
  local dir="$MIRROROS_FILES_CWD_ROOT/proc/$1"
  mkdir -p "$dir/fd"
  printf '%s (%s) S 1 %s %s %s %s 4194560 0 0\n' "$1" "${2##*/}" "$1" "$3" "$4" "$5" > "$dir/stat"
  ln -s "$2" "$dir/exe"
  ln -s "${6:-/}" "$dir/cwd"
}

# children <pid> <tid> <children...>
children() {
  mkdir -p "$MIRROROS_FILES_CWD_ROOT/proc/$1/task/$2"
  printf '%s ' "${@:3}" > "$MIRROROS_FILES_CWD_ROOT/proc/$1/task/$2/children"
}

@test "the newest child shell of the focused terminal gives its working directory" {
  process 100 "$TEST_DIR/exe/foot" 100 0 -1
  children 100 100 150
  children 100 101 200
  process 150 "$TEST_DIR/exe/firefox" 1 0 -1 "$TEST_DIR"
  process 200 "$TEST_DIR/exe/zsh" 200 34817 200 "$TEST_DIR/work"
  run "$FILES_CWD" --print
  [ "$status" -eq 0 ]
  [ "$output" = "$TEST_DIR/work" ]
  [ ! -s "$CALLS" ]
}

@test "a tmux client started from the shell gives the active pane path" {
  process 100 "$TEST_DIR/exe/foot" 100 0 -1
  children 100 100 200
  process 200 "$TEST_DIR/exe/zsh" 200 34817 300 "$TEST_DIR/work"
  process 300 "$TEST_DIR/exe/tmux" 200 34817 300 "$TEST_DIR/work"
  ln -s /dev/pts/7 "$MIRROROS_FILES_CWD_ROOT/proc/300/fd/0"
  run "$FILES_CWD" --print
  [ "$status" -eq 0 ]
  [ "$output" = "$TMUX_PANE_PATH" ]
  grep -qxF 'tmux display-message -c /dev/pts/7 -p #{pane_current_path}' "$CALLS"
}

@test "Foot running tmux directly gives the active pane path" {
  process 100 "$TEST_DIR/exe/foot" 100 0 -1
  children 100 100 200
  process 200 "$TEST_DIR/exe/tmux" 200 34817 200 "$HOME"
  ln -s /dev/pts/7 "$MIRROROS_FILES_CWD_ROOT/proc/200/fd/0"
  run "$FILES_CWD" --print
  [ "$status" -eq 0 ]
  [ "$output" = "$TMUX_PANE_PATH" ]
}

@test "an unreachable tmux server or a non-pty client opens HOME" {
  process 100 "$TEST_DIR/exe/foot" 100 0 -1
  children 100 100 200
  process 200 "$TEST_DIR/exe/tmux" 200 34817 200 "$TEST_DIR/work"
  ln -s /dev/pts/7 "$MIRROROS_FILES_CWD_ROOT/proc/200/fd/0"
  TMUX_UNREACHABLE=1 run "$FILES_CWD" --print
  [ "$output" = "$HOME" ]
  rm "$MIRROROS_FILES_CWD_ROOT/proc/200/fd/0"
  ln -s /dev/null "$MIRROROS_FILES_CWD_ROOT/proc/200/fd/0"
  : > "$CALLS"
  run "$FILES_CWD" --print
  [ "$output" = "$HOME" ]
  [ ! -s "$CALLS" ]
}

@test "another application, an unlisted shell or no active window opens HOME" {
  process 100 "$TEST_DIR/exe/firefox" 100 0 -1
  children 100 100 200
  # A helper shell spawned by an application does not lead its own session on a pty.
  process 200 "$TEST_DIR/exe/zsh" 100 0 -1 "$TEST_DIR/work"
  run "$FILES_CWD" --print
  [ "$output" = "$HOME" ]
  rm -r "$MIRROROS_FILES_CWD_ROOT/proc/200"
  process 200 "$TEST_DIR/exe/firefox" 200 34817 200 "$TEST_DIR/work"
  run "$FILES_CWD" --print
  [ "$output" = "$HOME" ]
  HYPR_PID='' run "$FILES_CWD" --print
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME" ]
}

@test "a deleted working directory opens HOME" {
  process 100 "$TEST_DIR/exe/foot" 100 0 -1
  children 100 100 200
  process 200 "$TEST_DIR/exe/zsh" 200 34817 200 "$TEST_DIR/gone"
  run "$FILES_CWD" --print
  [ "$output" = "$HOME" ]
}

@test "without --print Strata opens through uwsm with the directory as one argument" {
  mkdir -p "$TEST_DIR/work dir"
  process 100 "$TEST_DIR/exe/foot" 100 0 -1
  children 100 100 200
  process 200 "$TEST_DIR/exe/zsh" 200 34817 200 "$TEST_DIR/work dir"
  run "$FILES_CWD"
  [ "$status" -eq 0 ]
  grep -qxF "uwsm app -- strata $TEST_DIR/work dir" "$CALLS"
  run "$FILES_CWD" --unknown
  [ "$status" -eq 2 ]
}
