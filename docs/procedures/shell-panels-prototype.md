# Shell panels prototype (Story 4.4 research)

This procedure records the bounded research, laboratory prototype and supervised
laptop evidence for the Story 4.4 shell panels (plan 02-26). It is research, not
production delivery: no production panel, `configure` step or key binding is
added by it. Production plans 02-27 onward start from the gate outcome recorded
here and from the ADR that amends
[ADR 0012](../adr/0012-owned-quickshell-desktop-shell.md).

Governing sources: [architecture](../architecture.md),
[ADR 0012](../adr/0012-owned-quickshell-desktop-shell.md),
[ADR 0024](../adr/0024-networkmanager-resolved-dns-integration.md) and the
[desktop shell prototype](desktop-shell-prototype.md), whose guest-branch and
bundle-handoff pattern this work reuses.

## Boundaries

- Omarchy ISO extractions stay outside the repository (`/tmp/omarchy-45`,
  `/tmp/omarchy-406`). Upstream helpers are read, never executed. No personal
  configuration is read.
- Raw evidence stays in ignored `evidence/shell-panels/` and
  `evidence/shell-panels-prototype/`. Only redacted summaries enter this file:
  no SSID, PSK, MAC address, device name or pairing key.
- Third-party code never runs on the host; when it must run, it runs only in the
  laboratory guest on a recoverable checkpoint.
- No agent runs on the T14s; laptop evidence is supervised from the host and is
  non-qualifying. The Framework Laptop 13 Pro remains pending.

## Reference verification

Omarchy 4.5 is the primary reference; installed Omarchy `4.0.6-1` remains the
baseline of existing MirrorOS code where its provenance says so.

| Item | Result |
| --- | --- |
| ISO | `~/Downloads/omarchy-4.5.0-x86.iso`, 6,540,910,592 bytes |
| Official procedure | [omacom/omarchy-iso README, "Verify the download"](https://github.com/omacom/omarchy-iso) |
| Published checksum | `https://iso.omarchy.org/omarchy-4.5.0-x86.iso.sha256` |
| SHA-256 | `5d6288bc57f96f6231719830457582c846a2291985201c36a9a7d1216978b00f`; `sha256sum -c`: OK |
| Signature | `https://iso.omarchy.org/omarchy-4.5.0-x86.iso.sig`, made 2026-11-05 05:58:41 CET |
| Signing key | `40DFB630FF42BCFFB047046CF0134EE680CAC571` (EdDSA), fetched from `hkps://keys.openpgp.org` into a temporary `GNUPGHOME`, discarded afterwards |
| `gpg --verify` | `Good signature from "Omarchy <pkgs@omarchy.org>"`; the expected "not certified with a trusted signature" warning only |
| Inner root image | `arch/x86_64/omarchy-root.img.zst` matched its bundled SHA-256 `40dd61f3d9a7e5d8cf86736a8e5a577e5217db65865ad7f895c025876b2f3f8d` |
| Package | `omarchy 4.5.0-3`, URL `https://github.com/omacom/omarchy`, inside the root image |

The verification resolves TODO-007; DEC-021 is not reopened. Raw outputs are in
ignored `evidence/shell-panels/inventory-20261107T001818Z/`.

### Extraction method

Omarchy 4.0.6 shipped the `omarchy` package in the ISO's offline mirror, so it
was read with `bsdtar` and `unsquashfs`. Omarchy 4.5 no longer does: its
installer writes a pre-built btrfs root image (`omarchy-root.img.zst`) and the
package is already installed inside it. `btrfs restore` could not read that
image's zstd-compressed extents ("zstd frame incomplete"; 565 of 873 files
under `/usr/share/omarchy` restored empty), so it was rejected.

With maintainer authorization, the image was decompressed to `/var/tmp`, mapped
read-only with `udisksctl loop-setup -r`, mounted read-only (`ro`) by udisks,
and the package's files were copied to `/tmp/omarchy-45/root`. The loop device
and the decompressed image were removed afterwards.

- All 1,648 package files listed in the package `mtree` matched their SHA-256,
  except `usr/share/omarchy/install/helpers/logging.sh`, which the image build
  modified after installation (installer helper, not panel code). `.BUILDINFO`
  and `.PKGINFO` are package metadata and are not installed.
- `usr/share/omarchy/{default,config}` are not owned by the 4.5 package; they
  were copied from the same verified image.
- The 4.0.6 `default/` and `config/` trees, absent from the `omarchy 4.0.6-1`
  package, were extracted read-only from the 4.0.6 ISO squashfs into
  `/tmp/omarchy-406/live-share`. Their `omarchy-menu.jsonc` and `looknfeel.lua`
  hashes match the ones already cited in the shell and Hyprland `UPSTREAM.md`.

## Shared panel container

All five panels are bar-anchored popouts hosted by `shell/Ui/KeyboardPanel.qml`
through `shell/Ui/Panel.qml`, with the shared panel UI pieces. In 4.5:

| File | 4.5 lines | Notes |
| --- | ---: | --- |
| `Ui/KeyboardPanel.qml` | 575 | Layer-shell popout. New in 4.5 against the MirrorOS copy (453): card publication, a morph animation from the previous card and `heldTarget` hand-over when switching between panels (206 differing lines). |
| `Ui/Panel.qml` | 60 | Lifecycle, settings and Omarchy `ShellIpc`; not imported by MirrorOS. |
| `Ui/PanelController.qml`, `PanelKeyCatcher.qml` | 16, 100 | Already copied unchanged from the 4.5-equivalent source. |
| `Ui/PanelSlider.qml` | 159 | Used by audio and display; not yet in MirrorOS. |
| `Commons/ShellIpc.qml`, `IpcRegistry.qml` | 12, 77 | Omarchy IPC; excluded by ADR 0012 and the shell `UPSTREAM.md`. |

Omarchy 4.5 binds the panels with `SUPER+CTRL+A` (audio), `B` (Bluetooth),
`D` (display), `N` (network) and `P` (power), plus `SUPER+CTRL+<1-9>` for
"bar panel N". In 4.0.6 network was `SUPER+CTRL+W`, which DEC-006 retains;
4.5 moved it to `N` and reassigned nightlight. No binding is decided here.

## Per-panel inventory (Omarchy 4.5)

Line counts are `wc -l` physical lines. Each panel directory also has a 20-line
`manifest.json` that is excluded from any implementation. "Helpers to replace"
are upstream executables the panel invokes; none is imported or executed.

### Audio

| Criterion | Omarchy 4.5 |
| --- | --- |
| Functions | Output and input device lists with default selection; output/input level and mute; mute-all; per-application stream levels with MPRIS-derived labels; input peak meter (typed sources only); headphone and port availability; DSP/EasyEffects volume-sink resolution; OSD feedback; platform node hiding; virtual (untyped) input sources through `wpctl` (new in 4.5). |
| Files and lines | `audio/Panel.qml` 1363, `audio/Model.js` 304; `Commons/AudioNodes.qml` 50, `AudioNodesModel.js` 96, `UntypedInput.qml` 152; `Ui/PanelSlider.qml` 159. Panel and model total 1667. |
| Helpers to replace | `omarchy-audio-output-sink` (97), `omarchy-audio-sink-availability` (67, calls `omarchy-audio-tuning`), `omarchy-audio-output-set-default` (32), `omarchy-audio-input-set-default` (28). |
| Dependencies | `Quickshell.Services.Pipewire`, `Quickshell.Services.Mpris`, `Quickshell.Io`; PipeWire, WirePlumber, `wpctl`, `pactl` (Pulse-compatible server), `pw-link`; optional EasyEffects. |
| Persistent writes | No `shell.json` write. Default devices, levels and mute persist through WirePlumber state. The 4.5 panel watches `$XDG_CONFIG_HOME/easyeffects/db/easyeffectsrc` directly (a personal-configuration read). |
| Privileges and credentials | None; user session only. |
| Testability | Laboratory with the planned emulated audio device and a second virtual sink (DEC-027): device switching, levels, mute, ports and the unavailable state. Laptop: real jacks, hotplug, Bluetooth outputs and DSP routing. |

### Network / Wi-Fi

| Criterion | Omarchy 4.5 |
| --- | --- |
| Functions | Wired and Wi-Fi state; radio toggle; scan and network list; connect (open, OWE, PSK) with passphrase prompt and re-prompt on failure; enterprise PEAP/MSCHAPv2; disconnect and forget; band selection; DNS provider pills; connectivity check with native NetworkManager captive-portal detection and an explicit sign-in action (new helper in 4.5); throughput, ping and detail header; active-AP signal polling (new in 4.5); QR sharing and speed test as separate panels. |
| Files and lines | `network/Panel.qml` 2141, `network/Model.js` 452; total 2593. |
| Helpers to replace | `omarchy-network-status` (137), `omarchy-network-band` (192), `omarchy-dns` (319), `omarchy-network-captive-portal` (123, new in 4.5; pauses a Tailscale exit node, opens a web app), `omarchy-launch-floating-terminal-with-presentation` (14); the `omarchy.wifiqr` and `omarchy.speedtest` panels. |
| Dependencies | `Quickshell.Networking` (native WifiNetwork connect, PSK, disconnect, forget), `Quickshell.Io`; NetworkManager, `nmcli`, `ip`, `iw`, `ping`, `jq`, `wl-copy`, `uuidgen`; a browser/web app for captive portals. |
| Persistent writes | No `shell.json` write. NetworkManager profiles and their secrets (PSK, enterprise identity and password), band selection in the profile. `omarchy-dns` writes `/etc/systemd/resolved.conf` and `/etc/NetworkManager/conf.d/20-omarchy-dns.conf` and reloads NetworkManager and resolved. |
| Privileges and credentials | Passphrase entry in QML; PSK passed to NetworkManager through the native API; enterprise password piped on stdin to `nmcli connection edit` (kept off argv). `omarchy-dns` re-executes through `sudo`/`pkexec` with a passwordless `sudoers` grant; this conflicts with ADR 0024 (NetworkManager owns DNS policy). Captive-portal helper calls the local `tailscaled` API. QR sharing exposes the PSK. |
| Testability | Laboratory: wired state, connectivity and unavailable radio. Laptop (T14s, supervised): Wi-Fi scan and PSK connection. Enterprise, OWE, band, captive portal and DNS need dedicated networks and are not exercised in this plan. |

### Bluetooth

| Criterion | Omarchy 4.5 |
| --- | --- |
| Functions | Adapter power toggle; discovery with bounded lifecycle; paired, connected and available device sections; pair, connect, disconnect and forget; automatic switch to a newly connected Bluetooth audio output. |
| Files and lines | `bluetooth/Panel.qml` 1049, `bluetooth/Model.js` 177; total 1226. |
| Helpers to replace | `omarchy-bluetooth-device` (52), `omarchy-bluetooth-power` (89), `omarchy-audio-output-set-default` (32). |
| Dependencies | `Quickshell.Bluetooth`, `Quickshell.Services.Pipewire`, `Quickshell.Io`; BlueZ, `bluetoothctl`, `rfkill`; `bt-agent` (`bluez-tools`) user unit. |
| Persistent writes | No `shell.json` write. BlueZ pairing and trust store; rfkill soft block restored at boot by `systemd-rfkill`. |
| Privileges and credentials | Pairing runs `bluetoothctl pair` non-interactively with output discarded, then `trust` and `connect`. Confirmation is delegated to the `bt-agent -c NoInputNoOutput` user unit enabled at first run, so PIN and passkey entry has no UI (TODO-002). |
| Testability | Laboratory: unavailable state only (no adapter, no passthrough). Laptop (T14s, supervised, no UI): agent behaviour with PIN and passkey devices. |

### Display

| Criterion | Omarchy 4.5 |
| --- | --- |
| Functions | Per-display brightness (backlight, DDC, Apple); output enable and disable with a last-display guard; scale presets; text size; OSD feedback. |
| Files and lines | `monitor/Panel.qml` 944, `monitor/Model.js` 127; total 1071; `Ui/PanelSlider.qml` shared. |
| Helpers to replace | `omarchy-monitor-state` (23), `omarchy-brightness-display` (149; calls DDC, Apple, platform and OSD helpers), `omarchy-hyprland-monitor-scaling` (264), `omarchy-display-text-size` (236). |
| Dependencies | `Quickshell.Io`; Hyprland (`hyprctl`, `hl.monitor`), `jq`, `brightnessctl`, optional `ddcutil`. |
| Persistent writes | No `shell.json` write. Scaling writes a per-monitor rule into the user's Hyprland `monitors.lua` and, new in 4.5, a session-wide `GDK_SCALE`. Text size writes shell font overrides, GTK `gsettings` and terminal font configuration. |
| Privileges and credentials | None; backlight access through the user session. |
| Testability | Laboratory: one virtual output; no backlight. Laptop: backlight, external monitor, scale. MirrorOS already owns brightness and `display` commands from plan 02-25. |

### Power

| Criterion | Omarchy 4.5 |
| --- | --- |
| Functions | Battery state, percentage, rate and remaining time; percentage display toggle; power-profile selection with separate AC and battery choices; CPU and memory snapshot; hidden when no battery. |
| Files and lines | `power/Panel.qml` 548, `power/Model.js` 127; total 675. |
| Helpers to replace | `omarchy-battery-status` (231; reworked in 4.5 for non-`BAT*` batteries and missing rates), `omarchy-powerprofiles-list` (17), `omarchy-powerprofiles-set` (64), `omarchy-system-stats` (61). |
| Dependencies | `Quickshell.Services.UPower`, `Quickshell.Io`; UPower, battery sysfs, `power-profiles-daemon` (`powerprofilesctl`), `busctl`, `top`. |
| Persistent writes | `shell.json` `showPercentage` (inline entry update); `$XDG_STATE_HOME/omarchy/powerprofiles/{ac,battery}`. |
| Privileges and credentials | None; profiles through the system daemon's D-Bus policy. |
| Testability | Laboratory: no battery; the panel stays hidden. Laptop: battery, AC transitions, profiles. MirrorOS already owns `power-profile` from plan 02-25; the power watcher stays outside the shell (DEC-015). |

## Media and VPN sources

- **Shell media service:** `shell/plugins/services/media/` — `Service.qml` 553,
  `MediaModel.js` 201, `BarWidget.qml` 324 (MPRIS and PipeWire playback
  streams, active-player selection, track OSD). 4.0.6 already had it
  (523/142/314). In 4.5 `media.lua` routes media keys to `{ ipc = "media.*" }`
  instead of `omarchy-shell media ...`; MirrorOS uses the `playerctl` command
  boundary from plan 02-25. The audio panel uses MPRIS only for stream labels.
- **VPN design reference:** `panels/tailscale/` (2626 lines without the
  manifest; 4.0.6: 2358). It shows status, connect and disconnect, account switching,
  exit-node selection, peer browsing and copy actions, and Taildrop. It drives
  the `tailscale` CLI and requests the operator role with
  `pkexec tailscale set --operator=<user>`. `omarchy-network-captive-portal`
  pauses a Tailscale exit node during sign-in. `omarchy-install-service-nordvpn`
  installs an AUR client with `sudo`. No OpenConnect material exists in 4.5;
  the MirrorOS VPN helper prototype remains the in-scope reference.

## Extra panels (inventory only)

Not compared, prototyped or covered by the ADR unless approved at the gate
(DEC-026). Totals exclude `manifest.json`.

| Panel | Lines | Since | Description |
| --- | ---: | --- | --- |
| `clock` | 1339 | 4.0.6 (`WallClock.qml` new) | Date/time label with a calendar popup; outside this plan (TODO-008). |
| `disk-speedtest` | 151 | 4.0.6 | Disk write and read speed dials. |
| `dropbox` | 1179 | 4.0.6 | Dropbox status, storage, login and recent files (includes a Python helper). |
| `elsewhen` | 6409 | 4.5 | World clock with a spinnable globe. |
| `speedtest` | 207 | 4.0.6 | Internet speed test dials; invoked from the network panel. |
| `tailscale` | 2626 | 4.0.6 | VPN design reference above. |
| `weather` | 1341 | 4.0.6 | Weather pill with detail popup. |
| `wifiqr` | 406 | 4.0.6 | Connected Wi-Fi network as a QR code; exposes the PSK. |

## Differences from 4.0.6 in existing MirrorOS sources

Compared without changing existing code, for every source path in
`capabilities/desktop/shell/UPSTREAM.md` and for `media.lua`. "Changed" counts
`diff` lines between 4.0.6 and 4.5.

The shell's general pin, Omarchy `7075b61c`, is a revision between 4.0.6 and
4.5, not 4.0.6. Of the 44 `Copied` files, 11 are identical in 4.0.6 and 4.5,
14 match 4.5 only, one matches 4.0.6 only (`Ui/PanelToolTip.qml`) and 18 match
neither: `Ui/Button.qml`, `Ui/KeyboardPanel.qml`, `Ui/OpticalGlyph.qml`,
`Ui/PopupCard.qml`, `bar/widgets/KeyboardLayoutModel.js`, `bar/widgets/Tray.qml`
and the 12 copied notification files. `LICENSE.omarchy` is not shipped in the
package. `Commons/I18n.qml`, `InputDevices.qml`, `Numbers.js`, `Plural.js`,
`Ui/BarIconContent.qml`, `FilterInput.qml`, `IconContentBounds.qml`,
`OverlayWindow.qml`, `default/i18n/en/shell.json` and the split notification
files do not exist in 4.0.6.

Notable 4.5 changes in the panel-relevant sources:

| MirrorOS destination | Source | 4.0.6 → 4.5 lines | Changed | 4.5 change |
| --- | --- | --- | ---: | --- |
| `Ui/KeyboardPanel.qml` | `shell/Ui/KeyboardPanel.qml` | 419 → 575 | 242 | Card morph and hand-over between panels. |
| `bar/widgets/Audio.qml` | `panels/audio/Panel.qml` | 1249 → 1363 | 236 | Untyped virtual inputs, platform node hiding, primitive row snapshots against a PipeWire removal segfault, EasyEffects watch, I18n. |
| `bar/widgets/Network.qml`, `bar/NetworkModel.js` | `panels/network/{Panel.qml,Model.js}` | 1971 → 2141, 380 → 452 | 374, 168 | Native captive-portal state and sign-in helper, OWE transition handling, active-AP signal poll, DNS focus section. |
| `bar/widgets/Bluetooth.qml`, `bar/BluetoothState.qml` | `panels/bluetooth/Panel.qml` | 1046 → 1049 | 75 | I18n and hero status only; `Model.js` unchanged. |
| `bar/widgets/Monitor.qml` | `panels/monitor/Panel.qml` | 936 → 944 | 40 | Keeps mode, position and scale when re-enabling a display. |
| `bar/widgets/Power.qml`, `bar/PowerModel.js` | `panels/power/{Panel.qml,Model.js}` | 537 → 548, 104 → 127 | 111, 35 | Localized readings; deferred close without battery. |
| `osd/Osd.qml` | `shell/plugins/osd/Osd.qml` | 207 → 205 | 20 | Minor. |
| `bar/Bar.qml`, `bar/BarModel.js` | `shell/plugins/bar/*` | 2093 → 3222, 231 → 728 | 2237, 669 | Large rework; new indicators and widgets; not studied further. |
| `notifications/Service.qml` | `shell/plugins/notifications/Service.qml` | 1063 → 1664 | 2365 | Rebuilt; 4.5 has no `NotificationPanel.qml`, `Picker.qml` or `Settings.js`. |
| `hardware-bindings.lua` (Hyprland) | `default/hypr/bindings/media.lua` | 34 → 39 | — | Volume and brightness bound to `{ audio = ... }`/`{ brightness = ... }` tables, media keys to `{ ipc = "media.*" }`, `CTRL+XF86MonBrightness*` for MacBook keyboard backlight. |

The panel helpers changed little: `omarchy-network-band`, `omarchy-dns`,
`omarchy-bluetooth-{device,power}`, `omarchy-monitor-state` and
`omarchy-powerprofiles-list` are identical; `omarchy-battery-status` (+94) and
`omarchy-hyprland-monitor-scaling` (+61) grew most. None of these differences
changes the plan 02-26 approach, so DEC-021 stands. Per-file diffs are in the
inventory evidence.

## Alternatives shortlist

Status: Approved by the maintainer on 2026-11-07 without changes (DEC-022
mini-gate). The nine shortlisted candidates below enter the comparison matrix.

Discovery ran on 2026-11-07 through web search, the GitHub API and GitLab API,
and the Omarchy plugin registry (`omacom/omarchy-plugin-marketplace`
`registry.json`, 6,334 plugin sources; 244 matched panel keywords). Only
metadata and READMEs were read; nothing was cloned, installed or run. Stars and
dates are point-in-time signals as of that day. The registry snapshot of the
matched plugins is in ignored `evidence/shell-panels/shortlist-20261107/`.

License classification: GPL-2.0-or-later, GPL-3.0 (any variant), MIT and
Apache-2.0 are compatible with `GPL-3.0-only` for code reuse; AGPL-3.0 and
licenses without a clear grant are design reference only. Where the repository
ships the GPL-3.0 text without a version statement, the variant is recorded as
unstated; both variants are compatible.

### (a) Quickshell shells

| Candidate | License | Activity | Adoption | Compatibility | Reason |
| --- | --- | --- | --- | --- | --- |
| [Caelestia](https://github.com/caelestia-dots/shell) | GPL-3.0 (variant unstated) | Push 2026-11-05; release v2.5.0 (2026-09-18) | 13,267 stars | Quickshell (QML plus a C++ plugin); Hyprland is its primary target | Same toolkit and compositor; reusable license |
| [Dux Modular Shell](https://github.com/duxlabs-dev/dux-shell) (formerly DankMaterialShell) | MIT | Push 2026-11-07; release v2.1.1 (2026-11-06) | 8,822 stars | Quickshell QML with a Go backend (`dms`); supports Hyprland | Complete network, Bluetooth and audio surfaces; backend is a cost to assess against ADR 0012 |
| [illogical-impulse](https://github.com/end-4/dots-hyprland) (end-4) | GPL-3.0 (variant unstated) | Push 2026-10-11; release 2026.05.11 | 16,553 stars | Quickshell QML; Hyprland-first | Highest adoption; reusable license |

### (b) Omarchy community plugins

Adoption is low across the whole category: the most-starred panel-related
plugin has 67 stars. Plugins target the Omarchy 4 plugin API, not the MirrorOS
shell, so any reuse needs adaptation.

| Candidate | License | Activity | Adoption | Compatibility | Reason |
| --- | --- | --- | --- | --- | --- |
| [omarchy-vpn](https://github.com/jkoestinger/omarchy-vpn) | MIT | Push 2026-09-19 | 38 stars | Omarchy Quickshell plugin; drives NetworkManager OpenConnect, OpenVPN and WireGuard profiles plus an `omarchy-openconnect-auth` helper | Only general VPN panel; directly relevant to graphical VPN access |
| [omarchy-audio-control](https://github.com/ssupt/omarchy-audio-control) | MIT | Push 2026-10-24 | 18 stars | Omarchy Quickshell plugin with a Rust backend service; registry baseline `review-required` (bundled binary, service management) | Extends the stock audio panel with routing, scenes and output groups |
| [omarchy-bluetooth-audio](https://github.com/ssupt/omarchy-bluetooth-audio) | MIT | Push 2026-10-31 | 9 stars | Omarchy Quickshell plugin with a Rust backend service; registry baseline `review-required` (bundled binary) | Extends the stock Bluetooth panel with pairing failure reasons, retry and codec modes |

### (c) Dedicated tools

| Candidate | License | Activity | Adoption | Compatibility | Reason |
| --- | --- | --- | --- | --- | --- |
| [network-manager-applet](https://gitlab.gnome.org/GNOME/network-manager-applet) (`nm-applet`, `nm-connection-editor`) | GPL-2.0-or-later (`GPL-2.0+` source headers) | Commits 2026-10-20; last tag 1.36.0 (2024-01-19) | GNOME project; packaged in Arch `extra` | NetworkManager GUI with a secret agent and VPN plugin auth dialogs | Reference for credential entry and OpenConnect access |
| [Blueman](https://github.com/blueman-project/blueman) | GPL-3.0-or-later (README: any later version) | Push 2026-10-21; release 2.4.6 (2025-07-01) | 1,586 stars | BlueZ GUI with its own pairing agent | Reference for PIN and passkey pairing (TODO-002) |
| [pwvucontrol](https://github.com/saivert/pwvucontrol) | GPL-3.0 (variant unstated) | Push 2026-08-21; release 0.5.3 (2026-07-08) | 704 stars | PipeWire-native GUI mixer | Reference for output and input switching |

### Rejected candidates

| Candidate | Category | Failed filter or reason |
| --- | --- | --- |
| [Noctalia](https://github.com/noctalia-dev/noctalia) (MIT, 11,858 stars) | (a) | Compatibility: since v5 it is a native C++ shell, no longer Quickshell. Design reference only |
| [Ambxst](https://github.com/Axenide/Ambxst) (1,882 stars) | (a) | License: AGPL-3.0, design reference only; lower adoption than the three shortlisted shells |
| [omaproton-vpn](https://github.com/grichard99/omaproton-vpn) (MIT, 67 stars) | (b) | Compatibility: Proton VPN only, not NetworkManager or OpenConnect profiles |
| [omarchy-display-manager](https://github.com/Bmontythe3rd/omarchy-display-manager) (MIT, 12 stars) | (b) | Category cap: multi-monitor arrangement beyond the Omarchy display panel; adds a background service |
| [omarchy-network](https://github.com/Guneshbari/omarchy-network) (MIT, 6 stars) | (b) | Adoption, and registry baseline `needs-fixes` (privilege, package manager); hotspot and repeater are out of scope |
| [omarchy-anyconnect-sso](https://github.com/CIKR-Repos/omarchy-anyconnect-sso) | (b) | Adoption, and registry baseline `review-required` (privilege, package manager) |
| [impala](https://github.com/pythops/impala) (GPL-3.0, 2,890 stars) | (c) | Compatibility: requires iwd, while MirrorOS uses NetworkManager ([ADR 0024](../adr/0024-networkmanager-resolved-dns-integration.md)) |
| [bluetui](https://github.com/pythops/bluetui) (GPL-3.0, 3,072 stars) | (c) | Category cap: terminal UI; Blueman is the graphical pairing-agent reference |
| [overskride](https://github.com/kaii-lb/overskride) (GPL-3.0, 915 stars) | (c) | Maintenance: last release 2026-01-02; lower adoption than Blueman |
| [wiremix](https://github.com/tsowell/wiremix) (MIT OR Apache-2.0, 1,090 stars) | (c) | Category cap: terminal UI; no GitHub releases; pwvucontrol is the graphical reference |
| [pavucontrol](https://gitlab.freedesktop.org/pulseaudio/pavucontrol) | (c) | Compatibility: PulseAudio API; pwvucontrol is PipeWire-native |
| [networkmanager-dmenu](https://github.com/firecat53/networkmanager-dmenu) (MIT, 1,006 stars) | (c) | Not a panel: launcher menu |

## Comparison matrix

On 2026-11-07 each approved candidate was read as source at a pinned commit, as
an archive extracted outside the repository (`/tmp/shell-panels-candidates`).
Nothing was built, installed or run. Line counts are `wc -l` over the panel's
QML/JS (and backend sources where noted), excluding tests and generated mocks.
They are approximate, because shells share widgets across surfaces. File trees,
pinned commits and counts are in ignored
`evidence/shell-panels/comparison-20261107/`. No candidate needed to be seen
running, so nothing is deferred to Task 4.

### Candidate licenses

| Candidate | Commit | License | Classification |
| --- | --- | --- | --- |
| Caelestia | `bcbb5d5` | GPL-3.0 (variant unstated) | Code reuse compatible |
| Dux Modular Shell | `c97e462` | MIT | Code reuse compatible |
| illogical-impulse | `2f2a376` | GPL-3.0 (variant unstated) | Code reuse compatible |
| omarchy-vpn | `e0f2d97` | MIT | Code reuse compatible |
| omarchy-audio-control | `c822e48` | MIT | Code reuse compatible; ships a prebuilt backend binary next to its Rust source |
| omarchy-bluetooth-audio | `8d0c9b7` | MIT | Code reuse compatible; ships a prebuilt backend binary (`bin/omarchy-bluetooth-service`) next to its Rust source |
| network-manager-applet | `57f6d32` | GPL-2.0-or-later | Code reuse compatible (C/GTK, design reference in practice) |
| Blueman | `ec7c9d2` | GPL-3.0-or-later | Code reuse compatible (Python/GTK, design reference in practice) |
| pwvucontrol | `b732c20` | GPL-3.0 (variant unstated) | Code reuse compatible (Rust/GTK, design reference in practice) |

Omarchy 4.5 is the reference column; its full criteria are in the per-panel
inventory above, and its rows below only summarize it.

### Audio matrix

| Source | Functions | Files and lines | Helpers to replace | Dependencies | Persistent writes | Privileges and credentials | Testability | Extra functionality |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Omarchy 4.5 (reference) | Output/input selection, levels, mute, per-app streams, ports, DSP sink, virtual inputs | 1667 plus shared slider | Four `omarchy-audio-*` scripts | Quickshell PipeWire and MPRIS, `wpctl`, `pactl`, `pw-link` | WirePlumber state; reads EasyEffects config | None | Laboratory with emulated audio (DEC-027) | Untyped virtual inputs |
| Caelestia | Output/input selection, levels, mute, per-app volumes | 566 | None (native `Pipewire.preferredDefaultAudio*`) | Quickshell PipeWire; C++ plugin for the visualizer | `caelestia/shell.json` settings | None | Laboratory | Audio visualizer |
| Dux Modular Shell | Output/input selection, levels, mute, ports, per-app streams | 2569 QML | `pactl`, `wpctl` calls inside the service | Quickshell PipeWire, `pactl`, `wpctl`; `dms` Go backend for the shell | DMS settings under `$XDG_CONFIG_HOME` | None | Laboratory | Port selector, output OSD |
| illogical-impulse | Output/input selection, levels, per-app mixer | 512 | `pavucontrol` launcher | Quickshell PipeWire, `wpctl` | `illogical-impulse/config.json` | None | Laboratory | Overlay mixer |
| omarchy-audio-control | Per-app routing, scenes, output groups, profiles, microphone test, diagnostics | 8375 QML plus 11047 Rust | Rust `omarchy-audio-service` (user unit) and shell scripts | Omarchy plugin API, PipeWire, Rust backend | Scenes and routing under `$XDG_CONFIG_HOME`; installs a systemd user unit | None; a background service conflicts with ADR 0012 | Laboratory, partially (routing) | Persistent routing and multi-output groups |
| pwvucontrol | Full mixer: devices, streams, profiles, ports, routing | 5017 Rust | Not applicable (standalone application) | GTK4, `pipewire` and `wireplumber` Rust crates | WirePlumber state | None | Laboratory | Per-stream routing, channel volumes |

Not covered by: omarchy-vpn, omarchy-bluetooth-audio, network-manager-applet,
Blueman.

### Network / Wi-Fi matrix

| Source | Functions | Files and lines | Helpers to replace | Dependencies | Persistent writes | Privileges and credentials | Testability | Extra functionality |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Omarchy 4.5 (reference) | Wired/Wi-Fi state, scan, PSK and enterprise connect, forget, band, DNS, captive portal, details | 2593 | Five scripts, including `omarchy-dns` | `Quickshell.Networking`, NetworkManager, `nmcli` | NM profiles; `omarchy-dns` writes `/etc` | PSK via native API; enterprise password on stdin; DNS through `sudo`/`pkexec` (conflicts with ADR 0024) | Laboratory wired; T14s PSK | QR and speed-test panels |
| Caelestia | Wired/Wi-Fi state, scan, PSK connect, saved networks, Ethernet details, add network | 5383 | `nmcli` wrapper service (`Nmcli.qml`) | `nmcli`, Quickshell | NM profiles | PSK passed on the `nmcli` command line (visible in the process list) | Laboratory wired; T14s PSK | Ethernet detail and saved-network pages |
| Dux Modular Shell | Wired/Wi-Fi state, scan, PSK and enterprise, hotspot, cellular, details, QR | 3418 QML plus 17993 Go | `dms` Go backend (NetworkManager D-Bus, also iwd and networkd) | `dms` daemon, NetworkManager D-Bus | NM profiles; DMS settings | NetworkManager secret agent in the Go backend; prompts in a QML modal; uses `pkexec` only for the `wpa_supplicant` Ethernet backend | Laboratory wired; T14s PSK | Hotspot, cellular, 802.1X Ethernet |
| illogical-impulse | Wi-Fi state, scan, connect, PSK retry, radio toggle | 531 | None beyond `nmcli` calls | `nmcli`, Quickshell | NM profiles; `illogical-impulse/config.json` | PSK passed through the environment to `nmcli connection modify` (kept off argv) | Laboratory wired state; T14s PSK | None significant |
| network-manager-applet | Tray menu, all connection types, connection editor | 37281 C (whole applet) | Not applicable | GTK, libnm, libsecret | NM profiles; agent-owned secrets in the user keyring | Full NetworkManager secret agent; secrets stored in libsecret or NetworkManager | T14s (tray) | Enterprise, mobile broadband, VPN plugin editors |

Not covered by: omarchy-audio-control, omarchy-bluetooth-audio, Blueman,
pwvucontrol. omarchy-vpn covers VPN only (below).

### Bluetooth matrix

| Source | Functions | Files and lines | Helpers to replace | Dependencies | Persistent writes | Privileges and credentials | Testability | Extra functionality |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Omarchy 4.5 (reference) | Power, discovery, pair, connect, forget, audio switch | 1226 | `omarchy-bluetooth-device`, `-power`, audio output | `Quickshell.Bluetooth`, `bluetoothctl`, `bt-agent` | BlueZ store | `bt-agent -c NoInputNoOutput`: no PIN or passkey UI (TODO-002) | Laboratory unavailable; T14s without UI | None |
| Caelestia | Power, discovery, pair, connect, device info | 883 | None (native `device.pair()`) | `Quickshell.Bluetooth` | BlueZ store | No agent of its own; PIN and passkey depend on an external agent | Laboratory unavailable; T14s | Device detail page |
| Dux Modular Shell | Power, discovery, pair with PIN/passkey/confirmation modal, codecs | 2074 QML plus 2340 Go | `dms` Go backend | `dms` daemon, BlueZ D-Bus | BlueZ store; DMS settings | BlueZ agent with `KeyboardDisplay` capability in the Go backend (PIN, passkey, confirmation) | Laboratory unavailable; T14s | Codec selector |
| illogical-impulse | Power, discovery, pair, connect | 232 | None (native `device.pair()`) | `Quickshell.Bluetooth` | BlueZ store | No agent of its own | Laboratory unavailable; T14s | None |
| omarchy-bluetooth-audio | Pair with failure reasons and retry, rename, trust, block, forget, codec modes, audio on connect | 5969 QML plus 698 Rust | `bluetooth-device-action` (wraps `bluetoothctl`) and Rust service | Omarchy plugin API, `bluetoothctl`, `rfkill`, PipeWire | Per-device preferences; Rust service | No agent of its own; relies on Omarchy's `bt-agent` | Laboratory unavailable; T14s | Audio-on-connect policy |
| Blueman | Full manager, applet, agent, network and audio profiles | 15032 Python | Not applicable | GTK, BlueZ D-Bus, PulseAudio utilities | BlueZ store; GSettings | `KeyboardDisplay` agent with PIN, passkey and confirmation dialogs; polkit `blueman-mechanism` system service | T14s | PAN networking, file transfer |

Not covered by: omarchy-vpn, omarchy-audio-control, network-manager-applet
(Bluetooth tethering only), pwvucontrol.

### Display matrix

| Source | Functions | Files and lines | Helpers to replace | Dependencies | Persistent writes | Privileges and credentials | Testability | Extra functionality |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Omarchy 4.5 (reference) | Brightness, output enable/disable, scale, text size | 1071 | Four `omarchy-*` scripts | Hyprland, `brightnessctl`, `ddcutil` | `monitors.lua`, `GDK_SCALE`, font settings | None | Laboratory partial; laptop | None |
| Caelestia | Per-monitor brightness | 238 | `brightnessctl`, `ddcutil`, `asdbctl` | Quickshell, Hyprland monitor focus | None | None | Laboratory partial (no backlight) | Apple display brightness |
| Dux Modular Shell | Brightness, output configuration with confirmation, display profiles | 1543 QML plus 3774 Go | `dms` Go backend | `dms` daemon, wlr-output-management, logind, DDC | Display profiles in DMS settings | Brightness through logind `SetBrightness` | Laboratory partial; laptop | Timed confirmation and profiles |
| illogical-impulse | Per-monitor brightness | 271 | `brightnessctl`, `ddcutil` | Quickshell, Hyprland | `illogical-impulse/config.json` | None | Laboratory partial | Gamma OSD |

Not covered by: omarchy-vpn, omarchy-audio-control, omarchy-bluetooth-audio,
network-manager-applet, Blueman, pwvucontrol.

### Power matrix

| Source | Functions | Files and lines | Helpers to replace | Dependencies | Persistent writes | Privileges and credentials | Testability | Extra functionality |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Omarchy 4.5 (reference) | Battery, AC/battery profiles, stats | 675 | Four `omarchy-*` scripts | UPower, `power-profiles-daemon` | `shell.json`, profile state | None | Laptop only | Separate AC and battery profiles |
| Caelestia | Battery, remaining time, profile selection, degradation reason; battery monitor notifications | 353 | None (native UPower and PowerProfiles) | Quickshell UPower | None | None | Laptop only | Performance degradation reason |
| Dux Modular Shell | Battery detail and history chart, profile modal | 1853 | None (native UPower and PowerProfiles) | Quickshell UPower | Battery history cache; DMS settings | None | Laptop only | Battery history |
| illogical-impulse | Battery popup, profile toggle | 219 | None (native) | Quickshell UPower | `illogical-impulse/config.json` | None | Laptop only | None |

Not covered by: omarchy-vpn, omarchy-audio-control, omarchy-bluetooth-audio,
network-manager-applet, Blueman, pwvucontrol. Battery notifications in any
candidate overlap the power watcher, which stays outside the shell (DEC-015).

### VPN access (design input)

| Source | Functions | Files and lines | Dependencies | Privileges and credentials |
| --- | --- | --- | --- | --- |
| Omarchy 4.5 (reference) | Tailscale only | 2626 | `tailscale` CLI | `pkexec tailscale set --operator` |
| Caelestia | Generic `up`/`down` command providers (WireGuard, NetBird, Tailscale, WARP) | 838 | Configured commands | Built-in WireGuard provider uses `pkexec wg-quick` |
| Dux Modular Shell | NetworkManager VPN profiles, including OpenConnect, GlobalProtect and Fortinet SAML | 567 QML plus 2515 Go | `dms` NetworkManager backend | Secret agent prompts for OpenConnect passwords |
| illogical-impulse | Not covered | Not applicable | Not applicable | Not applicable |
| omarchy-vpn | NetworkManager OpenConnect, OpenVPN and WireGuard profiles plus five provider CLIs | 2254 (NetworkManager path) of 6262 | `nmcli`, NetworkManager-openconnect auth dialog | `omarchy-openconnect-auth` runs the NetworkManager-openconnect auth dialog without `nm-applet` and passes secrets to `nmcli` through a `umask 077` runtime file it deletes; AmneziaWG uses `sudo -n` or `pkexec` |
| network-manager-applet | All NetworkManager VPN plugins | Part of the applet | libnm, VPN plugin auth dialogs | Reference secret agent for VPN auth dialogs |

Not covered by: omarchy-audio-control, omarchy-bluetooth-audio, Blueman,
pwvucontrol.

### Findings for the gate

- **PIN and passkey pairing (TODO-002):** Omarchy, Caelestia,
  illogical-impulse and omarchy-bluetooth-audio register no interactive agent.
  Dux Modular Shell (Go backend) and Blueman (Python applet) register a
  `KeyboardDisplay` agent that handles PIN, passkey and confirmation.
  Quickshell's Bluetooth module (upstream `src/bluetooth`, read 2026-11-07)
  exposes `pair()` but no agent API, so an interactive agent means either a
  separate process or an external tool. Task 5 measures which behaviour the
  T14s needs.
- **Credential entry:** Caelestia puts the PSK on `nmcli` argv.
  illogical-impulse keeps it off argv through the environment. Omarchy 4.5 uses
  the native `Quickshell.Networking` API. Dux Modular Shell and
  network-manager-applet implement a NetworkManager secret agent. The native
  API, or a secret agent outside QML, are the patterns compatible with ADR 0012's
  "no authenticating QML" rule; this is assessed at the gate.
- **VPN access:** omarchy-vpn's `omarchy-openconnect-auth` matches the MirrorOS
  VPN helper prototype findings (OpenConnect through NetworkManager without
  `nm-applet`). Dux Modular Shell covers the same need through a resident
  daemon.
- **Architecture fit:** Dux Modular Shell's richest features depend on the
  resident `dms` daemon. The two ssupt plugins depend on a systemd user service.
  Both conflict with ADR 0012's exclusion of a background management service.
  Caelestia and illogical-impulse use Quickshell services and command helpers,
  as MirrorOS does, at lower line counts than Omarchy, but with fewer functions.

## Laboratory prototype

Approved by the maintainer on 2026-11-07 (Task 4). The shared container, the
audio panel and the network panel are built and reviewed, the run without
emulated audio is done and the bundle handoff is verified.

### Laboratory baseline

- Rollback point: the guest's own Limine snapshot (maintainer decision); no
  launcher checkpoint was taken and `~/qemu/mirroros-lab/checkpoints/` is empty.
- Launcher: optional `--audio` flag added to `~/qemu/mirroros-lab/vm` (local
  tooling outside the repository), adding `ich9-intel-hda` and `hda-duplex`
  backed by the SPICE audio channel with `--spice`, otherwise by host PipeWire.
  Documented in the laboratory README with a launcher test (6 tests pass); the
  previous launcher is kept as `vm.before-audio.<timestamp>.bak` [DEC-027].
- Guest booted with `vm boot --spice --gl --audio --ssh-port 2222`: one HDA
  card with an analog output and an analog input node.
- Base: host bundle of `ec84d74` (SHA-256
  `89522b0d1e2e5d2b003d84c4127c67aa41e32890c1f953b277f740b9ec01dd1d`), checksum
  verified in the guest, cloned on branch `story-4-4-panels-prototype`.
- `configure` at `ec84d74` was run in the guest, with sudo entered by the
  maintainer: all 19 step postconditions passed; only `system/audio` and
  `system/network` changed; `desktop/shell` was unchanged, so the prototype
  starts from the installed shell.
- Omarchy 4.5 source re-extracted read-only to `/tmp/omarchy-45` with the
  method in [Extraction method](#extraction-method): the compressed image
  stream matched its bundled SHA-256, the image was mapped and mounted
  read-only, the 279 `shell/` and `bin/` files matched the package `mtree`, and
  the loop device and decompressed image were removed.
- The prototype runs from the guest checkout as a transient user unit, with
  `mirroros-shell.service` stopped in the guest (maintainer authorization). A
  null sink created at runtime with `pactl load-module module-null-sink`
  provides the second output; it is not persisted.

### Shared container

`Ui/Panel.qml` from Omarchy 4.5 is reused with its `ShellIpc` handler replaced
by a plain Quickshell `IpcHandler` (6 changed lines), on top of the existing
`KeyboardPanel`, `PanelController` and `PanelKeyCatcher` and the bar's
`activePopout` coordinator. The audio bar widget becomes a `Panel` with IPC
target `mirroros.audio` (`open`, `close`, `show`, `hide`, `toggle`).

Maintainer check: bar anchoring, Escape and outside-click close, icon toggle,
replacement by another bar popup with the mouse, and keyboard navigation
inside the panel all behave as expected.

### Audio panel

Functions: hero with level name and a mute-all switch; output and input
sections with level percentage, slider and device rows with glyphs; default
selection through Quickshell's native `preferredDefaultAudioSink` and
`preferredDefaultAudioSource`; input peak meter, active only while the panel is
open; per-application mixer labelled from PipeWire properties only; an
unavailable or loading state without fabricated values; the WirePlumber dummy
sink is never listed and a null sink is marked "(virtual)".

| Source | Lines | Origin |
| --- | --- | --- |
| `Ui/PanelSlider.qml` | 159 | Omarchy 4.5, unchanged |
| `panels/audio/Model.js` | 304 | Omarchy 4.5, unchanged |
| `Ui/Panel.qml` | 64 | Omarchy 4.5, adapted (IPC handler) |
| `panels/audio/AudioPopup.qml` | 349 significant | Adapted: follows the 4.5 panel structure; 54% of significant lines textually present in 4.5 `audio/Panel.qml` |
| `panels/audio/AudioPanelModel.js` | 142 | New: pure model (cursor, state, filters, mixer rows) |
| `bar/widgets/Audio.qml` | +108 | New wiring on the existing widget |
| `Commons/i18n-en.json` | +6 keys | Values from the Omarchy 4.5 catalog |

Left out on purpose: DSP and EasyEffects volume-sink resolution, untyped
inputs through `wpctl`, MPRIS stream labels (pending the media service
decision, DEC-008) and every `omarchy-audio-*` helper. The existing
`ToggleSwitch`, `CursorSurface`, `PanelSectionHeader`, `PanelSeparator`,
`PanelKeyCatcher` and `PanelController` are byte-identical to 4.5;
`KeyboardPanel` and `PanelToolTip` are older versions and still compatible.

Tests: a prototype-local `audio-panel-model.test.mjs` (7 tests) and the existing
`audio-availability.test.mjs` (5 tests) pass in the guest.

Maintainer check: output switching between the emulated device and the virtual
sink, input selection, levels, mute and mouse control work; the panel matches
the Omarchy 4.5 panel observed on the T14s. Screenshots are kept in ignored
`evidence/shell-panels-prototype/lab-20261107/`.

### Network panel

Method: at the maintainer's request the Omarchy 4.5 panel is copied and
adapted rather than rewritten. A rewrite along the upstream structure and a
first copy that also pruned DNS and the captive portal were kept only as
ignored comparison material, not committed.

Functions: wired and Wi-Fi state with the metrics grid (ping, loss, receive
and transmit rates, address, gateway), connect and disconnect, Wi-Fi band
selection, per-connection DNS presets (DHCP, Cloudflare, Google and custom
entry in a terminal), captive-portal action, connectivity check, and an
unavailable state when NetworkManager is stopped. The MirrorOS missing-provider
glyph and tooltip are kept.

| Source | Lines | Origin |
| --- | --- | --- |
| `bar/widgets/Network.qml` | 2084 | Omarchy 4.5 `network/Panel.qml` (2141), adapted: 107 lines removed, 50 added |
| `panels/network/Model.js` | 452 | Omarchy 4.5, unchanged |
| `Ui/TextField.qml` | 58 | Omarchy 4.5, unchanged |
| `panels/network/bin/network-status` | 141 | Omarchy 4.5 `omarchy-network-status` (137), `omarchy-cmd-present` replaced by `command -v` |
| `panels/network/bin/network-band` | 195 | Omarchy 4.5 `omarchy-network-band` (192), renamed |
| `panels/network/bin/network-dns` | 203 | Adapted from Omarchy 4.5 `omarchy-dns` (319): per-connection DNS only |
| `Commons/i18n-en.json` | `network.*` keys | Values from the Omarchy 4.5 catalog |

Adaptations: `ShellIpc` replaced by an `IpcHandler` with target
`mirroros.network` (`open`, `close`, `show`, `hide`, `toggle`, `toggleNetwork`,
`openCaptivePortal`, `checkConnectivity`); QR and speed-test actions removed
(extra panels, DEC-026). `network-dns` writes only the Wi-Fi or Ethernet
profile's `ipv4.dns`, `ipv6.dns`, `ignore-auto-dns` and
`connection.dns-over-tls`, then reapplies the device; the global
NetworkManager `[global-dns]` drop-in, `resolved.conf` `DNS=`, `FallbackDNS=`
and `DNSOverTLS=`, `sudo`/`pkexec`, the passwordless sudoers rule and service
reloads are removed, and VPN profiles are untouched, so split DNS is preserved
[ADR 0024]. Custom DNS opens `uwsm app -- foot` with a done/failed wrapper.
The captive-portal action opens the Arch NetworkManager connectivity URI with
`xdg-open` instead of the Omarchy helper (Tailscale exit-node pause, Chromium
web app) and its `ping.omacom.io` endpoint.

Tests: a prototype-local `network-panel-model.test.mjs` (6 tests: status
parsing, throughput, band, rows, per-connection DNS boundary, no `omarchy-*`
calls) passes in the guest.

Maintainer check: container, wired metrics grid, removed items absent,
disconnect and reconnect, unavailable state while NetworkManager is stopped
and after it restarts, and the DHCP, Cloudflare, Google and custom DNS steps.
The NetworkManager audit showed four connection updates and device reapplies
as the session user with no polkit prompt in the guest; the final DNS state
matched the baseline. Intermediate `resolvectl` states were not captured.

### Run without emulated audio

The guest was restarted with `vm boot --spice --gl --ssh-port 2222` (no
`--audio`): no sound card, only WirePlumber's `auto_null` sink. With the
prototype running, the audio panel shows an "Unavailable" header and the
reason "No audio output; connect an audio device.", with no slider, device
row or level; `auto_null` is not listed. Screenshot in ignored
`evidence/shell-panels-prototype/lab-20261107/`.

### Handoff

- Source: guest branch `story-4-4-panels-prototype` at
  `053e7c304f6c93c30e5161ad263b3ebc41eb3176`, three commits over `ec84d74`.
- Bundle: incremental, requires
  `ec84d744778ed2efceb87760c959cfa82f86340f`. Guest and host SHA-256 matched:
  `326270bc47f5114080a6e08b044380763a5794d18a119fa38be134e2d063ae08`.
- `git bundle verify` passed in the guest and on the host; the bundle never
  entered the active host branch.
- Isolated review repository in ignored
  `evidence/shell-panels-prototype/handoff-053e7c3/review/`, clean on the
  prototype branch: 16 files, +4507/−12.
- Gitleaks (default rules, redacted) over the prototype history: no leaks.
- ShellCheck on the network helpers: info-level findings only (SC2030,
  SC2031, SC2086), the same as in the upstream helpers; `network-dns` is clean.
- Guest shell test suite: 81 tests, 79 pass, 0 fail, 2 environment skips.
- The prototype branch does not update `capabilities/desktop/shell/UPSTREAM.md`;
  the copied helpers carry an attribution header, the copied QML and
  JavaScript files do not. Production must record provenance.

### Findings

- The notifications panel has no open or toggle IPC function and no binding,
  so it cannot be reached from the keyboard; every production panel needs an
  open/toggle target.
- The bar audio glyph reflects the level and headphones, not the selected
  device.
- `qmllint` reports only `unqualified` and `missing-property` warnings for the
  new files, the categories already in the baseline; the baseline was not
  changed.
- `i18n-subset.mjs` cannot regenerate the catalog from Omarchy 4.5, because
  the notification keys exist only in the older catalog; production needs a
  decision on the catalog source.
- Quickshell reloads on file changes and loaded a half-copied tree once;
  production publication must stay atomic.
- Each bar instance per monitor declares the same IPC target.
- Persistence of the native default-device selection across sessions is not
  yet verified.
- MirrorOS fixes the panel outer gap at 5 px, while Omarchy derives it from
  half of Hyprland `gaps_out`; the measured gaps were equal and the perceived
  difference came from wallpaper contrast and resolution.
- `iw` is not in the MirrorOS packages; without it frequency, SSID and bit
  rate details are empty.
- `network-status` pings the gateway and `1.1.1.1` every 1.5 s while the
  panel is open, which is outbound traffic to a fixed third party.
- Band and DNS choices persist in NetworkManager profiles through
  unprivileged `nmcli`, allowed by polkit for the active session in the guest;
  this must be confirmed on the T14s.
- The DNS selection does not cover profiles created later, which ADR 0024
  requires of a DNS policy; the gate and the ADR must settle this.
- Dropping the global layer also drops `FallbackDNS` and global DNS over TLS.

Gate inputs raised so far: the input peak meter, which captures the default
source while the panel is open, was included at the maintainer's request; the
mixer without MPRIS; and the adaptation method, either rewriting along the
upstream structure (audio panel) or copying the upstream panel and adapting it
(network panel, maintainer choice).

## T14s evidence

Non-qualifying evidence collected on 2026-11-07 from the host over SSH, with
no agent on the T14s [DEC-002]. Network names, keys, hardware addresses,
profile identifiers, device names and pairing numbers are omitted. Redacted
summary in ignored `evidence/shell-panels/t14s-20261107/`.

### Setup

- Baseline: MirrorOS installed, production shell running; Wi-Fi is the only
  link (no Ethernet cable), one saved WPA2 profile on 5 GHz; `iw` not
  installed; Bluetooth with three paired devices, none using legacy PIN
  pairing, not pairable and not discoverable.
- Delivery: the base bundle (`ec84d74`) and the prototype bundle (`053e7c3`)
  were copied to a temporary directory, their checksums matched, `git bundle
  verify` passed and the prototype branch was cloned clean. The prototype
  model tests passed there (audio 7, network 6, audio availability 5).
- The prototype ran as a separate Quickshell instance in a transient user
  unit; the production shell kept running with the same process throughout.

### Wi-Fi through the prototype

- The maintainer disconnected, forgot and reconnected the network from the
  prototype panel, typing the PSK. NetworkManager recorded the disconnect,
  delete and add-and-activate operations from the prototype as the session
  user, all successful, with no sudo and no polkit prompt.
- The panel passes the PSK to `nmcli` on standard input, not on the command
  line. The resulting profile is system-wide and NetworkManager stores the
  secret in its root-only system keyfile (`psk-flags=0`).
- Without `iw` the band selector does not work, because `network-band` reads
  the link SSID and frequency from `iw`. With `iw` installed temporarily, the
  selector moved the link to 2.4 GHz and back to automatic, through
  unprivileged profile updates and reactivations. The panel never shows the
  frequency, channel or bit rate.
- Two DNS preset changes were recorded without the maintainer intending
  them. Each rewrote every saved Wi-Fi and Ethernet profile, not only the
  active one; the DHCP preset restored both.
- The packet-loss value turned red often. A direct measurement showed no
  loss to the router or `1.1.1.1` but high latency variation; the panel's
  single ping every 1.5 s with a 1 s timeout over a short window turns red on
  any lost sample.

### Bluetooth pairing agent (no UI)

- `NoInputNoOutput` agent in `bluetoothctl`, as in Quattro, pairing initiated
  from a phone: "Just Works"; the phone only asked for consent and no code
  appeared on either side, so the pairing has no man-in-the-middle
  protection. The phone was bonded but not trusted, and the agent then
  received `AuthorizeService` requests for its service connections.
- `KeyboardDisplay` agent: numeric comparison; both sides showed the same
  number and the maintainer confirmed on both. `AuthorizeService` requests
  followed again.
- Legacy PIN pairing could not be exercised: no available device uses it.
- Evidence for TODO-002: passkey or numeric comparison needs an agent that
  can show and confirm a number, and any agent must also answer service
  authorization (accept, reject or trust at pairing). Quickshell has no agent
  API, so the agent's owner is a gate decision.

### Findings

- `iw` is required for the band selector; MirrorOS does not install it.
- Band pills carry two marks, the current radio band and the chosen band;
  during a switch both are marked until the reconnection finishes, and the
  keyboard cursor is a third, hard-to-distinguish indication. Production
  should show the switch as in progress and style the three states apart.
- There is no double-click protection; each click issues a new profile
  update and reactivation.
- One click or Enter on a DNS preset rewrites every saved profile without
  confirmation, and the change persists.
- The packet-loss indicator is too sensitive for Wi-Fi.
- Profile changes from the session (delete, add, band, DNS) need no
  privilege on the T14s, as in the laboratory.

### Cleanup

`iw` was removed through the supervised tmux pattern, the temporary
directory was deleted and no prototype unit, process or helper remained. The
final state matched the baseline: one connected Wi-Fi profile with DHCP DNS,
default DNS over TLS and automatic band, the Ethernet profile on DHCP,
unchanged NetworkManager configuration, and three paired Bluetooth devices,
not pairable and not discoverable. Residue: the Wi-Fi profile is the
recreated one, and the package log and journals record the session.

## Gate outcome

Decided by the maintainer on 2026-11-07 (Task 6), accepting the recommended
option for every item. The ADR amending ADR 0012 and production plans 02-27
onward start from these decisions [DEC-020, DEC-025].

### Panels, functions and sources

- **Panel set (G1):** audio, network/Wi-Fi, Bluetooth, display and power.
- **Functions (G2):**
  - Audio: output and input selection, levels, mute, mute-all, input peak
    meter while open, per-application mixer with PipeWire names, unavailable
    state. Excluded: DSP and EasyEffects sink resolution, untyped virtual
    inputs.
  - Network/Wi-Fi: as prototyped (wired and Wi-Fi state, scan, connect with
    passphrase, disconnect, forget, band, DNS within G12, connectivity and
    captive-portal action, details). Excluded: QR sharing and speed test.
    Enterprise authentication goes through the terminal.
  - Bluetooth: power, discovery, pair, connect, disconnect, forget, switch to
    a new Bluetooth audio output.
  - Display: brightness, output enable and disable with the last-display
    guard, scale. Excluded: text size.
  - Power: battery state and AC and battery power profiles. Excluded: CPU and
    memory statistics.
- **Source (G3):** Omarchy 4.5 adapted for all five panels. No shortlisted
  candidate improves on it without a resident daemon or service that ADR 0012
  excludes (Dux Modular Shell, the ssupt plugins) or without losing functions
  (Caelestia, illogical-impulse); candidates remain design references.
- **Adaptation method (G4):** copy the upstream panel and adapt it, as the
  network prototype did, with per-file provenance in the shell `UPSTREAM.md`
  and `docs/attribution.md`. Production reimplements or adapts under its own
  review; prototype code is not promoted [DEC-024].
- **Extra panels (G9):** none. `wifiqr` stays excluded because it exposes the
  PSK.

### Production plan split (G5, TODO-006)

Evidence-driven split into four plans:

| Plan | Scope |
| --- | --- |
| 02-27 | Shared panel container and the local panels: audio, display, power; open/toggle IPC for every panel, including notifications; panel key bindings. |
| 02-28 | Network/Wi-Fi panel, including the `iw` package and the G12 DNS boundary. |
| 02-29 | Bluetooth panel and pairing agent (G6). |
| 02-30 | Graphical VPN access through an owned wrapper (G8). |

TODO-006 is resolved.

### Credential, privilege and service boundaries

- **Pairing agent (G6, TODO-002):** the existing `bt-agent -c NoInputNoOutput`
  (`bluez-tools`) runs as a user unit, as in Omarchy, and covers "Just Works"
  pairing, without man-in-the-middle protection. Numeric comparison, passkey
  and legacy PIN pairing use the documented terminal fallback, `bluetoothctl`
  with a `KeyboardDisplay` agent [DEC-006]. No agent in QML and no owned agent
  for now. Plan 02-29 decides how service authorization is answered
  (automatic acceptance or trust at pairing). TODO-002 is resolved.
- **Shell media service (G7, DEC-008):** none. The `playerctl` command
  boundary from plan 02-25 stays; the audio mixer labels streams with
  PipeWire names, and MPRIS labels are deferred.
- **Graphical VPN access (G8):** an owned Bash wrapper in
  `capabilities/system/vpn`, reimplemented from the OpenConnect helper
  prototype: local graphical session only, effective state verified after
  `down`, preferences under `$XDG_STATE_HOME/mirroros/`. The network panel
  lists NetworkManager VPN profiles and opens the wrapper in `foot` to
  connect. No credential passes through QML.
- **Wi-Fi passphrase in QML (G10):** admitted as network credential entry,
  not user authentication. The passphrase reaches NetworkManager only on
  standard input or through the native API, and the shell never stores or
  logs it. Enterprise authentication goes through the terminal. The ADR
  states this boundary against ADR 0012's rule that authentication is never
  project-owned QML.
- **PSK storage (G11):** NetworkManager's default, a system-wide profile with
  `psk-flags=0` in the root-only keyfile; no keyring dependency.
- **DNS from the panel (G12):** the active profile only, after an explicit
  confirmation; never every saved profile and never the global layer
  [ADR 0024].
- **Power watcher:** stays outside the shell [DEC-015].

### Production requirements from the evidence

- **Diagnostic traffic (G13):** no continuous `ping` to `1.1.1.1`; use the
  gateway and NetworkManager's connectivity check. The packet-loss indicator
  uses a longer window or a threshold.
- **UI (G14):** a band switch shows as in progress; current, chosen and
  focused states look distinct; repeated clicks do not repeat a pending
  action.
- Every panel has an open/toggle IPC target; one target per shell, not per
  bar instance.
- Production decides the i18n catalog source, since the 4.5 catalog lacks the
  notification keys.
- Publication of the shell tree stays atomic.
- Validation on real hardware stays per panel in the production plans; the
  Framework Laptop 13 Pro remains pending.

## Chronological log

- 2026-11-07: Omarchy 4.5 ISO verified against the official SHA-256 and
  signature (TODO-007 resolved). `btrfs restore` rejected after zstd extent
  failures; with maintainer authorization the root image was mounted
  read-only through `udisksctl`, the package copied and checked against its
  `mtree`, and the loop device and decompressed image removed. 4.0.6 `default/`
  and `config/` extracted read-only from the 4.0.6 ISO squashfs. Inventory,
  extra panels and 4.0.6 → 4.5 differences recorded; no existing code changed.
- 2026-11-07: Alternatives discovered from metadata and READMEs only (no
  install or execution); shortlist of three candidates per category proposed
  with rejected candidates and filters recorded. The maintainer approved the
  shortlist without changes.
- 2026-11-07: Comparison matrix built from pinned candidate sources read
  outside the repository; nothing built or run. No candidate run deferred to
  Task 4.
- 2026-11-07: Laboratory audio flag added and documented; guest configured at
  `ec84d74`; Omarchy 4.5 re-extracted read-only and cleaned up. Shared
  container and audio panel prototyped on the guest branch (`a0c9a29`,
  `d597222`) and reviewed by the maintainer. Network panel, run without audio
  and handoff pending.
- 2026-11-07: Network panel copied from Omarchy 4.5 and adapted (`053e7c3`)
  and reviewed by the maintainer; the Omarchy 4.5 root image was re-mapped
  read-only with maintainer authorization to copy the network helpers and
  cleaned up. Run without emulated audio showed the unavailable state.
  Incremental bundle handed off and verified on the host; isolated review,
  Gitleaks and ShellCheck recorded.
- 2026-11-07: Supervised T14s session: network prototype delivered by
  checksummed bundles and run beside the production shell; Wi-Fi forget and
  PSK reconnection, band selection with `iw` installed temporarily, and
  BlueZ `NoInputNoOutput` and `KeyboardDisplay` pairing with a phone.
  Prototype, `iw` and test pairing removed; final state matched the baseline.
- 2026-11-07: Gate held; the maintainer accepted the recommended option for
  every item (panel set, functions, sources, four-plan split, pairing agent,
  no shell media service, VPN wrapper, credential and DNS boundaries).
  TODO-002 and TODO-006 resolved.
