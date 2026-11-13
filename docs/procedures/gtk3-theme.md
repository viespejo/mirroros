# Native GTK3 theme preparation

## Scope and current behavior

Osaka Jade GTK3 is prepared alongside [GTK4](gtk4-theme.md) in `feat/gtk4-theme`. The maintainer approved the
isolated GTK3 portal file picker and requested both toolkit resources in this branch before later reconciliation
with main's Strata/portal work. After that reconciliation, `desktop/portal`'s system dconf default selects the
native `MirrorOS-default` entry for GTK3 and GTK4 together; portal routing and Strata are unchanged. It imports no GTK2 theme, XFCE decorations or application icon pack. GTK3's own widget assets
are included, unchanged, as necessary parts of the theme.

The [GTK3 sources record](../../capabilities/visual/gtk3/sources.md) contains the upstream revision, licenses,
hashes, adaptations and laboratory evidence. This is routine resource delivery under the existing configure
contract, not authorization for a new global selection mechanism.

## Layout and delivery

| Owner | Tree | Purpose |
|---|---|---|
| `visual/theme` | `/usr/share/mirroros/themes/default` | Palette including `gtk-3.0.css` and `gtk-4.0.css` |
| `visual/gtk4` | `/usr/share/mirroros/gtk4` | Existing GTK4 runtime and transitional launcher |
| `visual/gtk3` | `/usr/share/mirroros/gtk3` | GTK3 Osaka base, 126 assets, typography and retained notices |
| `visual/gtk4`, `visual/gtk3` | `/usr/share/themes/MirrorOS-default/gtk-4.0`, `gtk-3.0` | Native lookup entries, one manifest-checked tree each |
| `desktop/portal` | `/etc/dconf/db/local.d/00-mirroros-appearance` | System `gtk-theme` and `icon-theme` `'MirrorOS-default'` defaults |

The order is `visual/theme`, `visual/gtk4`, `visual/gtk3`, then the existing consumers. Each runtime is separately
manifest-checked, with safe ancestors, staged publication, permissions, conflict preservation and unchanged
reruns in running and target contexts. GTK3 has no synthetic palette identity, package requirement or launcher.
Delivery inputs and provenance are not installed as runtime files. Consumer capabilities own GTK dependencies.

GTK3's entry is `share/themes/MirrorOS/gtk-3.0/gtk.css` inside its runtime. It imports the fixed product palette,
base and shared typography. Upstream's `gtk-dark.css` is identical to `gtk.css`, so our dark entry imports that
same cascade. The 211 stable palette tokens reconstruct the original CSS byte for byte; upstream assets and
license notices retain their exact bytes. Typography matches GTK4's family stack and 13px sizing. The laboratory
resolved JetBrains Mono to Noto Sans Mono; actual JetBrains rendering remains unverified there.

Those nested runtime entries are not in GTK's search path. The native entry `entries/default/` is published as
`/usr/share/themes/MirrorOS-default/gtk-3.0/` with the same cascade through absolute imports, and the system dconf
default selects it at the next login unless the user sets `gtk-theme`. There is no global `GTK_THEME`, user-priority CSS injection,
application icon overlay, portal restart or user preference write. Native application icons remain the default;
only the neutral default-device check is shared, through the GTK4-owned native icon theme `MirrorOS-default`.

## Validation

Run from this worktree's root; configure contracts use disposable filesystem roots and command doubles:

```bash
node --test tests/capabilities/visual/gtk3/*.test.mjs tests/capabilities/visual/gtk4/*.test.mjs \
  tests/capabilities/visual/theme/*.test.mjs
bats tests/capabilities/visual/gtk3/configure.contract.bats \
  tests/capabilities/visual/gtk4/configure.contract.bats tests/capabilities/visual/theme/configure.contract.bats
shellcheck capabilities/visual/gtk3/apply capabilities/visual/gtk3/install-runtime
```

Tests guard exact upstream CSS reconstruction, complete asset inventory, URL targets, unchanged notices,
typography consistency, dark-entry imports, inert delivery, safe filenames including HiDPI `@2.png`, conflicts,
idempotency and both configure contexts. A combined contract checks GTK3/GTK4 coexistence and preservation of
user GTK settings, packaged icon content and portal selection. These do not qualify installed-session behavior.

The accepted raw-theme FileChooser preview used a private D-Bus bus and temporary XDG homes. Its appearance
approval does not establish product-source rendering, default routing, accessibility or remote filesystems.
Private-bus missing-parent/RealtimeKit/GVfs warnings are not hidden as integration success. Temporary fixture
paths and versions are recorded in the sources record; no lab helper is product code.

### Preparation verification

All capability Node tests discovered with `find tests/capabilities -name '*.test.mjs'` passed: 377 passes,
33 skips and no failures (410 total). The focused theme/GTK3/GTK4 Node run passed all 39 cases. The three
configure suites above passed all 23 cases. The broader Bats run of
`tests/capabilities/{mechanism,target}.contract.bats` and
`tests/capabilities/desktop/shell/configure.contract.bats` passed 125 cases with one existing Tmux-version skip:
148 passes and one skip across the completed configure suites.

An initial broader run launched Bats asynchronously and failed its SIGINT normalization case. Running the
unchanged suite in the foreground passed; asynchronous shells can inherit SIGINT ignored. No signal-handling
code was changed to accommodate that invocation. Host logs are `/tmp/mirroros-gtk3-{node,all-node,configure}.log`,
`/tmp/mirroros-gtk3-all-configure.log` (initial failure), and
`/tmp/mirroros-gtk3-all-configure-foreground.log` (complete passing rerun).

ShellCheck passed for both GTK3 scripts; tracked changes and authored new files passed whitespace checks.
Inherited upstream CSS/license whitespace is intentionally retained. A focused Gitleaks scan passed with no
findings (`/tmp/mirroros-gtk3-gitleaks.log`). A temporary product-resource copy, changing only the palette import,
loaded the normal and dark entries under VM GTK 3.24.52 with zero CSS diagnostics
(`/tmp/mirroros-gtk3-product-parser.log`, VM fixture `/tmp/mirroros-gtk3-product.egeo7BSj`). This windowless check
does not replace graphical product-source review or final-path/session qualification. No full configure,
product installation, global activation, merge or commit was performed.

## Conflict and recovery

An unknown, locally modified, incomplete, linked or unsafe runtime fails configure without being overwritten.
Inspect the reported path; restore the reviewed delivery or deliberately move it aside before rerunning.
Never delete personal GTK settings or reroute portals to make a publication test pass. To return one user's
session to Adwaita, run as that user `gsettings set org.gnome.desktop.interface gtk-theme Adwaita`; `gsettings reset
org.gnome.desktop.interface gtk-theme` restores the MirrorOS default. Configure never writes that user value. Close laboratory dialogs normally;
reverify any temporary process's executable, owner and isolated environment before stopping it.

## Later integration with main

The branch was rebased onto main's Strata/portal work. Both toolkit entries are published under the shared native
`MirrorOS-default` name through conflict-safe system lookup delivery, selected by the single dconf/portal owner
without global `GTK_THEME`, and explicit user theme preferences take precedence. The naming rule and Story 4.8
synchronization are recorded in the [theme sources](../../capabilities/visual/theme/sources.md).

Before activation acceptance, verify installed lookup paths, the actual Settings backend and portal FileChooser,
user overrides and high-contrast selection, both variants, real fonts, GTK4 pavucontrol, Strata's own styling,
libadwaita non-interference and reversible removal. A GTK3 theme does not directly style GTK4 Strata, but global
GTK4 selection still needs a Strata regression check. Sandbox or application-specific themes may not follow the
session default. Final graphical acceptance, a clean rebuilt candidate and physical qualification remain separate.
