# Reminders sources and ownership

## Packages

`jq` and `sound-theme-freedesktop` come from the official Arch `extra` repository. Configure records resolved
versions in `packages.tsv`; these are not version pins. `jq` parses `systemctl --user list-timers --output=json`;
`sound-theme-freedesktop` supplies `/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga`.

Runtime dependencies already declared elsewhere are not repeated: `systemd-run` and `systemctl` come from `systemd`
(`system/network`), `notify-send` from `libnotify` (`system/power`), `pw-play` from `pipewire` (`system/audio`) and
`qs` from `quickshell` (`desktop/shell`).

## Owned delivery

`reminder` is installed at `/usr/share/mirroros/reminders/reminder` (0755), with the Omarchy licence at
`/usr/share/mirroros/reminders/licenses/omarchy-reminders`. Usage:

- `reminder <minutes> [message]`: minutes are a positive whole number. A transient user timer
  `mirroros-reminder-<minutes>m-<epoch>-<pid>` runs `reminder deliver <unit>` after that many minutes. A message is
  written only to `$XDG_RUNTIME_DIR/mirroros/reminders/<unit>.message` (mode 0600), never to the unit's command
  line. A transient confirmation states the due time.
- `reminder show|list [-j|--json]`: one transient "Upcoming reminders" notification, or the JSON
  `{count, active, tooltip, reminders:[{unit, timer, minutes, message, label, remaining, remainingSeconds, at,
  atTime}]}` read by the shell's `mirroros.reminders` service.
- `reminder clear`: stops every `mirroros-reminder-*` timer and service, removes their message files and shows a
  transient notice.
- `reminder -i|--interactive`: opens the shell prompt through `qs ipc … call reminders open`.
- `reminder deliver <unit>` (internal): rejects names outside the reminder pattern, sends a Critical, non-transient
  "Reminder" notification from app `reminder` with the message (or "Your N minute(s) is/are up"), plays the sound
  (a failure is ignored), removes the message file and refreshes the indicator.

Every set, delivery and clear calls `qs ipc … call reminders refresh`, ignoring failures. Invalid argv prints usage to
stderr and returns 2. Only the delivery is Critical; the shell lets a Critical `reminder` notification pass Do Not
Disturb, while the transient notices are silenced like any other.

Reminders are relative and ephemeral: timers and the runtime directory end with the user session. The capability
has no daemon, resident process, persistent state, privilege, network access or user configuration.

## Omarchy attribution

`reminder` is adapted from Omarchy v4.5.0 (`ac2690cd7be4f47e4a255f5e2e78d904d436b068`, MIT, David Heinemeier
Hansson) `bin/omarchy-reminder`, read from the `~/code/omarchy` history clone. The interface and the JSON shape are
kept. Deliberate differences:

- owned paths: `/usr/share/mirroros/reminders/reminder` and `$XDG_RUNTIME_DIR/mirroros/reminders/`;
- unit names `mirroros-reminder-<minutes>m-<epoch>-<pid>`, with the `-<pid>` suffix so two reminders set in the
  same second do not collide;
- an internal `deliver` subcommand instead of an inline `bash -c` script, so the message never reaches the unit;
- Critical delivery with the freedesktop `alarm-clock-elapsed` sound, and transient non-delivery notices;
- English literals from `default/i18n/en/cli.json` `reminder.*` with one/other plurals instead of `omarchy-i18n`;
- `notify-send` instead of `omarchy-notification-send`, and the shell's `reminders` IPC target instead of
  `omarchy-shell`.

The MIT permission and copyright notice are retained in the adjacent `OMARCHY-LICENSE`.
