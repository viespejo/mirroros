# Desktop shell procedure

**Availability:** production source integrated from the reviewed Story 4.3 prototype (plan 02-19 Task 1);
configure delivery, the systemd user lifecycle, lock/idle configuration and keyboard bindings added by plan 02-19
Task 2 and proven so far only by host contracts. Clean reconstruction and attended acceptance belong to Task 3.
Until those pass, nothing here claims a ready graphical session or complete Story 4.3 acceptance.

The historical laboratory recipe and results remain in
[desktop-shell-prototype.md](desktop-shell-prototype.md); this procedure does not replace that record.

## Source layout

- `capabilities/desktop/shell/`: the owned Quickshell runtime with explicit composition in `shell.qml`
  (bar, menu with Apps launcher and selector, notifications, OSD, session actions). No plugin host,
  supervisor, Omarchy IPC, authentication or lock code ([ADR 0012](../adr/0012-owned-quickshell-desktop-shell.md)).
- [`UPSTREAM.md`](../../capabilities/desktop/shell/UPSTREAM.md): per-file provenance at the pinned Omarchy
  revision, license texts and open items.
- [`sources.md`](../../capabilities/desktop/shell/sources.md): ownership of defaults, preferences and
  private state, and the format justification.
- `tests/capabilities/desktop/shell/`: MirrorOS tests and tooling; not delivered with the runtime.

## Session delivery and lifecycle

`sudo operations/configure` (running system) or the installer's target-root run delivers the session; see the
[configure procedure](configure.md) for outcomes and conflicts.

| Concern | Owner | Delivered as |
|---|---|---|
| Shell runtime | `desktop/shell` | `/usr/share/mirroros/shell`, one manifest-checked tree |
| Shell startup and restarts | `mirroros-shell.service` user unit | `/etc/systemd/user/`, enabled per user, bound to the uwsm graphical session |
| Idle and lock requests | packaged `hypridle.service` + MirrorOS drop-in | `~/.config/hypr/hypridle.conf` |
| Lock surface and authentication | hyprlock + system PAM | `~/.config/hypr/hyprlock.conf` |
| Bindings and keyboard help registry | Hyprland configuration | `/usr/share/mirroros/hypr/{shell,window}-bindings.lua` |
| Terminal for `Terminal=true` entries | Foot | `~/.config/xdg-terminals.list` |

- The shell unit is the only startup owner (no Hyprland autostart, no supervision script). It restarts on
  failure at most five times a minute; then it stays failed: `journalctl --user -u mirroros-shell.service`.
- The shell and the lock are independent: hyprlock is started by hypridle's `lock_cmd`, never by the shell, so
  `systemctl --user restart mirroros-shell.service` leaves an active lock and hypridle running.
- Configure never starts or restarts anything. On a running session, either log out and in, or deliberately run
  `systemctl --user daemon-reload` and `systemctl --user restart mirroros-shell.service` (and
  `systemctl --user restart hypridle.service` only while unlocked).
- Keyboard: the session has `us,es` (`us` first, `SUPER+I` / `SUPER+SHIFT+I`), Compose on Right Alt, and every
  lock selects `us` first. The approved key table is registered at each configuration load; nothing is unbound
  at runtime. Keyboard help (`SUPER+K`) reads the registry the bindings export.
- Approved keys without an owner yet stay unbound and documented in the
  [Hyprland bindings record](../../capabilities/desktop/compositor/providers/hyprland/UPSTREAM.md): bar toggle,
  idle-lock toggle, TUI system monitor, layout cycling, monitor scaling and later-story keys.

Open risks verified only in Task 3: Quickshell reloads its configuration when its files change, so publishing a
new runtime under a running shell may reload that shell (untested; configure itself never restarts it). If
hypridle fails while locked, its stop also ends hyprlock (packaged kill mode) and Hyprland shows its lockdead
screen. The packaged `hypridle.service` contents and Terminal=true launches are checked on an installed system.

## Defaults, preferences and private state

| Item | Path | Owner |
|---|---|---|
| Common defaults | `defaults.json` beside `shell.qml` | MirrorOS, versioned |
| Personal overrides | `$XDG_CONFIG_HOME/mirroros/shell.json` (fallback `~/.config`) | User |
| Notification state | `$XDG_STATE_HOME/mirroros/shell/notifications/` (fallback `~/.local/state`) | Shell, private |
| While-away count | `while-away.json` in the notification state directory | Shell, private |
| Lock marker | `$XDG_RUNTIME_DIR/mirroros-shell-locked` | hypridle lock hooks |

To keep a device-local exception, set it in the interface or add only that key to `shell.json`, for example:

```json
{
  "version": 1,
  "notifications": { "fontScale": 110 }
}
```

To return to the common default, delete that key (or the whole file). An invalid file is reported in the
shell's log (`Preserving unsupported …`), the defaults apply and the file is left untouched until it is
fixed. To promote a choice for every device, edit `defaults.json` in the repository and review the change.

Notification history keeps 24 hours and at most 100 entries by default and restores active cards (DEC-020).
Its files are private (directory `0700`, files `0600`); never copy them into evidence.

## Behavior notes

- **Selector replacement (DEC-027):** opening another selector or a regular menu completes the pending
  selector request as cancelled: its done file appears and its selection file stays empty.
- **Notification `omarchy-exec-argv`:** preserved. Argv is validated structurally, executed literally with
  fixed positional data and only on a user click. Any same-user session-bus sender can set it; a sandboxed
  application reaching the session bus could therefore have a click run argv outside its sandbox. No sender
  authorization or sandbox guarantee is claimed.
- **Color-only states** follow the Omarchy reference (Story 4.3 criterion aligned under DEC-015/DEC-026).
- **While-away count (DEC-021/022):** notifications that arrive while the session is locked (new,
  non-transient ones; replacements excluded) are counted. The bar's notification indicator shows the count
  on return as a small superscript on the bell (capped at `9+`); unlocking does not clear it. Expanding the panel's history section marks it seen and it clears
  when that panel closes (clearing at once would remove the indicator hosting the open panel). The lock state is the
  lock marker, which hypridle's compositor-backed `on_lock_cmd`/`on_unlock_cmd` create and remove before
  calling the shell's `notifications lockChanged` IPC function; the shell also reads it at startup, so a
  restart during the lock reconciles. hypridle re-emits the lock on startup and its unit removes a stale
  marker before starting. Residual risk: if hypridle stays stopped while the session is unlocked, the
  marker is stale and the count stays hidden until hypridle starts again. The hooks and unit cleanup are
  delivered with the lock configuration (`capabilities/desktop/lock/`); with a user-owned
  `hypridle.conf` without them, the marker never appears and no count is shown. No content reaches the lock surface or the stored state.
- **Known inherited defect, not repaired:** with the notification panel open from the indicator, turning
  Do Not Disturb off (with nothing else active) removes the indicator from the bar's active block and
  destroys the panel; turning it on keeps the panel open. The behavior comes from upstream
  `Indicators.qml`; no data is lost.
- **Visual observation, inherited:** the bell glyph sits about 1-2 px above the clock's capitals; glyphs
  are centered by their painted bounds and the clock as a text line. Global bar alignment belongs to
  Story 4.8 and is not changed here.
- **Known upstream issue:** during the repeated hour of a daylight-saving change, Quickshell's
  `SystemClock` (bar clock) logs `QTimer::start: negative intervals` continuously; it ends with that hour.
  The quiet-log checks fail in that window and must be rerun afterwards.

## Verification

Host, no graphical session:

```bash
node --test tests/capabilities/desktop/shell/config-overrides.test.mjs \
    tests/capabilities/desktop/shell/while-away.test.mjs
node tests/capabilities/desktop/shell/menu-model.test.mjs [<omarchy-src>]
node tests/capabilities/desktop/shell/check-i18n.mjs
node tests/capabilities/desktop/shell/i18n-subset.mjs <omarchy-src> --check
node tests/capabilities/desktop/shell/check-provenance.mjs <omarchy-src>
shellcheck tests/capabilities/desktop/shell/*.sh capabilities/desktop/shell/services/hidden-entries.sh
```

`<omarchy-src>` is a read-only Omarchy checkout at the revision in `UPSTREAM.md`; the provenance check
refuses any other revision.

Configure delivery, bindings and lock contracts (host, test doubles, no session):

```bash
bats --jobs "$(nproc)" tests/capabilities/desktop/shell/install-runtime.contract.bats \
    tests/capabilities/desktop/shell/configure.contract.bats tests/capabilities/desktop/lock/configure.contract.bats
node --test tests/capabilities/desktop/hyprland-bindings.test.mjs
```

Disposable guest with Quickshell, Hyprland and the recorded Qt version only (synthetic data, isolated
HOME/XDG; never on the daily session). `qmllint-check.mjs` compares diagnostics with the reviewed baseline
and needs that environment; its baseline is updated only with `--capture` and an explicit review:

```bash
node tests/capabilities/desktop/shell/qmllint-check.mjs
tests/capabilities/desktop/shell/check-selector-replacement.sh
tests/capabilities/desktop/shell/check-dmenu.sh
tests/capabilities/desktop/shell/check-menu.sh
tests/capabilities/desktop/shell/check-bar.sh
tests/capabilities/desktop/shell/check-notifications.sh
tests/capabilities/desktop/shell/check-osd.sh
tests/capabilities/desktop/shell/check-while-away.sh
```

`check-bar.sh`, `check-notifications.sh` and `check-while-away.sh` refuse to run while another
notification daemon owns the bus. The checks need a UTF-8 locale: under a non-interactive SSH session,
export the session's `LANG`, otherwise Quickshell prefixes every IPC reply with a locale warning.
Exit code `2` means blocked, not passed. Input-injecting variants (`--keyboard`) and keyboard-layout checks
need specific authorization.
