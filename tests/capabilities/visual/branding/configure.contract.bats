#!/usr/bin/env bats
# visual/branding through the configure entry point, in both contexts, with test doubles.
load ../../support

setup() {
  cfg_test_setup
  printf 'CFG_STEPS=(visual/branding)\n' > "$CFG_TEST_DIR/code/capabilities/configure-steps"
  BRANDING_SOURCE="$CFG_SOURCE_ROOT/capabilities/visual/branding"
  BRANDING="$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/branding"
}
teardown() { cfg_test_teardown; }

branding_check() {
  local root="$1" version="${2:-2.59.2}" sha
  sha="$(sha256sum < "$BRANDING_SOURCE/mirroros-wordmark.svg" | cut -d' ' -f1)"
  bash "$BRANDING_SOURCE/install-assets" check "$BRANDING_SOURCE/mirroros-wordmark.svg" "$root/usr/share/mirroros/branding" \
    "svg-sha256:$sha rsvg-convert:$version size:1580x320"
}

render_count() { grep -c '^rsvg-convert --width 1580 --height 320$' "$CFG_TEST_CALLS" || true; }

@test "running configure renders and publishes the wordmark once and a rerun renders nothing" {
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/branding: changed'* ]]
  [ -e "$CFG_TEST_INSTALLED/librsvg" ]
  cmp "$BRANDING_SOURCE/mirroros-wordmark.svg" "$BRANDING/mirroros-wordmark.svg"
  [ "$(od -An -tu1 -N8 "$BRANDING/mirroros-wordmark.png" | tr -s ' ')" = ' 137 80 78 71 13 10 26 10' ]
  [ "$(stat -c %a "$BRANDING/mirroros-wordmark.png")" = 644 ]
  [ "$(stat -c %a "$BRANDING")" = 755 ]
  branding_check "$MIRROROS_CONFIGURE_ROOT"
  [ "$(render_count)" -eq 1 ]
  grep -qE $'^mirroros-branding\tcapabilities/visual/branding\t\t\tsvg-sha256:[0-9a-f]{64} rsvg-convert:2.59.2 size:1580x320$' \
    "$CFG_TEST_DIR/first/sources.tsv"
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/.branding.mirroros-staging" ]
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/branding: unchanged'* ]]
  [ "$(render_count)" -eq 0 ]
  cfg_test_no_install
}

@test "a changed renderer version renders again and replaces the previous delivery" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  : > "$CFG_TEST_CALLS"
  CFG_TEST_RSVG_VERSION=2.60.0 run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/branding: changed'* ]]
  [ "$(render_count)" -eq 1 ]
  branding_check "$MIRROROS_CONFIGURE_ROOT" 2.60.0
}

@test "target configure renders through the chroot and reruns unchanged" {
  cfg_test_target_context
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  grep -qxF "arch-chroot $CFG_TEST_TARGET_ROOT rsvg-convert --version" "$CFG_TEST_CALLS"
  grep -qxF "arch-chroot $CFG_TEST_TARGET_ROOT rsvg-convert --width 1580 --height 320" "$CFG_TEST_CALLS"
  branding_check "$CFG_TEST_TARGET_ROOT"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY" --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/branding: unchanged'* ]]
  [ "$(render_count)" -eq 0 ]
}

@test "a multi-line renderer version report is identified by its first line in target configure" {
  cfg_test_target_context
  CFG_TEST_RSVG_VERSION=2.63.4 CFG_TEST_RSVG_VERSION_DETAILS=1 run "$CFG_TEST_ENTRY" \
    --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/branding: changed'* ]]
  branding_check "$CFG_TEST_TARGET_ROOT" 2.63.4
  : > "$CFG_TEST_CALLS"
  CFG_TEST_RSVG_VERSION=2.63.4 CFG_TEST_RSVG_VERSION_DETAILS=1 run "$CFG_TEST_ENTRY" \
    --target-root "$CFG_TEST_TARGET_ROOT" --user alice
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/branding: unchanged'* ]]
  [ "$(render_count)" -eq 0 ]
}

@test "edited linked or unknown destinations are preserved and fail the step" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  printf 'local\n' >> "$BRANDING/mirroros-wordmark.png"
  cp "$BRANDING/mirroros-wordmark.png" "$CFG_TEST_DIR/edited.png"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/edited"
  [ "$status" -eq 4 ]
  grep -qF 'differs from its last MirrorOS delivery' "$CFG_TEST_DIR/edited/configure.log"
  cmp "$CFG_TEST_DIR/edited.png" "$BRANDING/mirroros-wordmark.png"
  rm -rf "$BRANDING"
  mkdir -p "$BRANDING" "$CFG_TEST_DIR/elsewhere"
  printf 'mine\n' > "$BRANDING/logo.png"
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/unknown"
  [ "$status" -eq 4 ]
  grep -qF 'is not a branding delivery by MirrorOS' "$CFG_TEST_DIR/unknown/configure.log"
  [ "$(< "$BRANDING/logo.png")" = mine ]
  rm -rf "$BRANDING"
  ln -s "$CFG_TEST_DIR/elsewhere" "$BRANDING"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ -L "$BRANDING" ]
  [ -z "$(ls -A "$CFG_TEST_DIR/elsewhere")" ]
}

@test "a failed or wrongly sized rendering publishes nothing and a rerun recovers" {
  CFG_TEST_RSVG_FAIL=1 run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/failed"
  [ "$status" -eq 5 ]
  grep -qF 'simulated rendering failure' "$CFG_TEST_DIR/failed/configure.log"
  [ ! -e "$BRANDING" ]
  [ -d "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/.branding.mirroros-staging" ]
  CFG_TEST_RSVG_WIDTH=10 run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/size"
  [ "$status" -eq 5 ]
  grep -qF 'The rendered wordmark is 10x320, expected 1580x320.' "$CFG_TEST_DIR/size/configure.log"
  [ ! -e "$BRANDING" ]
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  branding_check "$MIRROROS_CONFIGURE_ROOT"
  [ ! -e "$MIRROROS_CONFIGURE_ROOT/usr/share/mirroros/.branding.mirroros-staging" ]
}

@test "a failed rerendering keeps the previous complete delivery" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  cp -R "$BRANDING" "$CFG_TEST_DIR/previous"
  CFG_TEST_RSVG_VERSION=2.60.0 CFG_TEST_RSVG_FAIL=1 run "$CFG_TEST_ENTRY"
  [ "$status" -eq 5 ]
  diff -r "$CFG_TEST_DIR/previous" "$BRANDING"
  branding_check "$MIRROROS_CONFIGURE_ROOT"
}

@test "the wordmark keeps the installer banner silhouette exactly" {
  # shellcheck disable=SC2016 # The quoted program is JavaScript; its template literals are not shell expansions.
  run node -e '
    const fs = require("fs");
    const [banner, svg] = process.argv.slice(1).map(file => fs.readFileSync(file, "utf8"));
    const lines = banner.split("\n").filter(line => line.length).map(line => [...line.replace(/\s+$/, "")]);
    const width = Math.max(...lines.map(line => line.length));
    const want = new Set();
    lines.forEach((cells, row) => cells.forEach((cell, column) => {
      if (cell === "\u2588" || cell === "\u2580") want.add(`${column},${row * 2}`);
      if (cell === "\u2588" || cell === "\u2584") want.add(`${column},${row * 2 + 1}`);
      if (!" \u2588\u2580\u2584".includes(cell)) throw new Error(`unexpected banner glyph ${cell}`);
    }));
    const got = new Set();
    for (const [, x, y, w] of svg.matchAll(/M(\d+) (\d+)h(\d+)v1h-\d+z/g))
      for (let i = 0; i < Number(w); i++) {
        const key = `${Number(x) + i},${y}`;
        if (got.has(key)) throw new Error(`overlap at ${key}`);
        got.add(key);
      }
    if (!svg.includes(`viewBox="0 0 ${width} ${lines.length * 2}"`)) throw new Error("viewBox");
    if (!svg.includes(`fill="rgb(202,204,204)"`) || /<text|font-family|<image/.test(svg)) throw new Error("style");
    if (got.size !== want.size || [...want].some(key => !got.has(key))) throw new Error("silhouette differs");
  ' "$CFG_SOURCE_ROOT/install/confirmation/banner.txt" "$BRANDING_SOURCE/mirroros-wordmark.svg"
  [ "$status" -eq 0 ]
}

@test "the real renderer produces the declared PNG size from the wordmark" {
  [[ -x /usr/bin/rsvg-convert ]] || skip 'rsvg-convert is not installed'
  /usr/bin/rsvg-convert --width 1580 --height 320 < "$BRANDING_SOURCE/mirroros-wordmark.svg" > "$CFG_TEST_DIR/wordmark.png"
  mkdir -p "$CFG_TEST_DIR/stage/.branding.mirroros-staging"
  cp "$BRANDING_SOURCE/mirroros-wordmark.svg" "$CFG_TEST_DIR/wordmark.png" "$CFG_TEST_DIR/stage/.branding.mirroros-staging/"
  mv "$CFG_TEST_DIR/stage/.branding.mirroros-staging/wordmark.png" "$CFG_TEST_DIR/stage/.branding.mirroros-staging/mirroros-wordmark.png"
  run bash "$BRANDING_SOURCE/install-assets" publish "$BRANDING_SOURCE/mirroros-wordmark.svg" "$CFG_TEST_DIR/stage/branding" \
    real 1580 320 "$(stat -c %u "$CFG_TEST_DIR")" "$(stat -c %g "$CFG_TEST_DIR")"
  [ "$status" -eq 0 ]
  [ -f "$CFG_TEST_DIR/stage/branding/mirroros-wordmark.png" ]
}
