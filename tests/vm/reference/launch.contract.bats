load vm-support

setup() {
  reference_setup
  REFERENCE_CONFIG_PATH="${REFERENCE_REPOSITORY_ROOT}/vm/reference/reference-vm.conf"
  REFERENCE_LIB_DIR="${REFERENCE_REPOSITORY_ROOT}/vm/reference/lib"
  REFERENCE_GUEST_SCRIPT="${REFERENCE_REPOSITORY_ROOT}/vm/reference/guest/bootstrap-checks.sh"
  REFERENCE_DOCUMENTS_CLI="${REFERENCE_REPOSITORY_ROOT}/vm/reference/bootstrap-documents.mjs"
  LAUNCH_RUN_ID='20261005T120000Z-11111111-2222-4333-8444-555555555555'
  LAUNCH_FOREIGN_RUN_ID='20261005T120000Z-99999999-2222-4333-8444-555555555555'
  LAUNCH_BUILD_DIR="${REFERENCE_TEST_ROOT}/build run"
  LAUNCH_EVIDENCE_DIR="${REFERENCE_TEST_ROOT}/evidence run"
  LAUNCH_QEMU_ARGS_FILE="${REFERENCE_TEST_ROOT}/qemu args.txt"
  LAUNCH_SERIAL_CONTENT="${REFERENCE_TEST_ROOT}/serial content.txt"
  LAUNCH_FAKE_VARS="${REFERENCE_TEST_ROOT}/fake OVMF_VARS.fd"
  mkdir -m 700 "$LAUNCH_BUILD_DIR" "$LAUNCH_EVIDENCE_DIR"
  printf 'vars-template' > "$LAUNCH_FAKE_VARS"
  export REFERENCE_CALL_LOG LAUNCH_QEMU_ARGS_FILE
  export REFERENCE_QEMU_SERIAL_CONTENT="$LAUNCH_SERIAL_CONTENT"
  export PATH="${REFERENCE_DOUBLE_DIR}:${PATH}"
  launch_install_doubles
}

teardown() {
  pkill -f -- "sleep 31" 2>/dev/null || true
  reference_teardown
}

launch_install_doubles() {
  rm -f -- "${REFERENCE_DOUBLE_DIR}/qemu-system-x86_64" "${REFERENCE_DOUBLE_DIR}/qemu-img" \
    "${REFERENCE_DOUBLE_DIR}/gitleaks" "${REFERENCE_DOUBLE_DIR}/xorriso"

  cat > "${REFERENCE_DOUBLE_DIR}/qemu-system-x86_64" <<'EOF'
#!/usr/bin/bash
printf 'qemu-system-x86_64 %s\n' "$*" >> "${REFERENCE_CALL_LOG:?}"
if [[ "${1:-}" == '--version' ]]; then
  echo 'QEMU emulator version 9.9.9'
  exit 0
fi
printf '%s\n' "$@" > "${LAUNCH_QEMU_ARGS_FILE:?}"
serial=''
for argument in "$@"; do
  [[ "$argument" == file:* ]] && serial="${argument#file:}"
done
if [[ -n "$serial" && -f "${REFERENCE_QEMU_SERIAL_CONTENT:-}" ]]; then
  cat -- "$REFERENCE_QEMU_SERIAL_CONTENT" >> "$serial"
fi
case "${REFERENCE_QEMU_AFTER:-sleep}" in
  exit:*) exit "${REFERENCE_QEMU_AFTER#exit:}" ;;
  *) exec sleep 31 ;;
esac
EOF
  cat > "${REFERENCE_DOUBLE_DIR}/qemu-img" <<'EOF'
#!/usr/bin/bash
printf 'qemu-img %s\n' "$*" >> "${REFERENCE_CALL_LOG:?}"
: > "$5"
EOF
  cat > "${REFERENCE_DOUBLE_DIR}/gitleaks" <<'EOF'
#!/usr/bin/bash
printf 'gitleaks %s\n' "$*" >> "${REFERENCE_CALL_LOG:?}"
while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == '--report-path' ]]; then printf '[]\n' > "$2"; fi
  shift
done
exit "${REFERENCE_GITLEAKS_STATUS:-0}"
EOF
  cat > "${REFERENCE_DOUBLE_DIR}/xorriso" <<'EOF'
#!/usr/bin/bash
printf 'xorriso %s\n' "$*" >> "${REFERENCE_CALL_LOG:?}"
while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == '-output' ]]; then printf 'seed' > "$2"; fi
  shift
done
exit "${REFERENCE_XORRISO_STATUS:-0}"
EOF
  chmod 755 "${REFERENCE_DOUBLE_DIR}/qemu-system-x86_64" "${REFERENCE_DOUBLE_DIR}/qemu-img" \
    "${REFERENCE_DOUBLE_DIR}/gitleaks" "${REFERENCE_DOUBLE_DIR}/xorriso"
}

# Sources the preconditions, configuration, NoCloud, and launch modules, then evaluates a snippet.
launch_module() {
  local snippet="$1"
  shift

  /usr/bin/bash -c '
    set -Eeuo pipefail
    umask 077
    source "$1/preconditions.sh"
    source "$1/nocloud.sh"
    source "$1/launch.sh"
    launch_load_configuration "$2"
    PRECONDITIONS_OVMF_VARS_PATH="$3"
    LAUNCH_POLL_SECONDS=0.2
    snippet="$4"
    shift 4
    eval "$snippet"
  ' _ "$REFERENCE_LIB_DIR" "$REFERENCE_CONFIG_PATH" "$LAUNCH_FAKE_VARS" "$snippet" "$@"
}

launch_report_json() {
  local run_id="$1"
  local https_status="${2:-passed}"
  local https_code=200
  local tls=true
  local result=passed
  local id
  local checks=''

  if [[ "$https_status" == 'failed' ]]; then
    https_code=null
    tls=false
    result=failed
  fi
  for id in uefi_mode root_shell native_install_tools dns_resolution default_route; do
    checks+="\"${id}\":{\"status\":\"passed\",\"detail\":\"ok\"},"
  done
  checks+='"ipv4_address":{"status":"passed","detail":"ok","address":"10.0.2.15"},'
  checks+="\"https_request\":{\"status\":\"${https_status}\",\"detail\":\"d\",\"http_status\":${https_code},\"tls_verified\":${tls}}"
  printf '{"schema_version":1,"run_id":"%s","checks":{%s},"result":"%s"}' "$run_id" "$checks" "$result"
}

launch_write_serial() {
  local marker_run_id="$1"
  local body="$2"

  printf 'GRUB boot noise\r\nMIRROROS-REPORT-BEGIN %s\r\n%s\r\nMIRROROS-REPORT-END %s\r\n' \
    "$marker_run_id" "$body" "$marker_run_id" > "$LAUNCH_SERIAL_CONTENT"
}

launch_run_session() {
  # Prepares media, launches the double, waits, evaluates, and prints the evaluation status.
  launch_module '
    launch_prepare_disk "$1"
    launch_build_command "/bundle/test.iso" "$1/nocloud-seed.iso" "$2"
    launch_start "$2"
    launch_wait "$3" "$1" "$4"
    evaluation=0
    launch_evaluate "$5" "$3" || evaluation=$?
    kill "$LAUNCH_QEMU_PID" 2>/dev/null || true
    printf "%s %s\n" "$evaluation" "$LAUNCH_OUTCOME"
  ' "$LAUNCH_BUILD_DIR" "$LAUNCH_EVIDENCE_DIR" "$LAUNCH_RUN_ID" "$1" "$REFERENCE_DOCUMENTS_CLI"
}

@test "the QEMU command uses exactly the versioned reference configuration" {
  run launch_module '
    launch_build_command "/bundle dir/test.iso" "/build/nocloud-seed.iso" "/evidence"
    printf "%s\n" "${LAUNCH_QEMU_COMMAND[@]}"
  '
  [ "$status" -eq 0 ]
  mapfile -t actual <<< "$output"
  expected=(
    qemu-system-x86_64
    -machine q35,accel=kvm
    -cpu host
    -smp 2
    -m 4096
    -display none
    -nodefaults
    -no-user-config
    -monitor none
    -serial file:/evidence/guest-serial.log
    -drive if=pflash,format=raw,unit=0,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd
    -drive if=pflash,format=raw,unit=1,file=
    -drive 'if=none,id=iso,media=cdrom,format=raw,readonly=on,file=/bundle dir/test.iso'
    -device ide-cd,drive=iso,bus=ide.0,bootindex=1
    -drive if=none,id=seed,media=cdrom,format=raw,readonly=on,file=/build/nocloud-seed.iso
    -device ide-cd,drive=seed,bus=ide.1
    -drive if=none,id=disk0,format=qcow2,file=
    -device virtio-blk-pci,drive=disk0,bootindex=2
    -netdev user,id=net0
    -device virtio-net-pci,netdev=net0
  )
  [ "${#actual[@]}" -eq "${#expected[@]}" ]
  for index in "${!expected[@]}"; do
    [ "${actual[$index]}" == "${expected[$index]}" ]
  done
}

@test "the QEMU command grants no host share, forwarding, extra device, or software emulation" {
  run launch_module '
    launch_build_command "/bundle/test.iso" "/build/seed.iso" "/evidence"
    printf "%s\n" "${LAUNCH_QEMU_COMMAND[@]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" != *hostfwd* ]]
  [[ "$output" != *virtfs* ]]
  [[ "$output" != *9p* ]]
  [[ "$output" != *usb* ]]
  [[ "$output" != *tcg* ]]
  [[ "$output" != *-snapshot* ]]
  [ "$(grep -c '^-netdev$' <<< "$output")" -eq 1 ]
}

@test "commas in image paths are escaped for QEMU option parsing" {
  run launch_module '
    launch_build_command "/bundle/odd,name.iso" "/build/seed.iso" "/evidence"
    printf "%s\n" "${LAUNCH_QEMU_COMMAND[@]}"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *'file=/bundle/odd,,name.iso'* ]]
}

@test "the disk is a fresh sparse qcow2 image and the vars file is a private per-run copy" {
  run launch_module 'launch_prepare_disk "$1"' "$LAUNCH_BUILD_DIR"
  [ "$status" -eq 0 ]
  grep -qxF "qemu-img create -q -f qcow2 ${LAUNCH_BUILD_DIR}/disk.qcow2 32G" "$REFERENCE_CALL_LOG"
  [ "$(<"${LAUNCH_BUILD_DIR}/OVMF_VARS.fd")" == 'vars-template' ]
  [ "$(stat -c '%a' "${LAUNCH_BUILD_DIR}/disk.qcow2")" == '600' ]
  [ "$(stat -c '%a' "${LAUNCH_BUILD_DIR}/OVMF_VARS.fd")" == '600' ]
}

@test "the effective configuration records the fixed VM, Secure Boot off, and no port forwarding" {
  run launch_module '
    launch_describe_configuration
    printf "%s\n" "$LAUNCH_VM_CONFIGURATION_JSON"
  '
  [ "$status" -eq 0 ]
  node -e '
    const c = JSON.parse(process.argv[1]);
    if (c.machine !== "q35" || c.accel !== "kvm" || c.cpu !== "host" || c.smp !== 2 || c.memory_mib !== 4096) process.exit(1);
    if (c.disk.size !== "32G" || c.disk.format !== "qcow2" || c.firmware.secure_boot !== false) process.exit(1);
    if (c.network.port_forwarding !== false || c.global_deadline_seconds !== 300 || c.guest_https_timeout_seconds !== 30) process.exit(1);
  ' "$output"
}

@test "QEMU and OVMF versions are recorded as non-empty strings" {
  run launch_module '
    launch_collect_versions
    printf "%s\n%s\n" "$LAUNCH_QEMU_VERSION" "$LAUNCH_OVMF_VERSION"
  '
  [ "$status" -eq 0 ]
  mapfile -t lines <<< "$output"
  [ "${lines[0]}" == 'QEMU emulator version 9.9.9' ]
  [[ "${lines[1]}" == *'OVMF_CODE.4m.fd sha256'* ]]
}

@test "a missing configuration file is a damaged checkout" {
  run launch_module 'launch_load_configuration "$1"' "${REFERENCE_TEST_ROOT}/absent.conf"
  [ "$status" -eq 6 ]
  [[ "$output" == *'damaged checkout'* ]]
}

@test "NoCloud text carries the run ID and is scanned before the medium is built" {
  run launch_module 'nocloud_prepare "$1" "$2" "$3" "$4" cidata https://archlinux.org/ 30' \
    "$LAUNCH_RUN_ID" "$LAUNCH_BUILD_DIR" "$LAUNCH_EVIDENCE_DIR" "$REFERENCE_GUEST_SCRIPT"
  [ "$status" -eq 0 ]
  user_data="${LAUNCH_BUILD_DIR}/nocloud/user-data"
  [ "$(head -n 1 "$user_data")" == '#!/usr/bin/bash' ]
  grep -qxF "MIRROROS_RUN_ID='${LAUNCH_RUN_ID}'" "$user_data"
  grep -qxF "MIRROROS_HTTPS_URL='https://archlinux.org/'" "$user_data"
  grep -qxF "instance-id: ${LAUNCH_RUN_ID}" "${LAUNCH_BUILD_DIR}/nocloud/meta-data"
  [ "$(stat -c '%a' "$user_data")" == '600' ]
  [ "$(stat -c '%a' "${LAUNCH_BUILD_DIR}/nocloud-seed.iso")" == '600' ]
  mapfile -t calls < "$REFERENCE_CALL_LOG"
  [[ "${calls[0]}" == "gitleaks dir --redact --no-banner --report-format json --report-path ${LAUNCH_EVIDENCE_DIR}/gitleaks-nocloud.json ${LAUNCH_BUILD_DIR}/nocloud" ]]
  [[ "${calls[1]}" == xorriso*'-volid cidata'* ]]
  [ "${#calls[@]}" -eq 2 ]
}

@test "Gitleaks findings in the NoCloud text exit 2 and no medium is built" {
  REFERENCE_GITLEAKS_STATUS=1 run launch_module 'nocloud_prepare "$1" "$2" "$3" "$4" cidata https://archlinux.org/ 30' \
    "$LAUNCH_RUN_ID" "$LAUNCH_BUILD_DIR" "$LAUNCH_EVIDENCE_DIR" "$REFERENCE_GUEST_SCRIPT"
  [ "$status" -eq 2 ]
  [ ! -e "${LAUNCH_BUILD_DIR}/nocloud-seed.iso" ]
  ! grep -q '^xorriso' "$REFERENCE_CALL_LOG"
  [ -f "${LAUNCH_EVIDENCE_DIR}/gitleaks-nocloud.json" ]
  [ "$(stat -c '%a' "${LAUNCH_EVIDENCE_DIR}/gitleaks-nocloud.json")" == '600' ]
}

@test "a Gitleaks execution failure on the NoCloud text exits 5" {
  REFERENCE_GITLEAKS_STATUS=126 run launch_module 'nocloud_prepare "$1" "$2" "$3" "$4" cidata https://archlinux.org/ 30' \
    "$LAUNCH_RUN_ID" "$LAUNCH_BUILD_DIR" "$LAUNCH_EVIDENCE_DIR" "$REFERENCE_GUEST_SCRIPT"
  [ "$status" -eq 5 ]
  ! grep -q '^xorriso' "$REFERENCE_CALL_LOG"
}

@test "a failed NoCloud medium build exits 5" {
  REFERENCE_XORRISO_STATUS=1 run launch_module 'nocloud_prepare "$1" "$2" "$3" "$4" cidata https://archlinux.org/ 30' \
    "$LAUNCH_RUN_ID" "$LAUNCH_BUILD_DIR" "$LAUNCH_EVIDENCE_DIR" "$REFERENCE_GUEST_SCRIPT"
  [ "$status" -eq 5 ]
}

@test "a missing guest script is a damaged checkout" {
  run launch_module 'nocloud_prepare "$1" "$2" "$3" "$4" cidata https://archlinux.org/ 30' \
    "$LAUNCH_RUN_ID" "$LAUNCH_BUILD_DIR" "$LAUNCH_EVIDENCE_DIR" "${REFERENCE_TEST_ROOT}/absent.sh"
  [ "$status" -eq 6 ]
  [ ! -e "${LAUNCH_BUILD_DIR}/nocloud" ]
}

@test "the guest checks install nothing, start no installer, and never use an insecure transfer" {
  /usr/bin/bash -n "$REFERENCE_GUEST_SCRIPT"
  ! grep -E '\b(pacman|mkfs[.a-z0-9]*|wipefs|sgdisk|parted|fdisk|mkswap|mount|dd)\b +' "$REFERENCE_GUEST_SCRIPT"
  ! grep -E -- '--insecure|(^|[[:space:]])-k([[:space:]]|$)|--no-check-certificate' "$REFERENCE_GUEST_SCRIPT"
  grep -q -- "--proto '=https'" "$REFERENCE_GUEST_SCRIPT"
  grep -q -- '--output /dev/null' "$REFERENCE_GUEST_SCRIPT"
  grep -q -- '--max-time "\$MIRROROS_HTTPS_TIMEOUT_SECONDS"' "$REFERENCE_GUEST_SCRIPT"
}

# Runs the real guest script with host-independent doubles and returns the serial output path.
launch_run_guest_script() {
  local curl_output="$1"
  local curl_status="$2"
  local guest_dir="${REFERENCE_TEST_ROOT}/guest root"
  local guest_bin="${guest_dir}/bin"
  local tool

  mkdir -p "$guest_bin" "${guest_dir}/efi"
  for tool in pacstrap genfstab arch-chroot archinstall; do
    printf '#!/usr/bin/bash\nexit 0\n' > "${guest_bin}/${tool}"
  done
  cat > "${guest_bin}/ip" <<'EOF'
#!/usr/bin/bash
case "$*" in
  *'addr show'*) echo '2: eth0    inet 10.0.2.15/24 brd 10.0.2.255 scope global eth0' ;;
  *'route show'*) echo 'default via 10.0.2.2 dev eth0' ;;
esac
EOF
  printf '#!/usr/bin/bash\necho "93.184.216.34 STREAM archlinux.org"\n' > "${guest_bin}/getent"
  printf '#!/usr/bin/bash\necho 0\n' > "${guest_bin}/id"
  printf '#!/usr/bin/bash\nprintf "%%s" "%s"\nexit %s\n' "$curl_output" "$curl_status" > "${guest_bin}/curl"
  chmod 755 "${guest_bin}"/*
  : > "${guest_dir}/serial"
  {
    printf "MIRROROS_RUN_ID='%s'\n" "$LAUNCH_RUN_ID"
    printf "MIRROROS_HTTPS_URL='https://archlinux.org/'\n"
    printf "MIRROROS_HTTPS_TIMEOUT_SECONDS='30'\n"
    tail -n +2 -- "$REFERENCE_GUEST_SCRIPT" \
      | sed -e "s#/sys/firmware/efi#'${guest_dir}/efi'#" -e "s#^SERIAL_DEVICE=.*#SERIAL_DEVICE='${guest_dir}/serial'#" \
        -e 's#^NETWORK_WAIT_SECONDS=.*#NETWORK_WAIT_SECONDS=2#'
  } > "${guest_dir}/user-data"
  PATH="${guest_bin}:${PATH}" /usr/bin/bash "${guest_dir}/user-data"
  GUEST_SERIAL_PATH="${guest_dir}/serial"
}

@test "the guest script emits a run-bound report that the host accepts when every check passes" {
  launch_run_guest_script '200 0' 0
  run launch_module 'launch_extract_report "$1" "$2" "$3"' "$GUEST_SERIAL_PATH" "$LAUNCH_RUN_ID" "${REFERENCE_TEST_ROOT}/report.json"
  [ "$status" -eq 0 ]
  run node "$REFERENCE_DOCUMENTS_CLI" validate-report --report "${REFERENCE_TEST_ROOT}/report.json" --run-id "$LAUNCH_RUN_ID"
  [ "$status" -eq 0 ]
}

@test "the guest script reports a failed HTTPS check as a consistent failed report" {
  launch_run_guest_script '000 60' 60
  run launch_module 'launch_extract_report "$1" "$2" "$3"' "$GUEST_SERIAL_PATH" "$LAUNCH_RUN_ID" "${REFERENCE_TEST_ROOT}/report.json"
  [ "$status" -eq 0 ]
  run node "$REFERENCE_DOCUMENTS_CLI" validate-report --report "${REFERENCE_TEST_ROOT}/report.json" --run-id "$LAUNCH_RUN_ID"
  [ "$status" -eq 4 ]
}

@test "the guest script never reports HTTPS success without verified TLS" {
  launch_run_guest_script '200 20' 0
  run launch_module 'launch_extract_report "$1" "$2" "$3"' "$GUEST_SERIAL_PATH" "$LAUNCH_RUN_ID" "${REFERENCE_TEST_ROOT}/report.json"
  [ "$status" -eq 0 ]
  run node "$REFERENCE_DOCUMENTS_CLI" validate-report --report "${REFERENCE_TEST_ROOT}/report.json" --run-id "$LAUNCH_RUN_ID"
  [ "$status" -eq 4 ]
}

@test "a passing guest report yields status 0 and records the launch outcome" {
  launch_write_serial "$LAUNCH_RUN_ID" "$(launch_report_json "$LAUNCH_RUN_ID")"
  run launch_run_session 30
  [ "$status" -eq 0 ]
  [ "$output" == '0 report' ]
  [ "$(stat -c '%a' "${LAUNCH_EVIDENCE_DIR}/guest-serial.log")" == '600' ]
  [ "$(stat -c '%a' "${LAUNCH_EVIDENCE_DIR}/qemu-diagnostics.log")" == '600' ]
}

@test "a failed guest check yields status 4" {
  launch_write_serial "$LAUNCH_RUN_ID" "$(launch_report_json "$LAUNCH_RUN_ID" failed)"
  run launch_run_session 30
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" == '4 report' ]
}

@test "deadline expiry without a report yields status 5" {
  : > "$LAUNCH_SERIAL_CONTENT"
  run launch_run_session 2
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" == '5 deadline' ]
}

@test "a report bound to a foreign run in the markers is not accepted" {
  launch_write_serial "$LAUNCH_FOREIGN_RUN_ID" "$(launch_report_json "$LAUNCH_FOREIGN_RUN_ID")"
  run launch_run_session 2
  [ "${lines[-1]}" == '5 deadline' ]
}

@test "a report with a foreign run ID inside current-run markers is rejected" {
  launch_write_serial "$LAUNCH_RUN_ID" "$(launch_report_json "$LAUNCH_FOREIGN_RUN_ID")"
  run launch_run_session 30
  [ "${lines[-1]}" == '5 report' ]
}

@test "an incomplete report is rejected" {
  launch_write_serial "$LAUNCH_RUN_ID" '{"schema_version":1,"run_id":"'"$LAUNCH_RUN_ID"'","checks":{},"result":"passed"}'
  run launch_run_session 30
  [ "${lines[-1]}" == '5 report' ]
}

@test "success keywords in the serial log never grant qualification" {
  printf 'all checks passed\r\nresult: passed\r\nHTTP/1.1 200 OK\r\n' > "$LAUNCH_SERIAL_CONTENT"
  run launch_run_session 2
  [ "${lines[-1]}" == '5 deadline' ]
}

@test "QEMU exiting before a report yields status 5 with its original status preserved" {
  : > "$LAUNCH_SERIAL_CONTENT"
  REFERENCE_QEMU_AFTER=exit:3 run launch_module '
    launch_prepare_disk "$1"
    launch_build_command "/bundle/test.iso" "$1/nocloud-seed.iso" "$2"
    launch_start "$2"
    launch_wait "$3" "$1" 30
    evaluation=0
    launch_evaluate "$4" "$3" || evaluation=$?
    printf "%s %s %s\n" "$evaluation" "$LAUNCH_OUTCOME" "$LAUNCH_QEMU_STATUS"
  ' "$LAUNCH_BUILD_DIR" "$LAUNCH_EVIDENCE_DIR" "$LAUNCH_RUN_ID" "$REFERENCE_DOCUMENTS_CLI"
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" == '5 qemu_exited 3' ]
}

@test "launch records the owned PID and does not stop QEMU itself" {
  : > "$LAUNCH_SERIAL_CONTENT"
  run launch_module '
    launch_prepare_disk "$1"
    launch_build_command "/bundle/test.iso" "$1/nocloud-seed.iso" "$2"
    launch_start "$2"
    sleep 0.5
    if launch_qemu_running; then printf "running %s\n" "$LAUNCH_QEMU_PID"; fi
    kill "$LAUNCH_QEMU_PID"
  ' "$LAUNCH_BUILD_DIR" "$LAUNCH_EVIDENCE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == running\ [0-9]* ]]
}
