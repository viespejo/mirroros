# Hardware and connectivity procedure

Story 4.4 delivers the hardware core through configure. Provider choices were approved after supervised T14s
exploration on 2026-11-03. This is not a hardware qualification claim: the T14s is recognized and unqualified
under [ADR 0023](../adr/0023-recognized-unqualified-targets-and-target-hibernate-mode.md), and the Framework
Laptop 13 Pro remains the sole MVP laptop target, with physical validation pending.

## Ownership and activation

The explicit [step order](../../capabilities/configure-steps) places `system/audio`, `system/bluetooth`,
`system/power`, `system/network` and `system/vpn` before the Hyprland provider. See the [configure procedure](configure.md) for
prerequisites, both contexts, tracked-file conflicts, normalized outcomes and evidence. Running postconditions
check effective system state; target postconditions check installed files and enabled units without activation.
A successful configure is not proof of hardware usability.

- [Audio sources](../../capabilities/system/audio/sources.md): PipeWire, WirePlumber, pipewire-pulse,
  pipewire-alsa and playerctl; owned volume/media commands. User audio units are enabled under `default.target`,
  never started by configure. The approved user WirePlumber rule prefers A2DP on reconnect without removing
  microphone profile autoswitch. A user-owned drop-in is preserved.
- [Bluetooth sources](../../capabilities/system/bluetooth/sources.md): BlueZ and bluetoothctl. Configure enables
  bluetooth.service and starts it only if inactive. With no `/sys/class/bluetooth`, it instead reports unavailable
  and leaves the service enabled, matching BlueZ's hardware condition. A present subsystem requires active service.
- [Power sources](../../capabilities/system/power/sources.md): UPower, brightnessctl, power-profiles-daemon and
  libnotify. PPD is enabled and started only if inactive; profile switching uses D-Bus, not powerprofilesctl's
  optional Python dependency. The tracked logind drop-in owns only `HandlePowerKey=ignore`, with a reload only
  after the drop-in changes in the current step. Logind is never restarted. Existing hypridle/hyprlock continue
  to own lock-before-sleep. The user power watcher is enabled for `graphical-session.target`, never started by
  configure, and begins at the next graphical login.
- [Network sources](../../capabilities/system/network/sources.md): generic NetworkManager/systemd-resolved
  backend and stub integration under [ADR 0024](../adr/0024-networkmanager-resolved-dns-integration.md).
  Profiles and public DNS choices are preserved; VPN DNS/domains arrive dynamically. The step also delivers
  `network-status`, `network-band` and `network-dns`, their license and `iw`, without editing profiles. Panel actions
  change a profile only at runtime on explicit user action. See the network panel and migration sections below.
- [VPN sources](../../capabilities/system/vpn/sources.md): networkmanager-openconnect, OpenConnect and jq;
  configure checks plugin registration offline and delivers the owned `vpn-connect` and `vpn-profile` commands,
  without creating a profile, running them or authenticating.
- [Hyprland provenance](../../capabilities/desktop/compositor/providers/hyprland/UPSTREAM.md): hardware bindings
  call only owned commands under `/usr/share/mirroros/hardware/`. The display helper is compositor-local and
  changes runtime rules only, never persistent monitor files.

Configure never starts, restarts or reloads the shell, hypridle or desktop. Review configure evidence before
re-login or reboot; do not restart a graphical session remotely without the maintainer's explicit authorization.
Audio, display and power panels were delivered by plan 02-27, the network panel by plan 02-28, the Bluetooth
panel by plan 02-29 and the network panel's VPN section by plan 02-30, under [ADR 0025](../adr/0025-shell-panels.md).
No resident shell media service is added.

## Validation matrix

Each row has three environment-result columns. `Pending` means not performed, not passed; `Not applicable` means
the environment has no such hardware. Exploration validates individual mechanisms, not the delivered candidate.
Clean VM acceptance (plan 02-25 Task 6) and supervised T14s acceptance (Task 7) are complete as non-qualifying
evidence: they show how the candidate installs and behaves as recorded, not that any capability is qualified.
No capability below is claimed qualified.

Exploration date E1 is 2026-11-03: host base commit `03233ed55a190a78d129bd2f28ca9e49da979271`; installed ISO
commit reported as `ee07c83`, not independently reverified during exploration. E2 is the supervised seat-session
brightness check on 2026-11-04, same host base plus uncommitted Task 2/3 changes; no candidate configure was run.
These source identities must not be substituted for a future clean acceptance commit.

Acceptance identities, all exploratory or uncounted and none qualifying: V1 is the 2026-11-05 laboratory-VM
exception at `5e93654` (manual lab installation with a VirGL/SPICE display instead of the fixed reference VM, not
fixed-harness qualification). V2 is the 2026-11-06 runner-based clean installation at `179f288`: uncounted,
console-driven, with no separate reboot-persistence check. T14s acceptance A1 spans 2026-11-05 to 2026-11-06 on
candidates `5e93654`, `f075cf1` (microphone OSD IPC correction) and `e3c3228` (ALSA microphone state); the rows
name the commit where it matters. A2 is the final 2026-11-06 deployment of `179f288`: real DNS migration, reboot
persistence and a no-change rerun with 19 of 19 steps unchanged. Shell panel identities (plan 02-27, 2026-11-08):
V3 is the laboratory guest (QEMU, one `Virtual-1` output, no battery or backlight, with and without `--audio`),
not fixed-harness qualification, on candidates `2b5a6cd`, `608dda3`, `3857f79` and `8ec08b4`. A3 is the supervised
T14s delivery of candidates `3857f79`, `03696b5`, `8ec08b4`, `8c21d40` and `e9b9b6d` (final; its tree is the
committed plan 02-27 tree). Network panel identities (plan 02-28, 2026-11-09): V4 is the laboratory guest on
`a629c36`, with final-fix regression checks on `e350075`; A4 is the supervised, non-qualifying T14s session on
`a629c36` and final candidate `e350075`. Bluetooth panel identities (plan 02-29, 2026-11-09/10): V5 is the laboratory
guest (no Bluetooth subsystem) on `3748a64`; A5 is the supervised, non-qualifying T14s session on `7ef2959`, `f993a99`
and final `1907d37` (list-height and agent-stop fixes, not re-run in the guest). VPN section identities (plan
02-30, 2026-11-10): V6 is the laboratory guest (no Wi-Fi device) on `1393383`, fictitious profiles only; A6 is the
supervised, non-qualifying T14s session with the maintainer's corporate profile on `46810b9` and final `1bf11d5`
(Wi-Fi list height fix, not re-run in the guest). These temporary candidate commits
identify the tested trees, not a release ISO or fixed-harness qualification.

| Capability | Reference VM | T14s exploratory result (date and source above) | Framework Laptop 13 Pro |
|---|---|---|---|
| Audio output, mute and microphone | V1: audio reported unavailable without a level in the bar and OSD (maintainer visual). V2: console probe passed on the virtual dummy sink; graphical unavailable-audio not rechecked at `179f288` | A1 (`5e93654`, `f075cf1`, `e3c3228`): volume ±5/±1 and output mute with correct OSD; microphone key toggles both ways with a level-free message, and the ALSA capture switch and LED agree on `e3c3228`. Not verified: 100% cap, locked-session keys, capture quality. The microphone message is truncated with an ellipsis (unresolved) | pending target-laptop validation |
| Bluetooth and A2DP/HFP | V1, V2: no Bluetooth subsystem; BlueZ inactive and configure succeeded without failure | A1 (`f075cf1`, 2026-11-06): an existing headset pairing reconnected through `bluetoothctl`; A2DP active and audible. HFP availability only: capture and profile switch not exercised. New pairing and PIN/passkey not exercised | pending target-laptop validation |
| Display brightness | V1, V2: no backlight; brightness reported unavailable without a value | A1 (`5e93654`, 2026-11-05): all chords (±5/±1, max, min) with correct OSD, confirmed by the maintainer. E2 mechanism result retained | pending target-laptop validation |
| Media keys and MPRIS | Not applicable: no media keys or player; source and contract tests only | A1 (`5e93654`, 2026-11-05/06): owned actions through the keyboard launcher verified with a temporary test player (play-pause, next, previous). Physical media keys on an external keyboard confirmed; keycodes not captured. No dedicated multimedia keys were mapped on the T14s | pending target-laptop validation |
| Battery status | V1: battery indicator absent (maintainer visual). V2: battery count 0 | A1 (`5e93654`, 2026-11-05): UPower charge and source transitions observed. The 95/100 charge thresholds have an unknown origin and were left unchanged by maintainer decision | pending target-laptop validation |
| Low-battery warning | Not applicable: no battery; no fabricated charge | A1 (`e3c3228`, 2026-11-06): with a temporary 100% threshold the watcher sent a critical notification on a real discharge, did not repeat after dismissal and re-armed after an AC transition; the original 10% was restored. A real 10% crossing was not performed (waived by the maintainer) | pending target-laptop validation |
| Power key | V1, V2: effective HandlePowerKey=ignore; no key press | A1 (`5e93654`, 2026-11-05): a brief press opens only the session menu; no shutdown or suspend | pending target-laptop validation |
| Lid lock timing and clamshell | Not applicable: no lid or external monitor | A1 (`5e93654`, 2026-11-05): with an external monitor, lid close disabled only the internal panel and lid open restored both at their original scales, with the personal `monitors.lua` hash unchanged. Without a monitor the lock screen was the first content on resume (maintainer observation; the journal shows suspend and resume) | pending target-laptop validation |
| Display layout and scale | Not applicable: no external monitor; helper and source tests only | A1 (`5e93654`, 2026-11-05): internal-display toggle, mirror toggle and scale up/down confirmed visually, with readbacks for toggle and scale; the mirror state was not sampled independently. Persistent monitor files unchanged | pending target-laptop validation |
| Suspend and resume | Not applicable: no lid or sleep hardware | A1 (`5e93654`, 2026-11-05): session-menu suspend and lid suspend (s2idle) resumed to the lock screen first, in the same boot | pending target-laptop validation |
| Hibernate and resume | Not applicable: no sleep hardware | A1 (`5e93654`, 2026-11-05/06): session-menu hibernate resumed with the lock screen first, with `HibernateMode=shutdown` delivered per ADR 0023. mt7921e restore errors persist; recovery latency was not measured | pending target-laptop validation |
| Wi-Fi | Not applicable: no Wi-Fi hardware; do not infer Wi-Fi from wired networking | A1 (`f075cf1`, 2026-11-06): terminal reconnection through `nmtui` restored connectivity; the outage was not timed and no fresh public lookup was made. E1: power-save latency compared; mt7921e finding open. Global `wifi.powersave` delivery deferred (TODO-005) | pending target-laptop validation |
| Corporate VPN | V2: plugin registration only; no corporate profile or connection. V6 (`1393383`, 2026-11-10): `openconnect`, `jq`, `vpn-connect` and `vpn-profile` delivered and never run by configure; with fictitious profiles only, a profile without the secret flags is refused unchanged (exit 4) and authentication against `vpn.example.invalid` fails with cleanup | A1 (`f075cf1`, 2026-11-05/06): a private acceptance script outside the product authenticated and activated an existing profile through NetworkManager, and a corporate resource was reached. An earlier unexplained VPN loss was not resolved. A6 (`1bf11d5`, 2026-11-10, non-qualifying): `vpn-connect` launched from the network panel connected with username, password and OTP; a corporate resource was reached; split DNS with VPN scope, split routes without a new default route and unchanged profile settings; panel disconnect without a sudo or polkit prompt; `vpn-profile disconnect` over SSH exited 5 with the VPN still active. The NetworkManager authentication dialog under Hyprland is not used and remains unvalidated, and DNS transport-timeout behavior with the corporate resolver was not tested (documented unverified limit) | pending target-laptop validation |
| Automatic power profiles | V1, V2: power-profiles-daemon active | A1 (`5e93654`, `f075cf1`): default AC performance and battery balanced round trip; remembered custom choices (AC balanced, battery power-saver) were restored across source transitions in the same session and then removed. Persistence across re-login or reboot was not tested. A polkit denial of switching over SSH is expected | pending target-laptop validation |
| Per-domain DNS integration | V2 (`179f288`, 2026-11-06, uncounted runner): target configure 19 of 19 changed and running rerun 19 of 19 unchanged; stub link, resolved enabled and active, NetworkManager in systemd-resolved mode and a public lookup passed on first boot without manual repair | A2 (`179f288`, 2026-11-06): real migration from the external prototype (only `system/network` changed) with per-profile public DNS preserved, reboot persistence confirmed and a no-change rerun. Prototype on `f075cf1`: dynamic VPN scope and positive/NXDOMAIN lookups. Transport-timeout isolation not tested | pending target-laptop validation |
| Audio panel | V3 (`2b5a6cd`, `3857f79`): with `--audio`, outputs and inputs listed without the dummy sink, input peak meter, mixer row with slider and mute for a playing stream, "Advanced…" opens `pavucontrol`, `SUPER+CTRL+A`, numbered chords and Tab/Shift+Tab pass; without `--audio`, unavailable state without slider or level and `audio-device cycle` exits 4. Not exercised: MPRIS name, stream following and default persistence between devices (single sink and source) | A3 (`3857f79`, 2026-11-08): Bluetooth headset (A2DP) as output, a playing stream follows a newly chosen output, MPRIS player name with slider and mute, `SHIFT+XF86AudioMute` cycles outputs preserving mute, "Advanced…" opens `pavucontrol`, the unplugged jack microphone is hidden; a shortcut-chosen output persists across reboot and headset reconnection returns to the chosen default without taking over; no panel-side device state. Panel choice across logout/login: one unreproduced report of the headset selected, then kept on repetition with `default-nodes` snapshots. Not exercised: wired headphones (C2); Bluetooth microphone level (A2DP only) | pending target-laptop validation |
| Display panel | V3 (`2b5a6cd`, `608dda3`, `3857f79`, `8ec08b4`): fixed brightness state without backlight, runtime scale from the panel (selection immediate after the settle fix), chord scale changes shown within 1 s, the single output protected (outputs section hidden; command refusal in `check-panels.sh`), mirror toggle not offered with one output. External monitor not applicable | A3 (`03696b5`, `8ec08b4`, `8c21d40`, `e9b9b6d`, 2026-11-08), one external monitor: output on/off with the last-display guard, mirror-source disable, runtime scale, internal brightness slider without jumps, external fixed brightness, focused-monitor routing and numbered chords (DEC-045); ADR 0027 mirror toggle from the panel and the chord restores layout and cursor setting, and mirror-source disable from the panel passes on `e9b9b6d`. Observation: a brief Hyprland transient when re-enabling a mirrored external | pending target-laptop validation |
| Power panel | V3 (`2b5a6cd`): no battery; `SUPER+CTRL+P` and IPC do not open the panel and `battery-status` exits 4 without fabricated values | A3 (`03696b5`, 2026-11-08): size, cycles, charge limit and Holding state shown after two `battery-status` fixes (kernel thresholds over UPower policy values, C-locale parsing); a profile chosen on AC and on battery is kept per source across unplug/replug, matching the state files and the watcher journal. The maintainer set the thresholds to 75/80 by hand, outside the product | pending target-laptop validation |
| Network panel: wired, diagnostics, unavailable state and access | V4 (`a629c36`, 2026-11-09): configure and unchanged rerun, 19 steps; commands/license delivered; wired metrics, probes only while open with no process after close, NetworkManager stopped/restarted recovery, no Wi-Fi/band without hardware, Advanced opens nmtui; session suites pass. Final `e350075`: panel regression and qmllint pass | A4 (`e350075`, 2026-11-09, non-qualifying): chords, numbered panels, Tab, icon and outside click pass; several minutes of ping/loss without false red; Advanced opens nmtui. Coalesced list updates remove the close stall observed on `a629c36` | pending target-laptop validation |
| Network panel: Wi-Fi and band | V4: not applicable, no Wi-Fi device | A4 (`e350075`, 2026-11-09, non-qualifying): scan/list updates, disconnect/reconnect, forget and PSK reconnect, wrong-passphrase re-prompt, 2.4/5/Auto chosen/current/focus/pending states and ignored double click pass; journal records session-user operations. Not exercised: open/OWE, enterprise, 6 GHz and band rollback on failure | pending target-laptop validation |
| Network panel: per-profile DNS and portal | V4 (`a629c36`, 2026-11-09): confirmation with Cancel focused, Escape/other-pill dismissal, Custom empty cancel and apply pass; only active Ethernet changed, dummy Ethernet/VPN and global DNS unchanged, DHCP restores profile. Simulated portal recheck and browser-launch failure pass; real browser/portal not exercised | A4 (`e350075`, 2026-11-09, non-qualifying): Cloudflare/Google/Custom/DHCP pass on Wi-Fi only; VPN/Ethernet/loopback and global DNS unchanged, DHCP restores profile; no sudo/polkit prompt. Real portal and enterprise not exercised | pending target-laptop validation |
| Bluetooth panel | V5 (`3748a64`, 2026-11-09): configure and unchanged rerun (19 steps); `bluez-tools`, commands, license and agent unit delivered, unit enabled and skipped by its condition without a restart loop; panel opens unavailable with the tooltip reason and no devices; `SUPER+CTRL+B`, IPC, numbering and Tab pass; session suites and reviewed qmllint baseline pass | A5 (`7ef2959`, `f993a99`, `1907d37`, 2026-11-09/10, non-qualifying): agent active with no identities in its journal; radio switch with repeat protection; discovery stops after close; Just Works headset pairing trusts, connects and switches the default output; connecting a terminal-paired device leaves trust unchanged; disconnect/forget; unaccepted code requests fail with the Advanced literal and stay untrusted; Advanced numeric-comparison pairing leaves the device untrusted; not discoverable to a phone; chords, numbering 1–5, Tab, any-button click; no sudo/polkit; logout stops the agent at once. Failed: radio-off persistence across reboot. Phones can pair through Just Works when their consent dialog is accepted. Not exercised: legacy PIN, passkey entry, multi-monitor discovery handoff | pending target-laptop validation |
| Network panel: VPN section | V6 (`1393383`, 2026-11-10): no section and unchanged height without profiles; one and five fictitious profiles within the list cap; Connect opens Foot and closes the panel; Failed, Cancelled, `SAVE` (0600 file) and `FORGET` pass with an empty runtime directory and nothing active; hidden with NetworkManager stopped; session suites and the reviewed qmllint baseline pass. Not exercised: real connection, connected rows and Disconnect | A6 (`46810b9`, `1bf11d5`, 2026-11-10, non-qualifying): row reads Connected within 2 s after a panel Connect; panel Disconnect; saved username reused and `FORGET` asks again; Ctrl+C at the OTP prompt reports Cancelled with cleanup; Connect from the keyboard through the VPN row; one-VPN gating with a fictitious second profile. The card overflowed with a long Wi-Fi list on `46810b9`; on `1bf11d5` the Wi-Fi list cap yields the VPN section's height and the card fits. This server re-prompts after a wrong password, so Failed was not observed. No gateway or profile identity in the journal | pending target-laptop validation |

Selected evidence is local and ignored: `evidence/hardware/exploration-20261103T200419Z/REPORT.md` and
`evidence/hardware/task-3/verification.md`; shell panels: `evidence/shell-panels/lab-02-27/checkpoint-t8.md` and
`evidence/shell-panels/t14s-02-27/checkpoint-partial.md`; network panel:
`evidence/shell-panels/lab-02-28/checkpoint.md` and `evidence/shell-panels/t14s-02-28/checkpoint.md`; Bluetooth panel:
`evidence/shell-panels/lab-02-29/checkpoint.md` and `evidence/shell-panels/t14s-02-29/checkpoint.md`; VPN section:
`evidence/shell-panels/lab-02-30/checkpoint.md` and `evidence/shell-panels/t14s-02-30/checkpoint.md`.
Task 2–4 source/contract test results are recorded in the local plan
execution log; mocked tests do not establish clean installation or physical acceptance. Future acceptance records
must identify date, clean candidate commit, execution context and limitations for every row.

## Keyboard and terminal action paths

Open a terminal with `SUPER+Return`. Wi-Fi and Bluetooth terminal paths are permanent recovery interfaces,
not temporary replacements for later panels. No impala, iwd, bluetui or wiremix is added.

The Bluetooth, network, audio, display and power panels ([ADR 0025](../adr/0025-shell-panels.md)) open from their bar
icon, with `SUPER+CTRL+B`, `SUPER+CTRL+N`, `SUPER+CTRL+A`, `SUPER+CTRL+D` and `SUPER+CTRL+P`, or with
`SUPER+CTRL+1..9` for the Nth panel of the focused monitor's right bar section (defaults: Bluetooth 1, network 2,
audio 3, display 4, power 5; without an adapter the Bluetooth icon is hidden and the others move up one). The owned
terminal commands below remain available beside them.

| Action | Keyboard path | Owned terminal command |
|---|---|---|
| Volume ±5 / ±1 | Volume keys / ALT+volume keys | `volume raise`, `volume lower`, `volume +1`, `volume -1` |
| Output mute / microphone mute | XF86AudioMute / XF86AudioMicMute | `volume mute-toggle`, `volume mic-mute` |
| Switch audio output | SHIFT+XF86AudioMute | `audio-device cycle` |
| Brightness ±5% / ±1% | Brightness keys / ALT+brightness keys | `brightness +5%`, `brightness 5%-`, `brightness +1%`, `brightness 1%-` |
| Brightness max / min | SHIFT+brightness up / down | `brightness max`, `brightness min` |
| Media play-pause | XF86AudioPlay or XF86AudioPause | `media play-pause` |
| Media next / previous | XF86AudioNext / XF86AudioPrev; ALT+play / ALT+SHIFT+play | `media next`, `media previous` |
| Toggle internal display | SUPER+CTRL+Delete | `display laptop` |
| Toggle mirror | SUPER+CTRL+ALT+Delete | `display mirror` |
| Scale up / down | SUPER+/ / SUPER+ALT+/ | `display scale up`, `display scale down` |
| Session and power actions | XF86PowerOff or SUPER+Escape, then session-menu keyboard navigation | Existing session menu; confirmation remains required |

Commands in the table require the prefix `/usr/share/mirroros/hardware/`; they are not installed on PATH.
Hardware keys remain available while locked, with repetition on volume and incremental brightness. Volume never
exceeds 100%; OSD requests read measured volume/brightness or report unavailable. Mic mute uses a fixed message,
never a level. An OSD failure does not roll back a successful provider action and is reported separately.
Invalid arguments are rejected before provider effects; unavailable hardware/player is not a fabricated value.

`display laptop` toggles the internal panel only when another usable display exists; with the external display
remaining active this selects external-only or restores the laptop alongside it. `display mirror` toggles
mirroring; ending it returns the external display to the mode, position and scale it had before mirroring,
including runtime changes, from a session-only record. While mirroring, the cursor is drawn in software to
avoid a stale cursor image on the mirror output (Hyprland 0.57.0); ending the mirror restores the previous cursor
setting. The display panel offers the same toggle
([ADR 0027](../adr/0027-display-panel-mirror-toggle.md)). For laptop-only, disconnect the external display or use the existing personal native monitor layer;
these helpers do not introduce a persistent layout editor. Lid close with an external monitor disables only the
internal panel; lid open restores it explicitly. Without an external monitor, logind's suspend behavior remains.
Runtime layout/scale changes disappear on configuration reload or a new session and never rewrite `monitors.lua`
or `personal-monitors.lua`. Untrusted connector names are rejected before mutation.

Power-profile changes are occasional terminal actions, not reserved frequent-action bindings:

```bash
/usr/share/mirroros/hardware/power-profile set autodetect
/usr/share/mirroros/hardware/power-profile set ac balanced
/usr/share/mirroros/hardware/power-profile set battery power-saver
```

Explicit choices are remembered in `$XDG_STATE_HOME/mirroros/power-profiles/{ac,battery}` (default state root:
`~/.local/state`). Available profiles are validated; an unavailable remembered choice is reported rather than
silently rewritten. Defaults are performance on AC when available, otherwise balanced, and balanced on battery.
The watcher reapplies on power-source changes and sends one critical 30-second notification per discharging
battery episode at or below 10%, rearming after leaving that state. Do not discharge the laptop unsupervised to
prove this behavior. Keyboard-backlight keys are not bound: the T14s handles Fn+Space in firmware.

## Bluetooth panel

Open the Bluetooth icon with any mouse button or use `SUPER+CTRL+B`. Devices appear under Connected, Paired and
Available; discovery runs only while the panel is open and is stopped after close. Pair, connect, disconnect and
forget run the owned `/usr/share/mirroros/hardware/bluetooth-device` as the session user, one action at a time: the
acting row shows its pending label, other rows are dimmed and ignore input, and a failed command shows a failure
literal on that row. Pair trusts the device only after a successful pair, then connects; connect never changes trust.
The radio switch runs `bluetooth-power on` or `off` (rfkill soft block). After a panel pair or connect that ends
connected, the default output switches to the device's Bluetooth sink through `audio-device default output`. Pending
labels appear only for panel actions; device-initiated reconnections go straight to Connected. With BlueZ missing or
stopped the panel states the same reason as the bar tooltip; without an adapter the icon is hidden.

The session agent `mirroros-bt-agent.service` (`bt-agent -c NoInputNoOutput`, a user unit under
`graphical-session.target`) answers panel pairing with Just Works and authorizes services for paired devices only.
Its standard output is discarded so device identities stay out of the journal, and it is stopped with SIGHUP because
`bt-agent` ignores SIGTERM in effect. While it is registered the adapter reads `Pairable: yes`; MirrorOS never makes
the adapter discoverable. Phones may show the Just Works request as a consent dialog without a code: accepting it
pairs and trusts the phone without numeric comparison (no MITM protection). Use Advanced… when numeric comparison
is wanted. A code request that is not accepted fails with "Pairing failed. Devices that need a code: use Advanced…"
and the device stays untrusted under Available. The panel never shows or requests a code.

Observed limits on the T14s (non-qualifying): the radio-off state did not survive a reboot, because the
`thinkpad_acpi` switch reports `persistent` and its firmware boots unblocked, so systemd-rfkill does not restore it
([TODO-f923b17a](../technical-interviews/story-4-4-bluetooth-panel_log.md#todo-f923b17a)). A BLE mouse rejected a
host-initiated connect after a host disconnect until it was moved; the 20 s bounded attempt reported "Connect
failed". With many connected devices the panel can still exceed a short screen
([TODO-644fa670](../technical-interviews/story-4-4-bluetooth-panel_log.md#todo-644fa670)).

## Network panel

Open the network icon or use `SUPER+CTRL+N`; "Advanced…" opens `uwsm app -- foot -e nmtui` and closes the panel.
NetworkManager remains the connection owner. OpenConnect profiles appear in a VPN section between DNS and the Wi-Fi
list; see [Connect and disconnect](#connect-and-disconnect). PSKs go only through the
native NetworkManager API, never command arguments or shell logs. Scanning runs only while the panel is open.
Band selection requires `iw` and band data; the filled pill is the profile choice, the small marker is the current
radio band, and the outline is keyboard focus. A switch is pending and ignores repeats; failed activation attempts
restore the previous band. Live rollback on a failed band was not exercised.

DNS presets target only the explicit active Wi-Fi/Ethernet profile shown in the header. DHCP, Cloudflare and Google
first ask "Set DNS to <provider> for <profile>?", with Cancel focused. Escape, closing, changing the profile or choosing
another pill dismisses it. Custom opens Foot naming the profile; empty input cancels. Pending actions ignore repeats.
Cloudflare and Google set IPv4/IPv6 servers with opportunistic per-connection DNS over TLS; Custom uses default DoT.
Non-DHCP presets set `ignore-auto-dns` for both families: this also drops DHCP search domains and may break corporate
short names. The choice is per profile, not a default for later profiles. DHCP clears the manual servers and restores
automatic DNS. No global NetworkManager/resolved setting, `FallbackDNS` or global DNS over TLS is added; VPN profiles
are untouched. Review the trade-off before changing a corporate connection.

For enterprise (802.1X) networks use Advanced and configure through `nmtui`/`nmcli`, using the site's EAP method,
phase-2 settings, CA certificate and expected server domain. Use `nmcli` if the required certificate/domain fields are
not exposed in `nmtui`; never disable certificate verification to connect. Enter credentials only at protected prompts,
not argv or recorded commands. Unsaved enterprise rows open Advanced; saved profiles use the native connection path
and show the same hint when secrets are missing. There is no enterprise identity/password entry path in QML. Real
enterprise authentication remains unverified.

[ADR 0028](../adr/0028-network-panel-internet-latency-probe.md) permits gateway and `1.1.1.1` probes only while the
panel is open: 1.5 s polling, one packet per host, 2 s timeout, no overlapping runs. Ping and Packet loss describe the
internet samples; loss is red only with at least 10 samples and at least 10% loss in the 24-sample window. ICMP filtering
can make loss meaningless; NetworkManager's header remains the reachability signal. Portal/Limited/None show `--`.

Under Portal, "Open Captive Portal" explicitly launches `http://neverssl.com/` through `uwsm app -- xdg-open`.
A default browser must already be installed/configured; browser delivery/selection belongs to Story 4.5. Launch failure
keeps the panel open with "Could not open a web browser". Portal connectivity rechecks every 10 s even after the panel
closes. The laboratory exercised a simulated portal and missing-browser failure, not real browser sign-in or a real
portal. There is no web-app/window rule or automatic browser close.

If a manually installed Tailscale uses an exit node, privately note the current selection, disable it with
`tailscale set --exit-node=` before portal sign-in, then re-enable that same node afterwards through the local Tailscale
interface. This is a manual, separately authorized network operation, not performed by the panel. Automatic exit-node
pause/restore and its operator privileges remain TODO-023 in the
[network interview log](../technical-interviews/story-4-4-network-panel_log.md#todo-023); a test guard blocks adding
Tailscale to product packages without revisiting that integration. No Tailscale handling was validated here.

## Permanent connectivity fallback

Use `nmtui` interactively for Wi-Fi, or `nmcli --ask device wifi connect` with the selected network supplied in a
private interactive workflow. Enter credentials only at protected prompts; never supply a PSK as an argument.
Do not export SSID lists, device addresses or connection dumps to evidence. NetworkManager remains the owner;
no alternate Wi-Fi daemon is introduced.

For Bluetooth devices that need a code (numeric comparison, passkey or PIN), use the Bluetooth panel's "Advanced…"
action, which opens `bluetoothctl --agent KeyboardDisplay` in Foot, or run that command from a terminal. Closing the
panel stops discovery and BlueZ drops unpaired devices, so run `scan on` again, select the device locally, `scan off`,
then `pair` with its locally observed address and confirm the code on both sides. Add `trust` or `connect` only
deliberately; the terminal path does not trust. For device-initiated pairing, in the same session run
`default-agent`, `pairable on` and `discoverable on`, pair from the device, then `discoverable off` and
`pairable off`; the panel never changes these adapter properties. Do not copy device addresses, PINs, passkeys or
pairing keys to logs or source. Legacy PIN and passkey entry were not exercised. Audio reconnect should select
A2DP; microphone capture may switch to HFP.

## DNS integration and migration

[ADR 0024](../adr/0024-networkmanager-resolved-dns-integration.md) selects NetworkManager as the DNS-policy
authority and systemd-resolved as the per-link resolver, through `/run/systemd/resolve/stub-resolv.conf`.
No DNS provider is imposed: existing DHCP/RA and manual profile choices remain. VPN servers and domains are
received dynamically, not written into source or copied into a manual forwarding list.

Before a running migration, save work, ensure independent recovery access and explicitly approve a safe network
window. An active VPN/tunnel blocks a required transition; configure never disconnects it automatically.
An already-converged integration needs no migration, reload or new backup, even with an active VPN.

The mechanism accepts an absent target resolver or the exact live-medium regular-file copy; an arbitrary target
resolver requires private review. In running context, a legacy regular file's DNS servers and search domains must
match the current NetworkManager-provided values. Other options or an unrepresented manual policy require a
separately reviewed migration; do not remove them just to pass configure. Foreign links, conflicting backend/global
rules, an unavailable/masked resolver, unsafe parents, hardlinks or immutable/append-only files are rejected.
The exact retained prototype backend/stub may be adopted without rewriting profile DNS choices.

Recovery snapshots and operation diagnostics are root-private under `/var/lib/mirroros/configure/network-dns/`:
`current/` retains before/after files, service baseline, context and phase; prior attempts remain in private
`recovery.*` directories. Never copy these into evidence or Git. Normal failures attempt guarded restoration of
files, enablement and activity and report its outcome. A later run detects an interrupted applying transaction,
restores only recognised before/after states in the same context and stops for review before retrying. Subsequent
local edits, an incomplete snapshot or incomplete recovery require private inspection with rescue access;
do not delete phase markers or force restoration over edits. Retain recovery material until acceptance and a
separately approved cleanup. A Snapper snapshot/home backup remains independent protection.

Running postconditions inspect NM D-Bus mode, enabled/active resolved and absence of global index-0 DNS/domain
entries, then make a 15-second public `example.com` lookup. Operation limits are 30 seconds; missing connectivity
is not a passed lookup or a ready step. Target postconditions inspect declarations only. For subsequent target
commands, a private mount namespace supplies transient live-medium resolver input under a namespace-only `/run`
and uses `arch-chroot -r` on a namespace-only recursive bind of the target at `/mnt`, so installer targets under
`/run` remain reachable; no host resolver file or mount is changed. Live unshare/mount/lsattr support is required. Real first-boot and namespace behavior were exercised in the V2 clean installation (uncounted runner);
doubles alone do not establish them.

Privately verify VPN suffix scope, no unexpected root routing/default DNS route and unrelated public lookups on
the normal link. Search suffixes also route DNS; no conversion to a hard-coded route-only list is required.
A VPN pushing broader/missing/conflicting scope needs private review, not automatic profile rewriting.
There is no disconnected-name blocker: private names can reach the normal resolver while disconnected.
Application DoH/bypass is outside enforcement. Bounded positive/NXDOMAIN evidence is not transport-timeout or
universal no-leak evidence; transport-timeout isolation was not tested and remains an unverified limit. Reboot
persistence was confirmed on the T14s (A2).

## Private corporate VPN procedure

The approved provider remains the NetworkManager OpenConnect plugin. Exploration found that username,
password and OTP authentication worked through terminal OpenConnect, but `nmcli --ask connection up` alone
failed without a working graphical secret agent. Do not describe the auth dialog as validated under Hyprland.
The owned `vpn-connect` command (plan 02-30) performs the terminal authentication handoff, and the network panel
launches it.

Perform this workflow locally in an unrecorded terminal, as the graphical user, never through configure or a
captured SSH session. Disable shell tracing and terminal recording. Do not paste real values into command
history, agent chat or evidence. All editor steps below require a private editor with swap, backups, recovery
files and persistent history disabled; if that cannot be guaranteed, stop rather than writing private data to disk.

1. Create a private local VPN profile through interactive `nmcli connection edit type vpn vpn-type openconnect`.
   In the editor, choose a local connection name and set the `vpn.data` `gateway` to the private gateway including
   its tunnel-group path; `vpn-connect` reads the gateway only from the profile. `protocol=anyconnect` is recommended
   but optional (a missing protocol is used as `anyconnect`; any other value is refused), and `useragent` is optional
   for sites that require one.
   Set the plugin service to `org.freedesktop.NetworkManager.openconnect` and `vpn.data` entries
   `cookie-flags=2`, `gwcert-flags=2`, `gateway-flags=2`, `resolve-flags=2` (not saved). Preserve the site's
   reviewed route policy; never put credentials in profile properties. Save the profile privately on the machine,
   not in the repository. Use normal certificate verification; do not bypass trust errors.

### Connect and disconnect

Connect from the network panel (`SUPER+CTRL+N`): its VPN section lists OpenConnect profiles between the DNS controls
and the Wi-Fi list, and Connect opens Foot running `vpn-connect <uuid>` and closes the panel. In a local terminal,
run `/usr/share/mirroros/hardware/vpn-connect <uuid>` directly; `vpn-profile list` shows the UUIDs. The terminal names
the profile and asks for the username; OpenConnect then asks for the password and one-time code at its own prompts.
Foot reports Connected, Cancelled or Failed and waits for a key. Ctrl+C at any prompt cancels. Some servers ask for
the password again after a wrong one instead of failing; cancel with Ctrl+C. Only one VPN connects at a time from
the panel.

Disconnect from the panel row or with `/usr/share/mirroros/hardware/vpn-profile disconnect <uuid>` in the local
session. The command checks the effective state: over SSH, polkit denies the request while `nmcli` still reports
success, and the command exits 5 with the VPN connected. The panel shows "Still connected: disconnect not authorized"
(5), "NetworkManager unavailable" (4) or "Disconnect failed" on the row.

A typed username is saved only after typing `SAVE` (Enter uses it once), in
`${XDG_STATE_HOME:-$HOME/.local/state}/mirroros/vpn/<uuid>.json`, mode 0600 in a 0700 directory. A saved username is
reused with a notice; type `FORGET` to delete it and enter another, or delete the file. Delete the acceptance
prototype's `~/.mirroros-vpn-acceptance/` directory; nothing reads it any more.

| `vpn-connect` exit | Meaning |
|---|---|
| 0 | Connected |
| 2 | Usage or malformed UUID |
| 3 | Environment refused: root, SSH, no terminal, runtime directory not private tmpfs, missing tool, or unsafe preference file |
| 4 | Profile refused and left unchanged: missing, not OpenConnect, secret flags not 2, no gateway, or protocol other than `anyconnect`; fix step 1 or use the manual fallback |
| 5 | Profile already active, activating or deactivating |
| 6 | Cancelled (Ctrl+C, end of input, hangup or termination) |
| 7 | Authentication failed |
| 8 | Unsupported authentication output |
| 9 | NetworkManager activation failed |

| `vpn-profile` exit | Meaning |
|---|---|
| 0 | Success: listed, disconnected or already inactive |
| 2 | Usage or malformed UUID |
| 3 | Unknown UUID or not an OpenConnect profile |
| 4 | NetworkManager unavailable |
| 5 | Still connected after 5 s: disconnect not authorized or not complete |

On every exit `vpn-connect` removes its private runtime directory and brings down a partially activated profile.
No secret is stored in the profile and no profile, DNS or route setting changes. After connecting, privately verify
tunnel reachability, expected split routes and DNS ownership, recording only pass/fail and sanitized reasons.
NetworkManager must remain the single route/DNS-policy owner, with resolved executing its per-link policy. Check the
scope and limitations above; successful resource access alone does not prove DNS routing. Do not run standalone
OpenConnect as a tunnel or introduce another DNS writer.

### Manual fallback

Use the original handoff only when `vpn-connect` is unavailable or refuses a profile you have reviewed.

1. In a fresh Bash subshell with `umask 077`, create a `mktemp -d` directory in the private tmpfs
   `$XDG_RUNTIME_DIR` and register EXIT/HUP/INT/TERM cleanup of it. Keep all files there, mode 0600; never `/tmp`
   or the checkout.
2. Write an OpenConnect config file with a `server` entry containing the gateway/group and run
   `openconnect --protocol=anyconnect --authenticate --config <private-config-path>`, redirecting stdout to a
   protected runtime file. Credentials and OTP go only to its prompts. No root, tunnel, vpnc-script or verbose output.
3. Read the result only in the private editor, **never source it or use eval**. Write a separate passwd-file with
   `vpn.secrets.cookie` from `COOKIE`, `vpn.secrets.gwcert` from `FINGERPRINT`, `vpn.secrets.gateway` from `HOST`
   and `vpn.secrets.resolve` from `RESOLVE` as `key:value` lines, without the shell quoting or embedded newlines.
   Stop if fields are missing or the output differs; do not guess a mapping.
4. Run `nmcli connection up <local-profile-name> passwd-file <private-passwd-path>`, then remove the files and leave
   the subshell, also after failure or cancellation, disconnecting any partial connection. Never store a cookie in
   `vpn.secrets`, use `--show-secrets`, or export a profile. A host crash cannot be handled by a trap; runtime tmpfs
   is cleared on reboot. Verify as above and disconnect through NetworkManager, checking the effective state.

The gateway, certificate/fingerprint, authentication result, resolved addresses and credentials are all private.
Do not retain any of them as evidence, even when a value is not itself a password. Exploration established the
handoff once; future real connection acceptance remains supervised and must recheck that no secrets were saved.

## Evidence-driven tuning decisions

The exploration gate approved only the A2DP reconnect preference, with Omarchy 4.0.6 (MIT) provenance and notice
in the audio step. Profile-memory behavior and hardware chords also cite Omarchy 4.0.6 in their governing sources.
No upstream copy belongs under vendor/archiso-releng.

- `wifi.powersave`: disabling it reduced exploratory idle RTT from about 21 to 5 ms, but did not remove the
  mt7921e hibernate restore error. TODO-005 was explicitly deferred: evidence only, no global NetworkManager
  setting, policy/profile change or delivery route adopted. Global policy awaits Framework battery evidence;
  a new T14s-specific delivery mechanism needs separate governance outside this plan.
- No ASUS keyboard-backlight hook: irrelevant hardware and no delivered keyboard-backlight keysym.
- No global USB autosuspend change and no targeted btusb setting: no supporting peripheral symptom was observed.
- Lock timing passed exploration, so no `InhibitDelayMaxSec` or immediate lid-close lock was added. Any later
  failure requires maintainer review before crossing the plan's lock boundary.

## Supervised delivery, diagnostics and rollback

Before touching an installed T14s, obtain approval for consequential operations, take a Snapper root snapshot
on a Snapper-managed installation, and back up the user configuration/state that will be touched separately.
A root snapshot does not replace a home backup. Keep both private and record only non-sensitive identifiers.
Do not assume exploration snapshot numbers exist on another machine.

Transfer a checksummed Git bundle of a clean candidate over SSH, verify it, and extract it into the candidate
checkout. Record its commit and verify that checkout succeeded before configuring. Plan 02-28 observed that running
configure as root left `.git/index` root-owned, preventing a later user checkout; configure then re-applied the old
candidate. Use a fresh verified checkout for the next candidate rather than assuming the switch succeeded; this finding
was not fixed in configure. Run `sudo operations/configure` there, not `/usr/local/bin/mirroros-configure`,
which is pinned to the installed ISO's code snapshot. No agent is installed on the T14s or reference VM.
Newly delivered Hyprland binding files are not picked up automatically by the running compositor: use a new login
or, only with explicit authorization, `hyprctl reload`. Restart the shell service separately after publication
(TODO-018), as described in the [desktop shell procedure](desktop-shell.md#session-delivery-and-lifecycle).
A changed unit in `/etc/systemd/user` applies to a running session only after `systemctl --user daemon-reload` or
a new boot; plan 02-29 observed the old Bluetooth agent stop settings until the maintainer-approved reload.
After the maintainer-approved re-login/reboot, perform the physical checks and a second no-change configure run.
Clean VM installation must independently exercise installer target context and installed running context.

Useful local diagnostics (inspect privately; do not export raw device/profile/journal dumps):

- Configure's named failed step, outcome and `/var/log/mirroros/configure/<run-id>/configure-run.tsv` and log.
  A later step marked `not_run` is not ready. Tracked-file conflicts require preserving the edited file before
  deliberately restoring the owned destination and rerunning.
- `systemctl status bluetooth.service power-profiles-daemon.service`; user status for pipewire, pipewire-pulse,
  wireplumber and mirroros-power-watch; `wpctl status` for audio. User services require a user session.
- `busctl --system get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey`
  must report `ignore` after running configure; inspect administrator overrides if it does not. Never restart logind.
- UPower battery properties, `/sys/class/backlight`, and PPD's `Profiles`/`ActiveProfile` properties; test writes
  from the active graphical seat, not a plain SSH session. The exploration SSH brightness/polkit denial was not
  evidence of a failed seat-session provider.
- Hyprland binding registry/help and local monitor state; pass only `XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY` and
  `HYPRLAND_INSTANCE_SIGNATURE` from the actual session for authorized graphical commands. Do not dump the
  session environment. Do not issue a compositor reload as an incidental diagnostic.
- After a supervised suspend/hibernate, reconnect and privately inspect the boot journal for lock-before-sleep,
  same-boot resume and mt7921e errors. Reconnection alone does not establish resume correctness or a safe lock.
- VPN plugin registration and offline recognition can be checked without a corporate profile; actual
  authentication, DNS and route acceptance must not enter configure logs.

If rollback is needed, stop applying changes and preserve sanitized failure evidence. From independent rescue
media or a known-good boot/snapshot entry, inspect the pre-change Snapper snapshot and follow the installation's
native Btrfs/Limine recovery procedure; select the verified pre-change root only after explicit confirmation.
For non-Snapper storage, use the external backup/rescue path instead of assuming snapshot rollback is available.
Restore the separately backed-up user files as that user after reviewing exactly what will be overwritten.
Review package/file/unit state and reboot or re-login under supervision; never restart logind to recover a session.
Do not delete paired devices, private VPN profiles or personal configuration as an automatic recovery action.

Raw evidence remains in ignored `evidence/`, including VM results under `evidence/reference-vm/`. Retain only
allowlisted summaries with date, commit and result. Redact SSIDs, MACs, VPN servers, certificates, credentials,
serials and internal addresses before collection; scan selected evidence with Gitleaks on the host. Do not commit
generated output. T14s-specific findings belong in its [target notes](../../targets/thinkpad-t14s-gen1-amd/README.md)
and local TODO-582784b9 without resolving the open Wi-Fi/fingerprint findings or changing the todo's existing
closed status. Plan 02-25 Task 8 finalized the matrix after the two acceptance checkpoints.
