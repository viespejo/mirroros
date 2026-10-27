# ADR 0017: Live Console Display Preference

## Identifier and title

- **Identifier:** `0017`
- **Title:** Live Console Display Preference

## Status

`Accepted`

## Date

`2026-10-26`

## Context and question

The guided installer's kernel-default 8x16 console font is difficult to read on a 14-inch 1920x1080
ThinkPad T14s Gen 1 AMD panel. Doubling the original font preserves the wordmark but leaves only 33 rows
at 1080p, displacing the logo on the review screen. Intermediate Terminus fonts change the preferred
letter forms. Should the live medium prefer a lower display mode without imposing that mode on the
installed system or making an unsupported universal-display guarantee?

## Constraints and decision criteria

- Keep the existing text wordmark, console palette, Gum screens, and installation safety boundaries.
- Use native kernel and boot-loader mechanisms; add no graphics stack, display daemon, font generator,
  or runtime modesetting helper.
- The preference belongs only to the live medium. Installation plans, installed boot entries, configure's
  splash overlay, desktop and greeter monitor rules remain independent and unchanged.
- Preserve a boot-menu recovery path that does not request a display mode.
- Do not claim that a requested mode is supported, applied, or legible on every display.

## Alternatives considered

1. **Keep only the firmware/kernel display choice.** Minimal but reproduces the observed small text.
2. **Double the original font by default.** Preserves glyphs but reduces both rows and columns too far
   for the current review layout; not selected as the default.
3. **Use Terminus or create a 12x24 variant of the original font.** Changes letter forms or introduces
   maintained font assets and resampling; not selected.
4. **Force 720p on every connector and on the installed system.** Overreaches the evidence and ownership
   boundary; rejected.
5. **Best-effort live 720p request with explicit native-display recovery (selected).** Keeps the default
   font policy and improves apparent text size where the driver and panel can provide the mode.

## Evidence

- The maintainer booted the existing MirrorOS development ISO directly from USB on a ThinkPad T14s
  Gen 1 AMD Ryzen 7 PRO. `showconsolefont -i` reported `8x16x256` and the framebuffer virtual size was
  `1920,1080` before the display experiment.
- The artifact was `mirroros-2026.10.26-x86_64.iso`, SHA-256
  `945dbe0fbd3ce82984c266bf49ad6a872426c40fde0ed86efab8907277ac3cff`.
- After a one-boot, connector-specific `video=eDP-1:1280x720` request (the suggested frequency-qualified
  form was `video=eDP-1:1280x720@60`), the maintainer reported comfortable text and a satisfactory review
  screen. The exact command line and effective post-change framebuffer mode were not captured. No
  installation was required for this presentation observation.
- This is exploratory attended evidence, not qualification of the new connector-independent default,
  a rebuilt artifact, the reference VM, all warning/error combinations, or another physical target.
- The installed Omarchy desktop on that laptop used 1920x1080 with scale 1.6. Desktop scaling does not
  apply to a Linux VT. The maintainer also found the Omarchy 4.0.4 live menus small; they do not establish
  a more legible console policy.
- Linux documents `video=` mode requests and optional connector/force suffixes. A mode request is not
  a userspace availability check or a guarantee of automatic fallback.

## Decision

The default live boot entry requests `video=1280x720`, without a connector name, refresh-rate constraint,
CVT/reduced-blanking flag, force-enable suffix, `nomodeset`, or driver blacklist. This is a best-effort
preference handled by the kernel and graphics driver, not an enforced mode or an assertion that 720p is
advertised. It is not restricted to `Virtual-1` or `eDP-1`, and may affect multiple connected displays.

A second entry, **MirrorOS Live/Rescue - native display**, boots the same kernel and initramfs with the
same live-root parameters but no MirrorOS `video=` request. Here "native display" means preserving the
firmware/kernel choice, not a guarantee that firmware selected the panel's native resolution. This entry
is the explicit recovery path if the preference is unavailable, ignored, distorted, or blank. No automatic
fallback is promised. Both entries remain visible in the boot menu.

Apply the pair to systemd-boot and the retained GRUB configurations, preserving their existing live-root
and loopback arguments. The qualified boot scope remains UEFI/OVMF through systemd-boot; retaining GRUB
configuration does not qualify Ventoy or introduce a new supported boot path.

The live medium still sets no persistent console font. The install procedure documents optional temporary
`setfont -d default8x16` and `setfont -R` commands for a live VT and requires restarting the assistant to
redraw after a font change. Large text is not a new default or a guarantee that all screens fit.

This decision supersedes only ADR 0014's consequence that the live medium keeps its current boot visuals,
to the extent needed for the display-mode request and recovery entry. Its package list and all installed
presentation boundaries remain unchanged. ADR 0006's kernel-default font policy remains in force.

## Consequences and trade-offs

- At an effective 1280x720 with an 8x16 font the VT has approximately 160 columns and 45 rows, between
  native 1080p text and a doubled font. This does not guarantee fit for arbitrary warnings or long values.
- Non-native modes can lose sharpness, stretch, be rejected, or be ignored. The native-display entry is
  available without editing punctuation-sensitive kernel arguments.
- The boot menu itself is rendered before the kernel request and need not become larger.
- There is no display-derived field in a plan or approval, and no new installed kernel parameter.
- Future Archiso merges must preserve both entries and their identical non-display arguments.

## Replacement or reversal boundary

Revisit through an ADR if the preference regresses boot or diagnostics, if tested panels require a
capability-aware selector, if legibility needs responsive screen layouts, or if the requested scope expands
to installed boot or graphical sessions. Do not silently add forced modes or copy live parameters into
installed boot policy. Selecting the native-display entry reverses the request for one boot.

## Required validation

- Static contracts check the default request, native-display recovery, identical non-display boot
  arguments, unchanged font setup, and absence of the new request from installed-system policy/code.
- Before artifact promotion, build and boot the new ISO in UEFI/OVMF, exercise both entries, record actual
  connector modes, framebuffer size and font dimensions, and inspect all installer screens including
  review, long values, warnings and errors. Exercise cancellation without disk writes.
- Exercise a display where the requested mode is unavailable or ignored, and verify the native-display
  recovery path. Do not infer this from static tests or the ThinkPad's accepted mode alone.
- Repeat the default-entry and recovery observation on physical hardware. Keep the ThinkPad experimental;
  this decision does not expand the architecture's qualification boundary.
- Builds, VM launches, and physical installation still need their normal separate authorization. No such
  run is authorized merely by this ADR.

## References

- [Architecture](../architecture.md)
- [ADR 0006](0006-guided-live-installation-boundaries.md)
- [ADR 0014](0014-native-login-and-boot-presentation.md)
- [Install procedure: live display](../procedures/install.md#live-display-and-text-size)
- [Archiso upstream record](../../image/archiso/UPSTREAM.md)
- [Linux mode requests](https://docs.kernel.org/fb/modedb.html)
- [setfont manual](https://man.archlinux.org/man/setfont.8.en)

## Superseded by

[ADR 0018](0018-native-live-display-and-installer-presentation.md) supersedes this decision in full: the live medium no longer requests 720p and the installer offers temporary text sizing.
