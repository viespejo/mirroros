# Bluetooth sources and ownership

`bluez` and `bluez-utils` are official Arch `extra` packages; configure records actual versions in `packages.tsv`.
BlueZ owns Bluetooth transport and `bluetooth.service`; bluez-utils supplies the permanent `bluetoothctl` fallback.
The MirrorOS step is independently written. It enables the system service and starts it only when inactive in
running context and `/sys/class/bluetooth` exists, matching BlueZ's `ConditionPathIsDirectory`. Without that
subsystem (for example in the reference VM), it reports hardware unavailable without repeatedly attempting a
skipped start. Target context enables it without runtime activation. The separate `check` script requires an
active daemon when the subsystem exists and reports a missing adapter as unavailable, not as a failed installation.
This absent-subsystem exception was explicitly approved during Task 3 to satisfy the VM acceptance contract.

Story 4.4 provider approval: 2026-11-03, ignored
`evidence/hardware/exploration-20261103T200419Z/REPORT.md`. Pairing on the exploratory T14s required a default
agent and `pairable on`; it did not justify a new agent service or USB autosuspend change. No keys, addresses or
paired-device state are delivered or collected. A2DP preference belongs to `system/audio`. PIN/passkey UI remains
outside this slice. Hardware results are non-qualifying; Framework validation remains pending.

## Bluetooth panel commands and pairing agent

Plan 02-29 delivers the commands called by the shell Bluetooth panel
([ADR 0025](../../../docs/adr/0025-shell-panels.md)) to `/usr/share/mirroros/hardware/` (0755), the Omarchy MIT
license copy `OMARCHY-LICENSE` to `/usr/share/mirroros/hardware/licenses/omarchy-bluetooth` (0644) and the pairing
agent user unit to `/etc/systemd/user/mirroros-bt-agent.service` (0644), enabled into `graphical-session.target`
for the target user; a user-owned unit or link of that name is left untouched and logged. Configure never starts the
unit and never runs the commands; they run as the session user, only on panel action, without sudo, pkexec or a
polkit rule (`/dev/rfkill` carries the systemd `uaccess` tag). The statement above that the 2026-11-03 exploration
did not justify an agent service predates gate G6; DEC-067 to DEC-071 (recorded in
`docs/technical-interviews/story-4-4-bluetooth-panel_log.md`) supersede it for this slice.

| File | Status | Origin | MirrorOS divergences |
|---|---|---|---|
| `bluetooth-device` | Independently written | Sequence of Omarchy `v4.5.0:bin/omarchy-bluetooth-device` | Pair runs pair, trust, connect and stops at the first failure; connect never sets trust; every BlueZ call bounded by `timeout`; no `\|\| true` on pair, trust, connect or remove; step-distinct exit codes; no address or name in output |
| `bluetooth-power` | Adapted | Omarchy `v4.5.0:bin/omarchy-bluetooth-power` | No `toggle`; distinct exit codes (rfkill failure separate from adapter not coming up); bounded `bluetoothctl list`/`show`; wait overridable through `MIRROROS_BLUETOOTH_POWER_WAIT_SECONDS` |
| `mirroros-bt-agent.service` | Adapted | Omarchy `v4.5.0:default/systemd/user/bt-agent.service` | `mirroros-` name; `PartOf=`/`After=graphical-session.target`; `StandardOutput=null`; `KillSignal=SIGHUP` and `TimeoutStopSec=2s` (bt-agent catches SIGTERM without exiting, so the session stop held logout for the default 90 s on the T14s; SIGHUP is not caught and counts as a clean exit); own comment without the upstream claim that the adapter is pairable only while the panel scans |
| `OMARCHY-LICENSE` | Copied | Omarchy `v4.5.0:LICENSE` (MIT) | `# managed by MirrorOS configure` header only |

Service authorization (gate G6, DEC-067): `bt-agent -c NoInputNoOutput` is the session's default agent; it accepts
`AuthorizeService` for paired devices only, and BlueZ does not consult it for trusted devices. Trust is granted only
by a pair started from the panel, never on connect, so devices paired through the `bluetoothctl` fallback keep their
trust state. The panel never writes the adapter's pairable or discoverable properties (DEC-071); device-initiated
pairing and devices that need a code use `bluetoothctl --agent KeyboardDisplay` (DEC-070).

Privacy: without `-d`, `bt-agent` runs in the foreground and prints device aliases and addresses to standard output,
which systemd would store in the journal; `-d` forks and does not fit `Type=simple`. The unit therefore sets
`StandardOutput=null` and keeps standard error for diagnostics (DEC-069). Under systemd its standard input is
`/dev/null`, so interactive confirmation and authorization requests are rejected.

| Package | Repository | Responsibility / upstream |
|---|---|---|
| bluez-tools | extra | `bt-agent` default pairing agent (GPL); package only, no code copied; https://github.com/khvzak/bluez-tools |
