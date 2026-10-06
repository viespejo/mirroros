#!/usr/bin/bash
# Guest helpers shared by the runner and by both engines' `install` scripts.
# Sourced inside the live environment; nothing here runs on the installed system.

mirroros_proto_log() {
  printf 'MirrorOS prototype guest: %s\n' "$*"
}

# Reads the two synthetic credentials from file descriptor 3: the user password first, the root
# password second. Sets MIRROROS_USER_PASSWORD and MIRROROS_ROOT_PASSWORD in the calling shell.
mirroros_proto_read_secrets() {
  MIRROROS_USER_PASSWORD=''
  MIRROROS_ROOT_PASSWORD=''
  { IFS= read -r MIRROROS_USER_PASSWORD && IFS= read -r MIRROROS_ROOT_PASSWORD; } <&3 || return 1
  [[ -n "$MIRROROS_USER_PASSWORD" && -n "$MIRROROS_ROOT_PASSWORD" ]]
}

# Installs the shared systemd verification unit into the installed system (known prototype
# contamination, identical for both engines). Argument: the target root mount point.
mirroros_proto_install_verifier() {
  local target_root="$1"
  local seed_dir="${MIRROROS_SEED_DIR:?}"

  install -D -m 0755 "${seed_dir}/verify-postconditions.sh" \
    "${target_root}/usr/local/lib/mirroros-proto/verify-postconditions.sh" || return 1
  install -D -m 0644 "${seed_dir}/mirroros-proto-verify.service" \
    "${target_root}/etc/systemd/system/mirroros-proto-verify.service" || return 1
  install -d -m 0755 "${target_root}/etc/mirroros-proto" || return 1
  {
    printf "MIRROROS_RUN_ID='%s'\n" "${MIRROROS_RUN_ID:?}"
    printf "MIRROROS_HTTPS_URL='%s'\n" "${MIRROROS_HTTPS_URL:?}"
    printf "MIRROROS_HTTPS_TIMEOUT_SECONDS='%s'\n" "${MIRROROS_HTTPS_TIMEOUT_SECONDS:?}"
  } > "${target_root}/etc/mirroros-proto/verify.env" || return 1
  systemctl --root="$target_root" enable mirroros-proto-verify.service
}
