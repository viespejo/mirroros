# Story 4.4 Bluetooth panel — consolidated plan

Current design state for plan 02-29. Traceability tags point to
[story-4-4-bluetooth-panel_log.md](story-4-4-bluetooth-panel_log.md).

## Settled inputs

ADR 0025 and the 2026-11-07 gate fix the scope: a bar-anchored Bluetooth panel in the shared container from plan
02-27, offering power, discovery, pair, connect, disconnect, forget and switching to a newly connected Bluetooth audio
output, adapted from Omarchy `v4.5.0` with per-file provenance. Pairing confirmation is delegated to
`bt-agent -c NoInputNoOutput` from `bluez-tools` running as a user unit, which covers "Just Works" pairing without
man-in-the-middle protection; numeric comparison, passkey and legacy PIN pairing stay on the documented
`bluetoothctl` `KeyboardDisplay` terminal fallback, and no agent runs in QML. Panels act as the session user with no
`sudo`, `pkexec` or passwordless rule. The IPC target is `bluetooth` with only `open`, `close` and `toggle`, and
`SUPER+CTRL+B` is reserved for it (DEC-030, DEC-038, DEC-063 conventions).

## Pairing trust and service authorization

Trust is granted at exactly one point: when the user pairs a device from the panel, the action pairs, trusts and then
connects it. Connecting an already paired device never changes its trust state, so devices paired through the
terminal fallback or any other path are left as their owner configured them. Paired but untrusted devices still have
their service connections accepted by `bt-agent`, which authorizes services only for paired devices, while the user
session runs; outside a session they cannot complete device-initiated service connections. This diverges from
Omarchy `v4.5.0`, which also trusts on every connect, and the divergence is recorded in provenance [DEC-067].

## Owned command boundary

The panel calls only owned commands by absolute path under `/usr/share/mirroros/hardware/`, delivered by the existing
`system/bluetooth` step, which also gains the `bluez-tools` package. `bluetooth-device` takes one of `pair`,
`connect`, `disconnect` or `forget` plus a validated device address, bounds every BlueZ call with a timeout and,
unlike the upstream helper that swallows every failure, exits non-zero with a code that identifies the failed step,
so the panel can report it and drop the pending state; it never logs addresses or device names. Pairing follows the
trust rule above [DEC-067, DEC-068].

`bluetooth-power` keeps Omarchy's model: the rfkill soft block is the persisted radio state, restored at boot by
`systemd-rfkill`, and `on` waits for BlueZ to power the adapter before falling back to `bluetoothctl power on`. It
offers only `on`, `off` and `is-on`; there is no `toggle`, because the panel always asks for an explicit direction and
a toggle would let a second click inside the settle window undo the first [DEC-068].

Switching to a newly connected Bluetooth audio output reuses the plan 02-27 `audio-device default output <node-name>`
command, which works with PipeWire node names only and moves application streams, so no Bluetooth-specific audio
helper is added [DEC-068].

## Pairing agent unit

The pairing agent ships as `mirroros-bt-agent.service`, a user unit adapted from Omarchy `v4.5.0` with MIT
attribution and delivered by `system/bluetooth` to `/etc/systemd/user/`. It reuses the plan 02-25 power-watcher
pattern: configure enables it for the target user under `graphical-session.target` without starting it, so it begins
at the next graphical login, and a user-owned unit or link of the same name is left untouched. The unit keeps the
upstream guards that skip it without a Bluetooth subsystem or with `bluetooth.service` inactive, so the laboratory
guest does not enter a restart loop, and restarts on failure. Because foreground `bt-agent` prints device aliases and
addresses, its standard output is discarded while standard error is kept, so no device identity reaches the journal
[DEC-069].

## Advanced action and code-requiring devices

The panel ends with an "Advanced…" button, matching the audio and network panels, that opens the ADR 0025 terminal
fallback directly: `uwsm app -- foot -e bluetoothctl --agent KeyboardDisplay`. It is reachable by keyboard and closes
the panel once launched. Because BlueZ serves an outgoing pair request with the requesting client's own agent, pairing
from that session should present numeric comparison, passkey or PIN in the terminal while `bt-agent` remains the
default agent; this is verified on the T14s rather than assumed. Device-initiated pairing still reaches the default
agent, so the hardware procedure keeps `default-agent` and `pairable on` for that case. No ADR is needed: the tool is
the already accepted fallback [DEC-070].

Omarchy fails silently when a device needs a code and, by trusting the unpaired device, files it under "Paired".
MirrorOS instead stops at the failed pair step without trust or connect, clears only that row's pending state and
shows "Pairing failed. Devices that need a code: use Advanced…"; the panel never asks for or displays a code. These
divergences are recorded in the shell `UPSTREAM.md` [DEC-067, DEC-068, DEC-070].

## Adapter visibility and device-initiated pairing

The panel pairs outward only. Like the Omarchy `v4.5.0` panel it scans while open, but it never writes the adapter's
`pairable`, `discoverable` or their timeouts, leaving the adapter not discoverable and adding no persistent adapter
state; reconnection of already paired devices is unaffected. A phone or other device that must initiate pairing does
so through Advanced… and the documented terminal steps (`discoverable on`, `pairable on`, `default-agent`). Since
`bt-agent` under systemd rejects the authorization and confirmation requests that inbound Just Works pairing typically
raises, this is also the expected runtime behaviour, which the T14s checkpoint confirms together with the `Pairable`
state while the agent is registered and a successful outgoing Just Works pairing from the panel. The upstream unit
comment that claims panel-scoped pairability is not carried over [DEC-071].

## Action execution and pending state

The panel runs one device action at a time. A single `Process` executes `bluetooth-device`; the acting row shows its
pending label while every other row's actions are dimmed and ignored, following the G14 rule of no repeated or
overlapping actions. The action ends when the command exits rather than on a global timer: success leaves the row to
the live BlueZ state, while a non-zero exit shows a failure literal on that row, the DEC-070 Advanced hint for pairing
or a generic literal such as "Connect failed" otherwise. Upstream's 20 s clear-all `pendingTimeout` is removed because
the command's own bounded timeouts replace it, and disconnect no longer duplicates the native call. The radio switch
has its own `Process` for `bluetooth-power on|off` with a pending state and repeat protection. After a panel-initiated
connect or pair that ends connected, the panel switches the default output to the device's Bluetooth sink through
`audio-device default output <node-name>` [DEC-072, DEC-068].

Upstream text stays upstream: all 28 `bluetooth.*` catalog keys the 4.5 panel uses already exist in the pinned
`7075b61` catalog, so the subset is regenerated without moving the pin, and the rotating hero phrases are kept as in
the network panel [DEC-072].

## Bar integration

The panel follows the conventions the network panel applied. `Bar.qml` declares one `bluetooth` IPC target with only
`open`, `close` and `toggle`, routed to the focused monitor; upstream's extra `show`, `hide` and `toggleBluetooth`
entry points are dropped. `shell.qml` gains the `panel.bluetooth` global shortcut and `shell-bindings.lua` binds
`SUPER + CTRL + B` to it, which retires the last reserved panel chord across the Lua comment, the Hyprland
`UPSTREAM.md` and the binding and ambiguity tests [DEC-073].

Every mouse button on the bar icon simply opens or closes the panel. Omarchy `v4.5.0` and the current upstream source
toggle the radio on right click, but turning Bluetooth off persists through the rfkill soft block and cuts audio in
use, so MirrorOS leaves radio control to the explicit panel switch and records the divergence; the maintainer also
observed click-to-open behaviour on an updated Omarchy installation, which was not inspected [DEC-073].

When BlueZ is missing or stopped, the bar keeps its warning icon and the panel opens with the same reason as the
tooltip; without an adapter the widget stays hidden, as upstream. The upstream discovery lifecycle, which starts
scanning while open and reliably stops it after close, including handing that obligation to a sibling instance on
another monitor, is ported onto the existing `moduleWidgets()`. With the default layout the positional chords become
Bluetooth 1, network 2, audio 3, display 4 and power 5; on a machine without an adapter Bluetooth is not drawn and the
numbering stays as before. `docs/procedures/desktop-shell.md`, the `panelWidgetIdAt` tests and new `check-panels.sh`
Bluetooth cases (IPC and shortcut open/toggle, Tab switching, unavailable state with `bluetooth.service` stopped)
cover this [DEC-073].

## Validation

Source-level tests run on the host. A new `hardware-bluetooth-commands.bats`, with doubles for `bluetoothctl`, `rfkill`
and `timeout`, proves the command contracts: the trust-on-pair-only sequence, the stop at a failed pair with a
distinct exit code, step-distinct failures, no identities in output, and the rfkill power model without a toggle.
`hardware.contract.bats` extends to the new commands, unit, `bluez-tools` package, user-unit link, respect for a
user-owned unit, an unchanged rerun and the unchanged 19-step count. Node tests cover the adapted model and statically
guard the boundaries decided here: no `omarchy-*` call, no adapter visibility writes, device actions only through the
owned command, the exact Advanced command and click-to-open, alongside the 1–5 numbering, bindings with B bound,
provenance, the i18n subset, ShellCheck, whitespace and secret scans [DEC-074].

The laboratory guest has no Bluetooth subsystem, so it proves delivery and absence: configure with 19 steps and an
unchanged rerun, the unit enabled but skipped without a restart loop, the reviewed qmllint baseline, and the
`check-panels.sh` Bluetooth cases including the unavailable state, with the existing session suites. A virtual
controller was considered and not adopted [DEC-074].

The supervised T14s checkpoint, non-qualifying, exercises the real behaviour and confirms the hypotheses recorded
earlier: agent unit and clean journal, persistent radio control with repeat protection, discovery stopping after
close, outgoing Just Works pairing with trust and audio switching, trust left alone on connect, disconnect and forget,
the code-requiring failure path and Advanced numeric-comparison pairing, inbound pairing refused without the terminal
and the `Pairable` state, the shortcut, numbering and Tab, and the absence of privilege prompts. Legacy PIN pairing and
the Framework Laptop 13 Pro stay explicitly pending, and the hardware procedure gains a "Bluetooth panel" matrix row
[DEC-074, DEC-067, DEC-069, DEC-070, DEC-071].
