load vm-support

# Doubles for qualify-discovery on top of the Story 1.4 end-to-end doubles.
# REFERENCE_DISCOVERY_TARGET: target id echoed in the guest report.
# REFERENCE_DISCOVERY_EXIT: discovery exit status the guest reports (0, 2, 5, or 6).
# REFERENCE_QEMU_MODE: pass (default) or exit (QEMU exits before a report).
# REFERENCE_PLAN_REPORT: 1 adds a plan section; REFERENCE_PLAN_SAME_DIGEST=1 gives both plans one digest,
# REFERENCE_PLAN_TAMPER=1 changes the first plan checksum after the last run, and
# REFERENCE_PLAN_INVALID_EXIT sets the exit of the invalid-choices run (default 2).
# REFERENCE_COMPARE_STATUS: qemu-img compare status (0 identical, 1 different, 2 error).
reference_install_discovery_doubles() {
  reference_install_e2e_doubles
  rm -f -- "${REFERENCE_DOUBLE_DIR}/qemu-system-x86_64" "${REFERENCE_DOUBLE_DIR}/qemu-img"

  cat > "${REFERENCE_DOUBLE_DIR}/qemu-system-x86_64" <<'EOF'
#!/usr/bin/bash
printf 'qemu-system-x86_64 %s\n' "$*" >> "${REFERENCE_CALL_LOG:?}"
if [[ "${1:-}" == '--version' ]]; then
  echo 'QEMU emulator version 9.9.9'
  exit 0
fi
serial=''
for argument in "$@"; do
  [[ "$argument" == '-S' ]] && exit 0
  [[ "$argument" == file:*guest-serial.log ]] && serial="${argument#file:}"
done
case_name="$(basename "$(dirname "$serial")")"
run_id="$case_name"
case "$case_name" in
  approve | cancel | mismatch | layout-change) run_id="$(basename "$(dirname "$(dirname "$serial")")")" ;;
esac
printf 'SERIAL-NOISE-MARKER\r\n' >> "$serial"
exit_status="${REFERENCE_DISCOVERY_EXIT:-0}"
case "${REFERENCE_QEMU_MODE:-pass}" in
  exit) exit 3 ;;
  pass)
    if [[ "$exit_status" -eq 0 ]]; then validation='valid'; else validation='invalid'; fi
    facts="{\"format_version\":1,\"validation\":{\"status\":\"${validation}\",\"reasons\":[{\"code\":\"identity_pending_capture\"}],\"warnings\":[]}}"
    plan_section=''
    if [[ "${REFERENCE_PLAN_REPORT:-0}" == 1 ]]; then
      # shellcheck disable=SC2016 # The Node program is a literal; its arguments are passed explicitly.
      plan_section=",\"plan\":$(node -e '
        const { createHash } = require("node:crypto");
        const [same, tamper, invalidExit] = process.argv.slice(1);
        const plan = (hostname, option, digest, hostSource) => JSON.stringify({
          choices: { hostname: { value: hostname, source: hostSource }, storage_option: { value: option, source: "choice" } },
          digest: { algorithm: "sha256", value: digest },
        });
        const first = plan("mirroros-ref", "ext4-systemd-boot", "a".repeat(64), "override");
        const second = plan("mirroros-edit", "btrfs-rescue", (same === "1" ? "a" : "b").repeat(64), "choice");
        const sha = createHash("sha256").update(first).digest("hex");
        const run = (name, status, body) => ({
          name, exit_status: status, plan: body, plan_text: body === null ? null : "plan text\n",
          plan_run: "{}", stdout_tail: "", stderr_tail: "",
        });
        process.stdout.write(JSON.stringify({
          runs: [run("default", 0, first), run("edited", 0, second), run("invalid", Number(invalidExit), null)],
          sha256_before: sha,
          sha256_after: tamper === "1" ? "f".repeat(64) : sha,
        }));
      ' "${REFERENCE_PLAN_SAME_DIGEST:-0}" "${REFERENCE_PLAN_TAMPER:-0}" "${REFERENCE_PLAN_INVALID_EXIT:-2}")"
    fi
    if [[ "${REFERENCE_CONFIRMATION_REPORT:-0}" == 1 ]]; then
      # shellcheck disable=SC2016 # Literal Node program with explicit arguments.
      plan_section=",\"confirmation\":$(node -e '
        const [name, bad, missing] = process.argv.slice(1);
        const expected = {approve: [2, "approved", "engine_not_available"], cancel: [3, "cancelled", undefined],
          mismatch: [3, "cancelled", "confirmation_mismatch"], "layout-change": [2, "invalidated", "target_layout_changed"]}[name];
        const common = {run_id: "apply-run", outcome: bad === "1" ? "failed" : expected[1]};
        const files = {"apply-run.json": JSON.stringify({...common, exit_status: expected[0]}),
          "approval-record.json": JSON.stringify({...common, reason: expected[2]}), "apply.log": "plain log\n"};
        if (missing === "1") delete files["approval-record.json"];
        process.stdout.write(JSON.stringify({name, exit_status: expected[0], files, private_permissions: true, layout_write_status: 0}));
      ' "$case_name" "${REFERENCE_CONFIRMATION_BAD_OUTCOME:-0}" "${REFERENCE_CONFIRMATION_MISSING_RECORD:-0}")"
    fi
    printf 'MIRROROS-REPORT-BEGIN %s\r\n{"schema_version":1,"run_id":"%s","target":"%s","exit_status":%s,"facts":%s,"error":null,"stderr_tail":""%s}\r\nMIRROROS-REPORT-END %s\r\n' \
      "$run_id" "$run_id" "${REFERENCE_DISCOVERY_TARGET:?}" "$exit_status" "$facts" "$plan_section" "$run_id" >> "$serial"
    ;;
esac
exec sleep 31
EOF
  cat > "${REFERENCE_DOUBLE_DIR}/qemu-img" <<'EOF'
#!/usr/bin/bash
printf 'qemu-img %s\n' "$*" >> "${REFERENCE_CALL_LOG:?}"
case "$1" in
  create) : > "$5" ;;
  convert) : > "${*: -1}" ;;
  compare)
    if [[ "${REFERENCE_CONFIRMATION_REPORT:-0}" == 1 && "${REFERENCE_COMPARE_STATUS:-0}" == 0 ]]; then
      case "$(dirname "${*: -1}")" in
        *) [[ "$(grep -c 'qemu-img compare' "$REFERENCE_CALL_LOG")" -eq 4 ]] && exit 1 ;;
      esac
    fi
    exit "${REFERENCE_COMPARE_STATUS:-0}"
    ;;
esac
EOF
  cat > "${REFERENCE_DOUBLE_DIR}/sfdisk" <<'EOF'
#!/usr/bin/bash
printf 'sfdisk %s\n' "$*" >> "${REFERENCE_CALL_LOG:?}"
cat > "${REFERENCE_CALL_LOG}.sfdisk-input"
EOF
  chmod 755 "${REFERENCE_DOUBLE_DIR}/qemu-system-x86_64" "${REFERENCE_DOUBLE_DIR}/qemu-img" "${REFERENCE_DOUBLE_DIR}/sfdisk"
}

# Rewrites the synthetic bundle so that its build commit and dirty state are the given values.
reference_set_bundle_build() {
  local directory="$1"
  local commit="$2"
  local dirty="$3"

  # shellcheck disable=SC2016 # The Node program is a literal; its arguments are passed explicitly.
  node -e '
    const fs = require("node:fs");
    const [directory, commit, dirty] = process.argv.slice(1);
    const path = `${directory}/artifact-metadata.json`;
    const metadata = JSON.parse(fs.readFileSync(path, "utf8"));
    metadata.execution.commit = commit;
    metadata.execution.dirty = dirty === "true";
    fs.writeFileSync(path, JSON.stringify(metadata));
  ' "$directory" "$commit" "$dirty"
  local metadata_sha
  metadata_sha="$(sha256sum "${directory}/artifact-metadata.json")"
  metadata_sha="${metadata_sha%% *}"
  sed -i "s#^[0-9a-f]\{64\}  artifact-metadata.json\$#${metadata_sha}  artifact-metadata.json#" "${directory}/SHA256SUMS"
}

# Arguments: qualify-discovery arguments. Runs the copied qualifier from an unrelated directory.
reference_invoke_discovery() {
  local command_path="${REFERENCE_REPOSITORY_ROOT}/vm/reference/qualify-discovery"

  : > "$REFERENCE_CALL_LOG"
  if (
    cd -- "$REFERENCE_OUTSIDE_DIR" || exit 125
    PATH="${REFERENCE_DOUBLE_DIR}:${PATH}" \
      REFERENCE_CALL_LOG="$REFERENCE_CALL_LOG" \
      "$command_path" "$@"
  ) > "$REFERENCE_STDOUT_PATH" 2> "$REFERENCE_STDERR_PATH"; then
    REFERENCE_COMMAND_STATUS=0
  else
    # shellcheck disable=SC2034 # Read by the Bats contract suites.
    REFERENCE_COMMAND_STATUS=$?
  fi
}

# Prints the single run directory below evidence/reference-vm/discovery/.
reference_discovery_evidence_dir() {
  local -a runs=("${REFERENCE_REPOSITORY_ROOT}"/evidence/reference-vm/discovery/*/)

  [[ "${#runs[@]}" -eq 1 && -d "${runs[0]}" ]] || return 1
  printf '%s' "${runs[0]%/}"
}

reference_result_field() {
  node -e '
    const result = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
    const value = process.argv[2].split(".").reduce((node, key) => node?.[key], result);
    process.stdout.write(String(value));
  ' "$(reference_discovery_evidence_dir)/result.json" "$1"
}
