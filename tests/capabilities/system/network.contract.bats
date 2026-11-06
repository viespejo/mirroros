#!/usr/bin/env bats
load ../support
load network-support
setup() { network_setup; }
teardown() { cfg_test_teardown; }

@test "DNS running migration preserves policy, enables resolved and reruns without activation" {
  run network_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HW_TEST_ROOT/etc/resolv.conf")" = /run/systemd/resolve/stub-resolv.conf ]
  [ -e "$CFG_TEST_DIR/network-state/active" ]
  [ -e "$CFG_TEST_DIR/network-state/enabled" ]
  [ "$(< "$HW_TEST_ROOT/var/lib/mirroros/configure/network-dns/current/state")" = committed ]
  ! grep -E 'connection (modify|add|up|down)|restart|device reapply' "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  run network_run --output "$CFG_TEST_DIR/second"
  [ "$status" -eq 0 ]
  [[ "$output" == *'system/network: unchanged'* ]]
  ! grep -E 'systemctl (start|reload|enable)|nmcli general reload' "$CFG_TEST_CALLS"
  ! grep -R 'private-fixture' "$CFG_TEST_DIR/first" "$CFG_TEST_DIR/second"
}

@test "DNS target delivery supports later chroot calls without live activation and reruns unchanged" {
  cfg_test_target_context
  rm "$HW_TEST_ROOT/etc/resolv.conf"
  run network_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  [ -L "$HW_TEST_ROOT/etc/resolv.conf" ]
  grep -q '^unshare --mount --propagation private' "$CFG_TEST_CALLS"
  ! grep -E 'systemctl (is-active|start|reload|stop)|^nmcli|busctl|^timeout' "$CFG_TEST_CALLS"
  : > "$CFG_TEST_CALLS"
  run network_run --output "$CFG_TEST_DIR/second"
  [ "$status" -eq 0 ]
  [[ "$output" == *'system/network: unchanged'* ]]
  ! grep -E 'systemctl (enable|start|reload)|pacman -S ' "$CFG_TEST_CALLS"
}

@test "DNS target accepts exact live-medium resolver copy" {
  cfg_test_target_context
  cp -L /etc/resolv.conf "$HW_TEST_ROOT/etc/resolv.conf"
  run network_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
}

@test "DNS rejects manual legacy policy not represented by NetworkManager" {
  printf 'nameserver 192.0.2.99\n' > "$HW_TEST_ROOT/etc/resolv.conf"
  run network_run --output "$CFG_TEST_DIR/failed"
  [ "$status" -eq 4 ]
  grep -q '192.0.2.99' "$HW_TEST_ROOT/etc/resolv.conf"
  ! grep -E 'systemctl (enable|start|reload)' "$CFG_TEST_CALLS"
  ! grep -R '192.0.2.99' "$CFG_TEST_DIR/failed"
}

@test "DNS rejects foreign links, global policy and masked service without activation" {
  for kind in link global mask backend options; do
    rm -f "$HW_TEST_ROOT/etc/resolv.conf"
    printf 'nameserver 192.0.2.53\n' > "$HW_TEST_ROOT/etc/resolv.conf"
    case "$kind" in
      link) rm "$HW_TEST_ROOT/etc/resolv.conf"; ln -s /foreign/resolver "$HW_TEST_ROOT/etc/resolv.conf" ;;
      global) export NET_GLOBAL=1 ;;
      mask) export NET_MASKED=1 ;;
      backend) export NET_CONFLICT=1 ;;
      options) printf 'options ndots:5\n' >> "$HW_TEST_ROOT/etc/resolv.conf" ;;
    esac
    run network_run --output "$CFG_TEST_DIR/$kind"
    [ "$status" -eq 4 ]
    unset NET_GLOBAL NET_MASKED NET_CONFLICT
  done
  ! grep -E 'systemctl (enable|start|reload)' "$CFG_TEST_CALLS"
}

@test "DNS active VPN blocks migration without disconnect or profile changes" {
  export NET_ACTIVE_TYPES=$'802-11-wireless\nvpn'
  run network_run --output "$CFG_TEST_DIR/failed"
  [ "$status" -eq 4 ]
  [ ! -L "$HW_TEST_ROOT/etc/resolv.conf" ]
  ! grep -E 'connection (down|modify)|general reload|systemctl enable' "$CFG_TEST_CALLS"
}

@test "DNS failed refresh restores exact prior resolver and service state with private diagnostics" {
  export NET_FAIL=refresh
  run network_run --output "$CFG_TEST_DIR/failed"
  [ "$status" -eq 5 ]
  [ ! -L "$HW_TEST_ROOT/etc/resolv.conf" ]
  grep -qxF 'nameserver 192.0.2.53' "$HW_TEST_ROOT/etc/resolv.conf"
  [ ! -e "$CFG_TEST_DIR/network-state/active" ]
  [ ! -e "$CFG_TEST_DIR/network-state/enabled" ]
  [ ! -e "$HW_TEST_ROOT/etc/NetworkManager/conf.d/20-mirroros-dns.conf" ]
  [ "$(< "$HW_TEST_ROOT/var/lib/mirroros/configure/network-dns/current/state")" = rolled-back ]
  ! grep -R 'private-fixture' "$CFG_TEST_DIR/failed"
  grep -q 'private-fixture' "$HW_TEST_ROOT/var/lib/mirroros/configure/network-dns/current/operations.log"
  unset NET_FAIL
  run network_run --output "$CFG_TEST_DIR/retry"
  [ "$status" -eq 0 ]
}

@test "DNS interrupted migration restores before requiring a new reviewed retry" {
  run network_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  printf 'applying\n' > "$HW_TEST_ROOT/var/lib/mirroros/configure/network-dns/current/state"
  run network_run --output "$CFG_TEST_DIR/interrupted"
  [ "$status" -eq 4 ]
  [ ! -L "$HW_TEST_ROOT/etc/resolv.conf" ]
  [ "$(< "$HW_TEST_ROOT/var/lib/mirroros/configure/network-dns/current/state")" = rolled-back ]
}

@test "DNS interrupted migration never overwrites subsequent local edits" {
  run network_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  printf 'applying\n' > "$HW_TEST_ROOT/var/lib/mirroros/configure/network-dns/current/state"
  printf '\n# local edit\n' >> "$HW_TEST_ROOT/etc/NetworkManager/conf.d/20-mirroros-dns.conf"
  run network_run --output "$CFG_TEST_DIR/interrupted"
  [ "$status" -eq 4 ]
  grep -q 'local edit' "$HW_TEST_ROOT/etc/NetworkManager/conf.d/20-mirroros-dns.conf"
}

@test "DNS adopts exact external prototype without changing profile policy" {
  mkdir -p "$HW_TEST_ROOT/etc/NetworkManager/conf.d"
  printf '[main]\ndns=systemd-resolved\nrc-manager=unmanaged\n' > "$HW_TEST_ROOT/etc/NetworkManager/conf.d/20-mirroros-dns.conf"
  rm "$HW_TEST_ROOT/etc/resolv.conf"
  ln -s /run/systemd/resolve/stub-resolv.conf "$HW_TEST_ROOT/etc/resolv.conf"
  touch "$CFG_TEST_DIR/network-state/active" "$CFG_TEST_DIR/network-state/enabled" "$CFG_TEST_DIR/network-state/configured" "$CFG_TEST_DIR/network-state/refreshed"
  run network_run --output "$CFG_TEST_DIR/adopt"
  [ "$status" -eq 0 ]
  ! grep -E 'connection (modify|add|up|down)' "$CFG_TEST_CALLS"
}

@test "DNS target rejects resolver content not copied from the live medium" {
  cfg_test_target_context
  printf 'nameserver 192.0.2.99\n' > "$HW_TEST_ROOT/etc/resolv.conf"
  run network_run --output "$CFG_TEST_DIR/failed"
  [ "$status" -eq 4 ]
  [ ! -L "$HW_TEST_ROOT/etc/resolv.conf" ]
}

@test "DNS missing unit, unsupported reload or persistent global state is never ready" {
  export NET_CAN_RELOAD=no
  run network_run --output "$CFG_TEST_DIR/reload"
  [ "$status" -eq 4 ]
  unset NET_CAN_RELOAD
  export NET_GLOBAL_RUNTIME=1
  run network_run --output "$CFG_TEST_DIR/global"
  [ "$status" -eq 4 ]
  [ ! -L "$HW_TEST_ROOT/etc/resolv.conf" ]
  unset NET_GLOBAL_RUNTIME
  rm "$HW_TEST_ROOT/usr/lib/systemd/system/systemd-resolved.service"
  run network_run --output "$CFG_TEST_DIR/unit"
  [ "$status" -eq 4 ]
}

@test "DNS symlinked recovery parent is rejected without writing through it" {
  mkdir -p "$HW_TEST_ROOT/var/lib/mirroros" "$CFG_TEST_DIR/foreign"
  ln -s "$CFG_TEST_DIR/foreign" "$HW_TEST_ROOT/var/lib/mirroros/configure"
  run network_run --output "$CFG_TEST_DIR/failed"
  [ "$status" -eq 4 ]
  [ -z "$(find "$CFG_TEST_DIR/foreign" -mindepth 1 -print -quit)" ]
}

@test "DNS hardlinked resolver is preserved without migration" {
  ln "$HW_TEST_ROOT/etc/resolv.conf" "$CFG_TEST_DIR/resolver-alias"
  run network_run --output "$CFG_TEST_DIR/failed"
  [ "$status" -eq 4 ]
  [ ! -L "$HW_TEST_ROOT/etc/resolv.conf" ]
  [ "$(stat -c %h "$CFG_TEST_DIR/resolver-alias")" -eq 2 ]
}

@test "DNS local backend edit and malformed private recovery permissions are preserved" {
  mkdir -p "$HW_TEST_ROOT/etc/NetworkManager/conf.d"
  printf '[main]\ndns=dnsmasq\n' > "$HW_TEST_ROOT/etc/NetworkManager/conf.d/20-mirroros-dns.conf"
  run network_run --output "$CFG_TEST_DIR/backend"
  [ "$status" -eq 4 ]
  grep -qxF 'dns=dnsmasq' "$HW_TEST_ROOT/etc/NetworkManager/conf.d/20-mirroros-dns.conf"
  rm "$HW_TEST_ROOT/etc/NetworkManager/conf.d/20-mirroros-dns.conf"
  run network_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  chmod 0644 "$HW_TEST_ROOT/var/lib/mirroros/configure/network-dns/current/state"
  run network_run --output "$CFG_TEST_DIR/unsafe"
  [ "$status" -eq 4 ]
}

@test "DNS interrupted target state is not restored in running context" {
  run network_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  printf 'target\n' > "$HW_TEST_ROOT/var/lib/mirroros/configure/network-dns/current/context"
  printf 'applying\n' > "$HW_TEST_ROOT/var/lib/mirroros/configure/network-dns/current/state"
  : > "$CFG_TEST_CALLS"
  run network_run --output "$CFG_TEST_DIR/mismatch"
  [ "$status" -eq 4 ]
  [ -L "$HW_TEST_ROOT/etc/resolv.conf" ]
  ! grep -E 'general reload|systemctl (start|stop|enable|disable)' "$CFG_TEST_CALLS"
}

@test "missing target DNS adapter rejects the checkout before convergence" {
  rm "$CFG_TEST_DIR/code/capabilities/lib/target-exec"
  run network_run --output "$CFG_TEST_DIR/failed"
  [ "$status" -eq 6 ]
  cfg_test_no_install
}

@test "resolved Manager JSON allows per-link arrays but rejects global nested and malformed data" {
  touch "$CFG_TEST_DIR/network-state/active" "$CFG_TEST_DIR/network-state/configured" "$CFG_TEST_DIR/network-state/refreshed"
  export NET_DNS_JSON='{"type":"a(iiay)","data":[[2,2,[192,0,2,53]],[7,2,[192,0,2,54]]]}'
  run cfg_test_helpers 'cfg_network_effective'
  [ "$status" -eq 0 ]
  for value in '{"type":"a(iiay)","data":[[0,2,[192,0,2,53]]]}' '{"type":"a(iiay)","data":[[[2,2,[192,0,2,53]]]]}' 'private-fixture-malformed'; do
    export NET_DNS_JSON=$value
    run cfg_test_helpers 'cfg_network_effective'
    [ "$status" -eq 4 ]
    [[ "$output" != *'private-fixture'* ]]
  done
}

@test "DNS competing service prevents migration without stopping it" {
  export NET_COMPETING=1
  run network_run --output "$CFG_TEST_DIR/failed"
  [ "$status" -eq 4 ]
  ! grep -E 'systemctl (start|stop|enable)|general reload' "$CFG_TEST_CALLS"
}

@test "converged DNS with unavailable lookup is not ready without reloading or creating another snapshot" {
  run network_run --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  : > "$CFG_TEST_CALLS"
  export NET_LOOKUP_FAIL=1
  run network_run --output "$CFG_TEST_DIR/offline"
  [ "$status" -eq 4 ]
  ! grep -E 'systemctl (start|reload|enable)|nmcli general reload' "$CFG_TEST_CALLS"
  [ -z "$(find "$HW_TEST_ROOT/var/lib/mirroros/configure/network-dns" -name 'recovery.*' -print -quit)" ]
  [ "$(< "$HW_TEST_ROOT/var/lib/mirroros/configure/network-dns/current/state")" = committed ]
}

@test "DNS no public resolution is not ready and never produces a passed step" {
  export NET_LOOKUP_FAIL=1
  run network_run --output "$CFG_TEST_DIR/failed"
  [ "$status" -eq 4 ]
  [[ "$output" != *'system/network: changed'* ]]
}
