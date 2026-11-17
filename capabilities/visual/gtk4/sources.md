# Shared native GTK4 resources

## Osaka Jade source and license

The maintainer selected [Osaka Jade](https://github.com/abhinav20sep/osaka-jade-theme/tree/2ac2934f2ebf62ad1088bc5ea434c4670b8cd2dc/Osaka-Jade/gtk-4.0)
for native GTK4 after comparing isolated pavucontrol and three-page GTK Widget Factory instances on 2026-11-13.
The pinned commit is `2ac2934f2ebf62ad1088bc5ea434c4670b8cd2dc`. It was obtained from GitHub's `main` archive;
the archive's PAX commit comment identifies that revision. Archive SHA-256:
`6084a8c78a584ad64004eef49f3972aec85719e41a0037fa6aea4959c5996135`.

Only `Osaka-Jade/gtk-4.0/gtk.css` and its complete 182-file `assets/` directory are incorporated.
The identical upstream `gtk-dark.css` is not duplicated. This runtime incorporates no GTK2/GTK3 theme,
XFCE decoration, icon pack, wallpaper, terminal configuration or upstream installer.
GTK3 is now prepared separately by [visual/gtk3](../gtk3/sources.md), using the same Osaka revision and
shared typography; that resource addition does not activate either toolkit globally.

Upstream identifies the GTK theme and artwork as derived from Ubuntu Yaru under GPL-3.0 and CC BY-SA 4.0,
not under the repository's MIT license alone. Preserve both inherited license texts and the author list.
The upstream top-level MIT notice, including its explicit Yaru exception, is also retained unchanged.
This records upstream's license declaration, not an independent per-asset authorship/license audit.

| Source file | Delivered path | SHA-256 |
|---|---|---|
| `Osaka-Jade/gtk-4.0/gtk.css` | `base.css`, color-token adaptation | `b6496357400b151588e63aab6048d5b998083aa7a6cf9db60b26ce83f1d52596` (original) |
| `AUTHORS.yaru` | `licenses/AUTHORS.yaru` | `eb5e3c27ba894f34d2cab78093fb1bf54cfba7da29e5febf70416e67584db30b` |
| `COPYING.yaru` | `licenses/COPYING.yaru` | `cb4392586efcf6ade8315f08e392b3eaf2ab37565f3c6ce8ef03aa3d76ed23ff` |
| `LICENSE_CCBYSA.yaru` | `licenses/LICENSE_CCBYSA.yaru` | `7a8af68d18de818e54697230278c0ade42e6bac15d4116ef9560f74176431118` |
| `LICENSE` | `licenses/LICENSE.osaka-jade` | `5ce556535ed37e7061075c5ec86afc07a5199c804db70b1814795e7002980129` |

Assets retain their upstream bytes and filenames, without MirrorOS headers. The SHA-256 of the sorted
`<file SHA-256>  <relative filename>\n` inventory is
`7e66311c847d7860b96de009a6ee281efdf35fba667fb6c5e11c8f0183f53514`; tests check the inventory and all CSS URLs.

### Adaptations

- `base.css` marks the modification and preserves upstream CSS except for literal declaration colors replaced
  by 114 stable `mirroros_osaka_NNN` tokens. Their exact original values, in first-use order, are in
  `../theme/default/gtk-4.0.css`. Expanding the tokens and removing the added header reconstructs the original
  stylesheet byte for byte; a hash test guards this invariant. Semantic colors, swatches, selectors, sizing,
  effects and image references are not rewritten. Assets' intrinsic colors remain upstream artwork.
- The entry imports the reviewed palette, Osaka base, `typography.css`, then `apps/pavucontrol.css`.
  It no longer imports GTK's `Default-dark.css` or the superseded MirrorOS control/focus/chrome layers.
  The old custom Configuration-footer spacing is not applied to Osaka.
- `typography.css` retains the reviewed JetBrains Mono / JetBrainsMono Nerd Font / monospace stack and 13px
  window/popover sizing, selectively adapted from Strata as described below.
- `apps/pavucontrol.css` is original MirrorOS CSS scoped to `window.pavucontrol-window button.toggle`.
  It gives checked, enabled buttons the approved jade fill/border, a lighter hover, and a persistent unfocused
  selection. It does not change unchecked or disabled states, icon names, audio actions or Widget Factory.
  pavucontrol 6.2 `src/devicewidget.ui`, `src/streamwidget.ui`, `src/devicewidget.cc` and `src/mainwindow.cc`
  were inspection references, not copied code. Mute and lock are frameless toggles with fixed images; default
  has a frame. Osaka's later `button.flat:backdrop` rule otherwise clears the selected flat-button background.

This is a routine visual resource replacement within the existing native GTK4 and advanced-audio boundaries
(ADR 0026), not a new provider, configuration framework or session-selection mechanism. The session default is
selected separately, as described under [Native lookup entry](#native-lookup-entry); see the
[procedure](../../../docs/procedures/gtk4-theme.md).

## Native lookup entry

`entries/<theme>/` is published, outside the runtime tree, as the manifest-checked native entry
`/usr/share/themes/MirrorOS-<theme>/gtk-4.0`. Its `gtk.css` imports `/usr/share/mirroros/themes/<theme>/gtk-4.0.css`
and the installed `base.css`, `typography.css` and `apps/pavucontrol.css`.
Its `gtk-dark.css` imports `gtk.css`: with the dark `color-scheme` default GTK 4.24 loads that variant and,
without it, falls back to Adwaita's dark stylesheet (observed on the VM; the former launcher's `GTK_THEME` hid this).
Only `MirrorOS-default` exists. `desktop/portal` selects it as the system dconf `gtk-theme` default, so native
GTK4 applications use it without `GTK_THEME`; a user `gtk-theme` value takes precedence. Modified, unknown or linked
entries are conflicts. The naming rule is recorded in [theme sources](../theme/sources.md).

## Native icon theme

`icons/<theme>/` is published, outside the runtime tree, as the manifest-checked native icon theme
`/usr/share/icons/MirrorOS-<theme>`, with its manifest at the theme root (GTK ignores it). It contains:

- an original `index.theme` (`Inherits=Adwaita,hicolor`; `16x16/status`, `scalable/status` and `symbolic/status`
  with the same sizes and types as the packaged Adwaita 51 index, plus scalable `places`, `mimetypes`, `devices` and `apps`);
- the three neutral `emblem-default` SVG variants, the reviewed original MirrorOS drawing, identical in every
  variant (GPL-3.0-only); Adwaita 51 has no `emblem-default`, so the replaced check is AdwaitaLegacy's PNG;
- 14 folder, 30 file-type and 26 device icons and their `licenses/`, generated from pinned upstream sources with
  the theme's palette, as described under [Generated icon sources](#generated-icon-sources);
- 97 application icons and the Papercraft notices described under [Application icons](#application-icons).

Every other name, including other symbolic icons and emblems other than the check, resolves
through Adwaita exactly as before. No packaged file or Adwaita index is copied or overwritten, and no application
icon alias is shared globally. Only `MirrorOS-default` exists. `desktop/portal` selects it as the system dconf
`icon-theme` default; a user `icon-theme` value takes precedence and then drops all of these icons. Modified,
unknown or linked trees are conflicts.

## Application icons

The maintainer authorized product integration after reviewing temporary Apps/GTK3/GTK4 previews in the reference
VM. `icon-sources/papercraft/` holds 86 byte-identical SVG templates from local Omarchy
`c0c63402abee6e8335f9bd3c6da85348b9269b11`, `icons/papercraft/` (MIT, David Heinemeier Hansson).
The one excluded upstream template is `printer.svg.tpl`: the existing MirrorOS device drawing keeps that name.
`papercraft-tools/omarchy-theme-color` and `omarchy-theme-icon-palette` are unchanged from the same revision.
`application-sources.sha256` pins the imported templates/tools and retained license texts. They are development
inputs only and are never published as session executables. Their color-role resolution and simple template
substitution reproduce the reviewed SVGs using `visual/theme/<theme>/colors.toml`.

`icon-sources/mirroros-apps/` contains eleven original MirrorOS templates (GPL-3.0-only), described as
Papercraft-inspired, not upstream artwork: CMakeSetup, LimineSnapperSync, io.github.lgse.Strata, org.gtk.Demo4,
org.gtk.PrintEditor4, org.gtk.WidgetFactory4, org.gtk.gtk4.NodeEditor, org.pulseaudio.pavucontrol, qv4l2, qvidcap and
stoken-gui. Pavucontrol has only three vertically expanded raised sliders, without a speaker or indicators.
The shared generator emits these and the 86 upstream icons into `icons/default/scalable/apps/`; GTK3, GTK4 and
Apps consume the same native theme resources. No desktop identity, launch command or association changes.

Foot's footprint is by Lennard Hofmann (CC BY-SA 4.0); Neovim's mark is by Jason Long (CC BY 3.0), as declared in
the retained template descriptions. The MIT license, both CC texts and `ATTRIBUTION.md` are distributed under
`icons/default/licenses/papercraft/`. The legal texts were retrieved from
https://creativecommons.org/licenses/by-sa/4.0/legalcode.txt and
https://creativecommons.org/licenses/by/3.0/legalcode.txt. These terms are retained; MirrorOS does not relicense
upstream artwork as GPL. Rendering applies the MirrorOS palette to upstream's adaptations. Every other name falls
back to the theme inheritance chain. The neutral check, folder, file-type and device SVGs are unchanged.

Validation uses `tests/capabilities/visual/gtk4/gtk4.test.mjs`: source digests, exact regenerated output, 97 app
resources, role colors, no unresolved placeholders, no printer collision, retained check digest and license
coverage. The first integration reproduced all 97 preview SVGs byte-for-byte apart from their generated provenance
comment. Reference-VM GTK3 3.24.52, GTK4 4.24.1 and the actual AppLibrary resolved all 97 names to the same
candidate SVGs without changing session preferences. Configure/publication contracts passed with unchanged
reruns and conflict protection. Attended visual review is not replaced by these checks; installation is pending.

### Default-device check limitation

The maintainer reported a black check in both toggle states in pavucontrol `1:6.2-2`. A read-only GTK4 probe in
the reference VM confirmed that the installed `emblem-default.svg` resolves as non-symbolic, whereas
`emblem-default-symbolic.svg` and adjacent `audio-volume-muted-symbolic`/`changes-prevent-symbolic` resolve as
symbolic. Thus the ordinary SVG's currentColor does not follow the widget's foreground. A temporary alias to
the symbolic file still resolved as non-symbolic under the ordinary name. Changing its static fill would not
provide state-dependent colors. A proposed toggle-image CSS preference was withdrawn; pavucontrol CSS and all
three check SVGs remain byte-identical. A correction must arrange for the consumer to request symbolic artwork;
no fix or graphical acceptance is claimed here.

## Generated icon sources

The maintainer approved on 2026-11-13, after attended review of a temporary VM prototype in the GTK3 file chooser,
palette-colored folder, file-type and device icons in the style of Strata's file browser, replacing Adwaita's
full-color blue folders. `icon-sources/lucide/` and `icon-sources/catppuccin/` hold only the upstream files used, unmodified, with their licenses;
`SHA256SUMS` lists each file's digest and a test checks it. It is a delivery input, excluded from every published tree.

| Project | Revision | License | Files |
|---|---|---|---|
| [Lucide](https://github.com/lucide-icons/lucide) | tag `1.35.0`, commit `a79d711591318eaced16eeb9bbc923d0128cc3a1` | ISC; icons derived from Feather under MIT, both in `LICENSE` | 33 SVGs from `icons/` |
| [Catppuccin VSCode Icons](https://github.com/catppuccin/vscode-icons) | tag `v1.26.0`, commit `b6915da9f6889b683a110aa747de96c2820a537d` | MIT | 20 SVGs from `icons/css-variables/` |

These are the revisions Strata v1.2.1 bundles. MirrorOS takes them from upstream, not from Strata's copies.

`icon-sources/generate.mjs` is development-time Node.js; configure never runs it, because `visual/gtk4` precedes
`workflow/node`. After changing a source, a mapping or the palette, run
`node capabilities/visual/gtk4/icon-sources/generate.mjs default` and commit the result. A test regenerates the
theme and fails on any difference, unlisted color or insufficient contrast. Each generated SVG starts with a comment
naming its source and license.

- Folders (`folder`, `folder-open`, the XDG user directories, `user-home`, `user-desktop`, `folder-remote`) use
  Lucide's folder: a plain outline with a 15% fill, or a 92% fill with a dark Lucide glyph. Devices use the
  plain Lucide outline. This composition (fill opacities, glyph `translate(5.5 6.8) scale(.54)`, stroke 2.7) is
  adapted from Strata v1.2.1 `src/assets.rs` (MIT, `licenses/STRATA-LICENSE`); no Strata code is copied.
- Folders and devices use `bright_blue`, not the accent: GTK3/GTK4 selected rows use the accent as background and
  an accent icon disappeared on them in the prototype. Catppuccin's color variables map only to light palette
  tones for the same reason. Every color must reach 4.5:1 against `background` and 1.5:1 against `accent`. The
  mid-tone accent limits the latter to about 2.4:1, so selected icons stay legible but low in contrast.
- `image-svg+xml` is not provided because the publisher's safe-name rule excludes `+`; GTK falls back to
  `image-x-generic`.

In practice these icons appear in GTK's built-in file chooser: GTK3 applications, GTK4 applications still using
`GtkFileChooserDialog`, and the `gtk` fallback of the portal FileChooser. GTK4 `GtkFileDialog` requests go through
the portal to Strata, which draws its own icons. They also appear wherever GTK applications show folder, file-type
or device icons, for example in pavucontrol's device list.

## Strata typography source

The family stack and font sizing are adapted from [Strata v1.2.1](https://github.com/lgse/strata/tree/491e6ba9735e821f9f49910ffd2582076196865c),
commit `491e6ba9735e821f9f49910ffd2582076196865c`, `src/style.css` and `src/ui/theme/font.rs`.
The MIT notice, Copyright (c) 2026 LGSE Ltd., is retained unchanged in `STRATA-LICENSE` and delivered with it.
The earlier selective form-control adaptation is superseded by Osaka; it is not layered onto the new base.

| Inspected source file | SHA-256 |
|---|---|
| `src/style.css` | `f18c53a2c7fba73f5ac816047642359223367950e457448cc4e569737b624b6d` |
| `src/ui/theme/font.rs` | `cb27afd01f716b877bc813c34d935210acc650ceb52a253097775c8d6b5bcb31` |
| `LICENSE` | `9f7b0c37b47dc21925dae3176ebb065c4a8581331fbacb1ca939acc23a82a640` |

The font uses packages already declared by the terminal capability. Laboratory `fc-match 'JetBrains Mono'`
resolved Noto Sans Mono, so the attended preview confirms the shared stack/fallback and 13px sizing, not that
JetBrains itself was installed or rendered there.

## Ownership and delivery

- `visual/gtk4` owns the implementation at `/usr/share/mirroros/gtk4`, published immediately after `visual/theme`.
  It has no `theme.name` and no lookup entry of its own; native entries are named after the theme directory.
- `visual/theme` owns colors at `/usr/share/mirroros/themes/default/gtk-4.0.css`, including the retained general
  roles tied to `colors.toml` and the exact Osaka color tokens. Configure does not generate or rewrite CSS.
- `install-runtime` retains complete staged manifests, owner/mode checks, conflict preservation and idempotency
  in both configure contexts. Root owns the installed tree; directories/executables are 0755, other files 0644.
  Unknown, linked, unsafe, incomplete or locally modified deliveries are refused, not silently replaced.
- `apply`, `packages`, `install-runtime`, `icon-sources/` and this record are delivery inputs, excluded from runtime.
  Configure records the runtime manifest digest, Osaka commit, Strata typography revision and the Lucide and
  Catppuccin revisions; it adds no packages.
- No product installation or complete configure was performed for this adoption. Reconcile with main before
  installation; do not roll back the VM's newer portal/Strata configuration with this branch's baseline.

## Removed launcher and application icons

The transitional `/usr/share/mirroros/gtk4/launch` (process-local `GTK_THEME=MirrorOS` and a prepended
`XDG_DATA_DIRS` icon overlay for pavucontrol and GTK Widget Factory), its nested `share/themes/MirrorOS` entry, the
`icon-aliases.json` overlay of eight original drawings under 25 application aliases and the resolver's `gtk4`
consumer were removed once the session `gtk-theme` and `icon-theme` defaults covered pavucontrol. The audio
panel's Advanced action now runs `uwsm app -- pavucontrol` as ADR 0026 states. Configure replaces the earlier
runtime tree as an ordinary manifest update.

The approved icon policy is native application icons plus the neutral check and the generated folder, file-type and
device icons from the [native icon theme](#native-icon-theme). The alias drawings remain in version history; shipping
application icons again, globally or per application, is a separate maintainer decision. Theme selection and icon policy are
separate work, not implicitly activated by adopting Osaka.

## Validation and limits

The maintainer preferred Osaka after attended pavucontrol and GTK Widget Factory comparison, then accepted the
pavucontrol-only checked-toggle override. The raw theme with shared typography parsed without observed CSS
diagnostics in the temporary VM previews. This does not establish universal state, accessibility, scaling or
application coverage. Product-source palette extraction, scoped selectors and delivered paths require their own
checks; tests cover upstream reconstruction, assets/notices, cascade and publication contracts.

The previous base's page-by-page review and parser checks are historical, not qualification of Osaka. The earlier
single-check probes remain lookup evidence: each GTK3/GTK4 run passed 24 check lookups and 336 unchanged unrelated
paths. Those probes preceded the separate GTK3 resource preparation; they do not validate its stylesheet.
No libadwaita adaptation is introduced. Installed paths, real session defaults and user
overrides, GTK3 dark/high-contrast behavior, Strata and libadwaita runtime non-interference, recovery, clean rebuilt-candidate
and physical-target qualification remain open gates. No daemon, hot reload, forced process restart, copied user
configuration or Python product runtime is added.
