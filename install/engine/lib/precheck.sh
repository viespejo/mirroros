#!/usr/bin/bash
# shellcheck disable=SC2034 # Plan state is read by apply and by the operation libraries that source this file.
# Pre-check steps 1 to 6 of the installation engine (contracts/installation-engine.md, "Pre-check order").
# None of them writes to the target disk; a failure leaves the disk untouched and the password discarded.

declare -a OP_IDS=()
declare -A OP_DESC=()

# Step 1. The installer lock is inherited as fd 4 or taken here; a second run never touches anything.
acquire_lock() {
  install -d -m 0700 -- "$ENGINE_RUN_ROOT"
  # A descriptor 4 that is not the lock file is not an inherited lock: it is closed and the lock is taken here.
  if ! { [[ -e /proc/self/fd/4 ]] && [[ /proc/self/fd/4 -ef "$LOCK_FILE" ]]; }; then
    exec 4> "$LOCK_FILE"
  fi
  if ! flock -n 4; then
    printf 'MirrorOS engine: install_already_running: another installation run holds the installer lock.\n' >&2
    exit 2
  fi
}

prepare_output() {
  if [[ -e "${OUTPUT}/engine-run.json" ]]; then
    printf 'MirrorOS engine: --output already holds engine-run.json.\n' >&2
    exit 2
  fi
  install -d -m 0700 -- "$OUTPUT"
  ENGINE_LOG="${OUTPUT}/engine.log"
  : > "$ENGINE_LOG"
  chmod 0600 -- "$ENGINE_LOG"
  STARTED_AT="$(now_utc)"
}

# Step 2, first half: the engine's own embedded code identity (the same reading as install/discovery/discover).
read_identity() {
  local identity_file="${CODE_ROOT}/identity.json" content commit='' dirty=''
  if [[ -f "$identity_file" ]]; then
    content="$(< "$identity_file")"
    if [[ "$content" =~ \"commit\"[[:space:]]*:[[:space:]]*\"([0-9a-f]{40})\" ]]; then commit="${BASH_REMATCH[1]}"; fi
    if [[ "$content" =~ \"dirty\"[[:space:]]*:[[:space:]]*(true|false) ]]; then dirty="${BASH_REMATCH[1]}"; fi
  fi
  if [[ ! "$commit" =~ ^[0-9a-f]{40}$ || ( "$dirty" != true && "$dirty" != false ) ]]; then
    finish failed 6 engine_asset_mismatch precheck \
      'The embedded code identity (commit and dirty state) is missing or damaged.' \
      'Rebuild or re-clone the installation medium and run mirroros-install again; the disk was not touched.' ''
  fi
  IDENTITY_COMMIT="$commit"
  IDENTITY_DIRTY="$dirty"
}

# Steps 2 (second half) and 3. The plan is read once into memory; the loader validates it, checks the digest,
# and answers with the NUL-delimited stream described in install/engine/load-plan.mjs.
load_plan() {
  local stream=() index total count key value id description outcome_status
  PLAN_TEXT="$(< "$PLAN_FILE")" || {
    finish blocked 2 plan_not_json precheck 'The plan file cannot be read.' 'Run mirroros-install again; the disk was not touched.' ''
  }
  mapfile -d '' -t stream < <(printf '%s' "$PLAN_TEXT" | node "${SCRIPT_DIR}/load-plan.mjs" verify \
    --digest "$CONFIRMED_DIGEST" --commit "$IDENTITY_COMMIT" --dirty "$IDENTITY_DIRTY" 4>&- || true)
  if [[ "${#stream[@]}" -eq 0 ]]; then
    finish failed 6 engine_asset_mismatch precheck 'The plan loader produced no answer.' \
      'Rebuild or re-clone the installation medium and run mirroros-install again; the disk was not touched.' ''
  fi
  if [[ "${stream[0]}" == fail ]]; then
    outcome_status="${stream[1]}"
    PLAN_TEXT=''
    finish "$outcome_status" 2 "${stream[2]}" "${stream[5]:-precheck}" "${stream[3]}" "${stream[4]}" ''
  fi
  STORAGE_OPTION="${stream[2]}"
  HIBERNATION="${stream[3]}"
  DISK_PATH="${stream[4]}"
  DISK_BY_ID="${stream[5]}"
  total="${stream[6]}"
  index=7
  count=0
  while (( index < ${#stream[@]} )); do
    id="${stream[index + 1]}"
    description="${stream[index + 2]}"
    local parameters="${stream[index + 3]}"
    OP_IDS+=("$id")
    OP_DESC["$id"]="$description"
    index=$((index + 4))
    for (( value = 0; value < parameters; value++ )); do
      key="${stream[index]}"
      PARAM["${id}.${key}"]="${stream[index + 1]}"
      index=$((index + 2))
    done
    count=$((count + 1))
  done
  if (( count != total )); then
    finish failed 6 engine_asset_mismatch precheck 'The plan loader answer is inconsistent.' \
      'Rebuild or re-clone the installation medium and run mirroros-install again; the disk was not touched.' ''
  fi
  for id in "${OP_IDS[@]}"; do
    if [[ -z "${DISPATCH[$id]:-}" ]]; then
      finish blocked 2 stage_failed "$id" "The installation engine has no function for the operation ${id}." \
        'Generate a new plan with this artifact; the disk was not touched.' ''
    fi
  done
}

# Step 4. The engine never waits: the wait belongs to live preparation.
check_keyring() {
  if ! systemctl is-active --quiet pacman-init.service < /dev/null 3>&- 4>&- 2> /dev/null; then
    finish blocked 2 live_keyring_not_ready precheck \
      'The live package keyring is not initialized yet.' \
      'Wait for pacman-init.service to finish, then run mirroros-install again; the disk was not touched.' ''
  fi
}

# Step 5. The password is read once from fd 3, which is then closed; it must be one non-empty line.
read_password() {
  # shellcheck disable=SC2034 # The second read only detects a second line.
  local extra=''
  if ! { true <&3; } 2> /dev/null; then
    finish blocked 2 password_unavailable precheck 'No password channel is open.' \
      'Run mirroros-install again; the disk was not touched.' ''
  fi
  if ! IFS= read -r -u 3 PASSWORD || [[ -z "$PASSWORD" ]] || IFS= read -r -u 3 extra; then
    exec 3<&-
    finish blocked 2 password_unavailable precheck 'The password channel did not hold exactly one non-empty line.' \
      'Run mirroros-install again; the disk was not touched.' ''
  fi
  exec 3<&-
}

resolve_disk_node() {
  local by_id_link
  if [[ -n "$DISK_BY_ID" ]] && by_id_link="$(readlink -f -- "$(sys_path "/dev/disk/by-id/${DISK_BY_ID}")" 2> /dev/null)" && [[ -n "$by_id_link" ]]; then
    DISK_NODE="$by_id_link"
  else
    DISK_NODE="$(sys_path "$DISK_PATH")"
  fi
}

# The partition nodes and holders of the disk below the sysfs root, one per line of the result.
disk_sysfs_names() {
  local name="${DISK_NODE##*/}" entry
  printf '%s\n' "$name"
  for entry in "$(sys_path "/sys/block/${name}")/${name}"*; do
    [[ -d "$entry" ]] && printf '%s\n' "${entry##*/}"
  done
  return 0
}

# Step 6b. The disk and its partitions are not mounted, not swap, and have no holders.
check_occupancy() {
  local name mounts swaps holders busy='' sysfs_disk
  name="${DISK_NODE##*/}"
  mounts="$(sys_path /proc/self/mounts)"
  swaps="$(sys_path /proc/swaps)"
  sysfs_disk="$(sys_path "/sys/block/${name}")"
  # Mounts and swap are matched by device name (the disk or one of its partitions), not by sysfs enumeration.
  if [[ -r "$mounts" ]] && awk -v pattern="^/dev/${name}(p?[0-9]+)?\$" '$1 ~ pattern {found=1} END {exit !found}' "$mounts"; then
    busy="a partition of /dev/${name} is mounted"
  fi
  if [[ -r "$swaps" ]] && awk -v pattern="^/dev/${name}(p?[0-9]+)?\$" '$1 ~ pattern {found=1} END {exit !found}' "$swaps"; then
    busy="a partition of /dev/${name} is used as swap"
  fi
  for holders in "${sysfs_disk}/holders" "${sysfs_disk}/${name}"*/holders; do
    if [[ -d "$holders" && -n "$(ls -A -- "$holders" 2> /dev/null)" ]]; then
      busy="a partition of /dev/${name} has a device-mapper, LVM, encryption, or RAID holder"
    fi
  done
  if [[ -n "$busy" ]]; then
    finish blocked 2 target_disk_in_use precheck "The confirmed disk is in use: ${busy}." \
      "Release it manually (unmount, swapoff, or close the mapping) or run mirroros-install again; the disk was not touched." ''
  fi
}

# Step 6, immediately before the first destructive operation: re-read the disk with the read-only collector,
# compare it with the plan, and check occupancy. The password is discarded on any failure by finish.
final_block() {
  local storage_file="${OUTPUT}/.storage-recheck.json" result=() collector="${CODE_ROOT}/install/discovery/discover-storage"
  resolve_disk_node
  if ! "$collector" > "$storage_file" 2>> "$ENGINE_LOG" < /dev/null 3>&- 4>&-; then
    rm -f -- "$storage_file"
    finish blocked 2 stage_failed precheck 'The read-only storage collector failed during the final check.' \
      'Run mirroros-install again; the disk was not touched.' ''
  fi
  mapfile -d '' -t result < <(printf '%s' "$PLAN_TEXT" | node "${SCRIPT_DIR}/load-plan.mjs" check-disk --storage "$storage_file" 4>&- || true)
  rm -f -- "$storage_file"
  if [[ "${#result[@]}" -eq 0 ]]; then
    finish failed 6 engine_asset_mismatch precheck 'The disk comparison produced no answer.' \
      'Rebuild or re-clone the installation medium and run mirroros-install again; the disk was not touched.' ''
  fi
  if [[ "${result[0]}" == fail ]]; then
    finish "${result[1]}" 2 "${result[2]}" precheck "${result[3]}" "${result[4]}" ''
  fi
  check_occupancy
}
