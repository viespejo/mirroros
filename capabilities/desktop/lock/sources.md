# Lock and idle sources and ownership

## Providers

hyprlock and hypridle from the Arch `extra` repository, selected for Story 4.3 after the guest prototype
(DEC-019): hyprlock renders the lock surface (`ext-session-lock-v1`) and authenticates through the system PAM service
`/etc/pam.d/hyprlock` shipped by its package; hypridle owns idle detection, logind Lock/sleep requests and idle
inhibition. MirrorOS code never handles credentials and the desktop shell has no lock or PAM code
([ADR 0012](../../../docs/adr/0012-owned-quickshell-desktop-shell.md)). Package versions remain rolling; pacman
supplies their licenses.

## Ownership and lifecycle (DEC-023)

| Item | Location | Owner |
|---|---|---|
| Idle and lock requests | `~/.config/hypr/hypridle.conf` | Managed user file (`hypridle.conf`) |
| Lock surface | `~/.config/hypr/hyprlock.conf` | Managed user file (`hyprlock.conf`) |
| Lock colors | `~/.local/state/mirroros/current/theme/hyprlock.conf` | Selected theme ([theme sources](../../visual/theme/sources.md)) |
| Service | packaged `/usr/lib/systemd/user/hypridle.service` | Package |
| MirrorOS addition | `/etc/systemd/user/hypridle.service.d/10-mirroros.conf` | MirrorOS, tracked delivery |
| Enablement | `~/.config/systemd/user/graphical-session.target.wants/hypridle.service` | Selected user only |

Both native files use hypridle's and hyprlock's default paths, so no environment variable or argument is needed.
Unmarked files and links stay user-owned. The drop-in only removes a stale while-away lock marker before hypridle
starts and asks a running shell to reread it; the packaged command, restart policy and dependencies are unchanged.
hyprlock runs as a child of hypridle's `lock_cmd`, never of the shell, so stopping or restarting the shell leaves the
lock in place. Configure never starts, restarts or reloads hypridle.

## Configuration choices

- Lock after 300 seconds idle and before sleep; every lock path reaches `lock_cmd`.
- `lock_cmd` runs `/usr/share/mirroros/lock/lock-screen` only when no hyprlock exists. It selects layout index 0
  before starting hyprlock (decision J(a)) and, once hyprlock exits after unlocking, restores the layout that was
  active before locking (plan 02-20). A layout that cannot be read or switched never prevents locking.
  Behavior reference only: Omarchy `bin/omarchy-system-lock` at `7075b61c6aaa5d8589f6e816867508fc96dc49d9` (MIT)
  also selects the first layout when locking; no Omarchy file or script is copied or executed. Since plan 02-20
  index 0 is the configured layout ([ADR 0015](../../../docs/adr/0015-greeter-keyboard-layout-switching.md)), and
  `SUPER+I` / `SUPER+SHIFT+I` do not work at the lock screen. In the plan 02-20 VM (packaged hyprlock), hyprlock
  follows only the first layout change after locking; later changes switch the compositor layout but not the lock
  screen's indicator. Keeping the active layout when locking and switching while locked were therefore rejected,
  so the lock always uses the configured layout. Known cosmetic limitation: when another layout is active, the
  shell bar briefly shows the configured layout before the lock surface covers it.
- `on_lock_cmd` / `on_unlock_cmd` maintain `$XDG_RUNTIME_DIR/mirroros-shell-locked` and call the shell's
  `notifications lockChanged` IPC function for the while-away count (DEC-021/022; gate passed in plan 02-19
  Task 1). The marker carries no notification content.
- No screensaver, DPMS, backlight or automatic suspend policy.
- `hyprlock.conf` is an original MirrorOS layout under
  [ADR 0021](../../../docs/adr/0021-neutral-greeter-and-themed-lock.md): one password field over the selected
  background (`~/.local/state/mirroros/current/background`, ADR 0020) with `blur_passes = 3`, `blur_size = 8` and
  `brightness = 0.9`, or the theme background color when the image is missing; no clock, keyboard layout,
  screenshot, window or notification content. The field is `31.5%, 9.5%` of the output in physical pixels, with a
  3-pixel accent border, no rounding, the theme background at 80% and an `Enter Password` placeholder at 60%
  opacity. A failure shows PAM's message (`<i>$PAMFAIL</i>`, including faillock's remaining time) for five seconds
  (`general:fail_timeout = 5000`); the faillock policy is unchanged.
- Colors are the variables `$background`, `$field`, `$foreground`, `$accent` and `$failure`. The managed file
  defines neutral literal fallbacks (the greeter's colors), then sources the selected theme's `hyprlock.conf`
  through the `current/theme` link, as Foot does. A missing theme file is logged by hyprlock and the fallbacks
  remain. The link is user-controlled and hyprlock configuration can run commands through labels, so the lock
  trusts the selected theme like the user-writable lock file itself. Both paths use the default XDG state directory
  (`~/.local/state`), not a custom `XDG_STATE_HOME`.
- The previously shipped layout carried the managed header, so configure replaces it; a personal (unmarked) or
  linked `hyprlock.conf` stays user-owned and keeps its own layout.
- Behavior reference only: Omarchy `4.0.6-1` (inspected read-only on the reference VM) locks with one field over a
  blurred background; no Omarchy file, value set or asset is copied.

## Open limits

- The packaged unit's exact contents are verified on an installed system (plan 02-19 Task 3), not assumed here.
- If hypridle itself fails while locked, its service stop also ends the hyprlock child (default kill mode);
  Hyprland then shows its lockdead screen. Recovery (`misc:allow_session_lock_restore`) is untested.
- Multi-output lock, idle inhibition by applications and lock after resume remain unqualified.
- The ADR 0021 behavior (theme sourcing through `~` and the link, missing theme file, missing background, blur,
  percentage sizes and the failure display) was observed with temporary configurations on hyprlock `0.9.6`;
  the delivered file still requires installed VM qualification.
