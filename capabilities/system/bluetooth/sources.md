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
