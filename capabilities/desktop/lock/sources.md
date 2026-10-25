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
- `lock_cmd` selects layout index 0 (`us`) before starting hyprlock, only when no hyprlock exists (decision J(a)).
  Behavior reference only: Omarchy `bin/omarchy-system-lock` at `7075b61c6aaa5d8589f6e816867508fc96dc49d9` (MIT)
  also selects the first layout when locking; no Omarchy file or script is copied or executed.
- `on_lock_cmd` / `on_unlock_cmd` maintain `$XDG_RUNTIME_DIR/mirroros-shell-locked` and call the shell's
  `notifications lockChanged` IPC function for the while-away count (DEC-021/022; gate passed in plan 02-19
  Task 1). The marker carries no notification content.
- No screensaver, DPMS, backlight or automatic suspend policy.
- `hyprlock.conf` is an original MirrorOS layout: solid background, clock, password field and active layout; no
  screenshot, window or notification content.

## Open limits

- The packaged unit's exact contents are verified on an installed system (plan 02-19 Task 3), not assumed here.
- If hypridle itself fails while locked, its service stop also ends the hyprlock child (default kill mode);
  Hyprland then shows its lockdead screen. Recovery (`misc:allow_session_lock_restore`) is untested.
- Multi-output lock, idle inhibition by applications and lock after resume remain unqualified.
