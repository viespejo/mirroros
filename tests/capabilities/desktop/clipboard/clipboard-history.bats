#!/usr/bin/env bats
# Disposable clipboard fixtures only; no compositor, real history or opener is used.

setup() {
  local source="$BATS_TEST_DIRNAME/../../../../capabilities/desktop/clipboard/clipboard-history"
  CLIP_TEST_DIR=$(mktemp -d)
  CLIPBOARD_COMMAND="$CLIP_TEST_DIR/clipboard-history"
  sed "s|/usr/share/mirroros/shell/notifications/mirroros-notification-send|$CLIP_TEST_DIR/bin/mirroros-notification-send|" \
    "$source" > "$CLIPBOARD_COMMAND"
  export CLIP_TEST_DIR
  CLIP_TEST_REAL_TIMEOUT=$(command -v timeout)
  export CLIP_TEST_REAL_TIMEOUT
  export XDG_RUNTIME_DIR="$CLIP_TEST_DIR/runtime"
  export HOME="$CLIP_TEST_DIR/home" XDG_CACHE_HOME="$CLIP_TEST_DIR/cache"
  mkdir -p "$XDG_RUNTIME_DIR/mirroros/clipboard" "$HOME" "$CLIP_TEST_DIR/bin" "$CLIP_TEST_DIR/items"
  export CLIP_TEST_ROOT="$XDG_RUNTIME_DIR/mirroros/clipboard"
  : > "$CLIP_TEST_DIR/calls"
  : > "$CLIP_TEST_ROOT/db"
  printf '1\tdisposable text\n2\t[[ binary data 8 B png 1x1 ]]\n' > "$CLIP_TEST_DIR/list"
  printf 'disposable text\n' > "$CLIP_TEST_DIR/items/1"
  printf '\211PNG\r\n\032\n' > "$CLIP_TEST_DIR/items/2"
  cat > "$CLIP_TEST_DIR/bin/cliphist" <<'DOUBLE'
#!/usr/bin/bash
set -Eeuo pipefail
[[ "$1" == -db-path && "$2" == "$CLIP_TEST_ROOT/db" && "$3" == -max-items && "$4" == 200 &&
   "$5" == -config-path && "$6" == /dev/null ]] || exit 99
printf 'cliphist %s state=%s\n' "$*" "${CLIPBOARD_STATE:-}" >> "$CLIP_TEST_DIR/calls"
shift 6
[[ "${CLIP_TEST_FAIL:-}" != "$1" ]] || exit 17
case "$1" in
  store)
    case "${CLIPBOARD_STATE:-}" in
      sensitive) exit 0 ;;
      clear) tail -n +2 "$CLIP_TEST_DIR/list" > "$CLIP_TEST_DIR/next"; mv "$CLIP_TEST_DIR/next" "$CLIP_TEST_DIR/list" ;;
      *) cat > "$CLIP_TEST_DIR/stored"; : > "$CLIP_TEST_ROOT/db" ;;
    esac ;;
  list) cat "$CLIP_TEST_DIR/list" ;;
  decode) cat "$CLIP_TEST_DIR/items/$2" ;;
  delete)
    read -r id
    awk -F '\t' -v id="$id" '$1 != id' "$CLIP_TEST_DIR/list" > "$CLIP_TEST_DIR/next"
    mv "$CLIP_TEST_DIR/next" "$CLIP_TEST_DIR/list" ;;
  wipe) : > "$CLIP_TEST_DIR/list" ;;
  *) exit 98 ;;
esac
DOUBLE
  cat > "$CLIP_TEST_DIR/bin/wl-copy" <<'DOUBLE'
#!/usr/bin/bash
set -Eeuo pipefail
[[ "$1" == --type && $# == 2 ]] || exit 99
printf '%s' "$2" > "$CLIP_TEST_DIR/type"
cat > "$CLIP_TEST_DIR/copied"
exit "${CLIP_TEST_COPY_EXIT:-0}"
DOUBLE
  cat > "$CLIP_TEST_DIR/bin/df" <<'DOUBLE'
#!/usr/bin/bash
set -Eeuo pipefail
[[ "$*" == "-B1 --output=size,avail -- $XDG_RUNTIME_DIR" ]] || exit 99
count=0
[[ ! -f "$CLIP_TEST_DIR/df-count" ]] || read -r count < "$CLIP_TEST_DIR/df-count"
count=$((count + 1))
printf '%s\n' "$count" > "$CLIP_TEST_DIR/df-count"
available=${CLIP_TEST_AVAILABLE:-800000000}
if (( count > 1 )); then available=${CLIP_TEST_AFTER_AVAILABLE:-$available}; fi
if (( count > 3 )); then available=${CLIP_TEST_NORMALIZED_AVAILABLE:-$available}; fi
printf '1B-blocks Avail\n%s %s\n' "${CLIP_TEST_TOTAL:-1000000000}" "$available"
DOUBLE
  cat > "$CLIP_TEST_DIR/bin/test-open" <<'DOUBLE'
#!/usr/bin/bash
set -Eeuo pipefail
[[ "$(readlink /proc/self/fd/0)" == /dev/null && ! -e /proc/self/fd/9 ]] || exit 99
flock -n "$CLIP_TEST_ROOT/lock" true || exit 98
printf '%s' "$1" > "$CLIP_TEST_DIR/opened"
printf '%s\n' "$$" > "$CLIP_TEST_DIR/opener-pid"
if [[ "${CLIP_TEST_HOLD_OPEN:-0}" == 1 ]]; then
  : > "$CLIP_TEST_DIR/opener-ready"
  while [[ ! -e "$CLIP_TEST_DIR/opener-release" ]]; do sleep 0.02; done
fi
if [[ "${CLIP_TEST_HANG_OPEN:-0}" == 1 ]]; then
  sleep 60 &
  child=$!
  printf '%s\n' "$child" > "$CLIP_TEST_DIR/opener-child-pid"
  trap 'wait "$child" 2>/dev/null || :; exit 143' TERM
  wait "$child"
fi
exit "${CLIP_TEST_OPEN_EXIT:-0}"
DOUBLE
  cat > "$CLIP_TEST_DIR/bin/xdg-open" <<'DOUBLE'
#!/usr/bin/bash
set -Eeuo pipefail
[[ $# == 1 ]] || exit 99
: > "$CLIP_TEST_DIR/xdg-open-called"
exec "$CLIP_TEST_DIR/bin/test-open" "$1"
DOUBLE
  cat > "$CLIP_TEST_DIR/bin/xdg-mime" <<'DOUBLE'
#!/usr/bin/bash
set -Eeuo pipefail
[[ "$*" == 'query default text/plain' ]] || exit 99
[[ "$(readlink /proc/self/fd/0)" == /dev/null && ! -e /proc/self/fd/9 ]] || exit 99
flock -n "$CLIP_TEST_ROOT/lock" true || exit 98
: > "$CLIP_TEST_DIR/mime-query"
if [[ "${CLIP_TEST_HANG_QUERY:-0}" == 1 ]]; then exec sleep 60; fi
printf '%s\n' "${CLIP_TEST_HANDLER-org.example.Editor.desktop}"
exit "${CLIP_TEST_MIME_EXIT:-0}"
DOUBLE
  cat > "$CLIP_TEST_DIR/bin/uwsm" <<'DOUBLE'
#!/usr/bin/bash
set -Eeuo pipefail
[[ $# == 6 && "$1" == app && "$2" == -t && "$3" == service && "$4" == -- ]] || exit 99
printf '%s\n' "$@" > "$CLIP_TEST_DIR/uwsm-args"
exec "$CLIP_TEST_DIR/bin/test-open" "$6"
DOUBLE
  cat > "$CLIP_TEST_DIR/bin/timeout" <<'DOUBLE'
#!/usr/bin/bash
set -Eeuo pipefail
[[ "$1" == --kill-after=2s && "$2" == 10s ]] || exit 99
if [[ "${CLIP_TEST_SHORT_TIMEOUT:-0}" == 1 ]]; then
  shift 2
  exec "$CLIP_TEST_REAL_TIMEOUT" --kill-after=0.2s 0.2s "$@"
fi
exec "$CLIP_TEST_REAL_TIMEOUT" "$@"
DOUBLE
  cat > "$CLIP_TEST_DIR/bin/mirroros-notification-send" <<'DOUBLE'
#!/usr/bin/bash
printf '%s\n' "$@" > "$CLIP_TEST_DIR/notification"
DOUBLE
  cat > "$CLIP_TEST_DIR/bin/fzf" <<'DOUBLE'
#!/usr/bin/bash
printf '%s\n' "$@" > "$CLIP_TEST_DIR/fzf-args"
if [[ "${CLIP_TEST_FZF_EXIT:-0}" != 0 ]]; then exit "$CLIP_TEST_FZF_EXIT"; fi
awk 'NR == 1' > "$CLIP_TEST_DIR/selection"
cat "$CLIP_TEST_DIR/selection"
DOUBLE
  chmod 0755 "$CLIP_TEST_DIR/bin/"*
  export PATH="$CLIP_TEST_DIR/bin:$PATH"
}

teardown() { rm -rf -- "$CLIP_TEST_DIR"; }
cb() { bash "$CLIPBOARD_COMMAND" "$@"; }

@test "list and decode use only the constant runtime database and 200 item limit" {
  run cb list
  [ "$status" -eq 0 ]
  [ "$output" = "$(< "$CLIP_TEST_DIR/list")" ]
  cb decode 1 > "$CLIP_TEST_DIR/decoded"
  cmp "$CLIP_TEST_DIR/items/1" "$CLIP_TEST_DIR/decoded"
  grep -q -- '-db-path .* -max-items 200 -config-path /dev/null decode 1' "$CLIP_TEST_DIR/calls"
  [ ! -e "$XDG_CACHE_HOME/cliphist/db" ]
  [ "$(stat -c %a "$CLIP_TEST_ROOT")" = 700 ]
}

@test "an unused history lists empty and prunes previews without creating a database" {
  rm "$CLIP_TEST_ROOT/db"
  mkdir -p "$CLIP_TEST_ROOT/previews" "$CLIP_TEST_ROOT/open"
  : > "$CLIP_TEST_ROOT/previews/99.png"
  : > "$CLIP_TEST_ROOT/open/99.txt"
  run cb list
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$CLIP_TEST_ROOT/db" ]
  [ ! -s "$CLIP_TEST_DIR/calls" ]
  [ ! -e "$CLIP_TEST_ROOT/previews/99.png" ]
  [ -e "$CLIP_TEST_ROOT/open/99.txt" ]
}

@test "text at one MiB and image at 5000000 bytes are stored whole" {
  for spec in 'text 1048576' 'image/png 5000000'; do
    read -r type size <<< "$spec"
    head -c "$size" /dev/zero > "$CLIP_TEST_DIR/input"
    if [[ "$type" == text ]]; then
      tr '\000' a < "$CLIP_TEST_DIR/input" > "$CLIP_TEST_DIR/text"
      mv "$CLIP_TEST_DIR/text" "$CLIP_TEST_DIR/input"
    fi
    run cb store "$type" < "$CLIP_TEST_DIR/input"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    cmp "$CLIP_TEST_DIR/input" "$CLIP_TEST_DIR/stored"
    [ "$(stat -c %a "$CLIP_TEST_DIR/stored")" = 600 ]
    [ -z "$(find "$CLIP_TEST_ROOT" -name '.entry.*' -print)" ]
  done
}

@test "oversize text and PNG drop whole with only type and full size logged" {
  for spec in 'text 1048577' 'image/png 5000001' 'text 9000000'; do
    read -r type size <<< "$spec"
    head -c "$size" /dev/zero > "$CLIP_TEST_DIR/input"
    run cb store "$type" < "$CLIP_TEST_DIR/input"
    [ "$status" -eq 0 ]
    [ "$output" = "type=$type size=$size" ]
    [ ! -e "$CLIP_TEST_DIR/stored" ]
    [ ! -s "$CLIP_TEST_DIR/calls" ]
    [ -z "$(find "$CLIP_TEST_ROOT" -name '.entry.*' -print)" ]
  done
}

@test "the runtime reserve rejects entries that would leave below 25 percent free" {
  export CLIP_TEST_TOTAL=400 CLIP_TEST_AVAILABLE=110
  printf 'disposable' > "$CLIP_TEST_DIR/input"
  run cb store text < "$CLIP_TEST_DIR/input"
  [ "$status" -eq 0 ]
  [ "$output" = 'type=text size=10' ]
  [ ! -e "$CLIP_TEST_DIR/stored" ]
  [ ! -s "$CLIP_TEST_DIR/calls" ]
}

@test "a second free-space check rejects a concurrent space loss and exact reserve is allowed" {
  export CLIP_TEST_TOTAL=400 CLIP_TEST_AVAILABLE=200 CLIP_TEST_AFTER_AVAILABLE=109
  printf 'disposable' > "$CLIP_TEST_DIR/input"
  run cb store text < "$CLIP_TEST_DIR/input"
  [ "$status" -eq 0 ]
  [ "$output" = 'type=text size=10' ]
  [ ! -e "$CLIP_TEST_DIR/stored" ]
  rm "$CLIP_TEST_DIR/df-count"
  export CLIP_TEST_AFTER_AVAILABLE=110
  run cb store text < "$CLIP_TEST_DIR/input"
  [ "$status" -eq 0 ]
  cmp "$CLIP_TEST_DIR/input" "$CLIP_TEST_DIR/stored"
}

@test "an already exhausted runtime drains and drops without retaining contents" {
  export CLIP_TEST_TOTAL=400 CLIP_TEST_AVAILABLE=0
  printf 'disposable' > "$CLIP_TEST_DIR/input"
  run cb store text < "$CLIP_TEST_DIR/input"
  [ "$status" -eq 0 ]
  [ "$output" = 'type=text size=10' ]
  [ ! -e "$CLIP_TEST_DIR/stored" ]
}

@test "sensitive and clear states reach cliphist even with no free headroom" {
  export CLIP_TEST_AVAILABLE=0 CLIPBOARD_STATE=sensitive
  printf 'disposable notification code' > "$CLIP_TEST_DIR/input"
  run cb store text < "$CLIP_TEST_DIR/input"
  [ "$status" -eq 0 ]
  [ ! -e "$CLIP_TEST_DIR/stored" ]
  grep -q 'store state=sensitive$' "$CLIP_TEST_DIR/calls"
  [ ! -e "$CLIP_TEST_DIR/df-count" ]
  export CLIPBOARD_STATE=clear
  run cb store text < /dev/null
  [ "$status" -eq 0 ]
  grep -q 'store state=clear$' "$CLIP_TEST_DIR/calls"
  [ "$(wc -l < "$CLIP_TEST_DIR/list")" -eq 1 ]
}

@test "text capture preserves valid UTF-8 including non-ASCII bytes" {
  printf 'disposable caf\303\251 \347\225\214 \360\237\230\200\n' > "$CLIP_TEST_DIR/input"
  run cb store text < "$CLIP_TEST_DIR/input"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  cmp "$CLIP_TEST_DIR/input" "$CLIP_TEST_DIR/stored"
}

@test "BOM-less UTF-16 URLs normalize to UTF-8 and copy without NUL bytes" {
  printf 'https://example.org/disposable?test=1' > "$CLIP_TEST_DIR/expected"
  for encoding in UTF-16LE UTF-16BE; do
    iconv -f UTF-8 -t "$encoding" "$CLIP_TEST_DIR/expected" > "$CLIP_TEST_DIR/input"
    run cb store text < "$CLIP_TEST_DIR/input"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    cmp "$CLIP_TEST_DIR/expected" "$CLIP_TEST_DIR/stored"
    cp "$CLIP_TEST_DIR/stored" "$CLIP_TEST_DIR/items/1"
    run cb copy 1
    [ "$status" -eq 0 ]
    [ "$(< "$CLIP_TEST_DIR/type")" = 'text/plain;charset=utf-8' ]
    cmp "$CLIP_TEST_DIR/expected" "$CLIP_TEST_DIR/copied"
    [ -z "$(find "$CLIP_TEST_ROOT" -name '.entry.*' -print)" ]
  done
}

@test "UTF-16 with either BOM normalizes Unicode and removes the BOM" {
  printf 'disposable \347\225\214 \360\237\230\200' > "$CLIP_TEST_DIR/expected"
  for encoding in UTF-16LE UTF-16BE; do
    if [[ "$encoding" == UTF-16LE ]]; then printf '\377\376'; else printf '\376\377'; fi > "$CLIP_TEST_DIR/input"
    iconv -f UTF-8 -t "$encoding" "$CLIP_TEST_DIR/expected" >> "$CLIP_TEST_DIR/input"
    run cb store text < "$CLIP_TEST_DIR/input"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    cmp "$CLIP_TEST_DIR/expected" "$CLIP_TEST_DIR/stored"
  done
}

@test "malformed or ambiguous text drops whole with only type and size" {
  for fixture in invalid-utf8 truncated-utf16 ambiguous-nuls control-heuristic; do
    case "$fixture" in
      invalid-utf8) printf '\377invalid' ;;
      truncated-utf16) printf '\377\376h\000i' ;;
      ambiguous-nuls) printf 'a\000b\001c\000d\001' ;;
      control-heuristic) printf '\001\000a\000b\000c\000' ;;
    esac > "$CLIP_TEST_DIR/input"
    size=$(stat -c %s "$CLIP_TEST_DIR/input")
    run cb store text < "$CLIP_TEST_DIR/input"
    [ "$status" -eq 0 ]
    [ "$output" = "type=text size=$size" ]
    [ ! -e "$CLIP_TEST_DIR/stored" ]
    [ ! -s "$CLIP_TEST_DIR/calls" ]
    [ -z "$(find "$CLIP_TEST_ROOT" -name '.entry.*' -print)" ]
  done
}

@test "UTF-16 conversion cannot exceed the text cap even when its input is below it" {
  printf '\377\376' > "$CLIP_TEST_DIR/input"
  awk 'BEGIN { for (i=0; i<349526; i++) printf "\347\225\214" }' > "$CLIP_TEST_DIR/expected"
  iconv -f UTF-8 -t UTF-16LE "$CLIP_TEST_DIR/expected" >> "$CLIP_TEST_DIR/input"
  [ "$(stat -c %s "$CLIP_TEST_DIR/input")" -lt 1048576 ]
  run cb store text < "$CLIP_TEST_DIR/input"
  [ "$status" -eq 0 ]
  [ "$output" = 'type=text size=1048578' ]
  [ ! -e "$CLIP_TEST_DIR/stored" ]
  [ ! -s "$CLIP_TEST_DIR/calls" ]
  [ -z "$(find "$CLIP_TEST_ROOT" -name '.entry.*' -print)" ]
}

@test "UTF-16 Unicode below the normalized text cap is stored whole" {
  printf '\377\376' > "$CLIP_TEST_DIR/input"
  awk 'BEGIN { for (i=0; i<349525; i++) printf "\347\225\214" }' > "$CLIP_TEST_DIR/expected"
  iconv -f UTF-8 -t UTF-16LE "$CLIP_TEST_DIR/expected" >> "$CLIP_TEST_DIR/input"
  run cb store text < "$CLIP_TEST_DIR/input"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  cmp "$CLIP_TEST_DIR/expected" "$CLIP_TEST_DIR/stored"
  [ -z "$(find "$CLIP_TEST_ROOT" -name '.entry.*' -print)" ]
}

@test "conversion drains and drops when normalized bytes exceed runtime headroom" {
  export CLIP_TEST_TOTAL=400 CLIP_TEST_AVAILABLE=200 CLIP_TEST_AFTER_AVAILABLE=111
  printf '\377\376' > "$CLIP_TEST_DIR/input"
  printf '\347\225\214\347\225\214\347\225\214\347\225\214' > "$CLIP_TEST_DIR/expected"
  iconv -f UTF-8 -t UTF-16LE "$CLIP_TEST_DIR/expected" >> "$CLIP_TEST_DIR/input"
  run cb store text < "$CLIP_TEST_DIR/input"
  [ "$status" -eq 0 ]
  [ "$output" = 'type=text size=12' ]
  [ ! -e "$CLIP_TEST_DIR/stored" ]
  [ ! -s "$CLIP_TEST_DIR/calls" ]
  [ -z "$(find "$CLIP_TEST_ROOT" -name '.entry.*' -print)" ]
}

@test "normalized text rechecks the runtime reserve before storage" {
  export CLIP_TEST_TOTAL=400 CLIP_TEST_AVAILABLE=200 CLIP_TEST_NORMALIZED_AVAILABLE=111
  printf 'disposable12' > "$CLIP_TEST_DIR/expected"
  iconv -f UTF-8 -t UTF-16LE "$CLIP_TEST_DIR/expected" > "$CLIP_TEST_DIR/input"
  run cb store text < "$CLIP_TEST_DIR/input"
  [ "$status" -eq 0 ]
  [ "$output" = 'type=text size=12' ]
  [ ! -e "$CLIP_TEST_DIR/stored" ]
  [ ! -s "$CLIP_TEST_DIR/calls" ]
  [ -z "$(find "$CLIP_TEST_ROOT" -name '.entry.*' -print)" ]
}

@test "copy restores explicit text and PNG MIME types and exact bytes" {
  run cb copy 1
  [ "$status" -eq 0 ]
  [ "$(< "$CLIP_TEST_DIR/type")" = 'text/plain;charset=utf-8' ]
  cmp "$CLIP_TEST_DIR/items/1" "$CLIP_TEST_DIR/copied"
  run cb copy 2
  [ "$status" -eq 0 ]
  [ "$(< "$CLIP_TEST_DIR/type")" = image/png ]
  cmp "$CLIP_TEST_DIR/items/2" "$CLIP_TEST_DIR/copied"
  [ -z "$(find "$CLIP_TEST_ROOT" -name '.entry.*' -print)" ]
}

@test "preview is private, runtime-only and refuses non-PNG text" {
  run cb preview 2
  [ "$status" -eq 0 ]
  [ "$output" = "$CLIP_TEST_ROOT/previews/2.png" ]
  cmp "$CLIP_TEST_DIR/items/2" "$output"
  [ "$(stat -c %a "$output")" = 600 ]
  [ "$(stat -c %a "$CLIP_TEST_ROOT/previews")" = 700 ]
  run cb preview 1
  [ "$status" -eq 2 ]
  [ ! -e "$CLIP_TEST_ROOT/previews/1.png" ]
}

@test "list prunes orphan previews but never open files" {
  cb preview 2
  : > "$CLIP_TEST_ROOT/previews/99.png"
  : > "$CLIP_TEST_ROOT/open/99.txt"
  run cb list
  [ "$status" -eq 0 ]
  [ -f "$CLIP_TEST_ROOT/previews/2.png" ]
  [ ! -e "$CLIP_TEST_ROOT/previews/99.png" ]
  [ -f "$CLIP_TEST_ROOT/open/99.txt" ]
}

@test "delete removes entry files and orphan previews, clear removes all owned entry files" {
  cb preview 2
  : > "$CLIP_TEST_ROOT/previews/99.png"
  : > "$CLIP_TEST_ROOT/open/2.txt"
  : > "$CLIP_TEST_ROOT/open/99.txt"
  run cb delete 2
  [ "$status" -eq 0 ]
  [ ! -e "$CLIP_TEST_ROOT/previews/2.png" ]
  [ ! -e "$CLIP_TEST_ROOT/previews/99.png" ]
  [ ! -e "$CLIP_TEST_ROOT/open/2.txt" ]
  [ -e "$CLIP_TEST_ROOT/open/99.txt" ]
  : > "$CLIP_TEST_ROOT/previews/88.png"
  run cb clear
  [ "$status" -eq 0 ]
  [ -z "$(find "$CLIP_TEST_ROOT/previews" "$CLIP_TEST_ROOT/open" -type f -print)" ]
  grep -q 'wipe state=' "$CLIP_TEST_DIR/calls"
}

@test "open uses only the first URL, including two URLs on the same line" {
  printf 'before https://example.org/x27?a=1 https://example.net/second\nafter https://example.com/third\n' > "$CLIP_TEST_DIR/items/1"
  run cb open 1
  [ "$status" -eq 0 ]
  [ "$(< "$CLIP_TEST_DIR/opened")" = 'https://example.org/x27?a=1' ]
  [ ! -e "$CLIP_TEST_ROOT/open/1.txt" ]
}

@test "open strips URL delimiters and accepts domain-only text with an optional path" {
  printf '%s\n' "<http://example.org/path>'" > "$CLIP_TEST_DIR/items/1"
  run cb open 1
  [ "$status" -eq 0 ]
  [ "$(< "$CLIP_TEST_DIR/opened")" = 'http://example.org/path' ]
  printf '  example.org/path  \n' > "$CLIP_TEST_DIR/items/1"
  run cb open 1
  [ "$status" -eq 0 ]
  [ "$(< "$CLIP_TEST_DIR/opened")" = https://example.org/path ]
}

@test "other text opens a 0600 runtime file without changing original bytes" {
  printf 'not a domain: example.org\n\n' > "$CLIP_TEST_DIR/items/1"
  run cb open 1
  [ "$status" -eq 0 ]
  [ "$(< "$CLIP_TEST_DIR/opened")" = "$CLIP_TEST_ROOT/open/1.txt" ]
  [ "$(< "$CLIP_TEST_DIR/uwsm-args")" = "$(printf 'app\n-t\nservice\n--\norg.example.Editor.desktop\n%s' "$CLIP_TEST_ROOT/open/1.txt")" ]
  [ ! -e "$CLIP_TEST_DIR/xdg-open-called" ]
  cmp "$CLIP_TEST_DIR/items/1" "$CLIP_TEST_ROOT/open/1.txt"
  [ "$(stat -c %a "$CLIP_TEST_ROOT/open/1.txt")" = 600 ]
  [ "$(stat -c %a "$CLIP_TEST_ROOT/open")" = 700 ]
  [ ! -e "$XDG_CACHE_HOME/cliphist/db" ]
}

@test "open images use runtime previews and missing handlers notify without clipboard contents" {
  run cb open 2
  [ "$status" -eq 0 ]
  [ "$(< "$CLIP_TEST_DIR/opened")" = "$CLIP_TEST_ROOT/previews/2.png" ]
  cmp "$CLIP_TEST_DIR/items/2" "$CLIP_TEST_ROOT/previews/2.png"
  [ -e "$CLIP_TEST_DIR/xdg-open-called" ]
  [ ! -e "$CLIP_TEST_DIR/mime-query" ]
  export CLIP_TEST_OPEN_EXIT=3
  run cb open 1
  [ "$status" -eq 1 ]
  [ "$(< "$CLIP_TEST_DIR/notification")" = "$(printf '%s\n' -u normal --transient -- \
    'Clipboard entry could not be opened' \
    'Next action: check the default handler in mimeapps.list and the terminal configuration, then retry.')" ]
}

@test "missing sender preserves silent success and the open failure status" {
  rm -- "$CLIP_TEST_DIR/bin/mirroros-notification-send"
  run cb open 1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  export CLIP_TEST_OPEN_EXIT=7
  run cb open 1
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ ! -e "$CLIP_TEST_DIR/notification" ]
}

@test "text open uses the existing desktop association without selecting an application" {
  export CLIP_TEST_HANDLER=org.example.AlternateEditor.desktop
  run cb open 1
  [ "$status" -eq 0 ]
  grep -qxF org.example.AlternateEditor.desktop "$CLIP_TEST_DIR/uwsm-args"
  [ ! -e "$CLIP_TEST_DIR/xdg-open-called" ]
  [ ! -e "$CLIP_TEST_DIR/notification" ]
}

@test "missing or invalid text handlers notify without launching a fallback" {
  for handler in '' '-editor.desktop' 'path/editor.desktop' 'editor.desktop:action.desktop' \
    $'editor.desktop\nother.desktop' $'editor.desktop\rother.desktop'; do
    export CLIP_TEST_HANDLER="$handler"
    rm -f "$CLIP_TEST_DIR/notification"
    run cb open 1
    [ "$status" -eq 1 ]
    [ -e "$CLIP_TEST_DIR/mime-query" ]
    [ ! -e "$CLIP_TEST_DIR/uwsm-args" ]
    [ ! -e "$CLIP_TEST_DIR/xdg-open-called" ]
    grep -q 'Next action:.*mimeapps.list.*terminal configuration' "$CLIP_TEST_DIR/notification"
    [ "$(stat -c %a "$CLIP_TEST_ROOT/open/1.txt")" = 600 ]
  done
}

@test "MIME query and native launcher failures notify without fallback or content" {
  export CLIP_TEST_MIME_EXIT=3
  run cb open 1
  [ "$status" -eq 1 ]
  [ ! -e "$CLIP_TEST_DIR/uwsm-args" ]
  [ ! -e "$CLIP_TEST_DIR/xdg-open-called" ]
  [ -e "$CLIP_TEST_DIR/notification" ]
  unset CLIP_TEST_MIME_EXIT
  export CLIP_TEST_OPEN_EXIT=7
  run cb open 1
  [ "$status" -eq 1 ]
  [ -e "$CLIP_TEST_DIR/uwsm-args" ]
  [ ! -e "$CLIP_TEST_DIR/xdg-open-called" ]
  ! grep -q 'disposable text' "$CLIP_TEST_DIR/notification"
}

@test "a blocked MIME query times out and notifies instead of waiting indefinitely" {
  export CLIP_TEST_SHORT_TIMEOUT=1 CLIP_TEST_HANG_QUERY=1
  run "$CLIP_TEST_REAL_TIMEOUT" --kill-after=1s 4s bash "$CLIPBOARD_COMMAND" open 1
  [ "$status" -eq 1 ]
  [ -e "$CLIP_TEST_DIR/mime-query" ]
  [ ! -e "$CLIP_TEST_DIR/uwsm-args" ]
  [ ! -e "$CLIP_TEST_DIR/xdg-open-called" ]
  [ -e "$CLIP_TEST_DIR/notification" ]
}

@test "blocked text and image openers time out and leave no waiting child" {
  export CLIP_TEST_SHORT_TIMEOUT=1 CLIP_TEST_HANG_OPEN=1
  for id in 1 2; do
    run "$CLIP_TEST_REAL_TIMEOUT" --kill-after=1s 4s bash "$CLIPBOARD_COMMAND" open "$id"
    [ "$status" -eq 1 ]
    [ -e "$CLIP_TEST_DIR/notification" ]
    opener_pid=$(< "$CLIP_TEST_DIR/opener-pid")
    child_pid=$(< "$CLIP_TEST_DIR/opener-child-pid")
    ! kill -0 "$opener_pid" 2>/dev/null
    ! kill -0 "$child_pid" 2>/dev/null
    [ -z "$(find "$CLIP_TEST_ROOT" -name '.entry.*' -print)" ]
  done
}

@test "list and capture remain available while text or image openers are busy" {
  export CLIP_TEST_HOLD_OPEN=1
  for id in 1 2; do
    rm -f "$CLIP_TEST_DIR/opener-ready" "$CLIP_TEST_DIR/opener-release"
    cb open "$id" > "$CLIP_TEST_DIR/open-output" 2>&1 &
    opener=$!
    ready=0
    for attempt in {1..100}; do
      if [[ -e "$CLIP_TEST_DIR/opener-ready" ]]; then ready=1; break; fi
      sleep 0.02
    done
    run "$CLIP_TEST_REAL_TIMEOUT" 2s bash "$CLIPBOARD_COMMAND" list
    list_status=$status
    list_output=$output
    run "$CLIP_TEST_REAL_TIMEOUT" 2s bash "$CLIPBOARD_COMMAND" store text < "$CLIP_TEST_DIR/items/1"
    store_status=$status
    : > "$CLIP_TEST_DIR/opener-release"
    open_status=0
    wait "$opener" || open_status=$?
    [ "$ready" -eq 1 ]
    [ "$list_status" -eq 0 ]
    [ "$list_output" = "$(< "$CLIP_TEST_DIR/list")" ]
    [ "$store_status" -eq 0 ]
    [ "$open_status" -eq 0 ]
    cmp "$CLIP_TEST_DIR/items/1" "$CLIP_TEST_DIR/stored"
  done
}

@test "pick selects through fzf and copies without pasting; cancellation stays nonzero" {
  run cb pick
  [ "$status" -eq 0 ]
  cmp "$CLIP_TEST_DIR/items/1" "$CLIP_TEST_DIR/copied"
  grep -qxF -- '--with-nth=2..' "$CLIP_TEST_DIR/fzf-args"
  rm "$CLIP_TEST_DIR/copied"
  export CLIP_TEST_FZF_EXIT=130
  run cb pick
  [ "$status" -eq 130 ]
  [ ! -e "$CLIP_TEST_DIR/copied" ]
}

@test "upstream decode, store and copy failures remain failures and clean temporary files" {
  for command in decode store; do
    export CLIP_TEST_FAIL="$command"
    if [[ "$command" == decode ]]; then
      run cb copy 1
    else
      run cb store text < "$CLIP_TEST_DIR/items/1"
    fi
    [ "$status" -eq 17 ]
    [ -z "$(find "$CLIP_TEST_ROOT" -name '.entry.*' -print)" ]
  done
  unset CLIP_TEST_FAIL
  export CLIP_TEST_COPY_EXIT=19
  run cb copy 1
  [ "$status" -eq 19 ]
}

@test "failed listing remains a failure without pruning previews or opening fzf" {
  cb preview 2
  export CLIP_TEST_FAIL=list
  for command in list pick; do
    run cb "$command"
    [ "$status" -eq 17 ]
    [ -f "$CLIP_TEST_ROOT/previews/2.png" ]
    [ ! -e "$CLIP_TEST_DIR/fzf-args" ]
  done
}

@test "invalid usage, unsupported capture types and unsafe ids return 2 with usage before invoking tools" {
  for arguments in '' 'unknown' 'list extra' 'clear extra' 'store' 'store image/jpeg' 'store text extra' \
    'decode' 'copy -1' 'preview ../2' 'delete 1 extra' 'open abc' 'pick extra'; do
    # Intentional word splitting supplies these fixed, non-secret argv test cases.
    # shellcheck disable=SC2086
    run cb $arguments
    [ "$status" -eq 2 ]
    [[ "$output" == 'Usage: clipboard-history '* ]]
  done
  [ ! -s "$CLIP_TEST_DIR/calls" ]
}

@test "a symlinked runtime subtree is rejected without writing through it" {
  mv "$CLIP_TEST_ROOT" "$XDG_RUNTIME_DIR/original"
  ln -s "$XDG_RUNTIME_DIR/original" "$CLIP_TEST_ROOT"
  run cb store text < "$CLIP_TEST_DIR/items/1"
  [ "$status" -eq 2 ]
  [ ! -s "$CLIP_TEST_DIR/calls" ]
}
