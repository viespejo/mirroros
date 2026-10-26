# Branding sources and ownership

## Wordmark

`mirroros-wordmark.svg` is MirrorOS-owned material: a font-independent graphical adaptation of the block-letter
wordmark in [`install/confirmation/banner.txt`](../../../install/confirmation/banner.txt) (DEC-003 of the
[greeter and Plymouth interview](../../../docs/technical-interviews/greeter-plymouth_log.md)). Each terminal cell
becomes a 1x2-unit cell: `█` fills both halves, `▀` the upper and `▄` the lower; horizontally adjacent filled halves
are merged into one path segment. Trailing spaces are not part of the 79x16 view box. The silhouette is unchanged;
the banner itself is not modified. The fill is the lock screen's off-white `rgb(202, 204, 204)`; there is no
background, text, font, shadow or animation, so each theme supplies its own background. The branding test checks
the SVG cell by cell against the banner.

No external material is incorporated. Omarchy's SDDM and Plymouth themes were consulted as idea references only
(revision `1801adc1983b06f6ab218f8060e430cb3477d8d0`); no Omarchy asset is copied.

## Delivery

| Item | Location | Owner |
|---|---|---|
| Source | `/usr/share/mirroros/branding/mirroros-wordmark.svg` | MirrorOS, tracked tree |
| Raster | `/usr/share/mirroros/branding/mirroros-wordmark.png` | MirrorOS, rendered by configure |
| Delivery record | `/usr/share/mirroros/branding/.mirroros-manifest` | MirrorOS |

`librsvg` from `extra` provides `rsvg-convert`. The step renders the PNG with the installed renderer through
`cfg_exec` (inside the target in target context), at 1580x320 pixels: 20 pixels per unit, so every block edge stays
on a pixel boundary and consumers only scale it down. The generated PNG is never committed.

The render identity is the SVG SHA256, the `rsvg-convert` version and the size. It is recorded in the manifest and
as `mirroros-branding` in `sources.tsv`. A rerun with the same identity renders nothing; a new source, renderer
version or size renders and republishes. `install-assets` verifies the PNG signature and size before an atomic
exchange, so a failed or interrupted rendering keeps the previous complete tree and fails the step; leftover
staging (`/usr/share/mirroros/.branding.mirroros-staging`) is removed by the next rendering. An edited, unknown or
linked destination is never overwritten: the step reports the conflict and fails.

Consumers: the SDDM theme of [`desktop/login`](../../desktop/login/sources.md) reads the PNG; the Plymouth theme of
[`system/boot-splash`](../../system/boot-splash/sources.md) reads it through its `ImageDir`, so a new PNG regenerates
the boot images once.
