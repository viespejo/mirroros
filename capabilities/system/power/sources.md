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

`brightness` also accepts an absolute `N%` (1..100) and a leading `--no-osd`, which suppresses every OSD call; the
display panel uses both so slider drags do not flood the OSD (plan 02-27).

`battery-status` is a read-only command for the power panel. It selects the first UPower `battery_` device marked
`power supply: yes` (peripherals are ignored) and prints tab-separated, untranslated values: `percentage`
(integer), `state` (UPower state, or `holding` when AC is online and a charge-end threshold holds the battery below
full), `rate` (W, unsigned, preferring the instantaneous sysfs `power_now` or `current_now`×`voltage_now`), `size`
(full energy, Wh), `cycles`, `threshold` (`end` or `start-end`, from the battery's
`charge_control_{start,end}_threshold`, falling back to UPower only when the battery exposes none) and `time` (minutes to empty, or to the charge limit while charging).
UPower is read in the C locale, since a decimal-comma `LC_NUMERIC` would otherwise drop `size` and `time`.
Keys without a reading are omitted rather than fabricated. No system battery or inaccessible UPower exits 4.

The watcher applies autodetect at login and queries UPower on monitor events. It sends one critical, 30-second
notification per at-or-below-10% discharging episode, rearmed after leaving that state. Absent batteries are
reported unavailable. UPower monitor failure reaches systemd's restart policy. The user service is enabled for
`graphical-session.target`, never started by configure. PPD is system-enabled and started only if inactive.

`60-mirroros-power-key.conf` owns only `HandlePowerKey=ignore`. Its tracked-file delivery triggers a logind
**reload**, never restart, only when changed in that step. Running postconditions check the effective D-Bus value
and PPD profiles; target postconditions check delivered files and unit links. Neither shell nor desktop nor
hypridle is started, restarted or reloaded. Lid suspend and lock behavior remain owned by existing logind/hypridle.

## Reference, approval and limits

`battery-status` is adapted from Omarchy v4.5.0 (`ac2690cd7be4f47e4a255f5e2e78d904d436b068`) `bin/omarchy-battery-status`
`--shell` mode (MIT, Copyright (c) David Heinemeier Hansson), read from the `~/code/omarchy` history clone. Its
battery selection, rate preference, time and holding logic are retained; translated durations and units,
`omarchy-i18n`, the human status line and the `BAT*` threshold fallback are removed, and absence exits 4 instead of
printing nothing. Upstream prefers UPower's thresholds; MirrorOS prefers the kernel's, because UPower publishes its
own policy values (for example an 80% end) even with `ChargeThresholdEnabled` false, which would show a limit the
firmware does not apply (T14s, plan 02-27). The MIT permission notice is retained in `capabilities/system/audio/OMARCHY-LICENSE` and delivered
as `/usr/share/mirroros/hardware/licenses/omarchy-audio` beside the commands.

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
