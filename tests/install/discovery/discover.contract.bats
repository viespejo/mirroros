load discovery

setup() {
  discovery_setup
}

teardown() {
  discovery_teardown
}

@test "discover succeeds on a valid reference VM with an empty disk" {
  discovery_scenario reference-vm-empty
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  discovery_json_assert "$(discovery_facts_path)" "d.validation.status === 'valid'"
  discovery_json_assert "$(discovery_facts_path)" "d.layers.detected.firmware.boot_mode === 'uefi'"
  discovery_json_assert "$(discovery_facts_path)" "d.layers.detected.network.ready === true"
  discovery_json_assert "$(discovery_facts_path)" "d.layers.detected.storage.disks.some(x => x.identity.path === '/dev/vda' && x.eligible)"
  discovery_json_assert "$(discovery_facts_path)" "d.layers.detected.hardware.virtualization === 'kvm'"
  discovery_json_assert "$(discovery_facts_path)" "d.source.commit === 'a'.repeat(40) && d.source.dirty === false && d.source.requested_profile_id === 'reference-vm' && d.format_version === 2"
  discovery_json_assert "$(discovery_facts_path)" "d.profile.status === 'matched' && d.profile.profile_id === 'reference-vm'"
  grep -Fq 'Validation: valid' "$STDOUT_PATH"
  [ ! -e "${OUTPUT_DIR}/error.json" ]
  discovery_assert_private_permissions
}

@test "discover recognizes the reference VM without --target" {
  discovery_scenario reference-vm-empty
  discovery_run --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  discovery_json_assert "$(discovery_facts_path)" "d.validation.status === 'valid'"
  discovery_json_assert "$(discovery_facts_path)" "d.profile.status === 'matched' && d.profile.profile_id === 'reference-vm'"
  discovery_json_assert "$(discovery_facts_path)" "d.source.requested_profile_id === undefined"
  grep -Fq 'Profile: matched reference-vm' "$STDOUT_PATH"
  discovery_assert_private_permissions
}

@test "discover records an unmatched machine as unqualified without a generic profile" {
  discovery_scenario synthetic-laptop
  discovery_run --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  discovery_json_assert "$(discovery_facts_path)" "d.validation.status === 'valid' && d.profile.status === 'unqualified' && d.profile.profile_id === undefined"
  discovery_json_assert "$(discovery_facts_path)" "Object.keys(d.layers.target_override.policy).length === 0"
  grep -Fq 'Profile: unqualified' "$STDOUT_PATH"
  discovery_assert_no_planted_values
}

@test "discover does not infer a pending-capture profile for a machine without a defined identity" {
  discovery_scenario synthetic-laptop
  discovery_run --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  discovery_json_assert "$(discovery_facts_path)" "d.profile.profile_id !== 'framework-13-pro-amd'"
}

@test "discover treats a missing identity field as no match rather than a missing fact" {
  discovery_scenario reference-vm-empty
  rm -f -- "${FIXTURE_ROOT}/sys/class/dmi/id/sys_vendor"
  discovery_run --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  discovery_json_assert "$(discovery_facts_path)" "d.profile.status === 'unqualified' && d.validation.reasons.length === 0"
  rm -rf -- "$OUTPUT_DIR"
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 2 ]
  discovery_reason_codes_include target_identity_unobserved
}

@test "discover rejects two matching profiles as ambiguous and applies no override" {
  discovery_scenario reference-vm-empty
  cp -a "${CODE_ROOT}/targets/reference-vm" "${CODE_ROOT}/targets/reference-vm-twin"
  sed -i 's/"target_id": "reference-vm"/"target_id": "reference-vm-twin"/' "${CODE_ROOT}/targets/reference-vm-twin/target.json"
  mkdir -p "${CODE_ROOT}/targets/reference-vm/overrides"
  printf '%s\n' '{"minimum_disk_bytes": 1073741824}' > "${CODE_ROOT}/targets/reference-vm/overrides/discovery.json"
  discovery_run --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 2 ]
  discovery_reason_codes_include profile_ambiguous
  discovery_json_assert "$(discovery_facts_path)" "d.profile.status === 'unqualified' && Object.keys(d.layers.target_override.policy).length === 0"
}

@test "discover keeps the four layers and tags effective values with their source" {
  discovery_scenario reference-vm-empty
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  discovery_json_assert "$(discovery_facts_path)" "['portable_baseline', 'detected', 'target_override', 'runtime_private'].every(k => k in d.layers)"
  discovery_json_assert "$(discovery_facts_path)" "d.effective['firmware.boot_mode'].source === 'detected'"
  discovery_json_assert "$(discovery_facts_path)" "d.effective['policy.minimum_disk_bytes'].source === 'baseline'"
}

@test "discover records a pre-existing layout without making the disk ineligible" {
  discovery_scenario reference-vm-layout
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  discovery_json_assert "$(discovery_facts_path)" "d.layers.detected.storage.disks.some(x => x.identity.path === '/dev/vda' && x.eligible && x.layout.partitions.length === 2)"
}

@test "discover keeps the by-id link, serial, and size of a disk" {
  discovery_scenario reference-vm-empty
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  discovery_json_assert "$(discovery_facts_path)" "d.layers.detected.storage.disks.some(x => x.identity.by_id === 'virtio-SYNTH-VDA-0001' && x.identity.serial === 'SYNTH-VDA-0001' && x.identity.size_bytes === 34359738368)"
  discovery_json_assert "$(discovery_facts_path)" "d.layers.detected.storage.live_medium_device === '/dev/sr0'"
}

@test "discover lists every disk with its ineligibility reasons and selects none" {
  discovery_scenario disks-mixed
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  discovery_json_assert "$(discovery_facts_path)" "d.layers.detected.storage.disks.length >= 8"
  discovery_json_assert "$(discovery_facts_path)" "d.layers.detected.storage.disks.some(x => !x.eligible && x.ineligible_reasons.includes('removable'))"
  discovery_json_assert "$(discovery_facts_path)" "d.layers.detected.storage.disks.some(x => !x.eligible && x.ineligible_reasons.includes('below_minimum_size'))"
  discovery_json_assert "$(discovery_facts_path)" "d.layers.detected.storage.disks.some(x => !x.eligible && x.ineligible_reasons.includes('live_medium'))"
  discovery_json_assert "$(discovery_facts_path)" "!JSON.stringify(d).includes('selected')"
}

@test "discover warns only when the Secure Boot state is unknown" {
  discovery_scenario secure-boot-unknown
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  discovery_json_assert "$(discovery_facts_path)" "d.validation.warnings.some(w => w.code === 'secure_boot_unknown')"
  grep -Fq 'Warning secure_boot_unknown' "$STDOUT_PATH"
}

@test "discover exits 2 and still writes invalid facts for unsupported facts" {
  local fixture code
  while IFS=' ' read -r fixture code; do
    rm -rf -- "$FIXTURE_ROOT" "$OUTPUT_DIR"
    mkdir -p "$FIXTURE_ROOT"
    discovery_scenario "$fixture"
    discovery_run --target reference-vm --output "$OUTPUT_DIR"
    [ "$DISCOVERY_STATUS" -eq 2 ] || { printf '%s: status %s\n' "$fixture" "$DISCOVERY_STATUS" >&2; return 1; }
    discovery_json_assert "$(discovery_facts_path)" "d.validation.status === 'invalid'"
    discovery_reason_codes_include "$code" || { printf '%s: missing reason %s\n' "$fixture" "$code" >&2; return 1; }
    discovery_json_assert "$(discovery_facts_path)" "d.validation.reasons.every(r => r.code && r.message && r.next_step)"
    [ ! -e "${OUTPUT_DIR}/error.json" ]
  done <<'EOF'
bios boot_mode_not_uefi
uefi-32bit uefi_platform_32bit
efivars-unavailable efivars_unavailable
secure-boot-enabled secure_boot_enabled
network-no-route network_no_default_route
network-dns-failed network_dns_failed
network-https-failed network_https_failed
disks-none-eligible no_eligible_disk
identity-contradiction target_identity_mismatch
EOF
}

@test "discover exits 2 with a missing fact when a collector cannot determine it" {
  discovery_scenario reference-vm-empty
  : > "${DOUBLE_STATE}/architecture"
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 2 ]
  discovery_reason_codes_include fact_missing
}

@test "discover exits 2 for the Framework target while its identity is pending capture" {
  discovery_scenario synthetic-laptop
  discovery_run --target framework-13-pro-amd --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 2 ]
  discovery_reason_codes_include target_identity_pending_capture
  discovery_json_assert "$(discovery_facts_path)" "d.source.requested_profile_id === 'framework-13-pro-amd' && d.profile.status === 'unqualified'"
}

@test "discover exits 2 for an unknown target" {
  discovery_scenario reference-vm-empty
  discovery_run --target no-such-target --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 2 ]
  discovery_reason_codes_include target_unknown
  discovery_json_assert "$(discovery_facts_path)" "d.source.requested_profile_id === 'no-such-target' && d.profile.status === 'unqualified'"
}

@test "discover exits 2 for an unsafe target id without echoing it into the document" {
  discovery_scenario reference-vm-empty
  discovery_run --target '../reference-vm' --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 2 ]
  discovery_reason_codes_include target_unknown
  discovery_json_assert "$(discovery_facts_path)" "d.source.requested_profile_id === undefined"
}

@test "discover exits 2 for an override with an unknown key or a detected fact" {
  discovery_scenario reference-vm-empty
  mkdir -p "${CODE_ROOT}/targets/reference-vm/overrides"
  printf '%s\n' '{"unknown_key": 1}' > "${CODE_ROOT}/targets/reference-vm/overrides/discovery.json"
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 2 ]
  discovery_reason_codes_include override_unknown_key
  rm -rf -- "$OUTPUT_DIR"
  printf '%s\n' '{"firmware.secure_boot": "disabled"}' > "${CODE_ROOT}/targets/reference-vm/overrides/discovery.json"
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 2 ]
  discovery_reason_codes_include override_detected_fact
}

@test "discover applies an allowlisted override and passes the effective probe policy to the collector" {
  discovery_scenario reference-vm-empty
  mkdir -p "${CODE_ROOT}/targets/reference-vm/overrides"
  printf '%s\n' '{"https_probe_timeout_seconds": 12, "minimum_disk_bytes": 1073741824}' > "${CODE_ROOT}/targets/reference-vm/overrides/discovery.json"
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  discovery_json_assert "$(discovery_facts_path)" "d.effective['policy.https_probe_timeout_seconds'].source === 'override'"
  grep -Fq -- '--max-time 12' "${DOUBLE_STATE}/calls.log"
}

@test "discover applies the override of an automatically recognized profile before probing the network" {
  discovery_scenario reference-vm-empty
  mkdir -p "${CODE_ROOT}/targets/reference-vm/overrides"
  printf '%s\n' '{"https_probe_timeout_seconds": 12}' > "${CODE_ROOT}/targets/reference-vm/overrides/discovery.json"
  discovery_run --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  discovery_json_assert "$(discovery_facts_path)" "d.profile.profile_id === 'reference-vm' && d.effective['policy.https_probe_timeout_seconds'].source === 'override'"
  grep -Fq -- '--max-time 12' "${DOUBLE_STATE}/calls.log"
}

@test "discover applies no profile override to an unqualified machine" {
  discovery_scenario synthetic-laptop
  mkdir -p "${CODE_ROOT}/targets/reference-vm/overrides"
  printf '%s\n' '{"https_probe_timeout_seconds": 12}' > "${CODE_ROOT}/targets/reference-vm/overrides/discovery.json"
  discovery_run --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  discovery_json_assert "$(discovery_facts_path)" "d.profile.status === 'unqualified' && d.effective['policy.https_probe_timeout_seconds'].source === 'baseline'"
  ! grep -Fq -- '--max-time 12' "${DOUBLE_STATE}/calls.log"
}

@test "discover exits 5 and retains the child status and stderr when lsblk fails" {
  discovery_scenario reference-vm-empty
  printf '%s\n' 3 > "${DOUBLE_STATE}/lsblk_status"
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 5 ]
  [ ! -e "$(discovery_facts_path)" ]
  discovery_json_assert "${OUTPUT_DIR}/error.json" "d.code === 'child_failed' && d.stage === 'discover' && d.operation === 'lsblk' && d.child_exit_status === 3 && d.message && d.next_step"
  grep -Fq 'lsblk: simulated failure' "${OUTPUT_DIR}/raw/storage.stderr"
  grep -Fq 'lsblk: simulated failure' "$STDERR_PATH"
  ! grep -Fq 'Validation:' "$STDOUT_PATH"
}

@test "discover exits 5 for an unexpected curl, getent, ip, or systemd-detect-virt status" {
  local state_file status
  while IFS=' ' read -r state_file status; do
    rm -rf -- "$OUTPUT_DIR"
    discovery_scenario reference-vm-empty
    printf '%s\n' "$status" > "${DOUBLE_STATE}/${state_file}"
    discovery_run --target reference-vm --output "$OUTPUT_DIR"
    [ "$DISCOVERY_STATUS" -eq 5 ] || { printf '%s: status %s\n' "$state_file" "$DISCOVERY_STATUS" >&2; return 1; }
    discovery_json_assert "${OUTPUT_DIR}/error.json" "d.child_exit_status === ${status}"
    [ ! -e "$(discovery_facts_path)" ]
    rm -f -- "${DOUBLE_STATE}/${state_file}"
  done <<'EOF'
curl_status 2
dns_status 7
ip_status 9
virt_status 4
EOF
}

@test "discover treats a curl network failure as a not-ready network, not as a tool failure" {
  discovery_scenario reference-vm-empty
  printf '%s\n' 6 > "${DOUBLE_STATE}/curl_status"
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 2 ]
  discovery_reason_codes_include network_https_failed
}

@test "discover exits 6 when an embedded file is missing and writes only a structured error" {
  discovery_scenario reference-vm-empty
  rm -f -- "${CODE_ROOT}/install/discovery/validate-facts.mjs"
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 6 ]
  [ ! -e "$(discovery_facts_path)" ]
  discovery_json_assert "${OUTPUT_DIR}/error.json" "d.code === 'embedded_code_damaged' && d.child_exit_status === null && d.next_step"
  ! grep -Fq 'Validation:' "$STDOUT_PATH"
}

@test "discover exits 6 when an embedded Node module is damaged" {
  discovery_scenario reference-vm-empty
  printf '%s\n' 'export const broken = ;' > "${CODE_ROOT}/install/discovery/write-facts.mjs"
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 6 ]
  [ ! -e "$(discovery_facts_path)" ]
  [ -s "${OUTPUT_DIR}/error.json" ]
}

@test "discover exits 6 when the embedded identity is missing" {
  discovery_scenario reference-vm-empty
  rm -f -- "${CODE_ROOT}/identity.json"
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 6 ]
  discovery_json_assert "${OUTPUT_DIR}/error.json" "d.code === 'identity_missing'"
}

@test "discover exits 6 when the produced document fails its own validator" {
  discovery_scenario reference-vm-empty
  # An empty collector answer for the hardware section cannot be a valid document section.
  printf '%s\n' 'export function normalizeHardware() { return { facts: { cpu: 7 }, missing: [] }; }' \
    > "${CODE_ROOT}/hardware/discovery/normalize-hardware.mjs"
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 6 ]
  [ ! -e "$(discovery_facts_path)" ]
  discovery_json_assert "${OUTPUT_DIR}/error.json" "d.code === 'internal_contract_failure'"
}

@test "discover keeps planted MAC, SSID, DMI, and battery values out of every output" {
  discovery_scenario planted-sensitive
  # The planted values are really present in the fake system, so a careless collector would leak them.
  grep -Fq 'PLANTED-DMI-SERIAL-0001' "${FIXTURE_ROOT}/sys/class/dmi/id/product_serial"
  grep -Fq 'aa:bb:cc:dd:ee:ff' "${FIXTURE_ROOT}/sys/class/net/enp0s2/address"
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  discovery_assert_no_planted_values
}

@test "discover rejects a non-empty output directory without writing" {
  discovery_scenario reference-vm-empty
  mkdir -p "$OUTPUT_DIR"
  printf '%s\n' keep > "${OUTPUT_DIR}/previous.txt"
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 2 ]
  [ "$(find "$OUTPUT_DIR" -mindepth 1 | wc -l)" -eq 1 ]
  grep -Fq 'must be an absent or empty directory' "$STDERR_PATH"
}

@test "discover accepts an empty output directory and tightens its permissions" {
  discovery_scenario reference-vm-empty
  mkdir -m 755 "$OUTPUT_DIR"
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  discovery_assert_private_permissions
}

@test "discover defaults to evidence/install/<run-id>/ in the working directory" {
  discovery_scenario reference-vm-empty
  discovery_run --target reference-vm
  [ "$DISCOVERY_STATUS" -eq 0 ]
  local run_dir
  run_dir="$(find "${WORK_DIR}/evidence/install" -mindepth 1 -maxdepth 1 -type d)"
  [[ "${run_dir##*/}" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-f-]{36}$ ]]
  [ -f "${run_dir}/target-facts.json" ]
  discovery_json_assert "${run_dir}/target-facts.json" "d.source.run_id === '${run_dir##*/}'"
  [ "$(stat -c '%a' "${WORK_DIR}/evidence")" = '700' ]
  [ "$(stat -c '%a' "${run_dir}/target-facts.json")" = '600' ]
}

@test "discover retains uninterpreted raw collector output for diagnosis" {
  discovery_scenario reference-vm-empty
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  local name
  for name in firmware hardware storage network; do
    [ -s "${OUTPUT_DIR}/raw/${name}.json" ]
    node -e 'JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"))' "${OUTPUT_DIR}/raw/${name}.json"
  done
}

@test "discover never calls lsblk with probing options" {
  discovery_scenario reference-vm-empty
  discovery_run --target reference-vm --output "$OUTPUT_DIR"
  [ "$DISCOVERY_STATUS" -eq 0 ]
  grep -Fq 'lsblk --json --tree --bytes --output' "${DOUBLE_STATE}/calls.log"
  ! grep -Eq 'blkid|smartctl' "${DOUBLE_STATE}/calls.log"
}

@test "discover rejects unsupported and malformed arguments with status 2" {
  discovery_scenario reference-vm-empty
  discovery_run --bogus
  [ "$DISCOVERY_STATUS" -eq 2 ]
  grep -Fq 'unsupported argument' "$STDERR_PATH"
  discovery_run --target
  [ "$DISCOVERY_STATUS" -eq 2 ]
  discovery_run --target ''
  [ "$DISCOVERY_STATUS" -eq 2 ]
  grep -Fq -- '--target requires a value' "$STDERR_PATH"
  discovery_run --target reference-vm --target reference-vm
  [ "$DISCOVERY_STATUS" -eq 2 ]
  discovery_run --target reference-vm --output
  [ "$DISCOVERY_STATUS" -eq 2 ]
  discovery_run --help extra
  [ "$DISCOVERY_STATUS" -eq 2 ]
}

@test "discover --help prints help and exits 0 without touching the system" {
  discovery_run --help
  [ "$DISCOVERY_STATUS" -eq 0 ]
  grep -Fq 'Usage: install discover [--target <id>] [--output <dir>]' "$STDOUT_PATH"
  grep -Fq 'Normalized exit outcomes:' "$STDOUT_PATH"
  [ ! -s "$STDERR_PATH" ]
  [ ! -s "${DOUBLE_STATE}/calls.log" ]
}
