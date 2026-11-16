#!/usr/bin/env bats
# Execute the actual patched provider against isolated D-Bus doubles, never a live session.
# Supply HYPRLOCK_SOURCE_ARCHIVE on clean clones; no test downloads or package installs.
setup_file() {
  local root="$BATS_TEST_DIRNAME/../../../.."
  local archive="${HYPRLOCK_SOURCE_ARCHIVE:-$root/evidence/lock/quick-fprint-patch/hyprlock-0.9.7.tar.gz}"
  export FPRINT_TEST_BINARY="$BATS_FILE_TMPDIR/fingerprint-state"
  export FPRINT_TEST_UNAVAILABLE=''
  if [[ ! -f "$archive" ]] || ! command -v g++ > /dev/null; then
    export FPRINT_TEST_UNAVAILABLE='requires g++ and HYPRLOCK_SOURCE_ARCHIVE (verified hyprlock 0.9.7 tarball)'
    return
  fi
  [ "$(sha256sum "$archive" | cut -d ' ' -f 1)" = 01145790570ffabd31e9b528c517bdccae76f36e72d733f00c2696d9c3bf2c88 ] || return 1
  tar -xzf "$archive" -C "$BATS_FILE_TMPDIR" || return 1
  local source="$BATS_FILE_TMPDIR/hyprlock-0.9.7" patch
  for patch in "$root"/capabilities/desktop/lock/hyprlock/000[1-5]-*.patch; do
    patch --batch --fuzz=0 -d "$source" -Np1 -i "$patch" || return 1
  done
  # Expose private state only in the test translation unit. All provider methods are compiled unchanged.
  awk '!/^#include/ && !/^#pragma/ { sub(/^  private:/, "  public:"); print }' \
    "$source/src/auth/Fingerprint.hpp" > "$BATS_FILE_TMPDIR/provider.cpp"
  # Treat test signals as authentic fprintd broadcasts: the defect is ownership, not sender spoofing.
  awk '
    /^#include/ { next }
    /^static bool       isSignalFromService/ {
      print "static bool isSignalFromService(const sdbus::ServiceName&) { return true; }"
      skip=1
    }
    /^enum MatchResult/ { skip=0 }
    !skip { print }
  ' "$source/src/auth/Fingerprint.cpp" >> "$BATS_FILE_TMPDIR/provider.cpp"
  # Append the behavioral cases before compiling the executable.
  cp "$BATS_FILE_TMPDIR/provider.cpp" "$BATS_FILE_TMPDIR/test.cpp"
  awk '{ print }' "$BATS_TEST_DIRNAME/fixtures/fingerprint-state.cpp" >> "$BATS_FILE_TMPDIR/test.cpp"
  g++ -std=c++23 -Wall -Wextra -Wno-unused-parameter \
    -include "$BATS_TEST_DIRNAME/fixtures/fingerprint-dbus.hpp" \
    "$BATS_FILE_TMPDIR/test.cpp" -o "$FPRINT_TEST_BINARY"
}
setup() { [[ -z "$FPRINT_TEST_UNAVAILABLE" ]] || skip "$FPRINT_TEST_UNAVAILABLE"; }

@test "busy reader ignores another client's status and finger presence" { "$FPRINT_TEST_BINARY" busy; }
@test "claim retry recovers and accepts only the subsequent own verification" { "$FPRINT_TEST_BINARY" recover; }
@test "own verification accepts a normal match only once" { "$FPRINT_TEST_BINARY" own; }
@test "own early match is accepted without resurrecting the prompt on a late start reply" { "$FPRINT_TEST_BINARY" early-match; }
@test "failed verification start ignores later status and finger presence" { "$FPRINT_TEST_BINARY" start-error; }
@test "stopped verification cannot be resurrected by a late start reply" { "$FPRINT_TEST_BINARY" late-start; }
@test "an old start failure cannot invalidate a newer verification" { "$FPRINT_TEST_BINARY" generation; }
@test "exhausted verification ignores subsequent matches and finger presence" { "$FPRINT_TEST_BINARY" exhausted; }
@test "retry delay rejects matches until another own verification starts" { "$FPRINT_TEST_BINARY" retry; }
@test "sleep rejects a match and resume can start another verification" { "$FPRINT_TEST_BINARY" sleep; }
@test "termination invalidates verification before releasing the reader" { "$FPRINT_TEST_BINARY" terminate; }
@test "a claim completed after termination is released without starting verification" { "$FPRINT_TEST_BINARY" late-claim; }
@test "fade out ignores verification status" { "$FPRINT_TEST_BINARY" fading; }
@test "release failure still invalidates local verification ownership" { "$FPRINT_TEST_BINARY" release-error; }
