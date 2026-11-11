# Desktop shell fragments upstream record

## Origin and scope

- **Project:** [Omarchy](https://github.com/omacom/omarchy).
- **Revision:** `7075b61c6aaa5d8589f6e816867508fc96dc49d9` (read-only reference).
- **Additional tagged revisions:** `v4.5.0` → `ac2690cd7be4f47e4a255f5e2e78d904d436b068` and `v4.0.6` →
  `237f1b4071a0bff2296c6d740ba2b9fd695ebfa0`, read from a read-only Omarchy clone with history. All 873 files of
  package `omarchy 4.5.0-3` under `usr/share/omarchy/`, taken from the signature-verified Omarchy 4.5.0 ISO
  ([shell panels prototype procedure](../../../docs/procedures/shell-panels-prototype.md)), are byte-identical to
  `v4.5.0`. Rows name these revisions explicitly; the general pin above is not claimed for them.
- **License (SPDX):** `MIT`; upstream text copied unchanged to [LICENSE.omarchy](LICENSE.omarchy).
- **Copyright holders:** David Heinemeier Hansson; Neil Jagdish Patel (Copyright (c) 2026,
  Omapager notification-engine origin). The original notice remains unchanged in `notifications/Service.qml`.
- **Omapager license:** the complete original MIT text, Copyright (c) 2026 Neil Jagdish Patel, is retained
  unchanged in [LICENSE.omapager](LICENSE.omapager) alongside LICENSE.omarchy (which is not altered), so the
  notice-inclusion condition is met for the incorporated notification code. The host verified it externally,
  with maintainer authorization: the former repository `njpatel/omapager` redirects to
  [omacom/omapager](https://github.com/omacom/omapager); consulted revision
  `c389e73516828d18f26e8efec2127c0c3dc3cb97`; exact URL
  `https://raw.githubusercontent.com/omacom/omapager/c389e73516828d18f26e8efec2127c0c3dc3cb97/LICENSE`;
  host-provided copy SHA-256 `a2fe33052045a78c35a7a53ec452562e622a425ef7303c2cb631f07b2fd9e05d`.
  Scope limit: that revision is license evidence only. It is NOT a newly adopted code revision, NOT proof of
  the ancestral commit from which Omarchy incorporated the code, and NOT a full license audit; the code-source
  pin stays the Omarchy revision above. Earlier records that called this license unverified are historical.
- **Incorporation:** selective copied/adapted fragments in the MirrorOS-owned shell, integrated from the
  reviewed prototype at `6d7314fbed2c2db0db5794529479669320fc6687` (plan 02-19); not a fork or
  import of the complete shell. No plugin host, registry, supervisor, Omarchy IPC, authentication or lock code.
- Original MirrorOS code remains `GPL-3.0-only`; upstream material retains its MIT terms.

Paths in the destination column are relative to this directory. Source paths are relative to the upstream
repository; a `<rev>:` prefix (`v4.0.6:` or `v4.5.0:`) names the revision, and unprefixed paths use the
general revision above. `Copied` means byte-for-byte, with no added headers; `Adapted` includes new integration code.
This record covers Briefs 1 and 2 and the current Brief 3 implementation. Prototype evidence remains outside
source control. Full-source paths identify the origin, not a claim that the entire source file is imported.
MirrorOS-owned tests and tooling (all `New`, no upstream source) were relocated from this directory's former
`tests/` to the repository's `tests/capabilities/desktop/shell/` and are not delivered with the runtime.

## Per-file provenance

| Destination | Method | Source | Changes / scope |
|---|---|---|---|
| `Commons/Border.qml` | Copied | `shell/Commons/Border.qml` | Border policy, unchanged. |
| `Commons/BorderGeometry.js` | Copied | `shell/Commons/BorderGeometry.js` | Border geometry, unchanged. |
| `Commons/Color.qml` | Adapted | `shell/Commons/Color.qml` | Included-surface roles, validated product palette and bounded theme/personal surface settings. |
| `Commons/ThemePalette.js` | New | — | Bounded root-level palette reader with atomic fallback. |
| `Commons/WallpaperCatalog.js` | Adapted | Installed Omarchy `4.0.6-1` `shell/plugins/image-picker/ImagePickerModel.js`, SHA-256 `2eecf32b70811d0a39981e351ebe9843384aaf97b43dad1216651d2535a9a5da` | Basename deduplication and selected-path lookup only; NUL image/thumbnail pairs replace external rows. New ordered cycling and scan parser; no membership gate. Package Git revision unverified. |
| `Wallpaper.qml` | Adapted | `shell/plugins/background/Background.qml` from the installed Omarchy `4.0.6-1` reference, SHA-256 `6135a06b4c17c9a5a251053c294a657ecd80eb3a339f6eea146455b3925fd65b` | Per-screen background surface, crop, shared current/displayed/incoming/old state and 420 ms slanted-mask reveal started by the first ready panel. Retains reference failure semantics without timeout, acknowledgements or rollback. Double-left-click emits an integrated selector signal; ScreenMoveRemap guards output moves. No theme synchronization or right-click theme gesture. The package's Git revision has not been established; the general source pin above is not claimed for this file. |
| `Commons/SurfacePalette.js` | New | — | Bounded surface settings reader and alias resolver with per-setting fallback. |
| `Commons/I18n.qml` | Adapted | `shell/Commons/I18n.qml` | English-only API and catalog; no language state or OMARCHY_PATH. |
| `Commons/i18n-en.json` | Adapted | `default/i18n/en/shell.json` | Generated subset of used keys, values unchanged. The `network.*` keys used by the network panel match `v4.5.0` except `network.openCaptivePortal`, which keeps the pinned "Open Captive Portal" (`v4.5.0`: "Sign into network"). |
| `Commons/InputDevices.qml` | Copied | `shell/Commons/InputDevices.qml` | Native device-change watcher, unchanged. |
| `Commons/Numbers.js` | Copied | `shell/Commons/Numbers.js` | Number formatting, unchanged. |
| `Commons/Plural.js` | Copied | `shell/Commons/Plural.js` | Plural rules, unchanged. |
| `Commons/Style.qml` | Adapted | `shell/Commons/Style.qml` | Default tokens only; provisional local Nerd Font; no theme/fontconfig/Hyprland style loading. Adds only `easeOut` from `v4.5.0:shell/Commons/Style.qml` for the shared panel container. |
| `Commons/Util.qml` | Adapted | `shell/Commons/Util.qml` | Used helpers only; no RTL key reversal; identity widget-id normalization. |
| `Commons/qmldir` | New | — | Explicit included singleton declarations. |
| `Ui/ScreenMoveRemap.qml` | Copied | `v4.0.6:shell/Ui/ScreenMoveRemap.qml` | Unchanged output-position remap guard; registered in Ui/qmldir and used by the bar and background. Re-pinned from the installed Omarchy `4.0.6-1` reference (SHA-256 `ae09782672877502015e517c6f58565cf79b82e0aa1dc56ee5655989863ad8a7`, identical at `v4.0.6`); not assigned the general source pin. |
| `Ui/BarIconButton.qml` | Adapted | `shell/Ui/BarIconButton.qml` | Supports labels and measured custom icon content; glyphs retain upstream unscaled rendering. Labels omit the upstream figure-centering offset, as in `Ui/WidgetButton.qml`. |
| `Ui/BarIconContent.qml` | Copied | `shell/Ui/BarIconContent.qml` | Unchanged. |
| `Ui/BarIndicator.qml` | Adapted | `shell/Ui/BarIndicator.qml` | Uses the upstream caption font size for indicator glyphs. |
| `Ui/BarWidget.qml` | Copied | `shell/Ui/BarWidget.qml` | Unchanged. |
| `Ui/BorderOverlay.qml` | Copied | `shell/Ui/BorderOverlay.qml` | Unchanged. |
| `Ui/BorderSurface.qml` | Copied | `shell/Ui/BorderSurface.qml` | Unchanged. |
| `Ui/Button.qml` | Copied | `shell/Ui/Button.qml` | Unchanged. |
| `Ui/CursorSurface.qml` | Copied | `shell/Ui/CursorSurface.qml` | Unchanged. |
| `Ui/FilterInput.qml` | Copied | `shell/Ui/FilterInput.qml` | Unchanged; Brief 1. |
| `Ui/IconContentBounds.qml` | Copied | `shell/Ui/IconContentBounds.qml` | Unchanged. |
| `Ui/KeyboardPanel.qml` | Copied | `v4.5.0:shell/Ui/KeyboardPanel.qml` | Unchanged Omarchy 4.5 shared panel container; notification panel and bar panels. |
| `Ui/OpticalGlyph.qml` | Copied | `shell/Ui/OpticalGlyph.qml` | Unchanged. |
| `Ui/OverlayWindow.qml` | Adapted | `shell/Ui/OverlayWindow.qml` | Brief 1: removed RTL import/bindings; focused-output overlay retained. |
| `Ui/Panel.qml` | Adapted | `v4.5.0:shell/Ui/Panel.qml` | Shared panel lifecycle base. ShellIpc block removed (panel IPC is declared once in the bar); `ipcTarget`/`manageIpc` kept inert for API compatibility, `manageIpc` defaults to false. |
| `Ui/PanelActionButton.qml` | Copied | `shell/Ui/PanelActionButton.qml` | Unchanged. |
| `Ui/PanelController.qml` | Copied | `shell/Ui/PanelController.qml` | Unchanged. |
| `Ui/PanelHero.qml` | Copied | `shell/Ui/PanelHero.qml` | Unchanged. |
| `Ui/PanelKeyCatcher.qml` | Copied | `shell/Ui/PanelKeyCatcher.qml` | Unchanged. |
| `Ui/PanelSectionHeader.qml` | Copied | `shell/Ui/PanelSectionHeader.qml` | Unchanged. |
| `Ui/PanelSeparator.qml` | Copied | `shell/Ui/PanelSeparator.qml` | Unchanged. |
| `Ui/PanelSlider.qml` | Copied | `v4.5.0:shell/Ui/PanelSlider.qml` | Unchanged; panel level sliders. |
| `Ui/PanelToolTip.qml` | Copied | `shell/Ui/PanelToolTip.qml` | Unchanged. |
| `Ui/PointerMoveGate.qml` | Copied | `shell/Ui/PointerMoveGate.qml` | Unchanged; Brief 1. |
| `Ui/PopupCard.qml` | Copied | `shell/Ui/PopupCard.qml` | Unchanged; tray popups. |
| `Ui/TextField.qml` | Copied | `v4.5.0:shell/Ui/TextField.qml` | Unchanged; network panel passphrase field. |
| `Ui/ToggleSwitch.qml` | Copied | `shell/Ui/ToggleSwitch.qml` | Unchanged; notification preferences. |
| `Ui/WidgetButton.qml` | Adapted | `shell/Ui/WidgetButton.qml` | Supports optional optical icon rendering; text rendering is the default as in Omarchy. Labels are centered on their line box without the upstream `centerFigures` offset, which put figures one physical pixel below the icons beside them at scale 1.6; the property is kept inert for upstream callers. |
| `Ui/qmldir` | New | — | Explicit included UI declarations. |
| `WallpaperPicker.qml` | Adapted | `shell/plugins/image-picker/ImagePicker.qml` from installed Omarchy `4.0.6-1`, SHA-256 `9799f9cb52ffc4bd6d3089a50b73386b017e1c726b786e193e12d83561385ca8` | Skewed carousel, geometry, masks, keyboard and mouse selection. In-process thumbnail records and signals replace external response files; target-output selection, empty state and output-removal cancellation. Uses synchronous cached thumbnails as the reference and existing palette roles; no filter, labels, theme picker or external selector protocol. Package Git revision unverified. |
| `services/WallpaperActions.qml` | Adapted | Installed Omarchy `4.0.6-1` `bin/omarchy-theme-bg-next` (hash below), `bin/omarchy-theme-bg-install`, SHA-256 `f23306136f240f330db1d477eaedbc378a67ba98ee2f7dda665fe78bf41a2ba5`; `Background.qml` readlink behavior | Integrated argv orchestration: read selection link at startup/refresh; helper saves before display; next scans afresh, wraps and notifies on empty; install creates personal folder and opens Nautilus. Theme name derived from resolved theme target; native five-action IPC, no status or external selector protocol. One in-flight operation; failures logged. Package Git revision unverified. |
| `services/wallpaper-set` | Adapted | Installed Omarchy `4.0.6-1` reference `bin/omarchy-theme-bg-set`, SHA-256 `afee8d3bdd15917a2553c4f7a542de507f3f1b6e63eb92d38b5b1efe952209a0` | Resolves an existing file and replaces the selection link with `ln -nsf`; preserves a non-symlink state path. Returns the resolved path instead of invoking IPC; honors the shell's XDG state directory. Package Git revision unverified. |
| `services/wallpaper-thumbnails` | Adapted | Installed Omarchy `4.0.6-1` `/usr/bin/omarchy-menu-images`, SHA-256 `9d113b2138c49a944fe4e25f5b062d875d8ef4aaa5e00e59cc9282229d8e2093` | Reuses thumbnail generation, stat signatures, hash/index lookup, per-thumbnail flock, aged-lock/partial cleanup, single-threaded vips and parallel xargs, and failed-row pruning. MirrorOS cache namespace, base64 path keys in TSV, NUL pairs; rescans per picker opening instead of external row/preload caches. No temporary selection/done protocol or generic selector modes. Package Git revision unverified. |
| `services/WallpaperLibrary.qml` | New | — | Resolves current/theme on each request and derives the per-theme personal folder; fresh sorted scan for next or generated thumbnail records for the picker. |
| `services/list-wallpapers` | Adapted | Installed Omarchy `4.0.6-1` reference `bin/omarchy-theme-bg-next`, SHA-256 `3dbef062b7bde6322f428969bde9eb76fe436e3ab969ca0bc1ca7c46d5835241` enumeration | Directories passed as separate absolute arguments; NUL output, directory resolution before find, sorted paths without deduplication, missing-directory tolerance and explicit scan errors. No selection, state writes, notifications or IPC. |
| `services/AppLibrary.qml` | Adapted | `shell/services/AppLibrary.qml` | Brief 1: hidden-entry/icon logic; every launch through uwsm app, availability checks; no Omarchy scripts or config. |
| `services/AppSearch.js` | Copied | `shell/services/AppSearch.js` | Unchanged; Brief 1 ranking. |
| `services/hidden-entries.sh` | Copied | `shell/services/hidden-entries.sh` | Unchanged; Brief 1 desktop visibility scan. |
| `services/ShellConfig.qml` | Adapted | `shell/shell.qml` | Configuration subset (36-149, 168-172, 1096-1140); no plugin registry. Production (DEC-024/025): loads `defaults.json` and sparse user overrides from `$XDG_CONFIG_HOME/mirroros/shell.json`, saves only changed paths through a serialized private atomic writer that refuses to replace a file changed on disk, preserves invalid files and writes nothing at startup. Replaces Omarchy's complete-file replacement semantics. |
| `services/ShellPreferences.js` | New | — | Pure resolver: validation (version, top-level keys, kinds, forbidden prototype keys), object merge by present keys, whole-list replacement, changed-path diff, override removal, stable serialization. |
| `services/SessionActions.qml` | New | — | Closed six-action table with fixed argv (loginctl, uwsm, systemctl); fixed-command availability probes and short reasons; dry-run recording for tests. Behavior reference only: bin/omarchy-system and System guards. Production: lock probe requires the packaged `hypridle.service` user unit (DEC-023), not the prototype's transient unit. |
| `services/KeybindingHelp.qml` | New | — | Installed bindings from hyprctl binds -j, honest description/launchability notes, registry read from the Lua helper's runtime file (instance-checked, `id<TAB>keys<TAB>description`), bindings reported without a key (`code:N`) matched by modifiers and description only when unique, duplicate rows mapped to the same registry id left non-launchable, dispatch by validated registry id through hyprctl eval. Behavior reference only: bin/omarchy-menu-keybindings. |
| `services/StayAwake.qml` | New | — | Runtime-only Stay Awake state (`enabled`, off on every shell start, never read from or written to disk) and one native `Quickshell.Wayland` `IdleInhibitor` bound to a visible bar window (`Bar.qml` `liveWindow`); no process, `systemd-inhibit` or hypridle change. Behavior reference only: `v4.5.0:shell/plugins/bar/indicators/StayAwake.qml`. |
| `menu/Menu.qml` | Adapted | `shell/plugins/menu/Menu.qml` | Brief 3 shared menu replacing the Brief 1 launcher: tree, navigation stack/back, root search/drilldown, native Apps provider, dmenu select/multiple/onChange/input, card/delegate/scrims kept. Removed JSONC/user/language files, Bash providers and guard batch, uninstall/ConfirmDialog, plugin lifecycle and Omarchy IPC. Closed action table, unavailable rows with pinned reasons (no checkmark, kept in search), fixed-argv dmenu results, in-process selector handler for keyboard help, native IPC, Brief 1 Apps unavailable state, ComponentBehavior Bound. Navigation freezes only the card top (upstream also caps rows to the starting menu's height, which clipped the three-row MirrorOS root's submenus). Selection by stable row identity (`selectedId`, `settleCursor`, `activateSelected`): bounded MirrorOS repair of an upstream defect, see Boundaries and open items; no upstream fix is claimed. DEC-027: replacing an active selector with another selector or a regular menu first completes the old request as cancelled, once, with its own paths; result deliveries are queued so none is lost. |
| `menu/MenuModel.js` | Adapted | `shell/plugins/menu/MenuModel.js` | Unchanged except header and removal of the generated Bash guard batch (GUARD_READERS through guardScript) and summonAction; dmenu, parsing and translation helpers retained. Boundary verified by tests/capabilities/desktop/shell/menu-model.test.mjs. |
| `menu/MirrorMenu.js` | Adapted | `default/omarchy/omarchy-menu.jsonc` | Owned model with the upstream ids, labels, aliases, icons and order for Apps, Learn > Keybindings and System; closed action ids instead of commands; Apps is a submenu (upstream root Apps row opens the dock app grid); no screensaver or other Learn rows. Adds Style > Background and Install > Style > Background from installed Omarchy `4.0.6-1` `default/omarchy/omarchy-menu.jsonc`, SHA-256 `8c791cfc457d6c50b90a6636a6f28c9415a2fa6e4edf84826906457b75649689` (package Git revision unverified); original ids, icons, labels and aliases, closed wallpaper actions. |
| `bar/Bar.qml` | Adapted | `shell/plugins/bar/Bar.qml` | Top opaque horizontal bar, five regions, tooltip/popout/click contracts; closed component map replaces plugin/pool/drag discovery; no notch, glass, hide toggle or tray-region module host. Panel coordination from `v4.5.0:shell/plugins/bar/Bar.qml`: popout card and morph section, Tab switching, focused-monitor routing (`findPanelWidget`, `summonBarWidget`, `panelWidgetIdAt` on the focused monitor's bar) and `togglePanelAt`. Divergences: "focused monitor wins" routing (DEC-045) instead of open copy first; native `IpcHandler` targets `network`, `audio`, `display`, `power` declared once outside `Variants` with `open`/`close`/`toggle` only, instead of per-panel ShellIpc; no plugin registry, widget hosts, drag or dock code. MirrorOS addition: `liveWindow`, the first visible bar window, for the Stay Awake idle inhibitor. |
| `bar/BarModel.js` | Adapted | `shell/plugins/bar/BarModel.js` | entryId/entrySettings, slotEdge, barSizeFor subset; `centerSections`, `navigationRegions`, `isDrawnSlot` and `pickDrawnSlot` from `v4.5.0:shell/plugins/bar/BarModel.js`. New `panelAction` replaces upstream `pickPanelSlot` with "focused monitor wins" (DEC-045); new pure `panelSlots` backs the bar's panel navigation. |
| `bar/BluetoothState.qml` | Adapted | `v4.5.0:shell/plugins/panels/bluetooth/Panel.qml` | Native Bluetooth reader from 25, 33 (unchanged from 7075b61); fixed-URL loading deferred until acquired org.bluez appears. Sole importer of `Quickshell.Bluetooth`; the Bluetooth panel reads adapter and devices through it. |
| `bar/ClockModel.js` | Adapted | `shell/plugins/panels/clock/Model.js` | Clock-format subset only. |
| `bar/ProviderState.qml` | New | — | Startup-only bus-name/package inventory; no direct BlueZ/UPower probe or periodic activation. |
| `bar/indicators/Dnd.qml` | Adapted | `shell/plugins/bar/indicators/Dnd.qml` | Real directly composed notification service. MirrorOS addition (DEC-021/022): the indicator is also active while a while-away count is pending, showing the bell glyph with the count as a small superscript at its top-right corner inside the fixed status slot (capped at 9+, the first digit at a fixed position) and the existing `notifications.showHistory` tooltip; its unchanged click opens the panel. |
| `bar/indicators/StayAwake.qml` | Adapted | `v4.5.0:shell/plugins/bar/indicators/StayAwake.qml` | Reads the shell's runtime-only `mirroros.stay-awake` service instead of `omarchy.idle`, and its click calls the service `toggle()`. Upstream glyphs and the `bar.stayAwake` inactive tooltip kept; the active tooltip is the English literal "Allow Idle Lock" (the upstream value names a screensaver MirrorOS does not have). |
| `bar/widgets/ActiveWindow.qml` | Adapted | `v4.5.0:shell/plugins/bar/widgets/ActiveWindow.qml` | The label names the focused application before its title (`ActiveWindowModel.label`): the name comes from the desktop entry matched by Quickshell `DesktopEntries.heuristicLookup(appId)`, re-resolved when the entry list changes, or the raw app id; the tooltip shows the full label, and the root declares `tooltipHovered` (missing upstream), which the bar requires before showing it. The width is measured with a layout-independent `TextMetrics` instead of the elided `Text`'s `implicitWidth`, which formed a binding loop (also latent upstream). Plain text, `maxWidth` setting (280) and elision kept. Only a left click acts (`activate()`); both upstream `close()` paths (middle and right click) are removed. |
| `bar/widgets/ActiveWindowModel.js` | New | — | Pure label function: `<name> · <title>`, the name alone when the title is empty or equal to it ignoring case, the raw app id as the name when no entry matched, the title alone when no name is known, and `""` when nothing is known. |
| `bar/widgets/Audio.qml` | Adapted | `v4.5.0:shell/plugins/panels/audio/Panel.qml` | Audio panel on the shared `Panel` base (bar glyphs, wheel, OSD and mute-all from 7075b61 kept). Panel IPC lives in the bar (`manageIpc: false`); default selection is native `preferredDefaultAudioSink/Source` plus `audio-device default output/input <node-name>`, shown pending until it exits; port availability from `audio-device availability output/input` every 5 s while open, applied to outputs and inputs; volume sink is the default sink. Removed: `omarchy-audio-*` helpers, DSP/EasyEffects resolution and its FileView, tuning filter, `AudioNodes`, `UntypedInput`, `omarchy.media` and active-player highlighting. MPRIS player names label mixer rows and an "Advanced…" action launches `uwsm app -- pavucontrol` (ADR 0026). MirrorOS rejects WirePlumber's `auto_null` fallback (never listed, no volume writes, unavailable state without slider or level); other virtual sinks remain supported. |
| `bar/widgets/Bluetooth.qml` | Adapted | `v4.5.0:shell/plugins/panels/bluetooth/Panel.qml` | Bluetooth panel on the shared `Panel` base (missing/stopped-provider glyph, actionable tooltip and deferred `BluetoothState.qml` reader from 7075b61 kept, plus the same reason stated in the panel; hidden when BlueZ runs without an adapter). Panel IPC lives in the bar (`manageIpc: false`; `ShellIpc` and its `show`, `hide` and `toggleBluetooth` functions dropped). Device actions run the owned `bluetooth-device` (pair, connect, disconnect or forget an address) through one `Process`, one action at a time panel-wide: the acting row shows its pending label, other rows are dimmed and ignored, repeats are ignored, the action ends when the command exits and a non-zero exit shows a failure literal on that row only (a failed pair reads "Pairing failed. Devices that need a code: use Advanced…"); upstream's detached `omarchy-bluetooth-device`, `pendingActions` map, `syncPendingActions`, 20 s `pendingTimeout` and duplicate native `device.disconnect()` are removed. Trust is granted only by the command's pair (never by connect). The radio switch runs the owned `bluetooth-power on` or `off` through a `Process` with a busy state and ignored repeats, and states a failure under the hero; no `toggle`. After a panel-initiated pair or connect that ends connected, the Bluetooth sink is set natively with `Pipewire.preferredDefaultAudioSink` (immediate UI state) and through `audio-device default output <node-name>` instead of `omarchy-audio-output-set-default`. Discovery (`discoveryRetry`, `discoveryStop`, sibling handoff and destruction handoff) is kept on `bar.moduleWidgets()`; the panel never writes `pairable`, `pairableTimeout`, `discoverable` or `discoverableTimeout`, and never requests or shows a pairing code. Any mouse button on the icon toggles the panel (no right-click radio action). An "Advanced…" action at the end, keyboard-reachable, launches `uwsm app -- foot -e bluetoothctl --agent KeyboardDisplay` and closes the panel. The scrollable device list is capped at `Style.space(240)` (upstream 400), as in the network panel, so Advanced… stays inside the card on short scaled screens (T14s 1920×1080 at 1.6). Rotating hero phrases kept; device-list bindings kept as upstream (no `Qt.callLater` coalescing yet: an imperative list loses tracking of device property changes; revisit if BlueZ churn shows repeated rebuilds). Owned text is English literals. |
| `bar/widgets/Clock.qml` | Adapted | `shell/plugins/panels/clock/BarWidget.qml` | Bar label and persisted format cycle; calendar/timezone are integration points. |
| `bar/widgets/Indicators.qml` | Adapted | `shell/plugins/bar/widgets/Indicators.qml` | Static Dnd and StayAwake component map (default list in upstream order), no ShellIpc. |
| `bar/widgets/KeyboardLayout.qml` | Adapted | `shell/plugins/bar/widgets/KeyboardLayout.qml` | Native Hyprland layouts and device watcher; removed fcitx InputMethodState and cycle path. |
| `bar/widgets/KeyboardLayoutModel.js` | Copied | `shell/plugins/bar/widgets/KeyboardLayoutModel.js` | Unchanged. |
| `bar/widgets/MenuButton.qml` | Adapted | `shell/plugins/menu/BarWidget.qml` | Shared MirrorOS symbol path in the theme accent, drawn in whole physical-pixel blocks on the pixel grid; direct menu-root toggle; terminal click is an integration point. |
| `bar/widgets/Microphone.qml` | Adapted | `v4.5.0:shell/plugins/bar/widgets/Microphone.qml` | Native `Pipewire.defaultAudioSource` with `PwObjectTracker` only; `UntypedInput`/`viaWpctl` and the `AudioNodes` platform filter are removed (no virtual-source support). Visibility and the in-use highlight come from `MicrophoneModel.js`: hidden unless the source is in use or muted, and without a source or audio controls; a hidden indicator has zero width. Click toggles `source.audio.muted`, the wheel changes `source.audio.volume` by 0.05 within 0–1, and middle click calls `bar.requestPanel("omarchy.audio", "toggle")` instead of `omarchy-shell`. Upstream glyphs and `bar.microphone*` tooltips kept. |
| `bar/widgets/MicrophoneModel.js` | New | — | Pure model: `isShellLevelMeter` taken unchanged from `v4.5.0:shell/Commons/AudioNodesModel.js` (MIT); new `inUse` (any non-muted capture stream that is not a shell meter) and `visible` (a source with audio controls that is in use or muted). |
| `bar/widgets/Monitor.qml` | Adapted | `v4.5.0:shell/plugins/panels/monitor/Panel.qml` | Display panel on the shared `Panel` base (screen-count bar glyph from 7075b61 kept). Panel IPC lives in the bar (`manageIpc: false`; no `brightness`/`state` IPC); state from the owned Hyprland `display state`; the slider and bar wheel set the internal backlight with `brightness --no-osd N%` (wheel shows the shell OSD) and an external focused display shows the fixed-brightness state; outputs toggle with `display output <name> on/off` and scale presets apply at runtime with `display scale <value>`, both with the last-independent-output guard in the UI too; pending output and scale actions are shown distinctly; the open panel polls `display state` every second instead of every 5 s, so a scale changed outside it (no Hyprland event exists) is shown promptly. Added (ADR 0027): a "Mirror laptop display" toggle row running `display mirror`, shown only with an internal and an enabled external output, pending state shown and repeats ignored. Removed: text size, DDC/Apple and per-monitor brightness paths, `omarchy-monitor-state`, `omarchy-brightness-display`, `omarchy-hyprland-monitor-scaling` and direct `hyprctl eval`. |
| `bar/widgets/Network.qml` | Adapted | `v4.5.0:shell/plugins/panels/network/Panel.qml` | Network panel on the shared `Panel` base (missing-provider glyph and tooltip, OWE handling and active-AP signal poll from 7075b61 kept, plus an unavailable reason in the panel). Panel IPC lives in the bar (`manageIpc: false`; no `toggleNetwork`, `openCaptivePortal`, `checkConnectivity`, `showQr` or `speedTest` IPC). The owned `network-status`, `network-band` and `network-dns` commands replace `omarchy-network-status`, `omarchy-network-band` and `omarchy-dns`; `network-status` (which pings) runs only while the panel is open and is stopped on close (ADR 0028). DNS targets the header profile UUID: presets show an inline "Set DNS to <provider> for <profile>?" confirmation (focus on Cancel; Escape, close, profile change or another pill dismiss it), Custom opens `uwsm app -- foot` running `network-dns set <uuid> Custom` with a Done/Cancelled/Failed result, and pills are dimmed and inert while a change runs or without a Wi-Fi/Ethernet target; the provider read is not defaulted to DHCP. Band: Automatic is a pill beside the bands (no Automatic switch), the chosen band is the only filled pill, the current radio band carries a marker, the keyboard cursor is an outline, `network-band set <device> <uuid> <band>` targets the reported device-UUID pair, and while it runs the target reads "Switching…" with all pills dimmed and inert; the chosen band is not re-applied. Ping and Packet loss turn red only with at least 10 samples and 10 % loss. Captive portal: `uwsm app -- xdg-open http://neverssl.com/` as argv, closing on success and showing "Could not open a web browser" otherwise; no Tailscale exit-node pause, web app or window rules (the Arch connectivity host is HSTS-preloaded; Tailscale handling is TODO-023). Enterprise: no identity field or credential script; an unsaved enterprise row shows "Enterprise network: use Advanced…" and opens `nmtui`, a saved one connects natively and shows the same hint on missing secrets; an "Advanced…" action launches `uwsm app -- foot -e nmtui`. Clipboard copy runs `wl-copy <value>` without `bash -c`. Network-list changes trigger one deferred sync per event-loop turn (`Qt.callLater`) instead of one synchronous sync per change: stopping the scanner removes unsaved networks one by one, and with ~95 networks nearby the per-change rebuild blocked the shell for over a second on the T14s. Removed: QR sharing and speed test. Owned text is English literals. The VPN section is MirrorOS-owned with no upstream source (ADR 0025 G8, plan 02-30): OpenConnect profiles from the owned `vpn-profile list`, read on open, after a Disconnect and every 2 s only while the panel is open, and hidden with no profiles or on a failed read; its list is capped at `Style.space(96)` between DNS and the Wi-Fi list, and while it is shown the Wi-Fi list cap (`Style.space(240)`) yields the section's height so the card stays on screen (T14s overflow, RISK-001); Connect opens `uwsm app -- foot -e bash -c <wrapper> ... /usr/share/mirroros/hardware/vpn-connect <uuid>` and closes the panel, Disconnect runs `vpn-profile disconnect <uuid>` with one action in flight and failure literals on the acting row; one VPN at a time; a `vpn` keyboard section between DNS and Wi-Fi; no credential, username field or `nmcli connection up` in QML. |
| `bar/widgets/Power.qml` | Adapted | `v4.5.0:shell/plugins/panels/power/Panel.qml` | Power panel on the shared `Panel` base (bar glyph, persisted percentage setting, provider inventory and unavailable glyph/reason from 7075b61 kept). Left and right bar clicks both toggle the panel, matching Network; neither changes the percentage setting. Panel IPC lives in the bar (`manageIpc: false`; no `togglePercentage` IPC); details from the owned `battery-status`; profiles read through native `PowerProfiles` and written with `power-profile set <ac/battery> <profile>`; a pending profile is shown distinctly; without a battery the panel does not open. Removed: `omarchy-battery-status`, `omarchy-powerprofiles-*` and `omarchy-system-stats`. |
| `bar/widgets/Tray.qml` | Copied | `shell/plugins/bar/widgets/Tray.qml` | Unchanged, including LocalSend/Dropbox filtering. |
| `bar/widgets/TrayModel.js` | Copied | `shell/plugins/bar/widgets/TrayModel.js` | Unchanged. |
| `bar/widgets/Workspaces.qml` | Adapted | `shell/plugins/bar/widgets/Workspaces.qml` | Native workspace state; Lua focus dispatch and tiledLayout instead of Omarchy scripts/state; layout cycling is an integration point; active glyph uses text rendering as in Omarchy. |
| `panels/audio/Model.js` | Copied | `v4.5.0:shell/plugins/panels/audio/Model.js` | Unchanged; `isUntypedSource` and `streamRepresentsPlayer` are not called by the panel. |
| `panels/bluetooth/Model.js` | Adapted | `v4.5.0:shell/plugins/panels/bluetooth/Model.js` | Upstream functions unchanged (including the primitives-only `deviceRow` segfault guard, `deviceLists`, `bluetoothSinkMatchesDevice` and the name filters) except the per-address pending-action map: `cloneMap` and `withPendingAction` are removed and `pendingAction` reads a single in-flight `{ address, action }` (DEC-072). Added: `actionBlocked`, `startAction`, `failureLiteral` (pair points at Advanced…, other actions a generic literal), `actionResult` (bluetooth-device exit codes; a pair failing at trust or connect is not reported as a pairing failure) and `powerFailureLiteral`. |
| `panels/display/Model.js` | Adapted | `v4.5.0:shell/plugins/panels/monitor/Model.js` | Upstream functions unchanged; adds `parseState` for the owned `display state` JSON (brightness only for the focused internal panel) and `canToggle`/`independentEnabledCount` mirroring the command's last-independent-output guard, and `mirrorState` for the ADR 0027 mirror toggle. |
| `panels/network/Model.js` | Adapted | `v4.5.0:shell/plugins/panels/network/Model.js` | Upstream functions unchanged except `captivePortalUrl`, which is `http://neverssl.com/` because the prototype's Arch connectivity host is HSTS-preloaded and a portal cannot intercept it (TODO-023 for the Tailscale exit-node case). Removed: `enterpriseConnectScript` (no enterprise credential path; "Advanced…" opens `nmtui`). Added: `packetLossUrgent` (red only with at least 10 samples and 10 % loss, ADR 0028), `bandPillState` (distinct chosen, current and switching band states) and `dnsNeedsConfirmation`/`dnsConfirmationValid` (preset confirmation bound to one profile UUID). MirrorOS-owned with no upstream source (ADR 0025 G8, plan 02-30): the VPN section helpers `parseVpnProfiles`, `vpnRowAction`, `vpnStateLabel`, `vpnDisconnectFailure` and `vpnConnectScript`. |
| `panels/power/Model.js` | Adapted | `v4.5.0:shell/plugins/panels/power/Model.js` | Upstream functions unchanged (also back the bar glyph and percentage); adds `formatDuration` (English `battery.duration*` forms from v4.5.0 `default/i18n/en/cli.json`) and `withUnits` for the unit-free `battery-status` output; `parseProfiles` is not called because profiles come from native `PowerProfiles`. |
| `notifications/DeedButton.qml` | Copied | `shell/plugins/notifications/DeedButton.qml` | Unchanged. |
| `notifications/Delivery.js` | Copied | `shell/plugins/notifications/Delivery.js` | Unchanged quiet/delivery rules. |
| `notifications/Detect.js` | Copied | `shell/plugins/notifications/Detect.js` | Unchanged heuristics, not a privacy guarantee. |
| `notifications/Icons.js` | Copied | `shell/plugins/notifications/Icons.js` | Unchanged icon policy. |
| `notifications/Layout.js` | Copied | `shell/plugins/notifications/Layout.js` | Unchanged deck layout. |
| `notifications/Markup.js` | Copied | `shell/plugins/notifications/Markup.js` | Unchanged markup/source handling. |
| `notifications/NotificationPanel.qml` | Copied | `shell/plugins/notifications/NotificationPanel.qml` | Unchanged, including preferences and screen-share offer. Preferences reach only prototype shell.json through the injected root. |
| `notifications/Picker.qml` | Copied | `shell/plugins/notifications/Picker.qml` | Unchanged. |
| `notifications/Security.js` | Copied | `shell/plugins/notifications/Security.js` | Unchanged argv/navigation validation. |
| `notifications/Service.qml` | Adapted | `shell/plugins/notifications/Service.qml` | Original Omapager notice retained. Native IPC/direct composition, MirrorOS namespace/private state; excluded personal icon directory, legacy DND/cleanup and focus-app fallback. Kept sharing offer, preferences, argv execution and persistence; DEC-020 adopts the persistence policy. Production private state at `$XDG_STATE_HOME/mirroros/shell/notifications/`. MirrorOS addition (DEC-021/022): while-away count from the `$XDG_RUNTIME_DIR/mirroros-shell-locked` marker, reread through the `lockChanged` IPC function and at startup, persisted in `while-away.json` and cleared when the panel closes after its history section was expanded. |
| `notifications/Settings.js` | Copied | `shell/plugins/notifications/Settings.js` | Unchanged defaults/validation. |
| `notifications/Store.js` | Copied | `shell/plugins/notifications/Store.js` | Unchanged persistence/retention/redaction model; unused legacyDnd helper remains in this unmodified copy, never called by the adapted service. |
| `notifications/Toast.qml` | Copied | `shell/plugins/notifications/Toast.qml` | Unchanged. |
| `notifications/WhileAway.js` | New | — | While-away count model (DEC-021/022), wired through `notifications/Service.qml` after the guest proof of the hypridle lock signals and restart reconciliation. Stores no notification content. |
| `osd/Osd.qml` | Adapted | `shell/plugins/osd/Osd.qml` | Native IPC, MirrorOS namespace; new read-only source/showSource for PipeWire volume and sysfs brightness; unavailable is not a fabricated level. MirrorOS treats WirePlumber's `auto_null` fallback as no audio output, without rejecting other virtual sinks. |
| `osd/OsdModel.js` | Copied | `shell/plugins/osd/OsdModel.js` | Unchanged payload/state/icon model. |
| `shell.qml` | New | — | Explicit surface composition/service injection (including menu, session actions and keyboard help), closed direct routing; no plugin host. Panel `GlobalShortcut` entries (`appid: "mirroros"`) modeled on `v4.5.0:shell/shell.qml` usage without its shortcuts file, socket or `OMARCHY_PATH`. Hot reload disabled (`settings.watchFiles: false`, DEC-049). |
| `defaults.json` | Adapted | `config/omarchy/shell.json` | Versioned common shell defaults (DEC-024/025): the reduced bar defaults formerly embedded in `services/ShellConfig.qml`, unchanged in value. Plan 02-31 adds `omarchy.active-window` after the workspaces and `omarchy.microphone` immediately before `omarchy.audio`. |
| `LICENSE.omarchy` | Copied | `LICENSE` | Unchanged upstream license text. |
| `LICENSE.omapager` | New | — | Complete original Omapager MIT license text, byte-identical to the host-provided copy of omacom/omapager `LICENSE` at `c389e73516828d18f26e8efec2127c0c3dc3cb97` (license evidence only, not a code revision); retained with the incorporated notification code. Pinned by SHA-256 in `tests/capabilities/desktop/shell/check-provenance.mjs`. |
| `UPSTREAM.md` | New | — | This provenance record. |
| `sources.md` | New | — | Configuration ownership and format justification. |
| `apply` | New | — | Configure step: packages, runtime publication, user unit delivery and offline enablement. Not delivered with the runtime. |
| `packages` | New | — | Official package declarations consumed by the five surfaces. Not delivered with the runtime. |
| `install-runtime` | New | — | Manifest-checked, atomically exchanged runtime publication. Not delivered with the runtime. |
| `systemd/mirroros-shell.service` | New | — | Shell user unit tied to the uwsm graphical session (DEC-023). Not delivered with the runtime. |

## Runtime dependencies and ownership

Production package declarations are in `packages` (plus `hyprland` and `uwsm` from their own configure steps);
this inventory also lists optional and test-only tools. Installed versions are recorded in configure evidence; package services, presets and D-Bus activation are not owned by
this shell. Availability is never inferred from synthetic OSD events.

- Quickshell (`Quickshell`, `Io`, `Wayland`, `Hyprland`, `Networking`, `Bluetooth`,
  `Services.Notifications`, `Services.Pipewire`, `Services.SystemTray`, `Services.UPower`).
- Qt Quick, Controls, Layouts, Effects and Shapes; Hyprland is the current compositor provider.
- Wallpaper thumbnails: vipsthumbnail (libvips, official Arch extra) and flock (util-linux, core).
  Nautilus is owned by the separate desktop/files capability and launched with an argv array.
- Bash, coreutils/findutils/awk, pacman, busctl (systemd), hyprctl, nmcli (NetworkManager),
  xkbcli (libxkbcommon), inotifywait (inotify-tools), uwsm, wl-copy/wl-paste (wl-clipboard).
- Session actions: loginctl and systemctl (systemd), uwsm. Lock availability probes for hyprlock and the
  packaged `hypridle.service` user unit, the providers accepted under DEC-019/DEC-023 and owned by `../lock/`.
- Keyboard help: hyprctl binds -j, the registry file `$XDG_RUNTIME_DIR/mirroros-keybindings.tsv`
  exported by `../compositor/providers/hyprland/shell-bindings.lua` (delivered by configure) and
  hyprctl eval for dispatch.
- PipeWire/WirePlumber, BlueZ and UPower are external providers. No VM sink, battery or backlight is
  simulated. Bluetooth import is deferred while its service is stopped.
- xdg-desktop-portal and xdg-desktop-portal-hyprland are present as authorized laboratory drift. The
  notification sharing detector observes PipeWire properties; its synthetic fixture is not real capture.
- JetBrainsMono Nerd Font is provisional local typography. Omarchy's brand font is not incorporated.
- Tests/tooling: Node.js, qmllint (qt6-declarative), libnotify/notify-send, wtype for launcher input.
  Catalog tooling uses Node.js ESM; no project-owned Python generator or Python dependency is shipped.

## Boundaries and open items

- Notification persistence follows DEC-020 (24 hours, 100 entries, active cards restored, private files).
  Preferences keep the bounded upstream version-1 shape as sparse overrides over `defaults.json`
  (DEC-024/025); the format justification is in `docs/procedures/desktop-shell.md`. Omarchy widget
  identifiers (`omarchy.*`) are retained as data keys.
- `omarchy-exec-argv` is preserved as investigated: structural argv validation, fixed positional
  execution, activation only by a user click, validation again on restore. Trust model: any same-user
  session-bus sender can set it, the same boundary as any same-user process. Residual risk: a sandboxed
  application able to reach the session bus could have a click run argv outside its sandbox. No sender
  authorization, injection resistance beyond literal argv, or sandbox guarantee is claimed; the feature is
  not disabled.
- Color-only states inherited from Omarchy are accepted by the Story 4.3 criterion as aligned under
  DEC-015/DEC-026. Prototype deviation records stay historical, not retroactive compliance claims.
- Real audio/power/Bluetooth/backlight behavior and multi-monitor placement need target validation.
- The authorized temporary us/es test passed using Lua runtime configuration, restoring us afterwards.
  The six-panel source study is complete in prototype evidence; no panels were implemented. Synthetic SNI
  visibility/menu remain unverified without a suitable installed approved-language client.
- Guest-console review accepted the initial surfaces and retained Omarchy's 26-logical-pixel bar default.
  It found an inherited DND-panel lifetime asymmetry: switching from silenced to allowed can destroy the
  active indicator and its child panel, while the reverse transition keeps the inactive instance alive.
  This is documented, not fixed. Per-gesture/clipboard and complete preferences visual acceptance are
  not inferred from general feedback; automated preference persistence is separately covered.
  Production carries the DND behavior forward unchanged; a bounded synthetic guest reproduction is still
  pending before any repair.
- Future host-review proposal, not an adopted workflow: periodically compare only the recorded upstream
  source paths, evaluate individual fixes and dependencies, and record any additional upstream commits
  per file alongside the base revision, with regression checks. Do not assume upstream will fix an issue
  or automatically import unrelated shell code. Current provenance verification remains single-revision.
- Selector (dmenu) trust boundaries: callers choose the selection/done file paths and the onChange argv,
  which runs as the user. Any caller able to use qs IPC already runs as the same user, so no privilege
  boundary is added, but the paths and argv are caller-controlled; the earlier sandbox risk (a sandboxed
  application reaching session IPC or notification actions) applies equally. Results are written with
  fixed argv and positional data. DEC-027: a new selector or regular menu first completes a pending
  request as cancelled (done file, empty selection, its selection never run); one active request, no
  queue of requests. Regression: `tests/capabilities/desktop/shell/check-selector-replacement.sh`. No
  product command-line client exists; end-to-end CLI usability and dmenu compatibility are not claimed.
- Session actions run without a second confirmation, as upstream (accidental activation risk). Provider
  answers such as logind "yes" are declarations; disruptive actions are verified only individually.
- Keyboard help: a probe verified that globals persist between hyprctl eval calls and that a stored
  dispatcher can be dispatched later; eval prints no returned values, hence the registry file. Loading
  the real bindings and dispatching them from help were verified in authorized runtime tests (keyless
  `code:N` rows, function dispatchers and `hyprctl eval` dispatch by registry id). Unbinding them at
  revert crashed Hyprland 0.56.2 once (cause not established); the registry is runtime-only.
- Menu cursor (upstream defect, bounded MirrorOS repair): the upstream cursor is tracked by row index, and
  when the selected row's availability or position changes while the menu is open (for example Suspend
  turning unavailable, or an application row appearing above the selection), Enter runs whatever row now
  occupies that position. MirrorOS tracks the selected row by identity instead: the cursor follows the row;
  if it becomes unavailable or disappears, nothing is selected and Enter runs nothing, even if the row
  recovers, until the user selects an available row; its reason stays visible. No upstream fix is claimed,
  and the repair adds no confirmation dialog. Regression: `tests/capabilities/desktop/shell/check-menu.sh` (stable-selection variant,
  dry-run dispatch). An earlier record of this defect as unfixed is historical.
- While-away count (DEC-021/022): only the pure model exists. It is not wired into the shell, lock hooks
  or bar until a bounded guest proof of hypridle `on_lock_cmd`/`on_unlock_cmd` signals and shell-restart
  reconciliation passes; otherwise it remains pending maintainer review.
- Refresh reuse metrics after further changes.
