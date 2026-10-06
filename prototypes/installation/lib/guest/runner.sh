#!/usr/bin/bash
# Guest runner (boot 1). Executed in the live environment by the NoCloud user-data stub, from the
# mounted NoCloud medium. It is shared by both engines: only the engine's `install` script differs.
#
# Output goes to the serial console between run-bound marker lines. The credentials are read by the
# engine from file descriptor 3, which points at the read-only NoCloud medium; they are never passed
# as arguments and never written to another file.
set -u

SEED_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SERIAL_DEVICE=/dev/ttyS0
SETTLE_WAIT_SECONDS=180

# shellcheck disable=SC1091 # Resolved from the mounted NoCloud medium at run time.
source "${SEED_DIR}/common.sh"
# shellcheck disable=SC1091 # Written by the host harness next to this file.
source "${SEED_DIR}/seed.env"

exec > >(tee -a /run/mirroros-runner.log > "$SERIAL_DEVICE") 2>&1

wait_unit_settled() {
  local unit="$1"
  local deadline=$((SECONDS + SETTLE_WAIT_SECONDS))

  while [[ "$(systemctl is-active "$unit" 2> /dev/null)" == 'activating' ]]; do
    [[ "$SECONDS" -lt "$deadline" ]] || return 1
    sleep 2
  done
}

# Prints stdin between run-bound markers.
emit_block() {
  local marker="$1"

  printf '\n%s-BEGIN %s\n' "$marker" "$MIRROROS_RUN_ID"
  cat
  printf '%s-END %s\n' "$marker" "$MIRROROS_RUN_ID"
}

export MIRROROS_RUN_ID MIRROROS_VARIANT MIRROROS_MODE MIRROROS_TARGET_DISK MIRROROS_HTTPS_URL \
  MIRROROS_HTTPS_TIMEOUT_SECONDS
export MIRROROS_SEED_DIR="$SEED_DIR"

mirroros_proto_log "run ${MIRROROS_RUN_ID}: mode ${MIRROROS_MODE}, variant ${MIRROROS_VARIANT}"

# The live environment refreshes its mirrorlist and initializes the pacman keyring at boot. Wait for
# both so that neither engine races them and the recorded mirrorlist is the one actually used.
wait_unit_settled reflector.service || mirroros_proto_log 'reflector.service did not settle in time'
wait_unit_settled pacman-init.service || mirroros_proto_log 'pacman-init.service did not settle in time'

if [[ -f "${SEED_DIR}/mirrorlist" ]]; then
  cp -- "${SEED_DIR}/mirrorlist" /etc/pacman.d/mirrorlist
  mirroros_proto_log 'delivered an unreachable mirrorlist through NoCloud (failure-injection variant)'
fi
grep -Ev '^[[:space:]]*(#|$)' /etc/pacman.d/mirrorlist | emit_block MIRROROS-MIRRORLIST

if [[ "$MIRROROS_MODE" == 'attended' ]]; then
  # The attended helper starts the engine with the credentials on file descriptor 3.
  {
    printf '#!/usr/bin/bash\n'
    printf 'source %q/seed.env\n' "$SEED_DIR"
    printf 'export MIRROROS_RUN_ID MIRROROS_VARIANT MIRROROS_TARGET_DISK MIRROROS_HTTPS_URL MIRROROS_HTTPS_TIMEOUT_SECONDS\n'
    printf 'export MIRROROS_SEED_DIR=%q MIRROROS_UNATTENDED=0\n' "$SEED_DIR"
    printf 'exec /usr/bin/bash %q/engine/install "$@" 3< %q/secrets\n' "$SEED_DIR" "$SEED_DIR"
  } > /run/mirroros-attended.sh
  mirroros_proto_log 'attended session: log in on this serial console, then run: bash /run/mirroros-attended.sh'
  systemctl start serial-getty@ttyS0.service
  exit 0
fi

export MIRROROS_UNATTENDED=1
exec 3< "${SEED_DIR}/secrets"

started="$SECONDS"
/usr/bin/bash "${SEED_DIR}/engine/install" < /dev/null
engine_status=$?
duration=$((SECONDS - started))
exec 3<&-

mirroros_proto_log "engine finished with exit status ${engine_status} after ${duration} s"

{
  lsblk -b -o NAME,SIZE,TYPE,FSTYPE,PTTYPE,PARTTYPE,MOUNTPOINTS "$MIRROROS_TARGET_DISK" 2>&1
  printf '\n# sfdisk -d\n'
  sfdisk -d "$MIRROROS_TARGET_DISK" 2>&1
  printf '\n# wipefs (list only)\n'
  wipefs "$MIRROROS_TARGET_DISK" 2>&1
} | emit_block MIRROROS-DISKSTATE

printf '{"schema_version":1,"kind":"install","run_id":"%s","variant":"%s","engine_exit_status":%s,"duration_seconds":%s}\n' \
  "$MIRROROS_RUN_ID" "$MIRROROS_VARIANT" "$engine_status" "$duration" | emit_block MIRROROS-INSTALL

sync
sleep 2
systemctl poweroff
