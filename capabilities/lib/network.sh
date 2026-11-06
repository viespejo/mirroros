#!/usr/bin/bash
# DNS integration only; profiles, providers, VPN authentication and routing are not mutated.
# Queries suppress private diagnostics deliberately. Mutation diagnostics stay in root-private recovery storage.

cfg_network_fail() { printf 'Network DNS: %s\n' "$1" >&2; exit 4; }

cfg_network_safe_path() {
  local path="$1" parent boundary
  boundary="$(cfg_path /)"; boundary="${boundary%/}"
  [[ -n "$boundary" ]] || boundary=/
  parent="$(dirname -- "$(cfg_path "$path")")"
  while [[ "$parent" != "$boundary" && "$parent" != / ]]; do
    [[ ! -L "$parent" ]] || return 1
    if [[ -d "$parent" ]]; then
      [[ "$(stat -c %u -- "$parent")" == "$(stat -c %u -- "$(cfg_path /)")" ]] || return 1
      (( (8#$(stat -c %a -- "$parent") & 022) == 0 )) || return 1
    fi
    parent="$(dirname -- "$parent")"
  done
}

cfg_network_link_is_stub() {
  [[ -L "$(cfg_path /etc/resolv.conf)" &&
    "$(readlink -- "$(cfg_path /etc/resolv.conf)")" == /run/systemd/resolve/stub-resolv.conf ]]
}

# A pacstrap target carries a comment-only placeholder: no DNS policy to preserve.
cfg_network_resolver_placeholder() {
  awk '/^[[:space:]]*($|#|;)/ { next } { bad=1 } END { exit bad }' "$1"
}

cfg_network_unit_state() {
  local value
  value=$(cfg_exec systemctl is-enabled systemd-resolved.service 2>/dev/null) || :
  case "$value" in enabled|disabled) printf '%s\n' "$value" ;; *) return 4 ;; esac
}

cfg_network_static_policy() {
  local nm resolved
  nm=$(cfg_exec NetworkManager --print-config 2>/dev/null) || return 4
  # Foreign global DNS rules or another explicitly selected backend require review.
  awk '
    /^\[/ { section=$0 }
    /^\[global-dns/ { bad=1 }
    section == "[main]" && /^[[:space:]]*(dns|rc-manager)[[:space:]]*=/ {
      key=$0; sub(/=.*/, "", key); gsub(/[[:space:]]/, "", key)
      value=$0; sub(/^[^=]*=/, "", value); gsub(/[[:space:]]/, "", value)
      values[key]=value
    }
    END { exit bad || (values["dns"] != "" && values["dns"] != "default" && values["dns"] != "systemd-resolved") ||
      (values["rc-manager"] != "" && values["rc-manager"] != "auto" && values["rc-manager"] != "unmanaged") }
  ' <<< "$nm" || return 4
  resolved=$(cfg_exec systemd-analyze cat-config systemd/resolved.conf 2>/dev/null) || return 4
  awk '
    /^\[/ { section=$0 }
    section == "[Resolve]" && /^[[:space:]]*(DNS|Domains|DNSStubListener)[[:space:]]*=/ {
      key=$0; sub(/=.*/, "", key); gsub(/[[:space:]]/, "", key)
      value=$0; sub(/^[^=]*=/, "", value); gsub(/[[:space:]]/, "", value)
      values[key]=value
    }
    END { exit values["DNS"] != "" || values["Domains"] != "" ||
      (values["DNSStubListener"] != "" && values["DNSStubListener"] != "yes") }
  ' <<< "$resolved"
}

cfg_network_legacy_resolver() {
  local file dns domains supplied wanted
  file="$(cfg_path /etc/resolv.conf)"
  [[ -f "$file" && ! -L "$file" ]] || return 4
  # Unsupported resolver options may encode manual policy: do not silently discard them.
  awk '/^[[:space:]]*($|#|;)/ { next }
    $1 != "nameserver" && $1 != "search" && $1 != "domain" { bad=1 }
    END { exit bad }' "$file" || return 4
  dns=$(cfg_exec nmcli --escape no -t -f IP4.DNS,IP6.DNS device show 2>/dev/null) || return 4
  domains=$(cfg_exec nmcli --escape no -t -f IP4.DOMAIN,IP6.DOMAIN device show 2>/dev/null) || return 4
  wanted=$(awk '$1 == "nameserver" { print $2 }' "$file" | LC_ALL=C sort -u)
  supplied=$(awk '/^IP[46]\.DNS\[[0-9]+\]:/ { sub(/^[^:]*:/, ""); print }' <<< "$dns" | LC_ALL=C sort -u)
  [[ -n "$wanted" && "$wanted" == "$supplied" ]] || return 4
  wanted=$(awk '$1 == "search" || $1 == "domain" { for (i=2; i<=NF; i++) print $i }' "$file" | LC_ALL=C sort -u)
  supplied=$(awk '/^IP[46]\.DOMAIN\[[0-9]+\]:/ { sub(/^[^:]*:/, ""); print }' <<< "$domains" | LC_ALL=C sort -u)
  [[ "$wanted" == "$supplied" ]]
}

cfg_network_effective() {
  local value property expected
  cfg_exec systemctl is-active --quiet systemd-resolved.service > /dev/null 2>&1 || return 4
  for property in Mode RcManager; do
    expected='s "systemd-resolved"'
    [[ "$property" != RcManager ]] || expected='s "unmanaged"'
    value=$(cfg_exec busctl --system get-property org.freedesktop.NetworkManager \
      /org/freedesktop/NetworkManager/DnsManager org.freedesktop.NetworkManager.DnsManager "$property" 2>/dev/null) || return 4
    [[ "$value" == "$expected" ]] || return 4
  done
  for property in DNS Domains; do
    expected='a(iiay)'
    [[ "$property" != Domains ]] || expected='a(isb)'
    value=$(cfg_exec busctl --json=short --system get-property org.freedesktop.resolve1 /org/freedesktop/resolve1 \
      org.freedesktop.resolve1.Manager "$property" 2>/dev/null) || return 4
    # Manager arrays include all links; only interface index 0 denotes global policy.
    # shellcheck disable=SC2016 # signature is a jq variable passed explicitly with --arg.
    cfg_exec jq -e --arg signature "$expected" '
      .type == $signature and (.data | type == "array") and
      all(.data[]; type == "array" and length == 3 and (.[0] | type == "number" and . > 0))
    ' > /dev/null 2>&1 <<< "$value" || return 4
  done
}

cfg_network_lookup() {
  # No private name is ever used as a generic configure postcondition.
  cfg_exec timeout 15 getent ahostsv4 example.com > /dev/null 2>&1
}

cfg_network_dns_present() {
  cfg_network_link_is_stub && cfg_tracked_file_present /etc/NetworkManager/conf.d/20-mirroros-dns.conf &&
    cfg_unit_enabled systemd-resolved.service || return 4
  [[ "$CONFIGURE_CONTEXT" != running ]] || { cfg_network_effective && cfg_network_lookup; }
}

cfg_network_command() {
  local phase="$1" status=0
  shift
  cfg_log "Network DNS: $phase"
  cfg_exec timeout 30 "$@" >> "$CFG_NETWORK_TXN/operations.log" 2>&1 || status=$?
  if (( status )); then
    printf 'Network DNS: %s failed (child status %s); diagnostics retained in private recovery storage.\n' "$phase" "$status" >&2
    return "$status"
  fi
}

cfg_network_private_valid() {
  local directory="$1" owner file
  owner=$(stat -c %u -- "$(cfg_path /)")
  [[ -d "$directory" && ! -L "$directory" && "$(stat -c '%u:%a' -- "$directory")" == "$owner:700" ]] || return 4
  for file in "$directory"/*; do
    [[ -f "$file" && ! -L "$file" && "$(stat -c '%u:%a:%h' -- "$file")" == "$owner:600:1" ]] || return 4
  done
}

cfg_network_recover() {
  local failed=0 path name file state
  cfg_network_private_valid "$CFG_NETWORK_TXN" || return 4
  state=$(< "$CFG_NETWORK_TXN/state")
  [[ "$state" == prepared || "$state" == applying || "$state" == committed ]] || return 4
  [[ "$(< "$CFG_NETWORK_TXN/context")" == "$CONFIGURE_CONTEXT" ]] || return 4
  cfg_network_unit_state > /dev/null || return 4
  # Do not overwrite edits made after interruption. Only the exact before/after states are recoverable.
  for name in resolver configuration record; do
    case "$name" in
      resolver) path=/etc/resolv.conf ;;
      configuration) path=/etc/NetworkManager/conf.d/20-mirroros-dns.conf ;;
      record) path=/var/lib/mirroros/configure/delivered/etc/NetworkManager/conf.d/20-mirroros-dns.conf.sha256 ;;
    esac
    file="$(cfg_path "$path")"
    if [[ "$name" == resolver ]]; then
      cfg_network_link_is_stub && continue
      if [[ -f "$CFG_NETWORK_TXN/$name.before" ]]; then
        [[ -f "$file" && ! -L "$file" ]] && cmp -s "$file" "$CFG_NETWORK_TXN/$name.before" && continue
      fi
    elif [[ -f "$file" && ! -L "$file" ]]; then
      cmp -s "$file" "$CFG_NETWORK_TXN/$name.after" && continue
      if [[ -f "$CFG_NETWORK_TXN/$name.before" ]]; then
        cmp -s "$file" "$CFG_NETWORK_TXN/$name.before" && continue
      fi
    fi
    [[ ! -e "$file" && ! -L "$file" && "$(< "$CFG_NETWORK_TXN/$name.kind")" == absent ]] || return 4
  done
  for name in resolver configuration record; do
    case "$name" in
      resolver) path=/etc/resolv.conf ;;
      configuration) path=/etc/NetworkManager/conf.d/20-mirroros-dns.conf ;;
      record) path=/var/lib/mirroros/configure/delivered/etc/NetworkManager/conf.d/20-mirroros-dns.conf.sha256 ;;
    esac
    file="$(cfg_path "$path")"
    [[ ! -e "$file.restore" && ! -L "$file.restore" ]] || return 4
    case "$(< "$CFG_NETWORK_TXN/$name.kind")" in
      absent) rm -f -- "$file" || failed=1 ;;
      file)
        # Preserve original metadata in the private backup's separately recorded mode.
        install -m "$(< "$CFG_NETWORK_TXN/$name.mode")" "$CFG_NETWORK_TXN/$name.before" "$file.restore" &&
          mv -Tf -- "$file.restore" "$file" || failed=1 ;;
      stub)
        ln -s /run/systemd/resolve/stub-resolv.conf "$file.restore" && mv -Tf -- "$file.restore" "$file" || failed=1 ;;
      *) failed=1 ;;
    esac
  done
  if [[ "$CONFIGURE_CONTEXT" == running ]]; then
    cfg_network_command rollback-config nmcli general reload conf || failed=1
    if [[ "$(< "$CFG_NETWORK_TXN/active")" == active ]]; then
      cfg_network_command rollback-resolver systemctl reload systemd-resolved.service || failed=1
    fi
    cfg_network_command rollback-dns nmcli general reload dns-full || failed=1
  fi
  case "$(< "$CFG_NETWORK_TXN/enabled")" in
    enabled) cfg_network_command rollback-enable systemctl enable systemd-resolved.service || failed=1 ;;
    disabled) cfg_network_command rollback-disable systemctl disable systemd-resolved.service || failed=1 ;;
    *) failed=1 ;;
  esac
  if [[ "$CONFIGURE_CONTEXT" == running ]]; then
    case "$(< "$CFG_NETWORK_TXN/active")" in
      active) cfg_network_command rollback-start systemctl start systemd-resolved.service || failed=1 ;;
      inactive) cfg_network_command rollback-stop systemctl stop systemd-resolved.service || failed=1 ;;
      *) failed=1 ;;
    esac
    # Never run NSS probes after restoring activity: they can activate the service.
    state=inactive
    if cfg_exec systemctl is-active --quiet systemd-resolved.service > /dev/null 2>&1; then state=active; fi
    [[ "$state" == "$(< "$CFG_NETWORK_TXN/active")" ]] || failed=1
  fi
  for name in resolver configuration record; do
    case "$name" in
      resolver) path=/etc/resolv.conf ;;
      configuration) path=/etc/NetworkManager/conf.d/20-mirroros-dns.conf ;;
      record) path=/var/lib/mirroros/configure/delivered/etc/NetworkManager/conf.d/20-mirroros-dns.conf.sha256 ;;
    esac
    file="$(cfg_path "$path")"
    case "$(< "$CFG_NETWORK_TXN/$name.kind")" in
      absent) [[ ! -e "$file" && ! -L "$file" ]] || failed=1 ;;
      stub) cfg_network_link_is_stub || failed=1 ;;
      file)
        if [[ -f "$file" && ! -L "$file" ]]; then
          cmp -s -- "$file" "$CFG_NETWORK_TXN/$name.before" || failed=1
          [[ "$(stat -c %a -- "$file")" == "$(< "$CFG_NETWORK_TXN/$name.mode")" ]] || failed=1
        else failed=1; fi ;;
      *) failed=1 ;;
    esac
  done
  state=$(cfg_network_unit_state) || failed=1
  [[ "$state" == "$(< "$CFG_NETWORK_TXN/enabled")" ]] || failed=1
  (( failed == 0 )) || return 4
  printf 'rolled-back\n' > "$CFG_NETWORK_TXN/state" || return 4
  cfg_changed || return 4
}

cfg_network_abort() {
  local status="$1"
  trap - ERR INT TERM HUP
  if cfg_network_recover; then
    printf 'Network DNS: prior state restored; review private recovery diagnostics before retrying.\n' >&2
  else
    printf 'Network DNS: recovery incomplete; stop and inspect private recovery storage before retrying.\n' >&2
  fi
  exit "$status"
}

cfg_network_snapshot() {
  local path name file kind mode
  for name in resolver configuration record; do
    case "$name" in
      resolver) path=/etc/resolv.conf ;;
      configuration) path=/etc/NetworkManager/conf.d/20-mirroros-dns.conf ;;
      record) path=/var/lib/mirroros/configure/delivered/etc/NetworkManager/conf.d/20-mirroros-dns.conf.sha256 ;;
    esac
    file="$(cfg_path "$path")"
    kind=absent
    if [[ "$name" == resolver ]] && cfg_network_link_is_stub; then kind=stub
    elif [[ -f "$file" && ! -L "$file" ]]; then
      kind='file'
      mode=$(stat -c %a -- "$file")
      printf '%s\n' "$mode" > "$CFG_NETWORK_TXN/$name.mode"
      install -m 0600 -- "$file" "$CFG_NETWORK_TXN/$name.before"
    fi
    printf '%s\n' "$kind" > "$CFG_NETWORK_TXN/$name.kind"
  done
}

cfg_network_dns_apply() {
  local source="$1" conf=/etc/NetworkManager/conf.d/20-mirroros-dns.conf
  local private path current desired legacy
  private="$(cfg_path /var/lib/mirroros/configure/network-dns)"
  local enabled active=offline types archived old_err old_int old_term old_hup old_umask
  cfg_context
  for path in /etc/resolv.conf "$conf" /var/lib/mirroros/configure/network-dns/current/state \
    /var/lib/mirroros/configure/delivered/etc/NetworkManager/conf.d/20-mirroros-dns.conf.sha256; do
    cfg_network_safe_path "$path" || { cfg_network_fail 'unsafe parent path; review ownership before migration.'; }
  done
  CFG_NETWORK_TXN="$private/current"
  if [[ -e "$CFG_NETWORK_TXN" || -L "$CFG_NETWORK_TXN" ]]; then
    cfg_network_private_valid "$CFG_NETWORK_TXN" || { cfg_network_fail 'unsafe recovery storage.'; }
    [[ -f "$CFG_NETWORK_TXN/state" ]] || { cfg_network_fail 'incomplete snapshot; review private recovery storage.'; }
    case "$(< "$CFG_NETWORK_TXN/state")" in
      committed|rolled-back) ;;
      prepared|applying)
        cfg_network_recover || { cfg_network_fail 'interrupted migration requires private recovery review.'; }
        cfg_network_fail 'interrupted migration restored; review recovery, then rerun configure.' ;;
      *) cfg_network_fail 'unknown recovery state; review before retrying.' ;;
    esac
  fi
  [[ -f "$(cfg_path /usr/lib/systemd/system/systemd-resolved.service)" ]] || {
    cfg_network_fail 'packaged resolver unit is missing; repair the systemd installation.';
  }
  cfg_network_static_policy || { cfg_network_fail 'conflicting or unreadable DNS policy; review privately.'; }
  for path in systemd-networkd.service connman.service dnsmasq.service unbound.service; do
    current=is-enabled
    [[ "$CONFIGURE_CONTEXT" != running ]] || current=is-active
    if cfg_exec systemctl "$current" --quiet "$path" > /dev/null 2>&1; then
      cfg_network_fail 'competing network/resolver service; review ownership before migration.'
    fi
  done
  enabled=$(cfg_network_unit_state) || { cfg_network_fail 'resolver unit is masked, unavailable or unsupported.'; }
  if cfg_network_link_is_stub && cfg_tracked_file_present "$conf" && [[ "$enabled" == enabled ]]; then
    if [[ "$CONFIGURE_CONTEXT" == target ]]; then return 0; fi
    if cfg_network_effective; then
      cfg_network_lookup || cfg_network_fail 'public DNS lookup unavailable; integration unchanged, check connectivity.'
      return 0
    fi
  fi
  # A change needs a safe window, never an automatic VPN disconnect.
  if [[ "$CONFIGURE_CONTEXT" == running ]]; then
    types=$(cfg_exec nmcli -g TYPE connection show --active 2>/dev/null) || return 4
    if grep -Eq '^(vpn|tun|wireguard)$' <<< "$types"; then
      cfg_network_fail 'active tunnel; arrange a separately approved safe migration window.'
    fi
    active=inactive
    if cfg_exec systemctl is-active --quiet systemd-resolved.service > /dev/null 2>&1; then active=active; fi
    # A supported reload is mandatory; never substitute restart for a missing interface.
    current=$(cfg_exec systemctl show systemd-resolved.service -p CanReload --value 2>/dev/null) || return 4
    [[ "$current" == yes ]] || { cfg_network_fail 'resolver reload is unsupported; review upstream compatibility.'; }
  fi
  if ! cfg_network_link_is_stub; then
    path="$(cfg_path /etc/resolv.conf)"
    if [[ -e "$path" || -L "$path" ]]; then
      if [[ "$CONFIGURE_CONTEXT" == target ]]; then
        if [[ ! -f "$path" || -L "$path" ]] ||
          { ! cmp -s "$path" /etc/resolv.conf && ! cfg_network_resolver_placeholder "$path"; }; then
          cfg_network_fail 'target resolver is not the live-medium copy; review manual DNS policy.'
        fi
      else
        cfg_network_legacy_resolver || { cfg_network_fail 'legacy resolver policy is not represented by NetworkManager; review privately.'; }
      fi
    elif [[ "$CONFIGURE_CONTEXT" == running ]]; then
      cfg_network_fail 'running resolver is missing; repair connectivity before migration.'
    fi
  fi
  path="$(cfg_path "$conf")"
  desired=$(sha256sum < "$source"); desired=${desired%% *}
  legacy=$(printf '[main]\ndns=systemd-resolved\nrc-manager=unmanaged\n' | sha256sum); legacy=${legacy%% *}
  if [[ -e "$path" || -L "$path" ]]; then
    [[ -f "$path" && ! -L "$path" ]] || { cfg_network_fail 'backend path is not a regular file.'; }
    current=$(sha256sum < "$path"); current=${current%% *}
    [[ "$current" == "$desired" || "$current" == "$legacy" ]] || { cfg_network_fail 'backend configuration has local edits.'; }
  fi
  # Reject an unrecognised delivery record before snapshotting it.
  path=$(cfg_tracked_record "$conf")
  if [[ -e "$path" || -L "$path" ]]; then
    [[ -f "$path" && ! -L "$path" && "$(< "$path")" == "$desired" ]] || { cfg_network_fail 'conflicting backend delivery record.'; }
  fi
  for path in /etc/resolv.conf "$conf" /var/lib/mirroros/configure/delivered/etc/NetworkManager/conf.d/20-mirroros-dns.conf.sha256; do
    path="$(cfg_path "$path")"
    if [[ -f "$path" && ! -L "$path" ]]; then
      [[ "$(stat -c '%u:%g:%h' -- "$path")" == "$(stat -c '%u:%g' -- "$(cfg_path /)"):1" ]] || {
        cfg_network_fail 'resolver files must have system ownership and a single link.';
      }
      current=$(lsattr -d -- "$path" 2>/dev/null) || { cfg_network_fail 'cannot inspect resolver file attributes; check live e2fsprogs support.'; }
      current=${current%% *}
      [[ "$current" != *i* && "$current" != *a* ]] || { cfg_network_fail 'immutable or append-only resolver file; review before migration.'; }
    fi
  done
  old_umask=$(umask); umask 077
  mkdir -p -- "$private"
  chmod 0700 -- "$private"
  if [[ -d "$CFG_NETWORK_TXN" ]]; then
    archived=$(mktemp -d "$private/recovery.XXXXXXXX")
    rmdir -- "$archived"
    mv -T -- "$CFG_NETWORK_TXN" "$archived"
  fi
  mkdir -m 0700 -- "$CFG_NETWORK_TXN"
  cfg_network_snapshot
  install -m 0600 -- "$source" "$CFG_NETWORK_TXN/configuration.after"
  printf '%s\n' "$desired" > "$CFG_NETWORK_TXN/record.after"
  printf '%s\n' "$enabled" > "$CFG_NETWORK_TXN/enabled"
  printf '%s\n' "$active" > "$CFG_NETWORK_TXN/active"
  printf '%s\n' "$CONFIGURE_CONTEXT" > "$CFG_NETWORK_TXN/context"
  : > "$CFG_NETWORK_TXN/operations.log"
  printf 'prepared\n' > "$CFG_NETWORK_TXN/state"
  old_err=$(trap -p ERR); old_int=$(trap -p INT); old_term=$(trap -p TERM); old_hup=$(trap -p HUP)
  trap 'cfg_network_abort 5' ERR
  trap 'cfg_network_abort 3' INT
  trap 'cfg_network_abort 5' TERM HUP
  printf 'applying\n' > "$CFG_NETWORK_TXN/state"
  # Native paths and fixed content only; no profile/server/domain values enter cfg_run.
  cfg_tracked_file "$source" "$conf" 0644 "$legacy"
  path="$(cfg_path /etc/resolv.conf)"
  if ! cfg_network_link_is_stub; then
    ln -s /run/systemd/resolve/stub-resolv.conf "$path.mirroros-new"
    mv -Tf -- "$path.mirroros-new" "$path"
    cfg_changed
  fi
  if [[ "$enabled" == disabled ]]; then cfg_network_command enable systemctl enable systemd-resolved.service; fi
  if [[ "$CONFIGURE_CONTEXT" == running ]]; then
    if [[ "$active" == inactive ]]; then cfg_network_command start systemctl start systemd-resolved.service; fi
    cfg_network_command reload-config nmcli general reload conf
    cfg_network_command refresh-resolver systemctl reload systemd-resolved.service
    cfg_network_command republish-dns nmcli general reload dns-full
  fi
  if ! cfg_network_dns_present; then cfg_network_abort 4; fi
  printf 'committed\n' > "$CFG_NETWORK_TXN/state"
  cfg_changed
  # Restore the caller's traps without evaluating generated text.
  trap - ERR INT TERM HUP
  # The outer configure step owns these fixed handlers; no user-supplied trap is evaluated.
  if [[ -n "$old_err" ]]; then trap 'printf "Command failed (child status %s).\n" "$?" >&2; exit 5' ERR; fi
  if [[ -n "$old_int" ]]; then trap 'exit 3' INT; fi
  if [[ -n "$old_term" ]]; then trap 'exit 5' TERM; fi
  if [[ -n "$old_hup" ]]; then trap 'exit 5' HUP; fi
  umask "$old_umask"
}
