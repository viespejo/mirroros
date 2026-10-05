#!/usr/bin/bash

NOCLOUD_SEED_FILE=''

# Generates the per-run NoCloud text, scans it, and builds the temporary seed medium.
# Arguments: run ID, build run directory, evidence run directory, guest checks script,
# volume label, HTTPS URL, HTTPS timeout seconds.
# Statuses: 0 success, 2 scan findings, 5 scanner or medium-build failure, 6 missing guest script.
nocloud_prepare() {
  local run_id="$1"
  local build_run_dir="$2"
  local evidence_run_dir="$3"
  local guest_script="$4"
  local volume_label="$5"
  local https_url="$6"
  local https_timeout="$7"
  local seed_directory="${build_run_dir}/nocloud"
  local report_path="${evidence_run_dir}/gitleaks-nocloud.json"
  local scanner_status

  if [[ ! -f "$guest_script" || ! -r "$guest_script" ]]; then
    printf 'MirrorOS test: incomplete or damaged checkout; the guest checks script is missing: %s\n' \
      "$guest_script" >&2
    return 6
  fi

  umask 077
  if ! mkdir -m 700 -- "$seed_directory"; then
    printf 'MirrorOS test: could not create the NoCloud staging directory: %s\n' "$seed_directory" >&2
    return 5
  fi

  {
    printf '#!/usr/bin/bash\n'
    printf "MIRROROS_RUN_ID='%s'\n" "$run_id"
    printf "MIRROROS_HTTPS_URL='%s'\n" "$https_url"
    printf "MIRROROS_HTTPS_TIMEOUT_SECONDS='%s'\n" "$https_timeout"
    tail -n +2 -- "$guest_script"
  } > "${seed_directory}/user-data" || {
    printf '%s\n' 'MirrorOS test: could not write the NoCloud user-data.' >&2
    return 5
  }
  printf 'instance-id: %s\nlocal-hostname: mirroros-reference\n' "$run_id" > "${seed_directory}/meta-data" || {
    printf '%s\n' 'MirrorOS test: could not write the NoCloud meta-data.' >&2
    return 5
  }
  chmod 600 -- "${seed_directory}/user-data" "${seed_directory}/meta-data"

  if gitleaks dir --redact --no-banner --report-format json --report-path "$report_path" "$seed_directory"; then
    [[ ! -e "$report_path" ]] || chmod 600 -- "$report_path"
  else
    scanner_status=$?
    [[ ! -e "$report_path" ]] || chmod 600 -- "$report_path"
    if [[ "$scanner_status" -eq 1 ]]; then
      printf 'MirrorOS test: Gitleaks detected a secret in the NoCloud text; report preserved at %s. No medium was built.\n' \
        "$report_path" >&2
      return 2
    fi
    printf 'MirrorOS test: Gitleaks NoCloud scan failed with original status %s.\n' "$scanner_status" >&2
    return 5
  fi

  if ! xorriso -as mkisofs -quiet -output "${build_run_dir}/nocloud-seed.iso" \
    -volid "$volume_label" -joliet -rational-rock -graft-points \
    "user-data=${seed_directory}/user-data" "meta-data=${seed_directory}/meta-data"; then
    printf '%s\n' 'MirrorOS test: building the NoCloud medium failed.' >&2
    return 5
  fi
  chmod 600 -- "${build_run_dir}/nocloud-seed.iso"
  # shellcheck disable=SC2034 # Read by the qualification orchestrator.
  NOCLOUD_SEED_FILE="${build_run_dir}/nocloud-seed.iso"
}
