# Branding sources and ownership

## Wordmark

`mirroros-wordmark.svg` is MirrorOS-owned material: a font-independent graphical adaptation of the block-letter
wordmark in [`install/confirmation/banner.txt`](../../../install/confirmation/banner.txt) (DEC-003 of the
[greeter and Plymouth interview](../../../docs/technical-interviews/greeter-plymouth_log.md)). Each terminal cell
becomes a 1x2-unit cell: `█` fills both halves, `▀` the upper and `▄` the lower; horizontally adjacent filled halves
are merged into one path segment. Trailing spaces are not part of the 79x16 view box. The silhouette is unchanged;
the banner itself is not modified. The fill is the greeter's neutral off-white `rgb(202, 204, 204)`; there is no
background, text, font, shadow or animation, so each theme supplies its own background. The branding test checks
the SVG cell by cell against the banner.

No external material is incorporated. Omarchy's SDDM and Plymouth themes were consulted as idea references only
(revision `1801adc1983b06f6ab218f8060e430cb3477d8d0`); no Omarchy asset is copied.

## Shared symbol

`mirroros-symbol.svg` is original MirrorOS material, derived cell-for-cell from
[`install/confirmation/symbol.txt`](../../../install/confirmation/symbol.txt) under
[ADR 0019](../../../docs/adr/0019-shared-symbol-and-live-splash.md) and interview DEC-001/002/005.
Each terminal cell occupies 1x2 units in a square 16x16 view box. Full-block runs become path segments;
foreground is `#CACCCC` on transparent background, without text or a runtime font dependency.
The historical banner and graphical wordmark remain unchanged. An exact-cell contract checks the symbol.
The symbol introduces no external material or new attribution obligation.

## Delivery

| Item | Location | Owner |
|---|---|---|
| Historical source | `/usr/share/mirroros/branding/mirroros-wordmark.svg` | MirrorOS, tracked tree |
| Historical raster | `/usr/share/mirroros/branding/mirroros-wordmark.png` | MirrorOS, rendered by configure |
| Symbol source | `/usr/share/mirroros/branding/mirroros-symbol.svg` | MirrorOS, tracked tree |
| Symbol raster | `/usr/share/mirroros/branding/mirroros-symbol.png` | MirrorOS, rendered by configure |
| Delivery record | `/usr/share/mirroros/branding/.mirroros-manifest` | MirrorOS |

`librsvg` from `extra` provides `rsvg-convert`. The step renders the PNG with the installed renderer through
`cfg_exec` (inside the target in target context), at 1580x320 pixels: 20 pixels per unit, so every block edge stays
on a pixel boundary and consumers only scale it down. The symbol is rendered at 320x320, also 20 pixels per unit.
Generated PNGs are never committed.

The render identity includes both SVG SHA256 digests, the `rsvg-convert` version and both sizes. It is recorded in the manifest and
as `mirroros-branding` in `sources.tsv`. A rerun with the same identity renders nothing; a new source, renderer
version or size renders and republishes both assets. Intact previous wordmark-only deliveries migrate; manifest
integrity is checked before migration so local edits remain protected. `install-assets` verifies both staged
sources and PNG signatures and sizes before an atomic
exchange, so a failed or interrupted rendering keeps the previous complete tree and fails the step; leftover
staging (`/usr/share/mirroros/.branding.mirroros-staging`) is removed by the next rendering. An edited, unknown or
linked destination is never overwritten: the step reports the conflict and fails.

ADR 0019 selects the symbol PNG for the static SDDM theme of [`desktop/login`](../../desktop/login/sources.md)
and both consumers of the shared [`system/boot-splash`](../../system/boot-splash/sources.md) Plymouth theme.
Consumer adoption and live preparation are separate implementation tasks; installed boot-image identity must
include the symbol so changed delivery regenerates images once. Live preparation uses captured sources and
container librsvg, not host rendering or configure on live. Static rendering tests do not qualify actual
Plymouth, greeter, rebuilt-ISO, or physical-hardware behavior.
