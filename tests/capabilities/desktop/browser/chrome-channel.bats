#!/usr/bin/env bats

setup_file() {
  local kind primary subkey digest expires
  for kind in valid expired; do
    local dir="$BATS_FILE_TMPDIR/$kind"
    mkdir -p -m 0700 "$dir/gnupg"
    local -a gpg=(gpg --no-options --homedir "$dir/gnupg" --batch --pinentry-mode loopback --passphrase ''
      --faked-system-time 1710000000)
    expires=0
    if [[ $kind == expired ]]; then expires=1d; fi
    "${gpg[@]}" --quick-generate-key "MirrorOS $kind fixture" ed25519 cert 0
    primary=$("${gpg[@]}" --with-colons --list-keys | awk -F: '$1 == "fpr" {print $10; exit}')
    "${gpg[@]}" --quick-add-key "$primary" ed25519 sign "$expires"
    subkey=$("${gpg[@]}" --with-colons --list-keys | awk -F: '$1 == "sub" { subkey=1 } subkey && $1 == "fpr" { print $10 }')
    printf '%s\n' "$primary" > "$dir/primary"
    printf '%s\n' "$subkey" > "$dir/subkey"
    "${gpg[@]}" --export "$primary" > "$dir/key"
    cp "$BATS_TEST_DIRNAME/fixtures/Packages" "$dir/Packages"
    digest=$(sha256sum "$dir/Packages")
    printf 'Suite: stable\nDate: Sat, 09 Mar 2024 16:00:00 UTC\nSHA256:\n %s %s main/binary-amd64/Packages\n' \
      "${digest%% *}" "$(wc -c < "$dir/Packages")" > "$dir/Release"
    "${gpg[@]}" --local-user "$subkey!" --output "$dir/InRelease" --clearsign "$dir/Release"
  done
}

setup() {
  export CHROME_FIXTURE="$BATS_TEST_TMPDIR/channel"
  PRODUCTION="$BATS_TEST_DIRNAME/../../../../capabilities/desktop/browser/chrome-channel"
  CHANNEL="$BATS_TEST_TMPDIR/chrome-channel"
  mkdir "$BATS_TEST_TMPDIR/bin"
  install -m 0755 "$BATS_TEST_DIRNAME/fixtures/curl" "$BATS_TEST_TMPDIR/bin/curl"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

fixture() {
  local source="$BATS_FILE_TMPDIR/$1"
  mkdir "$CHROME_FIXTURE"
  cp "$source/"{key,InRelease,Packages} "$CHROME_FIXTURE/"
  # Only this temporary script is repinned. The production command has no fingerprint or URL override.
  sed "s/^primary=EB4C1BFD4F042F6DDDCCEC917721F63BD38B4796$/primary=$(< "$source/primary")/" \
    "$PRODUCTION" > "$CHANNEL"
}

@test "signed metadata returns stable amd64 version, hash, date and bound subkey" {
  fixture valid
  run bash "$CHANNEL"
  [ "$status" -eq 0 ]
  [ "$output" = $'158.0.8127.36-1\t0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\t2024-03-09T16:00:00Z\t'"$(< "$BATS_FILE_TMPDIR/valid/subkey")" ]
}

@test "the production pin rejects the test primary, even with an environment override" {
  fixture valid
  run env primary="$(< "$BATS_FILE_TMPDIR/valid/primary")" bash "$PRODUCTION"
  [ "$status" -eq 11 ]
  [[ "$output" == *'primary fingerprint mismatch'* ]]
}

@test "tampered InRelease fails before its contents are accepted" {
  fixture valid
  sed -i 's/Suite: stable/Suite: testing/' "$CHROME_FIXTURE/InRelease"
  run bash "$CHANNEL"
  [ "$status" -eq 11 ]
  [[ "$output" == *signature* ]]
}

@test "an expired signing subkey fails closed" {
  fixture expired
  run bash "$CHANNEL"
  [ "$status" -eq 11 ]
  [[ "$output" == *signature* ]]
}

@test "tampered Packages fails its signed SHA256 check" {
  fixture valid
  printf '\n# changed\n' >> "$CHROME_FIXTURE/Packages"
  run bash "$CHANNEL"
  [ "$status" -eq 11 ]
  [[ "$output" == *'Packages SHA256 mismatch'* ]]
}

@test "network loss has a distinct transient outcome" {
  fixture valid
  run env CHROME_NETWORK_OFFLINE=1 bash "$CHANNEL"
  [ "$status" -eq 10 ]
  [[ "$output" == *'unable to fetch'* ]]
}
