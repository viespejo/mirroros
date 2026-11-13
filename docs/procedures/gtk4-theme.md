# Native GTK4 theme

## Scope

MirrorOS's native GTK4 theme styles native GTK4 applications through the session's system `gtk-theme` and
`icon-theme` defaults, first reviewed with pavucontrol from the audio panel's **Advanced…** action. It does not
change user GTK settings, portal routing, audio values, Strata or the desktop's global environment. GTK3 resources
are prepared in [the GTK3 procedure](gtk3-theme.md) and share the same default; libadwaita adaptation is not covered.
The shared bundle is independent of palette-specific colors; each published theme gets its own native entry.

[GTK4 sources](../../capabilities/visual/gtk4/sources.md) record licensing,
layout, icon ownership, laboratory approval and validation limits. This applies the existing native-theme and
advanced-audio boundaries; it adds no configuration framework, provider, service or resident theme manager.

## Selected GTK4 base: Osaka Jade

On 2026-11-13 the maintainer selected Osaka Jade over the earlier MirrorOS/Strata-derived control treatment after
isolated pavucontrol and GTK Widget Factory comparison. The selected revision is
`2ac2934f2ebf62ad1088bc5ea434c4670b8cd2dc` from `abhinav20sep/osaka-jade-theme`; only its GTK4 CSS and widget assets
are incorporated in this runtime. The later GTK3 resource addition uses its own owner; GTK2, application icons,
XFCE borders and installation scripts remain excluded.

The shared runtime now loads the palette, Osaka base, retained 13px typography, and a pavucontrol-only checked-toggle
adapter. Mute and channel-lock are frameless toggles with fixed images; the default-device tick is framed. The
approved adapter gives checked, enabled buttons a jade background/border and preserves selection when unfocused.
It does not change the audio actions or other applications' toggles. The previous custom control/focus/chrome
layers and Configuration-footer spacing are superseded, not stacked onto Osaka.

All 114 literal declaration colors remain palette-owned. Tests expand their stable tokens to reconstruct the
pinned upstream CSS byte for byte, and check all 182 unchanged assets and the retained Yaru/Osaka notices. The
inherited GTK4 theme/artwork is not MIT-only; see the detailed [sources record](../../capabilities/visual/gtk4/sources.md).
The typography stack is unchanged; the VM resolved `JetBrains Mono` to Noto Sans Mono during review, so actual
JetBrains rendering remains a separate installed-font check.

The accepted temporary previews used native application icons plus the neutral check. The compatibility
launcher's wider alias overlay was later removed with the launcher. No full configure, global theme activation, merge or commit
is authorized by the visual selection alone. Reconcile with main's portal/Strata work before installed delivery.
The prior base's page-by-page, popup and parser results below are historical, not qualification of Osaka.

## Ownership correction and approved session-default amendment

The shared implementation now belongs to `capabilities/visual/gtk4/`, published by its own `visual/gtk4` configure
step at `/usr/share/mirroros/gtk4/`, immediately after `visual/theme`. Palette colors remain in
`visual/theme/default/gtk-4.0.css`, published under `/usr/share/mirroros/themes/default/`. The shared bundle's
synthetic `theme.name` is removed; it is not a selectable palette and does not use the selectable-theme publisher.
Its own bounded publisher retains staged manifest verification, owner/mode checks, conflict preservation and
idempotency in both configure contexts. Delivery scripts and provenance are excluded from runtime publication.

The maintainer also approved making the native GTK4 theme the session default and globally sharing only the
neutral default-device check. The session default and the shared check are implemented as described in
[Session default](#session-default). The relocated compatibility launcher was then removed; shipping application
icons again, globally or per application, is a separate maintainer decision.

## Session default

`visual/gtk4` publishes the native entry `/usr/share/themes/MirrorOS-default/gtk-4.0/gtk.css` (and `visual/gtk3`
its `gtk-3.0/` sibling), importing the default theme's palette and the installed shared layers. Each entry also
has `gtk-dark.css` importing `gtk.css`: under the dark `color-scheme` default GTK loads the dark variant, and the
first VM candidate without it fell back to Adwaita's dark stylesheet in GTK4. `desktop/portal`
adds `gtk-theme='MirrorOS-default'` to its system dconf key file, next to the dark `color-scheme`, so the Settings
portal answers it unless the user sets a value. The name is `MirrorOS-<theme directory>`, the identifier used by
`current/theme` and the resolver; each future theme gets its own entry, and Story 4.8 theme selection changes the
link and the user's `gtk-theme` together. GTK reloads running applications when `gtk-theme` changes; the default
itself takes effect at the next login. No `GTK_THEME`, user dconf, user CSS or per-application launcher is used.

Configure checks the compiled default without a bus. Effective Settings answers at login, GTK3/GTK4 rendering in
the installed session, user overrides, dark/high-contrast behavior, Strata regression and libadwaita
non-interference have not been validated on the VM yet. To return a user's session to Adwaita without changing the
product default, run as that user `gsettings set org.gnome.desktop.interface gtk-theme Adwaita`; `gsettings reset
org.gnome.desktop.interface gtk-theme` restores the MirrorOS default.

The neutral default-device check is shared the same way. `visual/gtk4` publishes the native icon theme
`/usr/share/icons/MirrorOS-default` (an `index.theme` inheriting Adwaita and hicolor, plus the three reviewed
`emblem-default` SVG variants) and `desktop/portal` adds `icon-theme='MirrorOS-default'` to the same key file.
Every other icon name resolves through Adwaita as before; no application alias is shared globally and no packaged
icon file is overwritten. Any consumer requesting `emblem-default` in this theme gets the check, not only
pavucontrol. On 2026-11-13 a running configure of the lab candidate changed only `visual/gtk4` and `desktop/portal`;
the rerun left all 23 steps unchanged. Without a new login the Settings portal answered `icon-theme`
`'MirrorOS-default'`; windowless GTK 4.24.1 and GTK 3.24.52 probes in the session received that name, resolved
`emblem-default` and its symbolic name from `/usr/share/icons/MirrorOS-default` in 24 lookups each (sizes 16/24/32,
scales 1/2, ordinary/forced symbolic) and 444 other lookup paths identical to Adwaita. Qt 6.12 in the shell's
environment (no `QT_*` variables) uses `hicolor` and ignores this key, so the shell is unaffected. Rendering of
the check in installed applications other than the accepted pavucontrol preview has not been reviewed.
To return a user to the packaged icons, run as that user `gsettings set org.gnome.desktop.interface icon-theme
Adwaita`; `gsettings reset org.gnome.desktop.interface icon-theme` restores the MirrorOS default.

### Selection prototype

A non-privileged reference-VM probe on 2026-11-13 tested GTK 4.24.1 and GTK 3.24.52. It created no windows and
changed no real dconf value, portal configuration or product installation. Separate `dbus-run-session` buses
hosted a minimal Settings portal with a version property and controlled `ReadAll` answers. A temporary native
`settings.ini` requested MirrorOS in every scenario. The probe read `gtk-theme-name`, loaded that named CSS
provider and compared its serialized CSS SHA-256 with Adwaita's provider. This checks selection and provider
resolution, not rendering or application-specific precedence.

| Settings source | GTK4 result | GTK3 result |
|---|---|---|
| Real portal answering Adwaita | Adwaita; local `settings.ini` did not win | Adwaita |
| Private portal answering Adwaita | Adwaita | Adwaita |
| Private portal answering MirrorOS, temporary resource search path | MirrorOS; CSS differs from Adwaita; zero CSS diagnostics | MirrorOS setting, but resolved CSS equals Adwaita |
| Private portal answering MirrorOS, native theme entry and standard `XDG_DATA_DIRS` | MirrorOS; CSS differs from Adwaita; zero CSS diagnostics | MirrorOS setting, but resolved CSS equals Adwaita |

The native-entry fixture was under the temporary `XDG_DATA_HOME/themes/MirrorOS/gtk-4.0/` search location; its
single import referenced the temporary runtime stylesheet. Only the fixed palette import in the copied product
stylesheet was relocated; the reviewed style cascade and assets were unchanged. No GTK3 stylesheet was supplied.
This proves that an entry in GTK's normal theme lookup can resolve the shared CSS without prepending the icon
bundle to `XDG_DATA_DIRS`; final system-path publication and entry imports still require installed-path tests.
The real session's `gtk-theme` remained Adwaita afterward.

Implementation evidence is temporary: local fixtures and the final clean transcript are in
`/tmp/mirroros-gtk4-session-probe.pZHYOPVV/`, with VM fixtures in
`/tmp/mirroros-gtk4-session-probe.TMJc1DOz/`. An initial fixture without the portal's version property was rejected
by GTK4 and is not selection evidence. The final run used `GIO_USE_VFS=local`, private cache/data/state directories
and disabled accessibility bridges for the windowless probes; it establishes neither GVfs nor accessibility
readiness. No laboratory helper is product code.

### Mechanism constraints and remaining decision

- Prefer a native session theme selection plus a normal theme lookup entry, not global `GTK_THEME`. GTK documents
  that variable primarily as a debugging override. A plain GTK4 `settings.ini` is insufficient when the session's
  Settings portal supplies `gtk-theme-name`.
- Main's pending `desktop/portal` owns the dconf profile, database compilation and dark default. Reconcile with that
  owner before integration; do not copy its pending implementation or create a second profile/database owner.
  A system dconf `org/gnome/desktop/interface gtk-theme='MirrorOS'` default is the candidate to validate through
  the actual backend, with user values retaining precedence and no writes to user dconf.
- This key is shared with GTK3. The historical probe fell back to Adwaita because no GTK3 CSS was supplied.
  GTK3 resources are now prepared separately for the approved joint default, but not globally published or
  selected. Preserve and test user theme choices, dark variants and high-contrast behavior; the earlier
  Adwaita fallback result is not evidence for the new GTK3 stylesheet.
- Libadwaita is not installed in this VM. Source inspection indicates its style manager owns its theme provider
  when `GTK_THEME` is unset; runtime non-interference remains unverified. Do not use global user-priority `gtk.css`
  injection as a substitute for theme selection or promise libadwaita coverage.
- The maintainer approved a shared substitution of only `emblem-default` and its symbolic variant with the
  original neutral check. Keep native application icons by default. The other 25 aliases are not activated
  globally; the launcher that carried them was removed. The shared substitution may affect any
  consumer requesting that name, not only pavucontrol, and is scoped to the supported Adwaita lookup rather than
  overriding arbitrary user icon themes. Publish without overwriting packaged Adwaita files or copying its index.
  Normal GTK theme selection and icon publication remain separate concerns.
- Configure must retain staged, conflict-safe, root-owned, idempotent publication in both contexts; no session
  service/application is started or restarted. Native GTK lookup permits user theme overrides and does not execute
  the former launcher's per-process resource trust checks. Document that boundary rather than claiming otherwise.

Upstream inspection references: [GTK settings and precedence](https://github.com/GNOME/gtk/blob/4.24.1/gtk/gtksettings.c),
[Wayland Settings translation](https://github.com/GNOME/gtk/blob/4.24.1/gdk/wayland/gdksettings-wayland.c),
[native theme lookup](https://github.com/GNOME/gtk/blob/4.24.1/gtk/gtkcssprovider.c), and
[`GTK_THEME` documentation](https://docs.gtk.org/gtk4/running.html#gtk_theme).
Record the selected mechanism and any architecture-changing prototype constraints through the ADR process before
production activation. Graphical review, shared-check publication, installed-session launch coverage, libadwaita
checks, user overrides, recovery and clean rebuilt-candidate qualification remain open gates.

### Single-check icon prototype

A temporary overlay containing only three existing original SVGs was checked with GTK 4.24.1 and GTK 3.24.52:
`Adwaita/16x16/status/emblem-default.svg`, `Adwaita/scalable/status/emblem-default.svg` and
`Adwaita/symbolic/status/emblem-default-symbolic.svg`. Both icon names resolved to that overlay at sizes 16/24/32,
scales 1/2 and ordinary/forced-symbolic modes: 24 check lookups passed per toolkit. Forced-symbolic requests
returned symbolic assets. For each toolkit, 336 lookup paths for the 25 application/generic alias names and three
standard system icons were identical with and without the overlay, including matching missing-icon behavior.
This is lookup evidence, not a rendering or contrast guarantee for non-symbolic consumers.

The source and binaries are temporary VM fixtures under the selection-prototype root above
(`check-icon-probe.c`, `check-icon-probe-gtk3`, `check-icon-probe-gtk4`, `check-only/` and
`check-only-results.log`). A pavucontrol preview now uses the same three files under its temporary
`XDG_DATA_HOME/icons`, standard `XDG_DATA_DIRS`, the existing isolated laboratory application config and the
reviewed shared CSS. Only its verified predecessor laboratory process was replaced. The live PID is recorded in
`preview.pid`; recheck its executable, owner and isolated environment before any later action. Its log is
`preview-single-check.log`. No real audio value, user icon directory, system icon file or global theme setting was
changed. The maintainer visually accepted this neutral-check pavucontrol preview. Conflict-safe publication in the
standard system lookup directory and the per-user recovery are now described under [Session default](#session-default);
broader GTK3/GTK4 rendering checks remain open.

## Delivery and use

After integration with the current product baseline, run the normal [configure procedure](configure.md).
Three separately owned configure steps publish independently manifest-checked trees:

| Owner | Tree | Purpose |
|---|---|---|
| `visual/theme` | `/usr/share/mirroros/themes/default` | Reviewed palette, including `gtk-3.0.css`, `gtk-4.0.css` and existing consumers |
| `visual/gtk4` | `/usr/share/mirroros/gtk4` | Osaka CSS/assets/notices, typography and pavucontrol adapter |
| `visual/gtk3` | `/usr/share/mirroros/gtk3` | Osaka GTK3 CSS/widget assets/notices and matching typography |

The shared runtime has no palette identity file. Its font stack uses JetBrains already declared by the terminal
capability. Pavucontrol brings GTK4 and Adwaita from the official repositories; `visual/gtk4` adds no package.
The native entries and the icon theme are described under [Session default](#session-default).

Configure never launches or reloads an application. Close any existing pavucontrol window normally, then use
**Advanced…**, which runs, as the session user:

```bash
uwsm app -- pavucontrol
```

No environment variable or data path is added; the application follows the session defaults. Real application
preferences remain in their existing locations. An already running single-instance application may receive the
request instead and keep its earlier appearance; nothing kills or restarts it. Normal GTK user CSS, user data and
user `gtk-theme`/`icon-theme` values remain effective. An installed GTK Widget Factory is reviewed the same way,
by running `gtk4-widget-factory`; its package is not part of the product declaration.

GTK reloads running applications when `gtk-theme` or `icon-theme` changes; there is no forced hot reload or
restart. Adding arbitrary palette selection is separate work.

## Validation

Run from the repository root:

```bash
node --test tests/capabilities/visual/theme/*.test.mjs tests/capabilities/visual/gtk4/*.test.mjs \
  tests/capabilities/desktop/shell/audio-panel-model.test.mjs
bats tests/capabilities/visual/theme/configure.contract.bats tests/capabilities/visual/gtk4/configure.contract.bats
shellcheck capabilities/visual/theme/apply capabilities/visual/theme/prepare-parent \
  capabilities/visual/theme/resolve-current capabilities/visual/gtk4/apply \
  capabilities/visual/gtk4/install-runtime
```

The contracts cover separate publication owners, excluded delivery inputs, absence of a synthetic palette identity,
both configure contexts, idempotency, executable delivery, preservation of unknown/modified
resources and user settings, palette roles, upstream CSS reconstruction, asset/notice hashes, import order,
typography, pavucontrol-only checked/hover/backdrop selection, the native entries and icon theme, the absence of
the removed launcher and overlay, and the Advanced action's plain `uwsm app -- pavucontrol` command.
They do not prove installed-session rendering or clean-candidate readiness.

Osaka adoption verification passed on the integration worktree: all discovered capability Node tests produced
369 passes, 33 skips and no failures (402 total). Theme/GTK4 configure contracts passed all 15 cases, including
running/target delivery and unchanged reruns. The broader mechanism/target/theme/GTK4/shell contract run hit its
180-second harness limit after 136 completed cases with no failures; the remaining shell suite was rerun
separately and all seven cases passed. Across the completed suites this covers 140 passes and one pre-existing
Tmux-version skip, not a claim that the interrupted command itself succeeded. ShellCheck, `git diff --check` and
a focused Gitleaks scan of the GTK4 runtime passed. The publisher now permits `@` in safe filenames for upstream
HiDPI `@2.png` assets; a byte-preserving delivery test covers those names.

A temporary copy of the product resources, changing only the fixed palette import to its fixture path, loaded
with zero parsing diagnostics under VM GTK 4.24.1. This was a windowless provider check, not installed-path or
product-source graphical acceptance. The fixture is `/tmp/mirroros-osaka-product.GxNI5joG` in the VM; host logs are
`/tmp/mirroros-osaka-adoption-{all-node,configure,all-configure,shell-configure,gitleaks}.log`. The attended raw-Osaka
preview and the later product-source parser check are distinct evidence. No global activation, full configure,
merge or commit was performed.

Historical pre-Osaka ownership-correction host verification passed: all `tests/capabilities/**/*.test.mjs` discovered with `find`
produced 368 passes, 33 skips and no failures (401 tests total). The selected Bats suites were
`tests/capabilities/{mechanism,target}.contract.bats`, the theme and GTK4 configure suites above, and
`tests/capabilities/desktop/shell/configure.contract.bats`: 140 passes and one existing Tmux-version skip.
ShellCheck passed for the changed delivery/launch scripts; `git diff --check` and a focused Gitleaks scan of
`capabilities/visual/gtk4` passed. SHA-256 comparisons against the pre-relocation sources confirmed all 90 moved
CSS/SVG/license/alias resources unchanged; only the launcher's runtime path changed and the synthetic identity
was removed. Host logs are `/tmp/mirroros-gtk4-layout-node-tests.log` and
`/tmp/mirroros-gtk4-layout-configure-tests.log`, not product artifacts. No relocated product tree was installed
or executed in the VM during this ownership correction.

After merging and publication in the disposable VM:

1. Check configure's delivered manifests and the unchanged rerun; it must not start/restart any user application,
   portal or session service, write GTK settings, or change user theme/background links.
2. Close the earlier test application normally. Open pavucontrol through **Advanced…** without a privilege prompt.
   Confirm that the launched process has no `GTK_THEME` and no product path in `XDG_DATA_DIRS`, while HOME,
   XDG config/data/cache/state homes and the session bus remain the real session's values. Inspect only these
   allowlisted variables, never dump the full environment or personal preferences.
3. Review Playback, Recording, Output Devices, Input Devices and Configuration at rest and with UI-only hover,
   keyboard focus, selected and disabled states. Open and dismiss **Show**, **Port** and **Profile** without
   selecting another audio option. Do not toggle mute, default devices, profiles, latency or real audio values
   solely to test CSS. Check the popup's transparent outer allocation, rounded panel and separation above/below.
4. Confirm the approved checked-toggle fill/border at rest, hover and unfocused, the neutral default-device check,
   and a real stream's symbolic icon
   without launching unrelated applications or collecting personal content. The new check is original geometry;
   its laboratory appearance was accepted, but installed-path rendering still needs confirmation. Unknown names
   must retain native fallback.
5. If Widget Factory is installed, review Pages 1–3 and transient dialogs/popovers for regressions. Preserve
   sample color swatches and hue/alpha ramps. Check focus and hit targets, not merely removal of blue.
6. Repeat with the supported window sizes and display scales. A lookup at scale 2 does not establish optical
   alignment, contrast or every rendering state. Record failures honestly; the laboratory's pre-existing
   accessibility-bus warning prevents claiming AT-SPI or full focus qualification from a parser pass.

The superseded shared CSS was parsed successfully with GTK 4.24.1 in a relocated temporary fixture; 312 icon lookups passed
at sizes 16/24/32 and scales 1/2, in ordinary/forced-symbolic modes, with standard Adwaita fallback preserved.
These are product-source checks, not installation at the final paths. No Python helper or temporary test path is
part of product delivery. A rebuilt candidate and physical-target qualification remain separate gates.

## Conflict and recovery

Unknown, modified, incomplete or linked product deliveries are preserved and fail configure. Inspect the named
conflict and restore the last reviewed delivery or move it aside deliberately before rerunning; never delete
personal configuration to make a theme check pass.

To return a user to Adwaita and its icons, see [Session default](#session-default); applications started afterward,
including pavucontrol from **Advanced…**, follow that user value. Do not reconfigure portals or Strata, copy
laboratory settings into HOME, or kill processes by name.

## Integration with pending work

This change was developed in `feat/gtk4-theme` from `8a9ad72`, outside the dirty main checkout, and was later
rebased onto main's Strata/portal work; the session default uses that work's single dconf owner. The notes below
record the reconciliation constraints. Preserve that work's `default/theme.name`,
source-name validation, Strata bridge and portal ownership. Shared GTK4 resources are no longer published as a
selectable theme and require no synthetic identity or weakened palette-name validation. Reconcile the shared
source and attribution records (one Strata project entry, covering both uses), retain the explicit `visual/gtk4`
configure order, followed by `visual/gtk3`, and rerun the combined configure contracts. GTK3 is prepared in this
branch alongside GTK4; its later native lookup and shared session default must use the same reconciled portal
owner, not a duplicate dconf configuration. Regression-check GTK4 Strata when selecting the global GTK4 default.
Do not run the older branch's complete configure on a newer Strata-configured VM: that branch's unrelated file
manager baseline is not a proposed rollback. Final-path testing belongs to the reconciled product candidate.
