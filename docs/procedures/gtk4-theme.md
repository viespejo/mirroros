# Native GTK4 theme

## Scope

MirrorOS's native GTK4 theme is a process-local consumer of the reviewed default palette, first used by
pavucontrol from the audio panel's **Advanced…** action. It does not change GTK settings, icon-theme selection,
portal routing, audio values, Strata or the desktop's global environment. GTK3 and libadwaita are not covered.
The shared bundle is independent of palette-specific colors; arbitrary themes are not admitted by the resolver.

[Theme sources](../../capabilities/visual/theme/sources.md#native-gtk4-theme-and-pavucontrol) record licensing,
layout, icon ownership, laboratory approval and validation limits. This applies the existing native-theme and
advanced-audio boundaries; it adds no configuration framework, provider, service or resident theme manager.

## Delivery and use

After integration with the current product baseline, run the normal [configure procedure](configure.md).
The `visual/theme` step publishes two independently manifest-checked trees:

| Tree | Purpose |
|---|---|
| `/usr/share/mirroros/themes/default` | Reviewed palette, including `gtk-4.0.css` and existing consumers |
| `/usr/share/mirroros/themes/gtk4` | Shared CSS, pavucontrol adapter, neutral SVG aliases, launcher and MIT notice |

The bundle's `theme.name` (`mirroros-gtk4`) is a resource-bundle identity, not a palette selection. The theme's
font stack uses the JetBrains font already declared by the terminal capability. Pavucontrol brings GTK4 and
Adwaita from the official repositories; no demo or additional runtime dependency is installed by `visual/theme`.

Configure never launches or reloads an application. Close any existing pavucontrol window normally, then use
**Advanced…**, or run as the session user:

```bash
uwsm app -- /usr/share/mirroros/themes/gtk4/launch pavucontrol
```

The launcher sets only `GTK_THEME` and prepends its resource directory to `XDG_DATA_DIRS`, in that process.
Real application preferences remain in their existing locations. An already running single-instance application
may receive the request instead and keep its earlier appearance; the launcher does not kill or restart it.
Normal GTK user CSS and user data remain effective. No full isolation from user customization is claimed.

The same launcher admits an already installed Widget Factory for explicit testing; its package is not part of
the product declaration:

```bash
/usr/share/mirroros/themes/gtk4/launch gtk4-widget-factory
```

Theme changes apply on the next application launch, not through forced hot reload. A new palette consumer must
retain the resolver's trust boundary and document its coverage; adding arbitrary palette selection is separate work.

## Validation

Run from the repository root:

```bash
node --test tests/capabilities/visual/theme/*.test.mjs \
  tests/capabilities/desktop/shell/audio-panel-model.test.mjs
bats tests/capabilities/visual/theme/configure.contract.bats
shellcheck capabilities/visual/theme/apply capabilities/visual/theme/resolve-current \
  capabilities/visual/theme/gtk4/launch
```

The contracts cover both configure contexts, idempotency, executable delivery, preservation of unknown/modified
resources and user settings, palette roles, import order, selected-row hover and popup fixes, CSD insets,
pavucontrol-only footer spacing, neutral SVG aliases and launcher argv/stdin/exit/permission behavior.
They do not prove installed-session rendering or clean-candidate readiness.

After merging and publication in the disposable VM:

1. Check configure's delivered manifests and the unchanged rerun; it must not start/restart any user application,
   portal or session service, write GTK settings, or change user theme/background links.
2. Close the earlier test application normally. Open pavucontrol through **Advanced…** without a privilege prompt.
   Confirm that the launched process uses `GTK_THEME=MirrorOS` and the product-only icon overlay, while HOME,
   XDG config/data/cache/state homes and the session bus remain the real session's values. Inspect only these
   allowlisted variables, never dump the full environment or personal preferences.
3. Review Playback, Recording, Output Devices, Input Devices and Configuration at rest and with UI-only hover,
   keyboard focus, selected and disabled states. Open and dismiss **Show**, **Port** and **Profile** without
   selecting another audio option. Do not toggle mute, default devices, profiles, latency or real audio values
   solely to test CSS. Check the popup's transparent outer allocation, rounded panel and separation above/below.
4. Confirm Configuration footer margins, the new neutral default-device check, and a real stream's symbolic icon
   without launching unrelated applications or collecting personal content. The new check is original geometry;
   its appearance needs confirmation beyond successful icon lookup. Unknown names must retain native fallback.
5. If Widget Factory is installed, review Pages 1–3 and transient dialogs/popovers for regressions. Preserve
   sample color swatches and hue/alpha ramps. Check focus and hit targets, not merely removal of blue.
6. Repeat with the supported window sizes and display scales. A lookup at scale 2 does not establish optical
   alignment, contrast or every rendering state. Record failures honestly; the laboratory's pre-existing
   accessibility-bus warning prevents claiming AT-SPI or full focus qualification from a parser pass.

The shared CSS was parsed successfully with GTK 4.24.1 in a relocated temporary fixture; 312 icon lookups passed
at sizes 16/24/32 and scales 1/2, in ordinary/forced-symbolic modes, with standard Adwaita fallback preserved.
These are product-source checks, not installation at the final paths. No Python helper or temporary test path is
part of product delivery. A rebuilt candidate and physical-target qualification remain separate gates.

## Conflict and recovery

Unknown, modified, incomplete or linked product deliveries are preserved and fail configure. Inspect the named
conflict and restore the last reviewed delivery or move it aside deliberately before rerunning; never delete
personal configuration to make a theme check pass. The launcher returns 4 when its required trusted resources or
application are unavailable, 2 for unsupported consumers, otherwise the application's exit outcome.

For a native appearance without the product overlay, close pavucontrol, then run from a normal session terminal:

```bash
pavucontrol
```

No global setting needs undoing. Do not invoke native recovery from a shell that inherited the test launcher
resources. Do not reconfigure portals or Strata, copy laboratory settings into HOME, or kill processes by name.

## Integration with pending work

This change was developed in `feat/gtk4-theme` from `8a9ad72`, outside the dirty main checkout. Its pending
Strata/portal work is not copied into this branch. Before merging, preserve that work's `default/theme.name`,
source-name validation, Strata bridge and portal ownership. The shared bundle already supplies its separate
`theme.name`, so both trees satisfy source-name validation without weakening it. Reconcile the shared source and
attribution records (one Strata project entry, covering both uses) and rerun the combined configure contracts.
Do not run the older branch's complete configure on a newer Strata-configured VM: that branch's unrelated file
manager baseline is not a proposed rollback. Final-path testing belongs to the reconciled product candidate.
