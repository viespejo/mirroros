#!/usr/bin/bash
# shellcheck disable=SC2034 # State variables are shared across the harness libraries sourced by harness.sh.
# Prototype harness: the temporary NoCloud medium.
#
# The medium carries the guest runner, the engine's guest files, the synthetic credentials, and the
# run parameters. The user-data is only a stub that mounts the medium and runs the runner.
#
# Canary exclusion: the Gitleaks scan of this temporary medium excludes exactly the two synthetic
# credential values, through a temporary configuration kept in build/. No other scan has an
# exclusion (see lib/README.md).

# Optional parameters (defaults preserve the Track 1 behavior):
#   PROTO_NOCLOUD_BASENAME        staging directory and medium name (default nocloud)
#   PROTO_NOCLOUD_ENGINE_SCRIPT   engine script the guest runner executes (default install)
#   PROTO_NOCLOUD_EXTRA_SEED_ENV  extra KEY='value' lines appended to seed.env (default none)
NOCLOUD_SEED_FILE=''
# Reference to the lib directory, set by harness.sh.
PROTO_LIB_DIR="${PROTO_LIB_DIR:-}"

proto_nocloud_write_scan_config() {
  local config_path="$1"

  (
    umask 077
    {
      printf '[extend]\nuseDefault = true\n\n[[allowlists]]\nregexes = [\n'
      printf "  '''%s''',\n" "$PROTO_USER_PASSWORD" "$PROTO_ROOT_PASSWORD"
      printf ']\n'
    } > "$config_path"
  )
}

# Arguments: run ID, build run dir, evidence run dir, engine guest dir, volume label, HTTPS URL,
# HTTPS timeout, variant, mode.
# Statuses: 0 success, 2 scan findings, 5 scanner or medium-build failure, 6 missing input.
proto_nocloud_prepare() {
  local run_id="$1"
  local build_run_dir="$2"
  local evidence_run_dir="$3"
  local engine_guest_dir="$4"
  local volume_label="$5"
  local https_url="$6"
  local https_timeout="$7"
  local variant="$8"
  local mode="$9"
  local base="${PROTO_NOCLOUD_BASENAME:-nocloud}"
  local engine_script="${PROTO_NOCLOUD_ENGINE_SCRIPT:-install}"
  local seed_directory="${build_run_dir}/${base}"
  local config_path="${build_run_dir}/gitleaks-${base}.toml"
  local report_path="${evidence_run_dir}/gitleaks-${base}.json"
  local guest_dir="${PROTO_LIB_DIR}/guest"
  local scanner_status
  local file

  for file in "${guest_dir}/runner.sh" "${guest_dir}/common.sh" "${guest_dir}/verify-postconditions.sh" \
    "${guest_dir}/mirroros-proto-verify.service" "${engine_guest_dir}/${engine_script}"; do
    if [[ ! -f "$file" || ! -r "$file" ]]; then
      printf 'MirrorOS prototype: incomplete or damaged checkout; a guest file is missing: %s\n' "$file" >&2
      return 6
    fi
  done

  umask 077
  if ! mkdir -m 700 -- "$seed_directory" "${seed_directory}/engine"; then
    printf 'MirrorOS prototype: could not create the NoCloud staging directory: %s\n' "$seed_directory" >&2
    return 5
  fi
  cp -- "${guest_dir}/runner.sh" "${guest_dir}/common.sh" "${guest_dir}/verify-postconditions.sh" \
    "${guest_dir}/mirroros-proto-verify.service" "$seed_directory" || return 5
  cp -R -- "${engine_guest_dir}/." "${seed_directory}/engine" || return 5

  {
    printf "MIRROROS_RUN_ID='%s'\n" "$run_id"
    printf "MIRROROS_VARIANT='%s'\n" "$variant"
    printf "MIRROROS_MODE='%s'\n" "$mode"
    printf "MIRROROS_TARGET_DISK='%s'\n" "$PROTO_TARGET_DISK"
    printf "MIRROROS_HTTPS_URL='%s'\n" "$https_url"
    printf "MIRROROS_HTTPS_TIMEOUT_SECONDS='%s'\n" "$https_timeout"
    if [[ -n "${PROTO_NOCLOUD_ENGINE_SCRIPT:-}" ]]; then
      printf "MIRROROS_ENGINE_SCRIPT='%s'\n" "$PROTO_NOCLOUD_ENGINE_SCRIPT"
    fi
    if [[ -n "${PROTO_NOCLOUD_EXTRA_SEED_ENV:-}" ]]; then
      printf '%s\n' "$PROTO_NOCLOUD_EXTRA_SEED_ENV"
    fi
  } > "${seed_directory}/seed.env" || return 5
  proto_secrets_write_file "${seed_directory}/secrets" || return 5
  if [[ "$variant" == 'unreachable-mirrors' ]]; then
    # The .invalid top-level domain never resolves (RFC 2606), so the server is unreachable.
    # shellcheck disable=SC2016 # $repo and $arch are literal pacman mirrorlist variables.
    printf 'Server = https://mirror.invalid/$repo/os/$arch\n' > "${seed_directory}/mirrorlist" || return 5
  fi

  # shellcheck disable=SC2016 # The user-data stub text must keep its own variables unexpanded.
  printf '#!/usr/bin/bash\nmnt=/run/mirroros-seed\nmkdir -p "$mnt" && mount -o ro -L %s "$mnt" || {\n  printf "\\nMIRROROS-SEED-MOUNT-FAILED\\n" > /dev/ttyS0\n  exit 1\n}\nexec /usr/bin/bash "$mnt/runner.sh"\n' \
    "$volume_label" > "${seed_directory}/user-data" || return 5
  printf 'instance-id: %s\nlocal-hostname: mirroros-proto\n' "$run_id" > "${seed_directory}/meta-data" || return 5
  chmod -R go-rwx -- "$seed_directory"

  proto_nocloud_write_scan_config "$config_path" || return 5
  if gitleaks dir --redact --no-banner -c "$config_path" --report-format json --report-path "$report_path" "$seed_directory"; then
    [[ ! -e "$report_path" ]] || chmod 600 -- "$report_path"
  else
    scanner_status=$?
    [[ ! -e "$report_path" ]] || chmod 600 -- "$report_path"
    if [[ "$scanner_status" -eq 1 ]]; then
      printf 'MirrorOS prototype: Gitleaks detected a secret in the NoCloud text; report preserved at %s. No medium was built.\n' \
        "$report_path" >&2
      return 2
    fi
    printf 'MirrorOS prototype: Gitleaks NoCloud scan failed with original status %s.\n' "$scanner_status" >&2
    return 5
  fi

  if ! xorriso -as mkisofs -quiet -output "${build_run_dir}/${base}-seed.iso" \
    -volid "$volume_label" -joliet -rational-rock "$seed_directory"; then
    printf '%s\n' 'MirrorOS prototype: building the NoCloud medium failed.' >&2
    return 5
  fi
  chmod 600 -- "${build_run_dir}/${base}-seed.iso"
  NOCLOUD_SEED_FILE="${build_run_dir}/${base}-seed.iso"
}
