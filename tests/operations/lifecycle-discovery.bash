LIFECYCLE_SUPPORT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LIFECYCLE_SOURCE_ROOT="$(cd -- "${LIFECYCLE_SUPPORT_DIR}/../.." && pwd -P)"

lifecycle_snapshot_root() {
  local manifest_path="$1"
  local root_name="$2"
  local root_path="$3"
  local relative_path
  local entry_type
  local mode
  local link_target
  local hash_record
  local absolute_path
  local content_hash
  local -A entry_types=()
  local -A entry_modes=()
  local -A entry_hashes=()
  local -a file_paths=()

  mode="$(stat -c '%a' -- "$root_path")"
  printf '%s\t.\tdirectory\t%s\t-\n' "$root_name" "$mode" >> "$manifest_path"

  while IFS= read -r -d '' relative_path &&
    IFS= read -r -d '' entry_type &&
    IFS= read -r -d '' mode; do
    entry_types["$relative_path"]="$entry_type"
    entry_modes["$relative_path"]="$mode"

    if [[ "$entry_type" == 'f' ]]; then
      file_paths+=("${root_path}/${relative_path}")
    elif [[ "$entry_type" == 'l' ]]; then
      link_target="$(readlink -- "${root_path}/${relative_path}")"
      hash_record="$(printf '%s' "$link_target" | sha256sum)"
      entry_hashes["$relative_path"]="${hash_record%% *}"
    fi
  done < <(find "$root_path" -mindepth 1 -printf '%P\0%y\0%m\0')

  if [[ "${#file_paths[@]}" -gt 0 ]]; then
    while IFS= read -r -d '' hash_record; do
      content_hash="${hash_record:0:64}"
      absolute_path="${hash_record:66}"
      relative_path="${absolute_path#"$root_path"/}"
      entry_hashes["$relative_path"]="$content_hash"
    done < <(sha256sum --zero "${file_paths[@]}")
  fi

  for relative_path in "${!entry_types[@]}"; do
    case "${entry_types[$relative_path]}" in
      f) entry_type='file' ;;
      d) entry_type='directory' ;;
      l) entry_type='symlink' ;;
      *) entry_type='other' ;;
    esac
    content_hash="${entry_hashes[$relative_path]:--}"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$root_name" "$relative_path" "$entry_type" \
      "${entry_modes[$relative_path]}" "$content_hash" >> "$manifest_path"
  done
}

lifecycle_snapshot() {
  local manifest_path="$1"
  local root_name
  local root_path

  : > "$manifest_path"

  for root_name in copy home; do
    if [[ "$root_name" == 'copy' ]]; then
      root_path="$LIFECYCLE_COPY_ROOT"
    else
      root_path="$LIFECYCLE_HOME"
    fi

    lifecycle_snapshot_root "$manifest_path" "$root_name" "$root_path"
  done

  LC_ALL=C sort -o "$manifest_path" "$manifest_path"
}

lifecycle_set_paths() {
  local test_root="$1"

  LIFECYCLE_TEST_ROOT="$test_root"
  LIFECYCLE_COPY_ROOT="${LIFECYCLE_TEST_ROOT}/repository copy"
  LIFECYCLE_HOME="${LIFECYCLE_TEST_ROOT}/temporary home"
  LIFECYCLE_OUTSIDE_DIR="${LIFECYCLE_TEST_ROOT}/outside working directory"
  LIFECYCLE_DOUBLE_DIR="${LIFECYCLE_TEST_ROOT}/tool doubles"
  LIFECYCLE_DOUBLE_SCRIPT="${LIFECYCLE_TEST_ROOT}/failing tool double"
  LIFECYCLE_CALL_LOG="${LIFECYCLE_TEST_ROOT}/tool calls.log"
  LIFECYCLE_BEFORE_MANIFEST="${LIFECYCLE_TEST_ROOT}/before.manifest"
  LIFECYCLE_AFTER_MANIFEST="${LIFECYCLE_TEST_ROOT}/after.manifest"
  LIFECYCLE_STDOUT_PATH="${LIFECYCLE_TEST_ROOT}/stdout.log"
  LIFECYCLE_STDERR_PATH="${LIFECYCLE_TEST_ROOT}/stderr.log"
  LIFECYCLE_CWD_PATH="${LIFECYCLE_TEST_ROOT}/invocation cwd.log"
}

lifecycle_setup() {
  local archive_path
  local tool_name

  LIFECYCLE_TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mirroros lifecycle discovery.XXXXXX")"
  lifecycle_set_paths "$LIFECYCLE_TEST_ROOT"
  archive_path="${LIFECYCLE_TEST_ROOT}/repository archive.tar"

  mkdir -p "$LIFECYCLE_COPY_ROOT" "$LIFECYCLE_HOME" \
    "$LIFECYCLE_OUTSIDE_DIR" "$LIFECYCLE_DOUBLE_DIR"

  tar -C "$LIFECYCLE_SOURCE_ROOT" \
    --exclude='./.git' \
    --exclude='./build' \
    --exclude='./dist' \
    --exclude='./evidence' \
    --exclude='./.agents' \
    --exclude='./docs/.obsidian' \
    -cf "$archive_path" .
  tar -xf "$archive_path" -C "$LIFECYCLE_COPY_ROOT"
  rm -f -- "$archive_path"

  printf '%s\n' \
    '#!/usr/bin/bash' \
    "printf '%s\\n' \"\${0##*/}\" >> \"\${LIFECYCLE_CALL_LOG:?}\"" \
    'exit 97' > "$LIFECYCLE_DOUBLE_SCRIPT"
  chmod 755 "$LIFECYCLE_DOUBLE_SCRIPT"

  for tool_name in \
    sudo pkexec doas su mkarchiso pacman pacstrap arch-chroot \
    qemu-system-x86_64 archinstall systemctl mount rm; do
    ln -s "$LIFECYCLE_DOUBLE_SCRIPT" "${LIFECYCLE_DOUBLE_DIR}/${tool_name}"
  done
}

lifecycle_teardown() {
  if [[ -n "${LIFECYCLE_TEST_ROOT:-}" && -d "$LIFECYCLE_TEST_ROOT" ]]; then
    rm -rf -- "$LIFECYCLE_TEST_ROOT"
  fi
}

lifecycle_invoke() {
  local command_name="$1"
  shift

  : > "$LIFECYCLE_CALL_LOG"
  : > "$LIFECYCLE_CWD_PATH"
  lifecycle_snapshot "$LIFECYCLE_BEFORE_MANIFEST"

  if (
    cd -- "$LIFECYCLE_OUTSIDE_DIR" || exit 125
    printf '%s\n' "$PWD" > "$LIFECYCLE_CWD_PATH"
    PATH="${LIFECYCLE_DOUBLE_DIR}:$PATH" \
      HOME="$LIFECYCLE_HOME" \
      LIFECYCLE_CALL_LOG="$LIFECYCLE_CALL_LOG" \
      "$LIFECYCLE_COPY_ROOT/operations/$command_name" "$@"
  ) > "$LIFECYCLE_STDOUT_PATH" 2> "$LIFECYCLE_STDERR_PATH"; then
    LIFECYCLE_COMMAND_STATUS=0
  else
    LIFECYCLE_COMMAND_STATUS=$?
  fi

  lifecycle_snapshot "$LIFECYCLE_AFTER_MANIFEST"

  if ! cmp -s "$LIFECYCLE_BEFORE_MANIFEST" "$LIFECYCLE_AFTER_MANIFEST"; then
    printf '%s\n' 'The command changed the disposable repository copy or temporary HOME.' >&2
    return 1
  fi

  if [[ -s "$LIFECYCLE_CALL_LOG" ]]; then
    printf '%s\n' 'The command invoked a privileged or domain-tool double:' >&2
    while IFS= read -r double_name; do
      printf '  %s\n' "$double_name" >&2
    done < "$LIFECYCLE_CALL_LOG"
    return 1
  fi
}

lifecycle_assert_status() {
  local expected_status="$1"
  [[ "$LIFECYCLE_COMMAND_STATUS" -eq "$expected_status" ]]
}

lifecycle_assert_stdout_contains() {
  grep -Fq -- "$1" "$LIFECYCLE_STDOUT_PATH"
}

lifecycle_assert_stderr_contains() {
  grep -Fq -- "$1" "$LIFECYCLE_STDERR_PATH"
}

lifecycle_assert_stderr_does_not_contain() {
  local grep_status

  if grep -Fq -- "$1" "$LIFECYCLE_STDERR_PATH"; then
    return 1
  else
    grep_status=$?
  fi

  [[ "$grep_status" -eq 1 ]]
}

lifecycle_assert_stderr_empty() {
  [[ ! -s "$LIFECYCLE_STDERR_PATH" ]]
}

lifecycle_assert_no_success_output() {
  local grep_status

  if grep -Eiq 'success(ful(ly)?)?|succeeded' \
    "$LIFECYCLE_STDOUT_PATH" "$LIFECYCLE_STDERR_PATH"; then
    return 1
  else
    grep_status=$?
  fi

  [[ "$grep_status" -eq 1 ]]
}

lifecycle_assert_invoked_outside_copy() {
  local invoked_from
  IFS= read -r invoked_from < "$LIFECYCLE_CWD_PATH"
  [[ "$invoked_from" == "$LIFECYCLE_OUTSIDE_DIR" ]] && \
    [[ "$invoked_from" != "$LIFECYCLE_COPY_ROOT/"* ]]
}
