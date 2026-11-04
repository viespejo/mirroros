# Power sources and ownership

## Packages and interfaces

`upower`, `power-profiles-daemon`, `brightnessctl` and `libnotify` are official Arch `extra` packages; configure
records resolved versions in `packages.tsv`. libnotify supplies the watcher's `notify-send`. D-Bus tools are
provided by the base systemd installation. PPD is driven over `net.hadess.PowerProfiles` with `busctl`, avoiding
powerprofilesctl's optional Python dependency. UPower owns power-source and battery state. Brightnessctl controls
a display backlight from the active seat; it never selects keyboard LEDs.

## MirrorOS delivery

`brightness`, `power-profile` and `power-watch` are independently written Bash commands delivered to
`/usr/share/mirroros/hardware/`. Invalid argv returns 2, unavailable providers return 4. Brightness calls the
existing measured-source OSD. OSD failure is reported without concealing a successful hardware action. The profile
command validates exposed profiles and atomically remembers explicit selections in the user's
`$XDG_STATE_HOME/mirroros/power-profiles/{ac,battery}` (default: `$HOME/.local/state`). AC defaults to performance
if exposed, otherwise balanced; battery defaults to balanced. Remembered unavailable profiles are reported rather
than silently overwritten. No private profile state is touched by privileged configure.

The watcher applies autodetect at login and queries UPower on monitor events. It sends one critical, 30-second
notification per at-or-below-10% discharging episode, rearmed after leaving that state. Absent batteries are
reported unavailable. UPower monitor failure reaches systemd's restart policy. The user service is enabled for
`graphical-session.target`, never started by configure. PPD is system-enabled and started only if inactive.

`60-mirroros-power-key.conf` owns only `HandlePowerKey=ignore`. Its tracked-file delivery triggers a logind
**reload**, never restart, only when changed in that step. Running postconditions check the effective D-Bus value
and PPD profiles; target postconditions check delivered files and unit links. Neither shell nor desktop nor
hypridle is started, restarted or reloaded. Lid suspend and lock behavior remain owned by existing logind/hypridle.

## Reference, approval and limits

Behavior references: Omarchy 4.0.6 (MIT, David Heinemeier Hansson), `bin/omarchy-powerprofiles-set`, its shell
battery service (10% warning), and `10-ignore-power-button.conf`. No literal upstream code is incorporated here;
only profile memory/defaults, threshold and power-key policy are adapted. Triggering is deliberately independent
of the shell (ADR 0012).

Provider gate approved 2026-11-03; ignored evidence is
`evidence/hardware/exploration-20261103T200419Z/REPORT.md`. T14s PPD exposed platform_profile with performance,
balanced and power-saver and allowed switching from the seat session. Brightnessctl was reconfirmed from Hyprland
at Task 3 start: 65535 -> 62258 -> 65535, with original brightness restored. The initial SSH-only permission failure
was a seat-session limitation. Lock timing passed, so no inhibit-delay or immediate-lock addition is delivered.
Keyboard-backlight hook rejected; no USB autosuspend or Wi-Fi power-save change. All T14s evidence remains
exploratory; Framework validation is pending. Actual warning, suspend and profile-switch acceptance is still
required under Tasks 6 and 7, not established by mocked tests.
