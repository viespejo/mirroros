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
  local root="$1" version="${2:-2.59.2}" sha symbol_sha
  sha="$(sha256sum < "$BRANDING_SOURCE/mirroros-wordmark.svg" | cut -d' ' -f1)"
  symbol_sha="$(sha256sum < "$BRANDING_SOURCE/mirroros-symbol.svg" | cut -d' ' -f1)"
  bash "$BRANDING_SOURCE/install-assets" check "$BRANDING_SOURCE/mirroros-wordmark.svg" "$root/usr/share/mirroros/branding" \
    "svg-sha256:$sha symbol-sha256:$symbol_sha rsvg-convert:$version size:1580x320 symbol-size:320x320"
}

render_count() { grep -c '^rsvg-convert --width ' "$CFG_TEST_CALLS" || true; }

legacy_delivery() {
  rm "$BRANDING/mirroros-symbol.svg" "$BRANDING/mirroros-symbol.png"
  local sha
  sha="$(sha256sum < "$BRANDING/mirroros-wordmark.svg" | cut -d' ' -f1)"
  { printf 'render svg-sha256:%s rsvg-convert:2.59.2 size:1580x320\n' "$sha"
    grep '^f ' "$BRANDING/.mirroros-manifest" | grep -v 'mirroros-symbol\.'
  } > "$CFG_TEST_DIR/legacy-manifest"
  cp "$CFG_TEST_DIR/legacy-manifest" "$BRANDING/.mirroros-manifest"
}

@test "running configure renders and publishes the wordmark once and a rerun renders nothing" {
  run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/first"
  [ "$status" -eq 0 ]
  [[ "$output" == *'visual/branding: changed'* ]]
  [ -e "$CFG_TEST_INSTALLED/librsvg" ]
  cmp "$BRANDING_SOURCE/mirroros-wordmark.svg" "$BRANDING/mirroros-wordmark.svg"
  cmp "$BRANDING_SOURCE/mirroros-symbol.svg" "$BRANDING/mirroros-symbol.svg"
  [ "$(stat -c %a "$BRANDING/mirroros-symbol.png")" = 644 ]
  [ "$(stat -c %u:%g "$BRANDING/mirroros-symbol.png")" = "$(stat -c %u:%g "$MIRROROS_CONFIGURE_ROOT")" ]
  [ "$(od -An -tu1 -N8 "$BRANDING/mirroros-wordmark.png" | tr -s ' ')" = ' 137 80 78 71 13 10 26 10' ]
  [ "$(stat -c %a "$BRANDING/mirroros-wordmark.png")" = 644 ]
  [ "$(stat -c %a "$BRANDING")" = 755 ]
  branding_check "$MIRROROS_CONFIGURE_ROOT"
  [ "$(render_count)" -eq 2 ]
  grep -qE $'^mirroros-branding\tcapabilities/visual/branding\t\t\tsvg-sha256:[0-9a-f]{64} symbol-sha256:[0-9a-f]{64} rsvg-convert:2.59.2 size:1580x320 symbol-size:320x320$' \
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
  [ "$(render_count)" -eq 2 ]
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
  bash "$BRANDING_SOURCE/install-assets" prepare "$BRANDING_SOURCE/mirroros-wordmark.svg" "$CFG_TEST_DIR/stage/branding" \
    "$(stat -c %u "$CFG_TEST_DIR")" "$(stat -c %g "$CFG_TEST_DIR")"
  cp "$CFG_TEST_DIR/wordmark.png" "$CFG_TEST_DIR/stage/.branding.mirroros-staging/mirroros-wordmark.png"
  /usr/bin/rsvg-convert --width 320 --height 320 < "$BRANDING_SOURCE/mirroros-symbol.svg" \
    > "$CFG_TEST_DIR/stage/.branding.mirroros-staging/mirroros-symbol.png"
  run bash "$BRANDING_SOURCE/install-assets" publish "$BRANDING_SOURCE/mirroros-wordmark.svg" "$CFG_TEST_DIR/stage/branding" \
    real 1580 320 "$(stat -c %u "$CFG_TEST_DIR")" "$(stat -c %g "$CFG_TEST_DIR")"
  [ "$status" -eq 0 ]
  [ -f "$CFG_TEST_DIR/stage/branding/mirroros-wordmark.png" ]
  [ -f "$CFG_TEST_DIR/stage/branding/mirroros-symbol.png" ]
}

@test "an intact previous wordmark delivery migrates atomically and converges" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  legacy_delivery
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ "$(render_count)" -eq 2 ]
  branding_check "$MIRROROS_CONFIGURE_ROOT"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ "$(render_count)" -eq 0 ]
}

@test "an edited previous delivery is protected during migration" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  legacy_delivery
  printf 'local\n' >> "$BRANDING/mirroros-wordmark.png"
  cp -R "$BRANDING" "$CFG_TEST_DIR/previous"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ "$(render_count)" -eq 0 ]
  diff -r "$CFG_TEST_DIR/previous" "$BRANDING"
}

@test "a failed symbol render preserves the legacy delivery and retry recovers" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  legacy_delivery
  cp -R "$BRANDING" "$CFG_TEST_DIR/previous"
  CFG_TEST_RSVG_SYMBOL_FAIL=1 run "$CFG_TEST_ENTRY"
  [ "$status" -eq 5 ]
  diff -r "$CFG_TEST_DIR/previous" "$BRANDING"
  CFG_TEST_RSVG_SYMBOL_WIDTH=10 run "$CFG_TEST_ENTRY" --output "$CFG_TEST_DIR/symbol-size"
  [ "$status" -eq 5 ]
  grep -qF 'The rendered symbol is 10x320, expected 320x320.' "$CFG_TEST_DIR/symbol-size/configure.log"
  diff -r "$CFG_TEST_DIR/previous" "$BRANDING"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  branding_check "$MIRROROS_CONFIGURE_ROOT"
}

@test "both graphical sources participate in delivery identity and edited symbols are protected" {
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  printf '\n' >> "$CFG_TEST_DIR/code/capabilities/visual/branding/mirroros-symbol.svg"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ "$(render_count)" -eq 2 ]
  printf '\n' >> "$CFG_TEST_DIR/code/capabilities/visual/branding/mirroros-wordmark.svg"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 0 ]
  [ "$(render_count)" -eq 2 ]
  printf 'local\n' >> "$BRANDING/mirroros-symbol.png"
  cp -R "$BRANDING" "$CFG_TEST_DIR/previous"
  : > "$CFG_TEST_CALLS"
  run "$CFG_TEST_ENTRY"
  [ "$status" -eq 4 ]
  [ "$(render_count)" -eq 0 ]
  diff -r "$CFG_TEST_DIR/previous" "$BRANDING"
}

@test "the square symbol preserves every installer cell without a font or background" {
  # shellcheck disable=SC2016 # The quoted program is JavaScript, not shell expansions.
  run node --input-type=module -e '
    import fs from "node:fs";
    const [symbol, svg] = process.argv.slice(1).map(file => fs.readFileSync(file, "utf8"));
    const lines = symbol.trimEnd().split("\n").map(line => [...line]);
    const want = new Set();
    lines.forEach((cells, row) => cells.forEach((cell, column) => {
      if (!" \u2588".includes(cell)) throw new Error("unexpected symbol glyph");
      if (cell === "\u2588") {
        want.add(`${column},${row * 2}`);
        want.add(`${column},${row * 2 + 1}`);
      }
    }));
    const got = new Set();
    for (const [, x, y, w, h, back] of svg.matchAll(/M(\d+) (\d+)h(\d+)v(\d+)h-(\d+)z/g)) {
      if (w !== back) throw new Error("open segment");
      for (let dx = 0; dx < Number(w); dx++)
        for (let dy = 0; dy < Number(h); dy++) {
          const key = `${Number(x) + dx},${Number(y) + dy}`;
          if (got.has(key)) throw new Error("overlap");
          got.add(key);
        }
    }
    if (Math.max(...lines.map(line => line.length)) !== 16 || lines.length !== 8 ||
        !svg.includes(`viewBox="0 0 16 16"`)) throw new Error("square proportions");
    if (!svg.includes(`fill="#CACCCC"`) || /<text|font|<image|<rect|opacity|background/.test(svg))
      throw new Error("style");
    if (got.size !== want.size || [...want].some(key => !got.has(key))) throw new Error("silhouette differs");
  ' "$CFG_SOURCE_ROOT/install/confirmation/symbol.txt" "$BRANDING_SOURCE/mirroros-symbol.svg"
  [ "$status" -eq 0 ]
}
