# Audio sources and ownership

## Packages

`pipewire`, `wireplumber`, `pipewire-pulse`, `pipewire-alsa`, `alsa-utils` and `playerctl` come from the official Arch `extra`
repository. Configure records resolved versions in `packages.tsv`; these are not version pins. WirePlumber supplies
`wpctl`; playerctl is the terminal MPRIS provider. PipeWire services and WirePlumber are enabled only for the
selected user, under `default.target`, without starting or restarting a user manager or service.

`alsa-utils` supplies the standard ALSA state/initialization units and udev rules. The T14s exploratory check on
2026-11-06 (candidate `f075cf1` plus the authorized package installation) found that installation followed by a
normal reboot created the UCM `Mic ACP LED Capture Switch`; the physical microphone mute key, ALSA control and
LED then agreed. MirrorOS does not write LED controls, patch UCM or invoke `alsactl` from configure. The first boot
had no saved ALSA state and used initialization fallback; the restore process returned 99, whose exact cause
remains unresolved. This is not Framework qualification or clean rebuilt-candidate validation. See plan 02-25's
Task 7 execution records and ignored `evidence/hardware/acceptance-20261105T223002Z/`.

## Owned delivery

`volume` and `media` are independently written MirrorOS commands installed at `/usr/share/mirroros/hardware/`.
They validate argv before provider calls. Volume changes use `wpctl set-volume -l 1.0`; the existing shell's
`qs ipc -p /usr/share/mirroros/shell call -- osd showSource volume` reads the measured source. The `--`
terminator prevents the microphone's `show` function from being parsed as Quickshell's IPC `show` subcommand.
Microphone mute reads the resulting `wpctl get-volume` state after toggling, using the existing normal/muted
microphone icons with `Mic on` or `Mic muted`, without a level. Failed or unrecognised readback reports unavailable
(4) without retrying the toggle or claiming a resulting mute state. Missing audio or MPRIS players return
unavailable (4); invalid input returns 2.
OSD failure does not undo a successful provider action and is reported separately. Configure does not claim an
active user audio session; activation and physical audio checks follow at the next login.

## Omarchy attribution and approval

The hardware-key command semantics are a behavior reference to Omarchy 4.0.6 (MIT, David Heinemeier Hansson).
`bluetooth-a2dp-autoconnect.conf` incorporates the rule block from
[`config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf`](https://github.com/basecamp/omarchy/blob/v4.0.6/config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf),
Omarchy 4.0.6, MIT; see the repository's [license](https://github.com/basecamp/omarchy/blob/v4.0.6/LICENSE).
The MIT permission and copyright notice are retained in the adjacent `OMARCHY-LICENSE`.
The user drop-in changes A2DP auto-connect only, preserving microphone profile autoswitch.

Approval: Story 4.4 exploration gate, 2026-11-03. Ignored evidence:
`evidence/hardware/exploration-20261103T200419Z/REPORT.md` and `bluetooth-a2dp-dropin.txt`. Reconnection selected
HFP before the rule, A2DP after it; capture switched to HFP and back. This is T14s exploratory evidence, not
Framework qualification. User-owned drop-ins are preserved by the configure file helper. No pairing data is read,
written or recorded by configure. Terminal pairing uses `bluetoothctl` from `system/bluetooth`.
