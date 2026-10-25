#!/usr/bin/env bats
# Contracts of capabilities/desktop/shell/install-runtime, run without root against a disposable copy of the source.

setup() {
  ROOT="$(cd -- "$BATS_TEST_DIRNAME/../../../.." && pwd -P)"
  INSTALLER="$ROOT/capabilities/desktop/shell/install-runtime"
  WORK="$(mktemp -d)"
  SOURCE="$WORK/source"
  DEST="$WORK/usr/share/mirroros/shell"
  cp -R "$ROOT/capabilities/desktop/shell" "$SOURCE"
  ORIGINAL_PATH="$PATH"
}

teardown() {
  export PATH="$ORIGINAL_PATH"
  rm -rf -- "$WORK"
}

publish() { bash "$INSTALLER" publish "$SOURCE" "$DEST" "$(id -u)" "$(id -g)"; }
check() { bash "$INSTALLER" check "$SOURCE" "$DEST"; }
staging_left() { compgen -G "$WORK/usr/share/mirroros/.shell.mirroros-staging.*" > /dev/null; }

@test "publication delivers every runtime file byte for byte with fixed modes and no delivery files" {
  run check
  [ "$status" -eq 1 ]
  run publish
  [ "$status" -eq 0 ]
  run check
  [ "$status" -eq 0 ]
  while IFS= read -r -d '' file; do
    relative="${file#"$SOURCE"/}"
    case "$relative" in apply|packages|install-runtime|systemd/*) continue ;; esac
    cmp "$file" "$DEST/$relative"
    if [[ -x "$file" ]]; then [ "$(stat -c %a "$DEST/$relative")" = 755 ]; else [ "$(stat -c %a "$DEST/$relative")" = 644 ]; fi
  done < <(find "$SOURCE" -type f -print0)
  [ "$(stat -c %a "$DEST/services/hidden-entries.sh")" = 755 ]
  [ "$(stat -c %a "$DEST")" = 755 ]
  for excluded in apply packages install-runtime systemd; do [ ! -e "$DEST/$excluded" ]; done
  [ -f "$DEST/.mirroros-manifest" ]
  run grep -q 'managed by MirrorOS configure' "$DEST/menu/Menu.qml" "$DEST/LICENSE.omarchy"
  [ "$status" -eq 1 ]
  run staging_left
  [ "$status" -eq 1 ]
}

@test "an unchanged rerun keeps the published tree and a changed source is exchanged as a whole" {
  publish
  inode="$(stat -c %i "$DEST/shell.qml")"
  run publish
  [ "$status" -eq 0 ]
  [ "$(stat -c %i "$DEST/shell.qml")" = "$inode" ]
  first="$(bash "$INSTALLER" digest "$SOURCE")"
  printf '// changed\n' >> "$SOURCE/shell.qml"
  printf 'new\n' > "$SOURCE/services/New.qml"
  [ "$(bash "$INSTALLER" digest "$SOURCE")" != "$first" ]
  run check
  [ "$status" -eq 1 ]
  run publish
  [ "$status" -eq 0 ]
  cmp "$SOURCE/shell.qml" "$DEST/shell.qml"
  cmp "$SOURCE/services/New.qml" "$DEST/services/New.qml"
  rm "$SOURCE/services/New.qml"
  publish
  [ ! -e "$DEST/services/New.qml" ]
  run staging_left
  [ "$status" -eq 1 ]
}

@test "a modified previous delivery is a conflict and is never overwritten" {
  publish
  printf '// local edit\n' >> "$DEST/shell.qml"
  cp "$DEST/shell.qml" "$WORK/edited"
  printf '// newer source\n' >> "$SOURCE/osd/Osd.qml"
  run publish
  [ "$status" -eq 4 ]
  [[ "$output" == *'differs from its last MirrorOS delivery'* ]]
  cmp "$WORK/edited" "$DEST/shell.qml"
  run staging_left
  [ "$status" -eq 1 ]
  cp "$SOURCE/shell.qml" "$DEST/shell.qml"
  touch "$DEST/extra.qml"
  run check
  [ "$status" -eq 4 ]
  rm "$DEST/extra.qml" "$DEST/bar/Bar.qml"
  run check
  [ "$status" -eq 4 ]
  cp "$SOURCE/bar/Bar.qml" "$DEST/bar/Bar.qml"
  chmod 0600 "$DEST/bar/Bar.qml"
  run check
  [ "$status" -eq 4 ]
}

@test "unknown destinations links and non-directories are conflicts and stay untouched" {
  mkdir -p "$DEST"
  printf 'user\n' > "$DEST/shell.qml"
  run publish
  [ "$status" -eq 4 ]
  [[ "$output" == *'not a shell runtime delivered by MirrorOS'* ]]
  [ "$(< "$DEST/shell.qml")" = user ]
  rm -r "$DEST"
  ln -s "$SOURCE" "$DEST"
  run publish
  [ "$status" -eq 4 ]
  [ -L "$DEST" ]
  rm "$DEST"
  printf 'file\n' > "$DEST"
  run publish
  [ "$status" -eq 4 ]
  [ "$(< "$DEST")" = file ]
}

@test "an interrupted exchange keeps the previous complete tree and the rerun converges and removes staging" {
  publish
  cp -R "$SOURCE" "$WORK/previous-source"
  printf '// changed\n' >> "$SOURCE/shell.qml"
  mkdir -p "$WORK/bin"
  printf '#!/usr/bin/bash\n[[ " $* " != *" --exchange "* ]] || exit 9\nexec /usr/bin/mv "$@"\n' > "$WORK/bin/mv"
  chmod 0755 "$WORK/bin/mv"
  PATH="$WORK/bin:$PATH" run publish
  [ "$status" -ne 0 ]
  run bash "$INSTALLER" check "$WORK/previous-source" "$DEST"
  [ "$status" -eq 0 ]
  staging_left
  run publish
  [ "$status" -eq 0 ]
  cmp "$SOURCE/shell.qml" "$DEST/shell.qml"
  run staging_left
  [ "$status" -eq 1 ]
}

@test "a source with a link or an unexpected argument is rejected before publication" {
  ln -s shell.qml "$SOURCE/link.qml"
  run publish
  [ "$status" -ne 0 ]
  [ ! -e "$DEST" ]
  rm "$SOURCE/link.qml"
  run bash "$INSTALLER" publish "$SOURCE" "$DEST" root root
  [ "$status" -eq 6 ]
  run bash "$INSTALLER" remove "$SOURCE" "$DEST"
  [ "$status" -eq 6 ]
}
