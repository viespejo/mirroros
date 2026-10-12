# shellcheck disable=SC2034 # State variables are read by the Bats files that load this helper.
ENGINE_SUPPORT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ENGINE_SOURCE_ROOT="$(cd -- "${ENGINE_SUPPORT_DIR}/../../.." && pwd -P)"
ENGINE_DISCOVERY_SUPPORT="${ENGINE_SOURCE_ROOT}/tests/install/discovery"
ENGINE_PLAN_FIXTURES="${ENGINE_SOURCE_ROOT}/tests/fixtures/plan"
ENGINE_CANARY='PLANTED-ENGINE-SECRET-0001'
ENGINE_COMMIT='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
ENGINE_TOOLS=(wipefs sfdisk blockdev partprobe udevadm mkfs.fat mkfs.ext4 mkfs.btrfs btrfs blkid mount umount mountpoint
  swapoff genfstab mkswap filefrag systemctl pacstrap arch-chroot sleep)

ENGINE_STATUS=0
ENGINE_PASSWORD="$ENGINE_CANARY"

engine_setup() {
  local tool

  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/mirroros engine.XXXXXX")"
  CODE_ROOT="${TEST_ROOT}/embedded code"
  FIXTURE_ROOT="${TEST_ROOT}/fixture root"
  DOUBLE_STATE="${TEST_ROOT}/double state"
  DOUBLE_BIN="${TEST_ROOT}/double bin"
  RUN_ROOT="${TEST_ROOT}/run root"
  OUTPUT="${TEST_ROOT}/run directory/engine"
  mkdir -p "$CODE_ROOT" "$FIXTURE_ROOT" "$DOUBLE_STATE/out" "$DOUBLE_BIN" "$RUN_ROOT"
  cp -a "${ENGINE_SOURCE_ROOT}/install" "${CODE_ROOT}/install"
  mkdir -p "${CODE_ROOT}/hardware"
  cp -a "${ENGINE_SOURCE_ROOT}/hardware/discovery" "${CODE_ROOT}/hardware/discovery"
  printf '{\n  "commit": "%s",\n  "dirty": false\n}\n' "$ENGINE_COMMIT" > "${CODE_ROOT}/identity.json"
  for tool in "${ENGINE_TOOLS[@]}"; do
    ln -s "${ENGINE_SUPPORT_DIR}/doubles/engine-double" "${DOUBLE_BIN}/${tool}"
  done
  ln -s "${ENGINE_DISCOVERY_SUPPORT}/doubles/lsblk" "${DOUBLE_BIN}/lsblk"
  : > "${DOUBLE_STATE}/calls.log"
  engine_make_packages
  node "${ENGINE_DISCOVERY_SUPPORT}/build-root.mjs" "${ENGINE_SOURCE_ROOT}/tests/fixtures/discovery/raw/reference-vm-layout.json" \
    "$FIXTURE_ROOT" "$DOUBLE_STATE"
  mkdir -p "${FIXTURE_ROOT}/etc/pacman.d"
  printf 'Server = https://mirror.example.invalid/$repo/os/$arch\n' > "${FIXTURE_ROOT}/etc/pacman.d/mirrorlist"
  engine_use_plan ext4-systemd-boot--password
}

# The prebuilt Limine packages and their manifest, as the artifact embeds them next to the engine code.
engine_make_packages() {
  local directory="${CODE_ROOT}/packages"
  mkdir -p "$directory"
  printf 'package one\n' > "${directory}/limine-mkinitcpio-hook-1.0-1-any.pkg.tar.zst"
  printf 'package two\n' > "${directory}/limine-snapper-sync-1.0-1-any.pkg.tar.zst"
  node -e '
    const { createHash } = require("crypto");
    const { readFileSync, writeFileSync } = require("fs");
    const directory = process.argv[1];
    const entry = (name, file) => ({
      name, file, version: "1.0-1",
      sha256: createHash("sha256").update(readFileSync(`${directory}/${file}`)).digest("hex")
    });
    writeFileSync(`${directory}/packages.json`, JSON.stringify({
      schema_version: 1,
      packages: [
        entry("limine-mkinitcpio-hook", "limine-mkinitcpio-hook-1.0-1-any.pkg.tar.zst"),
        entry("limine-snapper-sync", "limine-snapper-sync-1.0-1-any.pkg.tar.zst")
      ]
    }));
  ' "$directory"
}

engine_teardown() {
  if [[ -n "${TEST_ROOT:-}" && -d "$TEST_ROOT" ]]; then
    rm -rf -- "$TEST_ROOT"
  fi
}

# Selects a committed valid plan fixture and its digest.
engine_use_plan() {
  PLAN="${ENGINE_PLAN_FIXTURES}/valid/${1}.json"
  DIGEST="$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).digest.value)' "$PLAN")"
}

# Selects an invalid plan fixture; its digest is its own (the loader rejects it for the fixture's own reason).
engine_use_invalid_plan() {
  PLAN="${ENGINE_PLAN_FIXTURES}/invalid/${1}.json"
  DIGEST="$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")).digest.value)' "$PLAN")"
}

# Runs the engine with the doubles first on PATH and the password on fd 3. Sets ENGINE_STATUS; stdout and
# stderr are kept in the test root.
engine_run() {
  ENGINE_STATUS=0
  PATH="${DOUBLE_BIN}:${PATH}" DOUBLE_STATE="$DOUBLE_STATE" MIRROROS_DISCOVERY_ROOT="$FIXTURE_ROOT" \
    MIRROROS_ENGINE_RUN_ROOT="$RUN_ROOT" "${CODE_ROOT}/install/engine/apply" \
    --plan "$PLAN" --digest "$DIGEST" --output "$OUTPUT" 3< <(printf '%s\n' "$ENGINE_PASSWORD") \
    > "${TEST_ROOT}/stdout.log" 2> "${TEST_ROOT}/stderr.log" || ENGINE_STATUS=$?
}

# A field of engine-run.json read with Node (no jq).
engine_json() {
  node -e '
    const run = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
    const value = process.argv[2].split(".").reduce((item, key) => (item === undefined ? undefined : item[key]), run);
    process.stdout.write(typeof value === "object" ? JSON.stringify(value) : String(value));
  ' "${OUTPUT}/${2:-engine-run.json}" "$1"
}

# The call log of the doubles contains the tool (as the first word of a line).
engine_called() {
  grep -q -- "^${1} " "${DOUBLE_STATE}/calls.log"
}

# The line number of the first call of a tool in the call log.
engine_call_line() {
  grep -n -m1 -- "^${1} " "${DOUBLE_STATE}/calls.log" | cut -d: -f1
}

# No destructive tool was invoked.
engine_disk_untouched() {
  ! engine_called wipefs && ! engine_called sfdisk && ! engine_called mkfs.fat && ! engine_called mkfs.ext4 \
    && ! engine_called mkfs.btrfs && ! engine_called mount && ! engine_called pacstrap
}
