#!/usr/bin/env bats
load ../support

# Fixture profiles (DEC-052, DEC-061): an active Wi-Fi and Ethernet profile, a saved inactive Wi-Fi profile, a VPN
# active over the Wi-Fi device and an active bridge. Only the named profile may ever change.
WIFI=11111111-1111-4111-8111-111111111111
WIRED=22222222-2222-4222-8222-222222222222
SAVED=33333333-3333-4333-8333-333333333333
VPN=44444444-4444-4444-8444-444444444444
BRIDGE=55555555-5555-4555-8555-555555555555

setup() {
  cfg_test_setup
  for tool in nmcli ip iw ping; do
    cp "$CFG_SOURCE_ROOT/tests/capabilities/system/doubles/network-$tool" "$CFG_TEST_DIR/bin/$tool"
    chmod 0755 "$CFG_TEST_DIR/bin/$tool"
  done
  nm=$CFG_TEST_DIR/nm
  mkdir -p "$nm/conn" "$CFG_TEST_DIR/sys/net/wlan0/wireless" "$CFG_TEST_DIR/sys/net/wlan0/statistics" \
    "$CFG_TEST_DIR/sys/net/eth0/statistics"
  export MIRROROS_NET_CLASS_PATH=$CFG_TEST_DIR/sys/net
  printf '%s:vpn:wlan0\n%s:802-11-wireless:wlan0\n%s:802-3-ethernet:eth0\n%s:bridge:br0\n' \
    "$VPN" "$WIFI" "$WIRED" "$BRIDGE" > "$nm/active"
  printf 'wlan0:wifi:connected\neth0:ethernet:connected\nbr0:bridge:connected\n' > "$nm/devices"
  printf '100 (connected)\nHome:Net\n' > "$nm/device-wlan0"
  printf '2412 MHz:Home:Net\n5180 MHz:Home:Net\n5500 MHz:Other\n' > "$nm/wifi-wlan0"
  printf ':40\n*:72\n' > "$nm/signal-wlan0"
  profile "$WIFI" 'Home:Net' '802-11-wireless.band='
  profile "$WIRED" 'Wired'
  profile "$SAVED" 'Cafe' '802-11-wireless.band=a' 'ipv4.ignore-auto-dns=yes' 'ipv4.dns=9.9.9.9'
  profile "$VPN" 'Corporate' 'ipv4.dns=10.0.0.53'
  profile "$BRIDGE" 'Bridge'
  printf '1000\n' > "$CFG_TEST_DIR/sys/net/wlan0/statistics/rx_bytes"
  printf '2000\n' > "$CFG_TEST_DIR/sys/net/wlan0/statistics/tx_bytes"
  export HW_ROUTE_DEV=wlan0 HW_IW_SSID='Home:Net' HW_IW_FREQ=5180.0
}
teardown() { cfg_test_teardown; }

profile() {
  local file=$nm/conn/$1
  printf 'connection.id=%s\nipv4.ignore-auto-dns=no\nipv4.dns=\nipv6.ignore-auto-dns=no\nipv6.dns=\nconnection.dns-over-tls=default\n' "$2" > "$file"
  local setting
  for setting in "${@:3}"; do
    /usr/bin/awk -v key="${setting%%=*}" 'index($0, key "=") != 1' "$file" > "$file.new"
    printf '%s\n' "$setting" >> "$file.new"
    mv "$file.new" "$file"
  done
}

setting() { awk -v key="$2" 'index($0, key "=") == 1 { print substr($0, length(key) + 2) }' "$nm/conn/$1"; }
snapshot() { cp -R "$nm/conn" "$CFG_TEST_DIR/before"; }
# Every profile except the named one is byte-identical to the snapshot.
others_unchanged() {
  local file
  for file in "$CFG_TEST_DIR/before"/*; do
    [[ "${file##*/}" == "${1:-}" ]] || cmp "$file" "$nm/conn/${file##*/}"
  done
}
network() { /usr/bin/bash "$CFG_SOURCE_ROOT/capabilities/system/network/$1" "${@:2}"; }

@test "network-dns get reports the provider of the named profile only" {
  run network network-dns get "$WIFI"
  [ "$status" -eq 0 ]
  [ "$output" = DHCP ]
  profile "$WIRED" Wired 'ipv4.ignore-auto-dns=yes' 'ipv4.dns=8.8.8.8 8.8.4.4'
  run network network-dns get "$WIRED"
  [ "$output" = Google ]
  run network network-dns get "$WIFI"
  [ "$output" = DHCP ]
}

@test "network-dns Cloudflare and Google change only the target profile with the exact v4.5.0 values" {
  snapshot
  run network network-dns set "$WIFI" Cloudflare
  [ "$status" -eq 0 ]
  [ "$(setting "$WIFI" ipv4.dns)" = '1.1.1.1 1.0.0.1' ]
  [ "$(setting "$WIFI" ipv6.dns)" = '2606:4700:4700::1111 2606:4700:4700::1001' ]
  [ "$(setting "$WIFI" ipv4.ignore-auto-dns)" = yes ]
  [ "$(setting "$WIFI" ipv6.ignore-auto-dns)" = yes ]
  [ "$(setting "$WIFI" connection.dns-over-tls)" = opportunistic ]
  others_unchanged "$WIFI"
  [ "$(grep -c '^nmcli connection modify ' "$CFG_TEST_CALLS")" -eq 1 ]
  grep -q "^nmcli connection modify uuid $WIFI " "$CFG_TEST_CALLS"
  [ "$(grep -c '^nmcli device reapply' "$CFG_TEST_CALLS")" -eq 1 ]
  grep -qxF 'nmcli device reapply wlan0' "$CFG_TEST_CALLS"
  run network network-dns get "$WIFI"
  [ "$output" = Cloudflare ]

  run network network-dns set "$WIRED" Google
  [ "$status" -eq 0 ]
  [ "$(setting "$WIRED" ipv4.dns)" = '8.8.8.8 8.8.4.4' ]
  [ "$(setting "$WIRED" ipv6.dns)" = '2001:4860:4860::8888 2001:4860:4860::8844' ]
  [ "$(setting "$WIRED" connection.dns-over-tls)" = opportunistic ]
  grep -qxF 'nmcli device reapply eth0' "$CFG_TEST_CALLS"
  ! grep -q 'nmcli-locale' "$CFG_TEST_CALLS" || false
}

@test "network-dns DHCP clears the target profile back to automatic DNS" {
  profile "$WIFI" 'Home:Net' 'ipv4.ignore-auto-dns=yes' 'ipv4.dns=1.1.1.1 1.0.0.1' 'connection.dns-over-tls=opportunistic'
  snapshot
  run network network-dns set "$WIFI" DHCP
  [ "$status" -eq 0 ]
  [ "$(setting "$WIFI" ipv4.ignore-auto-dns)" = no ]
  [ "$(setting "$WIFI" ipv6.ignore-auto-dns)" = no ]
  [ -z "$(setting "$WIFI" ipv4.dns)" ]
  [ -z "$(setting "$WIFI" ipv6.dns)" ]
  [ "$(setting "$WIFI" connection.dns-over-tls)" = default ]
  others_unchanged "$WIFI"
}

@test "network-dns refuses inactive, VPN and bridge profiles with distinct codes and no change" {
  snapshot
  run network network-dns set "$SAVED" Cloudflare
  [ "$status" -eq 3 ]
  run network network-dns set 66666666-6666-4666-8666-666666666666 Cloudflare
  [ "$status" -eq 3 ]
  run network network-dns set "$VPN" Cloudflare
  [ "$status" -eq 5 ]
  run network network-dns set "$BRIDGE" Google
  [ "$status" -eq 5 ]
  run network network-dns get "$VPN"
  [ "$status" -eq 5 ]
  HW_NM_DOWN=1 run network network-dns set "$WIFI" Cloudflare
  [ "$status" -eq 4 ]
  others_unchanged
  ! grep -Eq '^nmcli (connection modify|device reapply)' "$CFG_TEST_CALLS" || false
}

@test "network-dns Custom names the profile, splits servers and cancels on empty input" {
  snapshot
  run network network-dns set "$WIFI" Custom <<< ''
  [ "$status" -eq 6 ]
  [[ "$output" == *'Home:Net'* ]]
  others_unchanged
  ! grep -Eq '^nmcli (connection modify|device reapply)' "$CFG_TEST_CALLS" || false

  run network network-dns set "$WIFI" Custom <<< '192.0.2.53, 2001:db8::53'
  [ "$status" -eq 0 ]
  [ "$(setting "$WIFI" ipv4.dns)" = 192.0.2.53 ]
  [ "$(setting "$WIFI" ipv6.dns)" = 2001:db8::53 ]
  [ "$(setting "$WIFI" ipv4.ignore-auto-dns)" = yes ]
  [ "$(setting "$WIFI" connection.dns-over-tls)" = default ]
  others_unchanged "$WIFI"
  run network network-dns get "$WIFI"
  [ "$output" = Custom ]
}

@test "network-dns reports a rejected change or failed reapply" {
  HW_NM_MODIFY_FAIL=1 run network network-dns set "$WIFI" Cloudflare
  [ "$status" -eq 1 ]
  ! grep -q '^nmcli device reapply' "$CFG_TEST_CALLS" || false
  HW_NM_REAPPLY_FAIL=1 run network network-dns set "$WIFI" Google
  [ "$status" -eq 1 ]
}

@test "network-dns rejects the v4.5.0 global form and malformed arguments" {
  for args in '' 'Cloudflare' "set $WIFI" "set $WIFI Quad9" "get" "get $WIFI extra" "set $WIFI DHCP extra"; do
    read -r -a argv <<< "$args"
    run network network-dns "${argv[@]}"
    [ "$status" -eq 2 ]
  done
  ! grep -q '^nmcli ' "$CFG_TEST_CALLS" || false
}

@test "network-dns never walks saved profiles, writes global DNS or escalates privileges" {
  run network network-dns set "$WIFI" Cloudflare
  [ "$status" -eq 0 ]
  # The only listing is of active connections; saved profiles are never enumerated.
  ! grep -Eq '^nmcli -e no -g [A-Z,]+ connection show$' "$CFG_TEST_CALLS" || false
  ! grep -Eq '^nmcli (general|networking|radio)|reload' "$CFG_TEST_CALLS" || false
  # Header comments document these removals; only code lines are checked.
  for command in network-dns network-band network-status; do
    ! grep -v '^[[:space:]]*#' "$CFG_SOURCE_ROOT/capabilities/system/network/$command" |
      grep -Eq '\b(sudo|pkexec|systemctl)\b|global-dns|resolved\.conf|FallbackDNS|DNSOverTLS' || false
  done
}

@test "network-band get reports current, available and selected bands with the profile UUID" {
  run network network-band get wlan0
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'band\t5\navailable\t2.4 5\nselected\tauto\nuuid\t%s' "$WIFI")" ]
  profile "$WIFI" 'Home:Net' '802-11-wireless.band=bg'
  run network network-band get wlan0
  [[ "$output" == *$'selected\t2.4'* ]]
  run network network-band get eth0
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "network-band get prints nothing without iw or band data" {
  tools=$CFG_TEST_DIR/tools
  mkdir -p "$tools"
  for tool in awk sed sort tr cat mktemp rm head xargs mv; do ln -s "$(command -v "$tool")" "$tools/$tool"; done
  rm "$CFG_TEST_DIR/bin/iw"
  PATH="$CFG_TEST_DIR/bin:$tools" run network network-band get wlan0
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  PATH="$CFG_TEST_DIR/bin:$tools" run network network-band set wlan0 "$WIFI" 5
  [ "$status" -eq 6 ]
  ! grep -q '^nmcli connection modify' "$CFG_TEST_CALLS" || false
}

@test "network-band set pins only the named profile and reactivates it within 30 seconds" {
  snapshot
  run network network-band set wlan0 "$WIFI" 2.4
  [ "$status" -eq 0 ]
  [ "$(setting "$WIFI" 802-11-wireless.band)" = bg ]
  others_unchanged "$WIFI"
  grep -qxF "nmcli connection modify uuid $WIFI 802-11-wireless.band bg" "$CFG_TEST_CALLS"
  grep -qxF "nmcli --wait 30 connection up uuid $WIFI" "$CFG_TEST_CALLS"
  run network network-band set wlan0 "$WIFI" auto
  [ "$status" -eq 0 ]
  [ -z "$(setting "$WIFI" 802-11-wireless.band)" ]
  : > "$CFG_TEST_CALLS"
  run network network-band set wlan0 "$WIFI" auto
  [ "$status" -eq 0 ]
  ! grep -Eq '^nmcli (connection modify|.*connection up)' "$CFG_TEST_CALLS" || false
}

@test "network-band refuses a stale device-UUID pair, a non-Wi-Fi profile and an unavailable band" {
  snapshot
  run network network-band set eth0 "$WIFI" 5
  [ "$status" -eq 3 ]
  run network network-band set wlan0 "$SAVED" 5
  [ "$status" -eq 3 ]
  run network network-band set eth0 "$WIRED" 5
  [ "$status" -eq 5 ]
  run network network-band set wlan0 "$WIFI" 6
  [ "$status" -eq 6 ]
  HW_NM_DOWN=1 run network network-band set wlan0 "$WIFI" 5
  [ "$status" -eq 4 ]
  others_unchanged
  ! grep -Eq '^nmcli (connection modify|.*connection up)' "$CFG_TEST_CALLS" || false
}

@test "network-band restores the previous band when the profile cannot come back up" {
  HW_NM_UP_FAIL_BAND=bg run network network-band set wlan0 "$WIFI" 2.4
  [ "$status" -eq 1 ]
  [ -z "$(setting "$WIFI" 802-11-wireless.band)" ]
  [ "$(grep -c "^nmcli --wait 30 connection up uuid $WIFI\$" "$CFG_TEST_CALLS")" -eq 2 ]
  grep -qxF "nmcli connection modify uuid $WIFI 802-11-wireless.band " "$CFG_TEST_CALLS"
}

@test "network-band rejects the v4.5.0 form and malformed arguments" {
  for args in '' '5' 'get' "set wlan0 $WIFI" "set wlan0 $WIFI 7" "get wlan0 extra"; do
    read -r -a argv <<< "$args"
    run network network-band "${argv[@]}"
    [ "$status" -eq 2 ]
  done
}

@test "network-status pings only the gateway and the single internet constant with a 2 second timeout" {
  run network network-status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *$'iface\twlan0'* ]]
  [[ "$output" == *$'gateway\t192.0.2.1'* ]]
  [[ "$output" == *$'uuid\t'"$WIFI"* ]]
  [[ "$output" != *"$VPN"* ]]
  [[ "$output" == *$'connection\tHome:Net'* ]]
  [[ "$output" == *$'connection_type\t802-11-wireless'* ]]
  [[ "$output" == *$'type\twifi'* ]]
  [[ "$output" == *$'ssid\tHome:Net'* ]]
  [[ "$output" == *$'router_ping_ms\t2.1'* ]]
  [[ "$output" == *$'internet_ping_ms\t14.2'* ]]
  [ "$(grep -c '^ping ' "$CFG_TEST_CALLS")" -eq 2 ]
  grep -qxF 'ping -n -c 1 -W 2 192.0.2.1' "$CFG_TEST_CALLS"
  grep -qxF 'ping -n -c 1 -W 2 1.1.1.1' "$CFG_TEST_CALLS"
  [ "$(grep -c '1\.1\.1\.1' "$CFG_SOURCE_ROOT/capabilities/system/network/network-status")" -eq 1 ]
  grep -q '^INTERNET_PROBE=1.1.1.1$' "$CFG_SOURCE_ROOT/capabilities/system/network/network-status"
}

@test "network-status reports Ethernet, a lost probe and no route without extra probes" {
  HW_ROUTE_DEV=eth0 run network network-status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *$'type\tethernet'* ]]
  [[ "$output" == *$'uuid\t'"$WIRED"* ]]

  : > "$CFG_TEST_CALLS"
  HW_PING_LOST=1.1.1.1 run network network-status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *$'internet_ping_ms\t'$'\n'* || "$output" == *$'internet_ping_ms\t' ]]

  : > "$CFG_TEST_CALLS"
  HW_ROUTE_GW= run network network-status --verbose
  [ "$(grep -c '^ping ' "$CFG_TEST_CALLS")" -eq 1 ]
  grep -qxF 'ping -n -c 1 -W 2 1.1.1.1' "$CFG_TEST_CALLS"

  : > "$CFG_TEST_CALLS"
  HW_ROUTE_DEV= run network network-status --verbose
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  ! grep -q '^ping ' "$CFG_TEST_CALLS" || false
  HW_ROUTE_DEV= run network network-status
  [ "$output" = $'disconnected\t\t\t' ]
}

@test "network-status summary line and usage" {
  run network network-status
  [ "$status" -eq 0 ]
  [ "$output" = $'wifi\tHome:Net\t72\t5180.0' ]
  ! grep -q '^ping ' "$CFG_TEST_CALLS" || false
  run network network-status --bogus
  [ "$status" -eq 2 ]
  run network network-status --verbose extra
  [ "$status" -eq 2 ]
}
