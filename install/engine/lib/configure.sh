#!/usr/bin/bash
# shellcheck disable=SC2034 # Configure fields are consumed by common.sh when writing records.

copy_boot_first_code() {
  local destination="$TARGET/usr/local/lib/mirroros/operations"
  install -d -m 0755 -- "$destination/lib" "$TARGET/usr/local/bin" &&
    install -m 0755 -- "$CODE_ROOT/operations/boot-first" "$destination/boot-first" &&
    install -m 0644 -- "$CODE_ROOT/operations/lib/uefi-boot-entry.sh" "$destination/lib/uefi-boot-entry.sh" &&
    chown 0:0 -- "$destination" "$destination/lib" "$destination/boot-first" "$destination/lib/uefi-boot-entry.sh" &&
    ln -sfn -- /usr/local/lib/mirroros/operations/boot-first "$TARGET/usr/local/bin/mirroros-boot-first" &&
    chown -h 0:0 -- "$TARGET/usr/local/bin/mirroros-boot-first"
}

copy_configure_code() {
  local destination="$TARGET/usr/local/lib/mirroros"
  install -d -m 0755 -- "$destination/operations/lib" "$TARGET/usr/local/bin" &&
    cp -- "$CODE_ROOT/operations/configure" "$destination/operations/configure" &&
    cp -- "$CODE_ROOT/operations/lib/lifecycle-discovery.sh" "$destination/operations/lib/lifecycle-discovery.sh" &&
    cp -- "$CODE_ROOT/operations/lib/timing.sh" "$destination/operations/lib/timing.sh" &&
    cp -R -- "$CODE_ROOT/capabilities" "$destination/" &&
    cp -- "$CODE_ROOT/identity.json" "$destination/identity.json" &&
    find "$destination" -type d -exec chmod 0755 {} + &&
    find "$destination" -type f ! -perm /111 -exec chmod 0644 {} + &&
    find "$destination" -type f -perm /111 -exec chmod 0755 {} + &&
    chmod 0755 -- "$destination/operations/configure" &&
    chown -R 0:0 -- "$destination" &&
    ln -sfn -- /usr/local/lib/mirroros/operations/configure "$TARGET/usr/local/bin/mirroros-configure" &&
    chown -h 0:0 -- "$TARGET/usr/local/bin/mirroros-configure"
}

run_configure() {
  local user='' id line status=0 record old key value kind known name
  local evidence_root="$TARGET/var/log/mirroros/configure" pipe="$OUTPUT/.configure.pipe"
  local previous=()
  for id in "${OP_IDS[@]}"; do
    if [[ "${DISPATCH[$id]}" == op_create_user ]]; then user="${PARAM["${id}.user_name"]-}"; fi
  done
  CURRENT_OP=configure
  timing_begin configure
  CONFIGURE_OUTCOME=6
  CONFIGURE_INTERRUPTED=0
  engine_log '== configure =='
  write_state running configure
  if ! copy_configure_code >> "$ENGINE_LOG" 2>&1; then
    finish not_configured 4
  fi
  for record in "$evidence_root"/*/configure-run.tsv; do
    [[ ! -f "$record" ]] || previous+=("$record")
  done
  mkfifo -m 0600 -- "$pipe"
  # Reset SIGINT inherited by asynchronous jobs before configure installs its own handlers.
  env --default-signal=INT,TERM,HUP "$CODE_ROOT/operations/configure" --target-root "$TARGET" --user "$user" \
    < /dev/null > "$pipe" 2>&1 3>&- 4>&- &
  CONFIGURE_PID=$!
  # The signal reaches configure in the same process group; never send it a second signal.
  trap 'CONFIGURE_INTERRUPTED=1' INT TERM HUP
  while true; do
    line=''
    if IFS= read -r line; then
      :
    elif (( CONFIGURE_INTERRUPTED )); then
      CONFIGURE_INTERRUPTED=0
      continue
    elif [[ -z "$line" ]]; then
      break
    fi
    engine_log "$line"
    if [[ "$line" =~ ^==\ ([1-9][0-9]*/[1-9][0-9]*)\ (.+)\ ==$ ]]; then
      CONFIGURE_POSITION="${BASH_REMATCH[1]}"
      CONFIGURE_STEP="${BASH_REMATCH[2]}"
      write_state running configure
    fi
  done < "$pipe"
  # A trapped signal can interrupt wait; do not clean up while configure still owns the target.
  while true; do
    status=0
    wait "$CONFIGURE_PID" || status=$?
    if ! kill -0 "$CONFIGURE_PID" 2> /dev/null; then break; fi
  done
  rm -- "$pipe"
  trap 'on_signal 2' INT
  trap 'on_signal 15' TERM
  trap 'on_signal 1' HUP
  CONFIGURE_OUTCOME="$status"
  # Signals before configure installs its handlers use the same outcomes as its handlers.
  case "$status" in
    130) CONFIGURE_OUTCOME=3 ;;
    129|143) CONFIGURE_OUTCOME=5 ;;
    0|2|3|4|5|6) ;;
    *) CONFIGURE_OUTCOME=6 ;;
  esac
  CONFIGURE_FAILED_STEP="$CONFIGURE_STEP"
  for record in "$evidence_root"/*/configure-run.tsv; do
    [[ -f "$record" ]] || continue
    known=0
    for old in "${previous[@]}"; do [[ "$record" != "$old" ]] || known=1; done
    (( known == 0 )) || continue
    CONFIGURE_EVIDENCE="${record%/configure-run.tsv}"
    CONFIGURE_EVIDENCE="${CONFIGURE_EVIDENCE#"$TARGET"}"
    while IFS=$'\t' read -r kind key value; do
      if [[ "$kind" == run && "$key" == failed_step ]]; then CONFIGURE_FAILED_STEP="$value"; fi
    done < "$record"
    # Deliver native configure records through the existing installation evidence collector.
    # Never copy arbitrary user content or configure temporary files; failure stays diagnostic.
    if install -d -m 0700 -- "$OUTPUT/configure"; then
      for name in configure-run.tsv packages.tsv sources.tsv; do
        if [[ -f "${record%/*}/$name" && ! -L "${record%/*}/$name" ]]; then
          if ! install -m 0600 -- "${record%/*}/$name" "$OUTPUT/configure/$name"; then
            engine_log "configure evidence could not be retained: $name"
          fi
        fi
      done
    else
      engine_log 'configure evidence directory could not be created'
    fi
  done
  timing_end configure
  if [[ "$CONFIGURE_OUTCOME" != 0 ]]; then finish not_configured 4; fi
}
