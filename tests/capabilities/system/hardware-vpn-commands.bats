#!/usr/bin/env bats
load ../support

# Owned VPN panel commands (DEC-076, DEC-081, DEC-093): only OpenConnect profiles, tab-separated list with the name
# last, verified disconnect that never trusts nmcli's down status, and nothing from vpn.data or vpn.secrets.
ZETA=aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa
ALPHA=bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb
BETA=cccccccc-cccc-4ccc-8ccc-cccccccccccc
WIREGUARD=dddddddd-dddd-4ddd-8ddd-dddddddddddd
OPENVPN=eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee
WIFI=ffffffff-ffff-4fff-8fff-ffffffffffff
UNKNOWN=12345678-1234-4234-8234-123456789abc

setup() {
  cfg_test_setup
  cp "$CFG_SOURCE_ROOT/tests/capabilities/system/doubles/vpn-nmcli" "$CFG_TEST_DIR/bin/nmcli"
  cp "$CFG_SOURCE_ROOT/tests/capabilities/system/doubles/vpn-openconnect" "$CFG_TEST_DIR/bin/openconnect"
  chmod 0755 "$CFG_TEST_DIR/bin/nmcli" "$CFG_TEST_DIR/bin/openconnect"
  hash -r
  unset SSH_CONNECTION
  export HOME=$CFG_TEST_HOME XDG_STATE_HOME=$CFG_TEST_DIR/state XDG_RUNTIME_DIR=/run/user/$EUID
  vpn=$CFG_TEST_DIR/vpn
  mkdir -p "$vpn/conn"
  : > "$vpn/profiles"
  : > "$vpn/active"
  profile "$WIFI" 802-11-wireless '' 'Home'
  profile "$ZETA" vpn org.freedesktop.NetworkManager.openconnect 'Zeta'
  profile "$ALPHA" vpn org.freedesktop.NetworkManager.openconnect 'Alpha'
  profile "$BETA" vpn org.freedesktop.NetworkManager.openconnect 'Beta: office'
  profile "$WIREGUARD" wireguard '' 'Tunnel'
  profile "$OPENVPN" vpn org.freedesktop.NetworkManager.openvpn 'Other plugin'
  printf '%s:activated\n%s:activating\n%s:activated\n%s:activated\n' "$WIFI" "$ALPHA" "$ZETA" "$WIREGUARD" > "$vpn/active"
  export MIRROROS_VPN_DOWN_WAIT_SECONDS=0
}
teardown() { cfg_test_teardown; }

# profile <uuid> <type> <service-type> <name>: a profile with synthetic private data that must never be printed.
profile() {
  local dir=$vpn/conn/$1
  mkdir -p "$dir"
  printf '%s:%s\n' "$1" "$2" >> "$vpn/profiles"
  printf '%s' "$4" > "$dir/connection.id"
  [[ -z "$3" ]] || printf '%s' "$3" > "$dir/vpn.service-type"
  printf '%s' 'gateway = vpn.example.invalid, protocol = anyconnect' > "$dir/vpn.data"
  printf '%s' 'cookie = synthetic-cookie' > "$dir/vpn.secrets"
}

vpn_profile() { /usr/bin/bash "$CFG_SOURCE_ROOT/capabilities/system/vpn/vpn-profile" "$@"; }
# A function, not an inline `! grep`, so a match fails the test under errexit.
absent() { ! grep -Eq -- "$1" "$CFG_TEST_CALLS"; }
not_active() { ! grep -q "^$1:" "$vpn/active"; }
no_private_data() {
  [[ "$output" != *vpn.example.invalid* && "$output" != *synthetic-cookie* ]]
  absent 'vpn\.data|vpn\.secrets|--show-secrets'
  absent '^nmcli-locale '
}

@test "vpn-profile list prints OpenConnect profiles only, active first and then by name" {
  run vpn_profile list
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '%s\tactive\tZeta\n%s\tactivating\tAlpha\n%s\tinactive\tBeta: office' "$ZETA" "$ALPHA" "$BETA")" ]
  [[ "$output" != *Tunnel* && "$output" != *'Other plugin'* && "$output" != *Home* ]]
  no_private_data
}

@test "vpn-profile list maps deactivating and keeps names with colons intact" {
  printf '%s:deactivating\n' "$BETA" > "$vpn/active"
  run vpn_profile list
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$(printf '%s\tinactive\tAlpha' "$ALPHA")" ]
  [ "${lines[1]}" = "$(printf '%s\tdeactivating\tBeta: office' "$BETA")" ]
  [ "${lines[2]}" = "$(printf '%s\tinactive\tZeta' "$ZETA")" ]
}

@test "vpn-profile list prints every control character in a name as ? and keeps the profile listed" {
  printf '%s' $'Tab\there' > "$vpn/conn/$ALPHA/connection.id"
  printf '%s' $'New\nline\aend' > "$vpn/conn/$BETA/connection.id"
  run vpn_profile list
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [ "${lines[1]}" = "$(printf '%s\tinactive\tNew?line?end' "$BETA")" ]
  [ "${lines[2]}" = "$(printf '%s\tactivating\tTab?here' "$ALPHA")" ]
}

@test "vpn-profile list prints nothing and succeeds without OpenConnect profiles" {
  printf '%s:wireguard\n%s:vpn\n' "$WIREGUARD" "$OPENVPN" > "$vpn/profiles"
  run vpn_profile list
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  : > "$vpn/profiles"
  : > "$vpn/active"
  run vpn_profile list
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "vpn-profile exits 4 when NetworkManager is unavailable" {
  export HW_VPN_NM_DOWN=1
  run vpn_profile list
  [ "$status" -eq 4 ]
  run vpn_profile disconnect "$ZETA"
  [ "$status" -eq 4 ]
  absent 'connection down'
}

@test "vpn-profile rejects usage errors and malformed UUIDs without calling NetworkManager" {
  for args in '' 'status' 'list extra' 'disconnect' "disconnect $ZETA extra" 'disconnect not-a-uuid' \
    "disconnect ${ZETA}0" "disconnect ${ZETA:1}" "connect $ZETA"; do
    # shellcheck disable=SC2086 # Each case is a deliberate word list.
    run vpn_profile $args
    [ "$status" -eq 2 ]
  done
  run vpn_profile disconnect "$ZETA;id"
  [ "$status" -eq 2 ]
  [ ! -s "$CFG_TEST_CALLS" ]
}

@test "vpn-profile disconnect refuses unknown and non-OpenConnect UUIDs with exit 3" {
  for uuid in "$UNKNOWN" "$WIREGUARD" "$OPENVPN" "$WIFI"; do
    run vpn_profile disconnect "$uuid"
    [ "$status" -eq 3 ]
  done
  absent 'connection down'
  no_private_data
}

@test "vpn-profile disconnect leaves an inactive profile alone" {
  run vpn_profile disconnect "$BETA"
  [ "$status" -eq 0 ]
  absent 'connection down'
}

@test "vpn-profile disconnect brings an active profile down and verifies it" {
  run vpn_profile disconnect "$ZETA"
  [ "$status" -eq 0 ]
  grep -qxF "nmcli connection down uuid $ZETA" "$CFG_TEST_CALLS"
  [ "$(grep -c 'connection down' "$CFG_TEST_CALLS")" -eq 1 ]
  not_active "$ZETA"
  grep -q "^$ALPHA:activating" "$vpn/active"
  no_private_data
}

@test "vpn-profile disconnect also brings an activating profile down" {
  run vpn_profile disconnect "$ALPHA"
  [ "$status" -eq 0 ]
  grep -qxF "nmcli connection down uuid $ALPHA" "$CFG_TEST_CALLS"
}

@test "vpn-profile disconnect exits 5 when nmcli reports success but the profile stays active" {
  export HW_VPN_DOWN=ignored
  run vpn_profile disconnect "$ZETA"
  [ "$status" -eq 5 ]
  grep -q "^$ZETA:activated" "$vpn/active"
  [[ "$output" == *'still connected'* ]]
  [[ "$output" != *Zeta* && "$output" != *"$ZETA"* ]]
}

@test "vpn-profile disconnect ignores a failed down status when the profile became inactive" {
  export HW_VPN_DOWN=failed
  run vpn_profile disconnect "$ZETA"
  [ "$status" -eq 0 ]
}

@test "vpn-profile disconnect polls a deactivating profile within the wait" {
  export HW_VPN_DOWN=slow
  run vpn_profile disconnect "$ZETA"
  [ "$status" -eq 5 ]
  printf '%s:activated\n' "$ZETA" > "$vpn/active"
  MIRROROS_VPN_DOWN_WAIT_SECONDS=1 run vpn_profile disconnect "$ZETA"
  [ "$status" -eq 0 ]
  MIRROROS_VPN_DOWN_WAIT_SECONDS=soon run vpn_profile disconnect "$ZETA"
  [ "$status" -eq 2 ]
}

# vpn-connect (DEC-078..DEC-080, DEC-092): synthetic .invalid values only. Interactive paths run under a pty with
# script(1) and need the real private tmpfs runtime directory of this user, which the command insists on.
USERNAME=user@corp.invalid
FLAGS='cookie-flags = 2, gwcert-flags = 2, gateway-flags = 2, resolve-flags = 2'
CONNECTABLE="authtype = password, gateway = vpn.example.invalid/group, protocol = anyconnect, $FLAGS"

vpn_connect() { /usr/bin/bash "$CFG_SOURCE_ROOT/capabilities/system/vpn/vpn-connect" "$@"; }
pty_ready() {
  ((EUID != 0)) && [[ -d $XDG_RUNTIME_DIR && ! -L $XDG_RUNTIME_DIR ]] || skip 'no private user runtime directory'
  [[ "$(stat -c '%u %a' "$XDG_RUNTIME_DIR")" == "$EUID 700" ]] || skip 'user runtime directory is not private'
  [[ "$(findmnt -n -o FSTYPE --target "$XDG_RUNTIME_DIR")" == tmpfs ]] || skip 'user runtime directory is not tmpfs'
  [[ -x /usr/bin/script ]] || skip 'script(1) is unavailable'
}
data() { printf '%s' "$2" > "$vpn/conn/$1/vpn.data"; }
inactive_all() { : > "$vpn/active"; }
leftovers() { compgen -G "$XDG_RUNTIME_DIR/mirroros-vpn.*" || true; }

# wait_for <text>: until the terminal transcript shows <text>, for up to 5 s.
wait_for() {
  local _
  for _ in {1..100}; do
    /usr/bin/grep -qF -- "$1" "$CFG_TEST_DIR/typescript" && return 0
    /usr/bin/sleep 0.05
  done
}

# connect <uuid> <step>...: runs vpn-connect under a pty. A step is "wait:<text>" or input bytes for printf %b.
# Sets $status, $output (the transcript without carriage returns) and $runtime_before.
connect() {
  local uuid=$1 step _ command result=$CFG_TEST_DIR/connect-status
  shift
  runtime_before=$(leftovers)
  : > "$CFG_TEST_DIR/typescript"
  /usr/bin/rm -f -- "$result" "$CFG_TEST_DIR/openconnect.runtime"
  command="$(printf '%q ' /usr/bin/bash "$CFG_SOURCE_ROOT/capabilities/system/vpn/vpn-connect" "$uuid"); "
  command+="printf '%s' \$? > $(printf '%q' "$result")"
  {
    for step in "$@"; do
      if [[ "$step" == wait:* ]]; then wait_for "${step#wait:}"; else printf '%b' "$step"; fi
    done
    for _ in {1..200}; do
      [[ ! -e "$result" ]] || break
      /usr/bin/sleep 0.05
    done
  } | SHELL=/usr/bin/bash /usr/bin/timeout 20 /usr/bin/script -qefc "$command" "$CFG_TEST_DIR/typescript" > /dev/null || true
  status=$(/usr/bin/cat "$result" 2> /dev/null || echo timeout)
  output=$(/usr/bin/tr -d '\r' < "$CFG_TEST_DIR/typescript")
}

# Steps that answer every prompt of a first connection with a typed username used once.
TYPED=('wait:VPN username (not' "$USERNAME\n" 'wait:Type SAVE' '\n' 'wait:Password:' 'synthetic-password\n'
  'wait:Response:' 'synthetic-otp\n')
AUTH=('wait:Password:' 'synthetic-password\n' 'wait:Response:' 'synthetic-otp\n')

# No private value on any recorded argv, no profile change, no forbidden option, and no runtime leftovers.
connect_clean() {
  absent "$USERNAME|vpn\.example\.invalid|synthetic-cookie|synthetic-fingerprint|synthetic-password|synthetic-otp"
  absent 'connection (modify|edit|add|delete|clone|import|load|reload)|--show-secrets|--verbose|--gnutls-priority'
  absent '(^| )(sudo|pkexec) '
  if [[ -s "$CFG_TEST_DIR/openconnect.runtime" ]]; then
    [ ! -e "$(< "$CFG_TEST_DIR/openconnect.runtime")" ]
  fi
  [ "$(leftovers)" = "$runtime_before" ]
}
not_called() { absent "^$1"; }

@test "vpn-connect rejects malformed arguments with exit 2 before anything else" {
  for args in '' 'not-a-uuid' "$BETA extra" "${BETA}0"; do
    # shellcheck disable=SC2086 # Each case is a deliberate word list.
    run vpn_connect $args < /dev/null
    [ "$status" -eq 2 ]
  done
  [ ! -s "$CFG_TEST_CALLS" ]
}

@test "vpn-connect refuses a non-interactive, remote or non-private environment with exit 3 before any input" {
  run vpn_connect "$BETA" < /dev/null
  [ "$status" -eq 3 ]
  pty_ready
  SSH_CONNECTION='192.0.2.1 1 192.0.2.2 22' connect "$BETA"
  [ "$status" -eq 3 ]
  XDG_RUNTIME_DIR=$CFG_TEST_DIR connect "$BETA"
  [ "$status" -eq 3 ]
  printf '#!/usr/bin/bash\necho ext4\n' > "$CFG_TEST_DIR/bin/findmnt"
  chmod 0755 "$CFG_TEST_DIR/bin/findmnt"
  connect "$BETA"
  [ "$status" -eq 3 ]
  rm "$CFG_TEST_DIR/bin/findmnt"
  mkdir "$CFG_TEST_DIR/minbin"
  for tool in nmcli jq findmnt stat mktemp; do ln -s "$(command -v "$tool")" "$CFG_TEST_DIR/minbin/$tool"; done
  PATH=$CFG_TEST_DIR/minbin connect "$BETA"
  [ "$status" -eq 3 ]
  [[ "$output" == *openconnect* && "$output" != *'VPN profile:'* ]]
  [ ! -s "$CFG_TEST_CALLS" ]
}

@test "vpn-connect refuses invalid profiles with exit 4, points to the procedure and changes nothing" {
  pty_ready
  connect "$UNKNOWN"
  [ "$status" -eq 4 ]
  for uuid in "$OPENVPN" "$WIFI"; do
    data "$uuid" "$CONNECTABLE"
    connect "$uuid"
    [ "$status" -eq 4 ]
  done
  for settings in "gateway = vpn.example.invalid/group, protocol = anyconnect" \
    "gateway = vpn.example.invalid/group, cookie-flags = 2, gwcert-flags = 0, gateway-flags = 2, resolve-flags = 2" \
    "protocol = anyconnect, $FLAGS" "gateway = , $FLAGS" "gateway = vpn.example.invalid, protocol = gp, $FLAGS" \
    "gateway = vpn.example.invalid, protocol = anyconnect, protocol = anyconnect, $FLAGS" \
    "gateway vpn.example.invalid, $FLAGS"; do
    data "$BETA" "$settings"
    connect "$BETA"
    [ "$status" -eq 4 ]
    [[ "$output" == *docs/procedures/hardware.md* && "$output" == *'No profile was changed.'* ]]
    [ "$(< "$vpn/conn/$BETA/vpn.data")" = "$settings" ]
  done
  not_called openconnect
  not_called 'nmcli connection up'
  connect_clean
}

@test "vpn-connect refuses a profile that is active, activating or deactivating with exit 5" {
  pty_ready
  data "$ZETA" "$CONNECTABLE"
  data "$ALPHA" "$CONNECTABLE"
  data "$BETA" "$CONNECTABLE"
  printf '%s:deactivating\n%s:activated\n%s:activating\n' "$BETA" "$ZETA" "$ALPHA" > "$vpn/active"
  for uuid in "$ZETA" "$ALPHA" "$BETA"; do
    connect "$uuid"
    [ "$status" -eq 5 ]
  done
  not_called openconnect
  connect_clean
}

@test "vpn-connect hands a typed username once to OpenConnect and activates the profile through a passwd-file" {
  pty_ready
  data "$BETA" "$CONNECTABLE"
  mkdir -p "$HOME/.mirroros-vpn-acceptance"
  printf '{"schema_version":1,"gateway":"https://legacy.invalid","username":"legacy.invalid"}\n' \
    > "$HOME/.mirroros-vpn-acceptance/$BETA.json"
  connect "$BETA" "${TYPED[@]}"
  [ "$status" -eq 0 ]
  [[ "$output" == *'VPN profile: Beta: office'* && "$output" == *'VPN connected.'* ]]
  [[ "$output" != *CONNECT* && "$output" != *'Using the VPN username saved'* ]]
  [ "$(< "$CFG_TEST_DIR/openconnect.answers")" = 'synthetic-password:synthetic-otp' ]
  local runtime
  runtime=$(< "$CFG_TEST_DIR/openconnect.runtime")
  [[ "$runtime" == "$XDG_RUNTIME_DIR"/mirroros-vpn.* ]]
  grep -qxF "openconnect --protocol=anyconnect --authenticate --config $runtime/auth.conf" "$CFG_TEST_CALLS"
  [ "$(< "$CFG_TEST_DIR/openconnect.conf")" = "$(printf 'server = vpn.example.invalid/group\nuser = %s' "$USERNAME")" ]
  grep -qxF "nmcli connection up uuid $BETA passwd-file $runtime/passwd" "$CFG_TEST_CALLS"
  [ "$(< "$vpn/passwd-$BETA")" = "$(printf '%s\n' 'vpn.secrets.cookie:synthetic-cookie-value' \
    'vpn.secrets.gwcert:pin-sha256:synthetic-fingerprint' 'vpn.secrets.gateway:192.0.2.10' \
    'vpn.secrets.resolve:vpn.example.invalid:192.0.2.10')" ]
  grep -q "^$BETA:activated" "$vpn/active"
  [ "$(< "$vpn/conn/$BETA/vpn.data")" = "$CONNECTABLE" ]
  [ ! -e "$XDG_STATE_HOME/mirroros" ]
  connect_clean
}

@test "vpn-connect treats a missing protocol as anyconnect and writes the useragent only to the private config" {
  pty_ready
  data "$BETA" "gateway = vpn.example.invalid, useragent = AnyConnect Linux 4.10, $FLAGS"
  connect "$BETA" "${TYPED[@]}"
  [ "$status" -eq 0 ]
  grep -q '^openconnect --protocol=anyconnect --authenticate --config ' "$CFG_TEST_CALLS"
  absent 'AnyConnect Linux|useragent'
  [ "$(< "$CFG_TEST_DIR/openconnect.conf")" = "$(printf 'server = vpn.example.invalid\nuser = %s\nuseragent = AnyConnect Linux 4.10' "$USERNAME")" ]
  connect_clean
}

@test "vpn-connect saves a username only after SAVE, reuses it with a notice and forgets it on FORGET" {
  pty_ready
  data "$BETA" "$CONNECTABLE"
  local directory=$XDG_STATE_HOME/mirroros/vpn file=$XDG_STATE_HOME/mirroros/vpn/$BETA.json
  connect "$BETA" 'wait:VPN username (not' "$USERNAME\n" 'wait:Type SAVE' 'SAVE\n' "${AUTH[@]}"
  [ "$status" -eq 0 ]
  [ "$(< "$file")" = "{\"schema_version\":1,\"username\":\"$USERNAME\"}" ]
  [ "$(stat -c '%a %h' "$directory")" = '700 2' ]
  [ "$(stat -c '%a %h' "$file")" = '600 1' ]
  [ ! -L "$file" ]
  [ "$(find "$directory" -mindepth 1 | wc -l)" -eq 1 ]

  inactive_all
  connect "$BETA" 'wait:Using the VPN username saved' '\n' "${AUTH[@]}"
  [ "$status" -eq 0 ]
  [[ "$output" != *'VPN username (not'* && "$output" != *"$USERNAME"* ]]
  [ "$(sed -n 2p "$CFG_TEST_DIR/openconnect.conf")" = "user = $USERNAME" ]

  inactive_all
  connect "$BETA" 'wait:type FORGET' 'FORGET\n' 'wait:VPN username (not' 'other.user@corp.invalid\n' \
    'wait:Type SAVE' '\n' "${AUTH[@]}"
  [ "$status" -eq 0 ]
  [[ "$output" == *'Saved VPN username deleted.'* ]]
  [ "$(sed -n 2p "$CFG_TEST_DIR/openconnect.conf")" = 'user = other.user@corp.invalid' ]
  [ ! -e "$file" ]
  absent 'other\.user'
  connect_clean
}

@test "vpn-connect refuses unsafe or invalid saved usernames with exit 3 and never overwrites them" {
  pty_ready
  data "$BETA" "$CONNECTABLE"
  local directory=$XDG_STATE_HOME/mirroros/vpn file=$XDG_STATE_HOME/mirroros/vpn/$BETA.json
  mkdir -p "$directory"
  chmod 0700 "$XDG_STATE_HOME" "$XDG_STATE_HOME/mirroros" "$directory"
  printf '{"schema_version":1,"username":"%s"}\n' "$USERNAME" > "$CFG_TEST_DIR/saved.json"
  chmod 0600 "$CFG_TEST_DIR/saved.json"

  ln -s "$CFG_TEST_DIR/saved.json" "$file"
  connect "$BETA"
  [ "$status" -eq 3 ]
  rm "$file"
  ln "$CFG_TEST_DIR/saved.json" "$file"
  connect "$BETA"
  [ "$status" -eq 3 ]
  rm "$file"
  for content in '{"schema_version":1,"gateway":"vpn.example.invalid","username":"user"}' \
    '{"schema_version":2,"username":"user"}' '{"schema_version":1,"username":"bad user"}' 'not json'; do
    printf '%s\n' "$content" > "$file"
    connect "$BETA"
    [ "$status" -eq 3 ]
    [ "$(< "$file")" = "$content" ]
  done
  printf '{"schema_version":1,"username":"%s"}\n' "$USERNAME" > "$file"
  chmod 0644 "$file"
  connect "$BETA"
  [ "$status" -eq 3 ]
  chmod 0600 "$file"
  chmod 0755 "$directory"
  connect "$BETA"
  [ "$status" -eq 3 ]
  not_called openconnect
  connect_clean
}

@test "vpn-connect cancels with exit 6 at the username, password and one-time code prompts and cleans up" {
  pty_ready
  data "$BETA" "$CONNECTABLE"
  connect "$BETA" 'wait:VPN username (not' '\x03'
  [ "$status" -eq 6 ]
  connect "$BETA" 'wait:VPN username (not' '\x04'
  [ "$status" -eq 6 ]
  not_called openconnect
  connect "$BETA" 'wait:VPN username (not' "$USERNAME\n" 'wait:Type SAVE' '\n' 'wait:Password:' '\x03'
  [ "$status" -eq 6 ]
  connect_clean
  HW_VPN_OC='wait' connect "$BETA" 'wait:VPN username (not' "$USERNAME\n" 'wait:Type SAVE' '\n' \
    'wait:Password:' 'synthetic-password\n' 'wait:Response:' '\x03'
  [ "$status" -eq 6 ]
  not_called 'nmcli connection up'
  not_active "$BETA"
  [ ! -e "$XDG_STATE_HOME/mirroros" ]
  connect_clean
}

@test "vpn-connect exits 7 when authentication fails and activates nothing" {
  pty_ready
  data "$BETA" "$CONNECTABLE"
  HW_VPN_OC=failed connect "$BETA" "${TYPED[@]}"
  [ "$status" -eq 7 ]
  not_called 'nmcli connection up'
  not_active "$BETA"
  connect_clean
}

@test "vpn-connect exits 8 on unsupported authentication output and activates nothing" {
  pty_ready
  data "$BETA" "$CONNECTABLE"
  local good="HOST='192.0.2.10'\nFINGERPRINT='pin-sha256:synthetic-fingerprint'\nRESOLVE='vpn.example.invalid:192.0.2.10'"
  export HW_VPN_OC=output
  for result in "COOKIE=synthetic-cookie\n$good" "COOKIE='synthetic-cookie'\nEXTRA='x'\n$good" \
    "COOKIE='synthetic-cookie'\nCOOKIE='synthetic-cookie'\n$good" "COOKIE=''\n$good" \
    "COOKIE='synthetic-cookie'\nHOST='192.0.2.10'\nFINGERPRINT='pin-sha256:synthetic-fingerprint'" \
    "COOKIE='synthetic\tcookie'\n$good" "COOKIE='synthetic-cookie'; touch $CFG_TEST_DIR/injected\n$good" \
    "export COOKIE='synthetic-cookie'\n$good"; do
    printf '%b\n' "$result" > "$CFG_TEST_DIR/openconnect.output"
    connect "$BETA" "${TYPED[@]}"
    [ "$status" -eq 8 ]
    connect_clean
  done
  [ ! -e "$CFG_TEST_DIR/injected" ]
  not_called 'nmcli connection up'
  not_active "$BETA"
}

@test "vpn-connect exits 9 when activation fails and brings a partial activation down" {
  pty_ready
  data "$BETA" "$CONNECTABLE"
  HW_VPN_UP=failed connect "$BETA" "${TYPED[@]}"
  [ "$status" -eq 9 ]
  not_active "$BETA"
  not_called 'nmcli connection down'
  connect_clean

  HW_VPN_UP=partial connect "$BETA" "${TYPED[@]}"
  [ "$status" -eq 9 ]
  grep -qxF "nmcli connection down uuid $BETA" "$CFG_TEST_CALLS"
  not_active "$BETA"
  [[ "$output" != *'may still be connected'* ]]
  connect_clean

  inactive_all
  HW_VPN_UP=partial HW_VPN_DOWN=ignored connect "$BETA" "${TYPED[@]}"
  [ "$status" -eq 9 ]
  grep -q "^$BETA:activating" "$vpn/active"
  [[ "$output" == *'may still be connected'* ]]
  connect_clean
}
