# Shared native GTK3 resources

## Osaka Jade source and license

The maintainer accepted Osaka Jade GTK3 in an isolated laboratory FileChooser portal preview on 2026-11-13,
then approved preparing GTK3 alongside GTK4 in `feat/gtk4-theme`, without global activation or reconciliation
with the pending main Strata/portal work yet.

The source is [Osaka Jade](https://github.com/abhinav20sep/osaka-jade-theme/tree/2ac2934f2ebf62ad1088bc5ea434c4670b8cd2dc/Osaka-Jade/gtk-3.0),
commit `2ac2934f2ebf62ad1088bc5ea434c4670b8cd2dc`, from the same GitHub archive already used for GTK4.
Archive SHA-256: `6084a8c78a584ad64004eef49f3972aec85719e41a0037fa6aea4959c5996135`.
The archive digest and PAX commit comment were verified locally before incorporation. The CSS and every asset
were compared byte for byte against entries read directly from that archive.

Only `Osaka-Jade/gtk-3.0/gtk.css` and its complete 126-file `assets/` directory are incorporated. Upstream's
`gtk-dark.css` is byte-identical to `gtk.css`; our dark entry imports the ordinary entry instead of duplicating
it. No GTK2 theme, XFCE decoration, application icon pack, wallpaper or upstream installer is incorporated.
GTK3's widget assets are part of the theme, not an application icon overlay; their names and bytes are retained.

Upstream declares the inherited Ubuntu Yaru theme software under GPL-3.0 and artwork under CC BY-SA 4.0.
The MIT notice explicitly excludes the Yaru-derived theme/artwork from MIT-only coverage. All four notices are
retained unchanged with the runtime, as for GTK4. This records upstream's declaration, not an independent
per-asset authorship/license audit.

| Source file | Delivered path | SHA-256 |
|---|---|---|
| `Osaka-Jade/gtk-3.0/gtk.css` and identical `gtk-dark.css` | `base.css`, color-token adaptation | `44a62ba35af01c67ae163fe400e882dac001efc165e3ae84b075416b0dd7ea5a` (original) |
| `AUTHORS.yaru` | `licenses/AUTHORS.yaru` | `eb5e3c27ba894f34d2cab78093fb1bf54cfba7da29e5febf70416e67584db30b` |
| `COPYING.yaru` | `licenses/COPYING.yaru` | `cb4392586efcf6ade8315f08e392b3eaf2ab37565f3c6ce8ef03aa3d76ed23ff` |
| `LICENSE_CCBYSA.yaru` | `licenses/LICENSE_CCBYSA.yaru` | `7a8af68d18de818e54697230278c0ade42e6bac15d4116ef9560f74176431118` |
| `LICENSE` | `licenses/LICENSE.osaka-jade` | `5ce556535ed37e7061075c5ec86afc07a5199c804db70b1814795e7002980129` |

The SHA-256 of the sorted `<file SHA-256>  <relative filename>\n` asset inventory is
`6af5d41a81db3d34cecde09fe4b44bf89fa79ffb29edda15e415b241ca4899d1`. Tests guard this inventory and all CSS URLs.
No MirrorOS headers are added to unchanged upstream assets or notices.

## Adaptations and typography

- `base.css` adds a modification notice and replaces 211 literal declaration colors with stable first-use
  `mirroros_osaka_gtk3_NNN` tokens. Their exact values live in `../theme/default/gtk-3.0.css`; expanding those
  tokens and removing the added header reconstructs upstream byte for byte. Selectors, sizing, state rules,
  images and intrinsic artwork colors are otherwise untouched. GTK4's tokens and styles remain unchanged.
- The GTK3 entry imports the fixed reviewed palette, Osaka base, then `typography.css`. The dark entry loads
  that same cascade, matching upstream's identical variants. High-contrast and arbitrary theme compatibility
  are not implied by a dark entry.
- `typography.css` retains exactly the GTK4 family stack and 13px sizing, adapted from Strata v1.2.1,
  commit `491e6ba9735e821f9f49910ffd2582076196865c`, `src/style.css` and `src/ui/theme/font.rs`.
  The MIT notice, Copyright (c) 2026 LGSE Ltd., is retained as `STRATA-LICENSE`, SHA-256
  `9f7b0c37b47dc21925dae3176ebb065c4a8581331fbacb1ca939acc23a82a640`.
  The inspected source hashes and font provenance are in [GTK4 sources](../gtk4/sources.md#strata-typography-source).
  A consistency test keeps the two typography files aligned. No pavucontrol adapter is imported into GTK3.

This is another native CSS/palette consumer within the existing configure and visual-resource boundaries
(ADR 0010), not a new configuration framework or session-selection mechanism. It requires no new ADR for
resource preparation. The later global-selection mechanism retains its separate decision and qualification
gates; see the [GTK3 procedure](../../../docs/procedures/gtk3-theme.md).

## Ownership and delivery

- `visual/gtk3` publishes `/usr/share/mirroros/gtk3` after `visual/theme` and `visual/gtk4`. The runtime has no
  `theme.name`, is not a selectable palette and has no lookup entry of its own; the native entry below is GTK's.
- `entries/<theme>/` (`gtk.css`, `gtk-dark.css`) is published, outside the runtime tree, as the manifest-checked
  native entry `/usr/share/themes/MirrorOS-<theme>/gtk-3.0`, importing `/usr/share/mirroros/themes/<theme>/gtk-3.0.css`
  and the installed `base.css` and `typography.css`. Only `MirrorOS-default` exists. `desktop/portal` selects it as
  the system dconf `gtk-theme` default shared with GTK4; a user value takes precedence. Modified, unknown or linked
  entries are conflicts.
- `visual/theme` owns `/usr/share/mirroros/themes/default/gtk-3.0.css`. Configure publishes static reviewed CSS;
  it does not extract, generate or rewrite styles at runtime.
- The bounded publisher follows GTK4's staged manifest contract: root-owned installed resources, directories
  0755 and ordinary files 0644, atomic replacement of intact deliveries, idempotency and preservation of
  unknown, modified, incomplete, linked or unsafe deliveries in both running and target contexts.
- `apply`, `packages`, `install-runtime` and this record are excluded from runtime. Configure records the
  manifest digest, Osaka revision and Strata typography revision. The resource step adds no packages;
  consumers own their GTK dependency, and the terminal capability already declares the Nerd Font package.
- No application launcher, icon overlay, user GTK CSS/settings, dconf database, portal configuration, service
  action or global environment variable is introduced. The neutral-check policy stays with the existing
  GTK4 integration work, not a duplicate GTK3 publication owner.

## Laboratory evidence and limits

The approved raw-upstream preview used GTK 3.24.52 and xdg-desktop-portal-gtk 1.15.3 on a private D-Bus bus.
A persistent temporary Gio client invoked public `org.freedesktop.portal.FileChooser.OpenFile`; the resulting
window was `Osaka Jade GTK3 - Portal preview` in workspace 3. The backend's allowlisted environment confirmed
`GTK_THEME=Osaka-Jade` and temporary XDG homes. Native Adwaita icons and the shared font stack at 13px were used;
`fc-match 'JetBrains Mono'` resolved Noto Sans Mono, not JetBrains. No CSS parsing diagnostic was observed.

VM fixture: `/tmp/mirroros-osaka-gtk3-portal.gmZedAHn`. The original session portal PIDs remained active, its theme
remained Adwaita and the user manager had no global `GTK_THEME`. Private-bus startup produced additional
activated portal processes plus missing-parent, RealtimeKit and GVfs warnings; this does not qualify routing,
accessibility or filesystem/network integration. The user approved appearance, not broad GTK3 coverage.

The preview predates product palette extraction. A later temporary copy of the product runtime, changing only
the fixed palette import to its fixture path, loaded both `gtk.css` and `gtk-dark.css` under GTK 3.24.52 with
zero parsing diagnostics. VM fixture: `/tmp/mirroros-gtk3-product.egeo7BSj`; host transcript:
`/tmp/mirroros-gtk3-product-parser.log`. This is a windowless provider check, not product-source graphical or
installed-path acceptance.

Host validation passed 377 capability Node tests with 33 skips, plus 148 Bats contracts with one existing
Tmux-version skip across the focused and broader suites. ShellCheck, authored whitespace checks and a focused
Gitleaks scan passed. Original upstream whitespace in the base and notices is retained. Full commands and the
initial background signal-test limitation are recorded in the procedure.

Installed paths, system-native theme lookup, effective portal defaults, user overrides, dark/high-contrast
behavior, GTK4/Strata and libadwaita non-interference, recovery and clean rebuilt-candidate qualification remain
separate checks. No full configure, product installation, global activation, merge or commit was part of this preparation.
