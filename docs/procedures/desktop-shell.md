# Desktop shell procedure

**Availability:** production source and configure delivery are integrated (plan 02-19 Tasks 1/2). Task 3 has
clean-reference target/running evidence and bounded attended session results at candidate
`8c3c3cccc46421598b1fce47a330452c78230a80`; the maintainer accepted this bounded Task 3 result with its listed
limits. Mouse drag and quiet-runtime failures remain recorded under scoped exceptions. Nothing here claims a
ready complete Story 4.3 environment or laptop qualification.

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
- Keyboard: the session has the resolved layout first, then `us,es` without duplicates (`SUPER+I` /
  `SUPER+SHIFT+I`; [ADR 0015](../adr/0015-greeter-keyboard-layout-switching.md)), Compose on Right Alt, and every
  lock starts in the resolved layout and restores the previous one after unlocking; `SUPER+I` does not switch it
  at the lock screen (hyprlock follows only the first switch after locking), and the bar may briefly show the
  resolved layout while locking. The approved key table is registered at each configuration load; nothing is unbound
  at runtime. Keyboard help (`SUPER+K`) reads the registry the bindings export.
- Approved keys without an owner yet stay unbound and documented in the
  [Hyprland bindings record](../../capabilities/desktop/compositor/providers/hyprland/UPSTREAM.md): bar toggle,
  idle-lock toggle, TUI system monitor, layout cycling, monitor scaling and later-story keys.

Open risks: Quickshell reloads its configuration when its files change, so publishing a new runtime under a
running shell may reload that shell (untested; configure itself never restarts it). Failure of hypridle while
locked remains untested: its packaged control-group kill mode could end its hyprlock child; no safe outcome is
claimed. Task 3 inspected the real packaged unit and verified `Terminal=true` through uwsm, Foot and a real TTY
without foot-server; a maintainer-attended synthetic window confirmed the launch.

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

## Final-source verification checkpoint

Plan 02-19 Task 3 received A (Accept) for its bounded evidence and explicit limits, not complete story readiness.
The reference used a verified base ISO at source `d9edb3d` plus separately
verified candidate inputs at `8c3c3cc`, not an unchanged final-source release ISO. Selected run evidence is under
`evidence/desktop-shell-production/candidate-20261025T032813Z-amended/` (ignored, hash-checked and secret-scanned).

| Check | Observed outcome |
|---|---|
| Clean candidate contracts | Mechanism Bats 85/85 with `--jobs 1`; other five affected contracts 52/52 with `--jobs 8`; Node 27/27; menu model 12/12; provenance 93 files; i18n checks passed. These are selected suites, not the whole repository. |
| Target/running configure | Target all 10 steps changed; first running 9 unchanged/Hyprland changed; identical second running all 10 unchanged. No running package transaction or process restart observed. First-running session-file difference has no established cause. |
| Installed QML | 57 files, 829 reviewed warnings, no new/stale baseline entries; checker 0. This is not zero diagnostics. |
| Selector and dmenu | Selector replacement 17 PASS, exit 0; dmenu 26 PASS, exit 0. Keyboard injection was not run; pointer cancellation remains unverified. |
| Original graphical suites | Menu exit 1 (64 PASS/4 quiet failures); bar exit 1 (5/1); notifications exit 1 (7/1); OSD exit 1 (7/1); while-away exit 1 (17/1). Counts include lint where invoked; early-stopped checks were not passes. |
| Functional continuation | Authorized diagnostic-only copies of bar/notification tests reached their ends: sparse save/no-op, restart, live config, default updates/reset, invalid-file preservation, restored notifications/quiet state/preferences, literal argv after restart, private permissions and retention all passed. Each suite still exited 1 with three quiet failures; no runtime or baseline suppression. |
| Native reload | One `hyprctl reload`, exit 0; same compositor/shell/idle PIDs, no errors, 116 effective bindings, 110 registry entries with unique matches. Post-reload help and terminal passed attended checks. |
| One shell failure | One authorized SIGKILL of the shell main process; automatic on-failure recovery, IPC ready, exactly one restart, compositor/hypridle unchanged. Bar/menu recovery confirmed attended. Start-limit exhaustion was not exercised. |
| Session lifecycle | Attended System logout reached SDDM; selected-user compositor/shell/idle absent and graphical target inactive. New SDDM login started one of each, zero restarts/errors; registry regenerated for the new instance. |
| Lock and counter | Explicit lock from es returned to us, wrong password rejected and private unlock passed. Shell restart while locked left lock and hypridle intact. Named synthetic notifications around a locked shell restart produced count 2, then 0 after history expansion/panel close. |

Specific evidence directories: `terminal-attended-20261025T150349Z/`,
`functional-completion-20261025T143716Z/`, `native-reload-20261025T144305Z-display-exception/`,
`shell-failure-20261025T150613Z/`, `session-lifecycle-20261025T151340Z/`,
`counter-20261025T135921Z/` and `qmllint-20261025T140716Z/`.

The native reload/lifecycle checks preserve a maintainer-owned local `Virtual-1` display exception
(`1920x1080@60.00`, scale `1.2`); it is not a common default and does not explain the earlier configure rewrite.
A temporary unprivileged `systemd-inhibit --what=idle` was authorized for attended testing, bounded to one hour;
its absence was subsequently confirmed. No production timeout was changed and no inhibitor remains claimed active.

### Open failures and limits

- Both SUPER+left drag (move) and SUPER+right drag (resize) fail in the reference. Keyboard resizing works.
  Registered mouse bindings and source inspection do not establish a cause or fix. The maintainer accepted a
  reference-VM-only exception and no repeated identical test (DEC-029); retain both results as failed, not passed.
  QEMU involvement is plausible, not demonstrated. Comparative hardware qualification remains pending; no hardware
  success or blanket Story 4.3 acceptance follows from this exception.
- Quiet checks still fail on missing PipeWire/UPower and intermittent portal diagnostics. DEC-030 accepts a
  temporary exception only for these observed absent-provider categories, owned by Stories 4.4/4.5; revisit it
  when those providers are delivered. Original suite exit 1 and unavailable states remain visible. No provider
  was installed or warning suppressed to manufacture a pass; new or unrelated diagnostics are not waived.
  Private-bus inability to activate the real user manager remains a fixture limitation, not production evidence.
  Production journal checks confirmed the provider-warning categories. The reviewed QML baseline is separate.
- Idle locking was observed repeatedly, but exact 300-second timing and idle-from-es reset remain unverified.
  Tray visibility, multi-output and remaining standard-keyboard family checks are not qualified by other passes.
- No new suspend retest, hardware qualification, actual restart-limit exhaustion or changed-runtime live-reload
  qualification was performed. Original prototype defects and failed attempts remain historical evidence.
- Initial fixtures with overlong IPC paths, invalid counter stimuli, a partial manual command, expired SSH and a
  snapshot requested while still at SDDM remain recorded as such, not product passes. Later corrected evidence
  does not erase their original outcomes.

Final Task 3 review accepted this bounded result and its listed limits. Story 4.3 closure remains unclaimed:
reference-only drag exception DEC-029 and temporary absent-provider diagnostic exception DEC-030 do not waive
other requirements. Unverified checks above remain unverified. Publication and laptop migration are separate
operations.

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
