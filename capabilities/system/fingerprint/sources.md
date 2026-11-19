# Fingerprint sources and ownership

`fprintd` and `libfprint` are official Arch `extra` packages, installed on every target whether or not a reader is
present; configure records actual versions in `packages.tsv`. fprintd is D-Bus activated and owns the readers;
configure never starts it. `libfprint-git` and platform (non-USB) readers are out of scope
([ADR 0030](../../../docs/adr/0030-shell-hosted-polkit-agent-and-fingerprint.md)).

The step delivers the commands to `/usr/share/mirroros/hardware/` (0755), the Omarchy MIT license copy
`OMARCHY-LICENSE` to `/usr/share/mirroros/hardware/licenses/omarchy-fingerprint` (0644), the invitation user unit to
`/etc/systemd/user/mirroros-fingerprint-invite.service` (0644), enabled into `graphical-session.target` for the
target user, and the managed PAM stacks `/etc/pam.d/polkit-1` and `/etc/pam.d/sudo` (0644).

| File | Status | Origin | MirrorOS divergences |
|---|---|---|---|
| `lid-closed` | Adapted | Omarchy `7075b61:bin/omarchy-hw-laptop-closed` | `MIRROROS_ACPI_LID_PATH` and `MIRROROS_INPUT_CLASS_PATH` test overrides; contract header (read-only, bounded logind call, errors read as an open lid) |
| `fingerprint-reader` | Adapted | Omarchy `7075b61:bin/omarchy-hw-fingerprint` | USB sysfs only, no platform reader file; `MIRROROS_USB_DEVICES_PATH` test override |
| `fingerprint-setup` | Adapted | Enroll and verify part of Omarchy `7075b61:bin/omarchy-setup-security-fingerprint` | No package install, `sudo`, PAM edit or lock-screen step; re-enroll or delete when prints exist; no Touch ID branch; waits for a key |
| `fingerprint-invite` | Adapted | Omarchy `7075b61:install/user/first-run/setup-fingerprint.hook` | Marker under `${XDG_STATE_HOME:-~/.local/state}/mirroros/`; prints from `fprintd-list`; bounded wait for `org.freedesktop.Notifications`; critical-urgency `notify-send --wait` (so it does not expire unseen), with the reviewed Quattro `󰈷` glyph via `mirroros-glyph` (plan 02-42); the standard `setup` action opens `fingerprint-setup` through `uwsm app -- foot` |
| `mirroros-fingerprint-invite.service` | Independently written | — | Oneshot user unit in `graphical-session.target` |
| `polkit-1` | Adapted | PAM layout of `setup_pam_config` in Omarchy `7075b61:bin/omarchy-setup-security-fingerprint` | Whole managed file instead of `sed` insertions; gate path `/usr/share/mirroros/hardware/lid-closed` |
| `sudo` | Adapted | `/etc/pam.d/sudo` from Arch `sudo 1.9.17.p2-6` plus the Omarchy gate and `pam_fprintd` lines | Whole managed file; the four packaged lines are kept byte for byte |
| `OMARCHY-LICENSE` | Copied | Omarchy `LICENSE` (MIT) | `# managed by MirrorOS configure` header only |

## PAM stacks

Both stacks place `auth [success=1 default=ignore] pam_exec.so quiet /usr/share/mirroros/hardware/lid-closed`
immediately before `auth sufficient pam_fprintd.so`, followed by the vendor `system-auth` includes. With the lid
closed the gate skips exactly `pam_fprintd`; any other result, including a probe error, continues to `pam_fprintd`
and then the password. Without enrolled prints `pam_fprintd` returns at once and the password prompt follows.
`lid-closed` is the only MirrorOS-owned code in a PAM stack; `pam_exec` needs its literal root-owned path.

The `polkit` package (128-1) ships its stack as `/usr/lib/pam.d/polkit-1`; a file in `/etc/pam.d` takes precedence,
so configure creates `/etc/pam.d/polkit-1` with the same four `system-auth` includes after the gate and
`pam_fprintd`. `/etc/pam.d/sudo` is a `sudo` backup file. Configure replaces it only when it holds the packaged content
(SHA256 `7ec1c668c10e0f83d00e25f336872212fe04ce2c2563e1d661d34d28852f4649`, `sudo 1.9.17.p2-6`, reported
`[unmodified]` by `pacman -Qii sudo`) or the last MirrorOS delivery; it creates it when absent. Package versions,
the packaged content and its hash were taken from the reference VM.

Any other content (a local edit) stops the step with exit 4 naming the file and is never overwritten. Remedy: restore
the packaged content (for example from the cached `sudo` package) or move the file aside, then rerun configure.

After a `sudo` update, pacman keeps the managed file and writes `/etc/pam.d/sudo.pacnew` when the packaged content
changed. Review the new packaged lines, carry any change into `capabilities/system/fingerprint/sudo`, record the new
version and hash here and in `apply`, then remove the `.pacnew` file.
