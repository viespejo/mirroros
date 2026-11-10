# Story 4.4 Bluetooth panel — technical interview log

Planning interview for plan 02-29 (Bluetooth panel and pairing agent). Decision IDs continue the Story 4.4 sequence
after DEC-066 ([network panel log](story-4-4-network-panel_log.md)). Settled inputs that are not reopened here:
[ADR 0025](../adr/0025-shell-panels.md) and the gate outcome in the
[shell panels prototype procedure](../procedures/shell-panels-prototype.md#gate-outcome).

## DEC-067
- **Question**: How is BlueZ service authorization answered (gate item G6, left open for plan 02-29)?
- **Context/Nuances**: `bt-agent` (bluez-tools 0.2.0, `src/lib/agent-helper.c`) answers `AuthorizeService` by
  accepting when the device is Paired and rejecting otherwise; BlueZ does not consult the agent at all for Trusted
  devices. Omarchy `v4.5.0` `omarchy-bluetooth-device` runs `trust` after `pair` and again on every `connect`. The
  T14s evidence showed bonded-but-untrusted phones receiving `AuthorizeService` requests for their service
  connections. `bt-agent` is a user unit, so it is absent outside a user session (for example at the greeter);
  untrusted devices then cannot complete device-initiated service connections. Options: (A) trust at pairing and on
  connect, as Omarchy; (B) never trust, rely on `bt-agent` accepting services for paired devices while the session
  runs; (C) trust only at pairing initiated from the panel, never on connect.
- **User Response**: Chose C.
- **Decision**: The panel's pair action runs pair, then trust, then connect; connect never sets trust, so devices
  paired through another path (for example the `bluetoothctl` terminal fallback) keep their trust state unchanged.
  Paired but untrusted devices still get their services accepted by `bt-agent` while the user session runs. This is a
  documented divergence from Omarchy `v4.5.0` recorded in provenance.
- **Status**: Accepted

## DEC-068
- **Question**: Which owned commands replace the Omarchy Bluetooth and audio helpers called by the panel?
- **Context/Nuances**: Omarchy `v4.5.0` calls `omarchy-bluetooth-device` (every step ends in `|| true` and the script
  always exits 0, so the panel never learns of a failure), `omarchy-bluetooth-power` (state held in the rfkill soft
  block, persisted across reboots by `systemd-rfkill`; `on` waits for the adapter and falls back to
  `bluetoothctl power on`) and `omarchy-audio-output-set-default` (node id plus `pactl`). Plans 02-27 and 02-28
  established owned commands under `/usr/share/mirroros/hardware/`, called by absolute path as the session user.
  `/dev/rfkill` carries the systemd `uaccess` tag, so the session user can block and unblock without privilege.
  `audio-device default output <node-name>` already exists (DEC-043/044: names only, moves application streams).
- **User Response**: Approved and asked to record it directly.
- **Decision**: Two owned commands in `capabilities/system/bluetooth/`, delivered to `/usr/share/mirroros/hardware/`:
  (1) `bluetooth-device pair|connect|disconnect|forget <address>` validates the address, applies bounded timeouts,
  implements pair as pair, trust, connect and connect without trust (DEC-067), returns real, step-distinct non-zero
  exit codes instead of swallowing failures so the panel can surface them and clear its pending state, and never logs
  addresses or device names; (2) `bluetooth-power on|off|is-on` keeps Omarchy's rfkill soft-block semantics, with no
  `toggle` because the panel always requests an explicit direction. The audio output switch reuses
  `audio-device default output <node-name>`; no new audio helper. `bluez-tools` is added to
  `capabilities/system/bluetooth/packages`.
- **Status**: Accepted

## DEC-069
- **Question**: How is the `bt-agent` user unit delivered and enabled?
- **Context/Nuances**: Plan 02-25 established the user-unit pattern with the power watcher: `cfg_tracked_file` to
  `/etc/systemd/user/`, `cfg_user_unit_enable` into `graphical-session.target` (enable-only, starts at the next
  graphical login; a user-owned unit or link is left untouched and logged) and the `cfg_user_unit_enabled`
  postcondition. Omarchy `v4.5.0` `default/systemd/user/bt-agent.service` (MIT) carries
  `ConditionPathIsDirectory=/sys/class/bluetooth`, `ExecCondition=/usr/bin/systemctl is-active --quiet
  bluetooth.service` (no restart loop without a usable adapter, for example in the laboratory guest) and
  `Restart=on-failure`. Without `-d`, `bt-agent` runs in interactive mode and prints device aliases and addresses to
  standard output, which systemd would store in the journal; `-d` forks and is incompatible with `Type=simple`. In
  interactive mode, `RequestConfirmation` and `RequestAuthorization` read standard input, which is `/dev/null` under
  systemd, so those requests are rejected (handled by the pairable/inbound-pairing question).
- **User Response**: Asked for a fuller explanation, then approved and asked to record it directly.
- **Decision**: `capabilities/system/bluetooth/mirroros-bt-agent.service`, adapted from the Omarchy `v4.5.0` unit with
  MIT attribution, is delivered by the `system/bluetooth` step to `/etc/systemd/user/mirroros-bt-agent.service` and
  enabled with `cfg_user_unit_enable … graphical-session.target`, with `cfg_user_unit_enabled` as postcondition;
  enable-only, it starts at the next graphical login. It keeps the upstream condition, `ExecCondition` and
  `Restart=on-failure`, adds `PartOf=`/`After=graphical-session.target`, runs
  `/usr/bin/bt-agent -c NoInputNoOutput` and sets `StandardOutput=null` (standard error kept) so device addresses and
  names never reach the journal. The `mirroros-` prefix avoids colliding with a user or package `bt-agent.service`.
- **Status**: Accepted

## DEC-070
- **Question**: Does the Bluetooth panel gain an "Advanced…" action, and how does it handle a device that cannot pair
  without a code?
- **Context/Nuances**: The maintainer proposed an "Advanced…" button like the audio (ADR 0026, `pavucontrol`) and
  network (DEC-060, `nmtui`) panels. ADR 0025 already names `bluetoothctl` with a `KeyboardDisplay` agent as the
  terminal fallback for numeric comparison, passkey and legacy PIN pairing, so opening it applies an accepted decision
  and needs no ADR. `bluetoothctl` 5.79 accepts `--agent <capability>`; BlueZ serves an outgoing `Pair()` with the
  calling client's agent when it has one, otherwise the default agent, so pairing from that session should show or
  request the code in the terminal while `bt-agent` stays the default agent (to verify on the T14s). Device-initiated
  pairing still reaches the default agent, so the documented `default-agent` and `pairable on` steps remain for it.
  Omarchy `v4.5.0` behaviour, read from source and not exercised on hardware: `pair` runs detached with output
  discarded and `|| true`; a code request cannot be answered and fails or times out after 20 s; the helper still runs
  `trust` on the unpaired device and a failing `connect`, then exits 0; the panel shows no error, its 20 s
  `pendingTimeout` clears every pending action, and `Model.deviceLists` now files the trusted-but-unpaired device under
  "Paired", so later clicks run `connect` and fail silently again.
- **User Response**: Asked what Omarchy does in that case, then approved and asked to record it directly.
- **Decision**: An "Advanced…" button at the end of the panel opens
  `uwsm app -- foot -e bluetoothctl --agent KeyboardDisplay`; it is keyboard-reachable and the panel closes after
  launching it. `bluetooth-device pair` stops at a failed pair step without running trust or connect and exits
  non-zero (DEC-067, DEC-068), so no device is left trusted but unpaired. On that failure the panel clears the pending
  state of that row only and shows the literal "Pairing failed. Devices that need a code: use Advanced…"; the panel
  never requests or displays a code. `docs/procedures/hardware.md` updates the fallback: Advanced, then `pair` for
  outgoing pairing; `default-agent` and `pairable on` for device-initiated pairing. The divergences from Omarchy are
  recorded in the shell `UPSTREAM.md`; no ADR.
- **Status**: Accepted

## DEC-071
- **Question**: Does the panel change the adapter's `Pairable` or `Discoverable` state, and how is device-initiated
  pairing handled?
- **Context/Nuances**: The Omarchy `v4.5.0` panel never writes `pairable` or `discoverable`; it only drives
  `discovering` while open. The upstream `bt-agent.service` comment claiming the adapter is pairable only while the
  panel scans therefore does not match the 4.5 code. Quickshell's `BluetoothAdapter` exposes writable `pairable`,
  `pairableTimeout`, `discoverable` and `discoverableTimeout`, and documents that `pairable` should typically only be
  changed by system settings applications. The T14s baseline was not pairable and not discoverable; BlueZ 5.79
  defaults are `AlwaysPairable=false` and `PairableTimeout=0`. Scanning lets the laptop find and pair outward; a phone
  can only find and pair with the laptop while it is discoverable and pairable. Under systemd `bt-agent` rejects
  `RequestAuthorization` and `RequestConfirmation`, which BlueZ typically asks for inbound Just Works pairing.
  Reconnection of already paired devices does not depend on either property.
- **User Response**: Approved and asked to record it directly.
- **Decision**: The panel never writes `pairable`, `pairableTimeout`, `discoverable` or `discoverableTimeout`; it only
  pairs outward, scanning while open as upstream does, which covers ADR 0025's "discovery, pair". Device-initiated
  pairing (typically a phone) goes through Advanced…/the terminal with `discoverable on`, `pairable on` and
  `default-agent`, documented in `docs/procedures/hardware.md`. The adapted MirrorOS unit carries its own accurate
  comment. The T14s checkpoint verifies, rather than assumes, the `Pairable` state with `bt-agent` registered, that
  outgoing Just Works pairing from the panel succeeds, and that inbound Just Works pairing is not accepted without the
  terminal.
- **Status**: Accepted

## DEC-072
- **Question**: How does the panel execute device and radio actions and track their pending state?
- **Context/Nuances**: Omarchy `v4.5.0` launches every action with `execDetached` and never sees a result, keeps
  per-address `pendingActions` in parallel, settles them when BlueZ state changes, clears all of them with one 20 s
  `pendingTimeout`, runs both native `device.disconnect()` and the helper on disconnect, and gives the radio switch no
  repeat protection. DEC-068 and DEC-070 need the owned command's exit code, so actions must run through `Process`.
  BlueZ serializes operations on one controller, and concurrent pair/connect is unreliable. The network panel uses one
  `Process` per action type. Settled during exploration: all 28 `bluetooth.*` keys used by the 4.5 panel exist in the
  pinned catalog `7075b61`, so `i18n-subset.mjs` regeneration needs no pin move; the network panel kept upstream
  rotating hero phrases, so the Bluetooth panel keeps them too. Options: (A) one device action at a time panel-wide;
  (B) concurrent per-device actions with dynamically created processes.
- **User Response**: Chose A.
- **Decision**: One `Process` runs `bluetooth-device`; while it runs, the acting row shows its pending state
  ("Connecting…", "Disconnecting…", "Forgetting…") and actions on every other row are dimmed and ignored (G14). An
  action ends when the command exits: on 0 the BlueZ state governs the row; on non-zero the row shows a failure
  literal (DEC-070 for pair, a generic literal such as "Connect failed" otherwise). The global 20 s `pendingTimeout` is
  removed; the command's bounded timeouts replace it. The radio switch has its own `Process` running
  `bluetooth-power on|off` with a pending state and ignored repeats. Every action goes only through the owned command;
  the duplicate native `device.disconnect()` call is dropped. The automatic switch to the Bluetooth audio output still
  fires only after a panel-initiated connect or pair that ends connected, through
  `audio-device default output <node-name>` (DEC-068).
- **Status**: Accepted

## DEC-073
- **Question**: How is the Bluetooth panel wired into the bar: IPC, shortcut, icon clicks, unavailable state and
  positional numbering?
- **Context/Nuances**: Plan 02-27/02-28 conventions (DEC-030, DEC-038, DEC-063): one plain IPC target per panel in
  `Bar.qml` outside `Variants` with only `open/close/toggle` and focused-monitor routing; `GlobalShortcut` entries in
  `shell.qml`; `SUPER+CTRL+B` reserved for Bluetooth. `Bar.qml` already offers `moduleWidgets()`, which the upstream
  discovery lifecycle uses to hand the stop obligation between per-monitor instances. The upstream `ShellIpc` exposes
  `open/close/show/hide/toggle/toggleBluetooth`. Default right section: tray, keyboard layout, Bluetooth, network,
  audio, display, power; positional numbering counts drawn panels only. The current widget shows a warning glyph and
  reason when BlueZ is missing or stopped, and hides when BlueZ runs without an adapter (as upstream). Right click: in
  both Omarchy `v4.5.0` and the local `quattro` HEAD `9044b7e8e` (2026-11-07) the right button runs
  `toggleBluetooth()`; DEC-016 only recorded the click targets as integration points and no decision existed. The
  maintainer reports that right click behaves like left click on an updated Omarchy; that installation was not
  inspected (possible newer upstream change, an unnoticed delayed radio toggle, or local override). Turning the radio
  off is persistent (rfkill soft block) and drops audio in use. Audio kept upstream right click (mute all); network has
  no right-click action.
- **User Response**: Asked when right click turning Bluetooth off had been decided (it had not), reported the observed
  upstream behaviour, then approved option B together with the rest.
- **Decision**: One `IpcHandler { target: "bluetooth" }` in `Bar.qml` with only `open`, `close` and `toggle` and
  focused-monitor routing; `show`, `hide` and `toggleBluetooth` are dropped. `GlobalShortcut` `panel.bluetooth` in
  `shell.qml` and `SUPER + CTRL + B` in `shell-bindings.lua` through `hl.dsp.global("mirroros:panel.bluetooth")`; B
  moves from reserved to bound in the Lua comment, the Hyprland `UPSTREAM.md` "Reserved and unbound" list and the
  binding and ambiguity tests, leaving no reserved panel chord. Any mouse button on the icon opens or closes the panel,
  as in the network panel; the radio changes only through the panel switch. This divergence from `v4.5.0` is recorded
  in the shell `UPSTREAM.md`. With BlueZ missing or stopped, the warning icon stays and the panel opens stating the same
  reason as the tooltip; with no adapter the widget stays hidden. The upstream discovery start/stop lifecycle and
  sibling handoff are ported on `moduleWidgets()`. Default numbering becomes Bluetooth 1, network 2, audio 3, display 4,
  power 5 (`SUPER+CTRL+1` no longer opens network); without an adapter Bluetooth is not drawn and numbering stays as
  before. Both are recorded in `docs/procedures/desktop-shell.md` and the `panelWidgetIdAt` tests. `check-panels.sh`
  gains Bluetooth cases: open and toggle by IPC and global shortcut, Tab switching, and the unavailable state with
  `bluetooth.service` stopped.
- **Status**: Accepted

## DEC-074
- **Question**: How is the Bluetooth panel tested and validated?
- **Context/Nuances**: ADR 0025 requires per panel: provenance, model and helper tests including the absence of
  `omarchy-*` calls, the unavailable state without the service, real-hardware validation in an authorized session
  (T14s non-qualifying, Framework Laptop 13 Pro pending), and the UI requirements (pending states, no repeated
  actions). Existing coverage: `hardware.contract.bats` (bluetooth.service, absent subsystem, failed activation, the
  power-watch user-unit pattern), doubles for `systemctl`, `busctl` and `hardware-tool`, and
  `hardware-network-commands.bats` as the command-test model. The laboratory guest has no Bluetooth subsystem, so it
  covers only configure and the unavailable state. Emulating a controller with `hci_vhci`/`btvirt` was considered and
  not adopted (tools likely not packaged by Arch; lab infrastructure outside this plan).
- **User Response**: Approved and asked to record it directly.
- **Decision**: Source tests: new `tests/capabilities/system/hardware-bluetooth-commands.bats` with new `bluetoothctl`,
  `rfkill` and `timeout` doubles for `bluetooth-device` (address validation; pair as pair, trust, connect; failed pair
  without trust or connect and a distinct exit code; connect without trust; disconnect and forget; step-distinct
  codes; no addresses or names in output) and `bluetooth-power on|off|is-on` (block/unblock, wait, `power on`
  fallback, no `toggle`); `hardware.contract.bats` extended for command (0755) and unit delivery, `bluez-tools`, the
  `graphical-session.target.wants/mirroros-bt-agent.service` link, a respected user-owned unit, an unchanged rerun and
  19 steps; Node `bluetooth-panel-model.test.mjs` for the adapted `Model.js`; static tests for no `omarchy-*` call, no
  `pairable`/`discoverable` write, device actions only through `Process` with the owned command (no `execDetached`, no
  native `device.disconnect()`), the exact Advanced command and click-to-open on every button; `panelWidgetIdAt` with
  numbering 1–5, binding and ambiguity tests with B bound, `check-provenance`, `i18n-subset --check`, ShellCheck,
  `git diff --check` and Gitleaks. Laboratory guest: configure exit 0 with 19 steps and an unchanged rerun, unit enabled
  but skipped by its condition without a restart loop, reviewed qmllint baseline, `check-panels.sh` Bluetooth cases
  including the unavailable state with `bluetooth.service` stopped, and the existing session suites. Supervised T14s
  (non-qualifying, tmux/SSH pattern): unit active after login and journal free of addresses and names; radio on/off
  from the panel, persistence across reboot and repeat protection; discovery stopped after close
  (`Discovering: no`); outgoing Just Works headset pairing left trusted with automatic audio output switch; connecting
  a terminal-paired untrusted device leaves trust unchanged; disconnect and forget; a code-requiring device shows the
  failure literal without a false "Paired" and pairs through Advanced with numeric comparison (verifying DEC-070);
  inbound pairing not accepted without the terminal and the `Pairable` state with the agent registered (DEC-071);
  `SUPER+CTRL+B`, numbering and Tab; no sudo or polkit prompt. Legacy PIN and the Framework Laptop 13 Pro are recorded
  as not exercised/pending. `docs/procedures/hardware.md` gains a "Bluetooth panel" matrix row with the Framework
  column "pending target-laptop validation".
- **Status**: Accepted
