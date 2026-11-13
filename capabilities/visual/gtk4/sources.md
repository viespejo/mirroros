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
(ADR 0026), not a new provider, configuration framework or session-selection mechanism. Global activation and
its separate decision/qualification gates remain pending; see the [procedure](../../../docs/procedures/gtk4-theme.md).

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
  It has no `theme.name`; native lookup name `MirrorOS` is independent of palette identity.
- `visual/theme` owns colors at `/usr/share/mirroros/themes/default/gtk-4.0.css`, including the retained general
  roles tied to `colors.toml` and the exact Osaka color tokens. Configure does not generate or rewrite CSS.
- `install-runtime` retains complete staged manifests, owner/mode checks, conflict preservation and idempotency
  in both configure contexts. Root owns the installed tree; directories/executables are 0755, other files 0644.
  Unknown, linked, unsafe, incomplete or locally modified deliveries are refused, not silently replaced.
- `apply`, `packages`, `install-runtime` and this record are delivery inputs, excluded from runtime. Configure
  records the runtime manifest digest, Osaka commit and Strata typography revision; it adds no packages.
- No product installation or complete configure was performed for this adoption. Reconcile with main before
  installation; do not roll back the VM's newer portal/Strata configuration with this branch's baseline.

## Transitional launcher and icons

The compatibility launcher remains `/usr/share/mirroros/gtk4/launch`, admitting only pavucontrol and an installed
GTK Widget Factory. It forwards argv/stdin and `exec` preserves child status. It never closes existing instances;
single-instance forwarding may retain an earlier process's appearance. It preserves real application preferences,
HOME, XDG homes, session bus and graphical context; only process-local `GTK_THEME=MirrorOS` and a prepended
`XDG_DATA_DIRS` are set. Root ownership, safe ancestors, required CSS and the complete runtime tree are checked
before launch, and the launcher admits only the resolver's default palette, the one its entry point imports. These are point-in-time permission
checks, not a sandbox or content-integrity guarantee against privileged edits. Normal user CSS/data still apply.

Its retained application-alias overlay is transitional, not the approved final icon policy. The eight original
MirrorOS drawings, 25 aliases and neutral check remain under GPL-3.0-only; no upstream Osaka/Yaru application
icons are imported. The overlay has no copied Adwaita index/cache or packaged theme tree. Standard/unknown names
retain native fallback. Names and trademarks imply no endorsement.

The approved default remains native application icons with only the three neutral `emblem-default` SVG variants
shared in supported Adwaita lookup, without overwriting packaged files. The accepted Osaka preview used that
single-check overlay, not the launcher's full alias set. Global check publication and removal of the mandatory
launcher dependency await reconciliation with main's portal owner; optional per-application icon launchers remain
deferred. Theme selection and icon policy are separate work, not implicitly activated by adopting Osaka.

## Validation and limits

The maintainer preferred Osaka after attended pavucontrol and GTK Widget Factory comparison, then accepted the
pavucontrol-only checked-toggle override. The raw theme with shared typography parsed without observed CSS
diagnostics in the temporary VM previews. This does not establish universal state, accessibility, scaling or
application coverage. Product-source palette extraction, scoped selectors and delivered paths require their own
checks; tests cover upstream reconstruction, assets/notices, cascade, launcher and publication contracts.

The previous base's page-by-page review and parser checks are historical, not qualification of Osaka. The earlier
single-check probes remain lookup evidence: each GTK3/GTK4 run passed 24 check lookups and 336 unchanged unrelated
paths. Those probes preceded the separate GTK3 resource preparation; they do not validate its stylesheet.
No libadwaita adaptation is introduced. Installed paths, real session defaults and user
overrides, GTK3 dark/high-contrast behavior, Strata and libadwaita runtime non-interference, recovery, clean rebuilt-candidate
and physical-target qualification remain open gates. No daemon, hot reload, forced process restart, copied user
configuration or Python product runtime is added.
