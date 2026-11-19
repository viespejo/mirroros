# Desktop shell sources and configuration ownership

## Quattro notification engine

Plan 02-42 integrates the reviewed Quattro notification candidate. The plan records the candidate source
pin `e6aec9716dbb8748e0d4e66ff927cb7b04a2e17a`; that object was not available in the local Omarchy
checkout used for this integration. The notification rows in [UPSTREAM.md](UPSTREAM.md) use local
Quattro commit `520c3ed969d30b58defe03eb19d603f32b4cb002` as their per-file comparison reference,
not as a replacement for the candidate pin. The original Omapager notice and license are retained.

## Apps visibility policy

`launcher.hides` owns a bounded launcher-only hide list: `uuctl`, `foot-server` and `footclient`.
This is a MirrorOS-selected subset of Omarchy v4.5.0's `default/omarchy/launcher.hides`
(commit `ac2690cd7be4f47e4a255f5e2e78d904d436b068`, MIT), not an import of its complete policy.
`services/AppLibrary.qml` reuses that revision's unchanged `loadConfiguredHides` parser and adapts its FileView
watcher: the path becomes `Quickshell.shellPath("launcher.hides")`, and `onFileChanged` calls `reload()`.
Reference VM `quickshell 0.3.2-1`: the original upstream change handler reused cached text and failed a
live-edit check; explicit reload follows the existing ShellConfig reader and lets `onLoaded` apply new bytes.
The delivered file is
`/usr/share/mirroros/shell/launcher.hides`, one desktop id per line, with the optional `.desktop` suffix
normalized away. Load and change events replace the configured hide set and emit `appsChanged`;
a failed read clears only that set. No user-specific hide-list loader or Omarchy path dependency is added.
The shared library excludes these ids from Apps and application search while retaining the standard desktop
visibility filters. Regular Foot stays visible; no package, desktop file, launch command or association changes.
Reference VM package inspection (`pacman -Qo` and installed desktop entries): `uwsm 0.27.1-1` owns
`uuctl.desktop` (user systemd unit manager); `foot 1.28.0-2` owns `foot.desktop`, `foot-server.desktop` and
`footclient.desktop` (normal terminal, server and client). These facts come from the VM, not the development host.
Synthetic regressions: `tests/capabilities/desktop/shell/app-library.test.mjs` covers the external list,
normalization, replacement, empty/failure state, change notification and retained desktop visibility filters.
Verification: 239 shell Node tests passed, 11 skipped; six install-runtime contracts passed; provenance covers
153 files. VM qmllint: 92 QML files, 2511 reviewed diagnostics, no new or stale entries. A temporary real-library
instance passed initial visibility, hiding Foot after a list edit, and restoring Foot after restoring the list,
without restarting Quickshell; Omasnap remained visible and the three technical entries remained hidden.
The UTF-8 run emitted no QML warnings or errors. Only the temporary test list was edited for this check.

## Apps launcher grid

Apps now follows the application grid in the latest stable Omarchy release, v4.5.0
(`ac2690cd7be4f47e4a255f5e2e78d904d436b068`), checked through GitHub's latest-release API and the pinned
repository sources, not development-host package contents. See [UPSTREAM.md](UPSTREAM.md#apps-grid-omarchy-450).
The root Apps row and direct routes (SUPER+D and SUPER+ALT+SPACE) share the same centered, screen-bounded
seven-column/four-row grid. Search keeps the card centered; names wrap to two lines. Arrows move by cell or
column count and clamp at either end; Enter launches, Escape clears a filter before closing, and empty-filter
Backspace retains menu back-navigation. Provider updates retain selection by app identity. No dock or software
removal is added; root search, other submenus and selectors remain lists.

Synthetic checks cover geometry, route gating, selection, centering and the omission of list peeks/scrims.
Host verification: shell Node tests 234 passed, 11 skipped, zero failures; menu model 16/16; provenance covers
152 runtime files; catalog key coverage and integration-script syntax passed. These are synthetic/source checks,
not graphical acceptance. The integration script now compares direct/tree Apps geometry and search centering.
Reference VM validation: QML lint passes for 92 files with 2511 reviewed diagnostics, including 17 new
Style QObject token-resolution warnings reviewed for this change; no categories are disabled. The isolated menu
checks pass every new direct/tree geometry and search-centering assertion. The complete script retains exactly
the same six failures before and after this change: two stale Trigger/root-navigation expectations and four
missing-theme fixture warnings. These pre-existing test issues are not repaired or reported as passing here.
A menu-only temporary preview using the VM's real app library loaded without QML warnings. Both routes showed
19 apps in seven columns, a 901-by-526 logical-unit centered card; filtering to Foot returned three apps without
moving/resizing it. A captured tree-route view was inspected for icon/label layout and absence of list scrims.
The bounded candidate was then built from the installed runtime plus only the Apps files and their provenance,
published through install-runtime after a clean integrity check, and mirroros-shell.service restarted. Its manifest
check returned 0, the service remained active and loaded without QML errors, and installed direct/tree routes
both reported the same centered grid geometry. Sudo ran in a maintainer-authenticated tmux window which closed
automatically on successful completion. SSH IPC checks imported the graphical session's WAYLAND_DISPLAY.
No keyboard/pointer injection or application launch was performed. Attended keyboard/pointer launch, scrolling
beyond four rows, empty/unavailable states and screen changes remain unverified.

## Native application icons and passive updates

Apps reads the same `org.gnome.desktop.interface icon-theme` preference as GTK3/GTK4, including user overrides.
The `services/app-icons` Bash helper indexes application/device contexts in the selected theme, its recursive
inheritance chain, hicolor and pixmaps, in that order. XDG user/system roots are honored without splitting paths
on spaces; unrelated themes and action contexts are excluded. Within a theme root, SVG precedes PNG and larger
nominal PNG sizes precede smaller ones. This ordering and queued rescans adapt Omarchy
`520c3ed969d30b58defe03eb19d603f32b4cb002`; see [UPSTREAM.md](UPSTREAM.md#native-application-icons-and-stable-refresh).
File mtime/ctime/size signatures on image URLs reload changed resources without restarting Qt. Opening the menu
and catalog changes rescan; gsettings monitor observes theme preference changes read-only. Loose image edits
while the menu remains open are picked up at the next scan, not watched individually. Explicit dependency:
`glib2` provides gsettings and `gsettings-desktop-schemas` provides the native interface schema (reference VM:
`glib2 2.90.1-1`, `gsettings-desktop-schemas 51.0-1`, inspected with pacman -Qo/-Si). No preference is written.
The shared artwork is owned by [visual/gtk4](../../visual/gtk4/sources.md#application-icons).

Passive app/availability updates preserve bounded scroll without forcing the selected row back into view.
Selection continues to follow identity; removing it disables activation until another row is selected. Opening
or changing the search resets the grid to the beginning. Stale deferred rebuild callbacks cannot restore an older
view. Equal rendered Apps rows retain the ListModel and its delegates/images, including on reopening; changed
labels, icons, order or visibility rebuild it. This is bounded reuse, not a second catalog cache or an unmeasured
latency claim. Other menu lists and selectors retain their behavior. Tests cover theme precedence, inheritance,
PNG sizes, paths with spaces, symlinks, signatures, queued scans, row equality and bounded scroll.

Validation: host Node suites passed 261 tests, skipped 12 environment-dependent tests, zero failures; all 15 GTK4
configure/shell-publication contracts passed. Provenance covers 154 runtime files; i18n, ShellCheck and whitespace
checks passed. Reference VM: all 20 Apps tests passed, including a real 80-entry QML fixture that checked delegate
identity on unchanged refresh and reopening, scroll preservation/clamping, search reset, stable selection and
no activation after removal. QML lint retained exactly 2511 reviewed diagnostics across 92 files. GTK3, GTK4 and
AppLibrary resolved all 97 application names to identical candidate SVGs. The complete isolated menu script under
C.UTF-8 passed every Apps assertion and retained the six previously recorded failures (two stale root/navigation
expectations and four missing-theme fixture warnings). An initial non-UTF-8 SSH run was stopped because Qt locale
warnings polluted its JSON transport; its temporary process was stopped before rerunning. The installed shell
was not replaced or restarted for these checks; product publication and attended real launch remain pending.

## Screenshot command consumer (plan 02-40)

Trigger → Capture extends the existing menu with Screenshot and Screenshot with annotation. Both use closed action
ids and fixed argv to `/usr/share/mirroros/screenshot/screenshot`, with only the second adding `--edit`. The existing
menu IPC accepts `capture`, `screenshot` and `trigger.capture`; no second menu mechanism or capture daemon exists.
The English catalog owns these four new labels. Keyboard help reads the provider's existing MirrorOSKeys registry,
including both capture shortcuts and the Capture menu chord. Color/QR and their reserved keys stay deferred to
02-41; recording is excluded. Capture alone has a screen-clamped 440-unit card. Actions close the menu and dispatch
immediately, without a capture timer or backing-window wait. The Hyprland provider applies Omarchy's menu-only
no-animation rule after a viewer-keyboard trial reproduced the faded menu in the exported PNG; one repeated
Screenshot selector/export check passed with the rule and the maintainer approved adoption. Repeated reliability
and annotation were not separately retested in that comparison. Earlier VM launch-path checks observed runtime
recent inheritance after a new user manager; overall Task 3 delivery closure remains pending.
See [UPSTREAM.md](UPSTREAM.md#capture-menu-additions-plan-02-40) and the
[screenshots procedure](../../../docs/procedures/screenshots.md).

## Upstream material

Per-file provenance, licenses and the pinned Omarchy revision are recorded in
[UPSTREAM.md](UPSTREAM.md). Unchanged reused files stay byte-identical to that
revision and carry no MirrorOS header. MirrorOS tests and tooling live under
`tests/capabilities/desktop/shell/` and are not part of the delivered runtime.

## Weather forecast time zone (ADR 0029)

Weather uses the session `TZ` override or the system zone from a read-only, unprivileged
`timedatectl show --property=Timezone --value` query, resolved before the first forecast and
retained until the shell restarts. An empty system result falls back to explicit `GMT`.
All saved locations use that zone, matching the panel's local-date forecast filtering.
No zone is persisted and no system configuration is changed.

Reference VM `mirroros-ref`, 2026-11-16: the complete weather forecast query returned HTTP 403
with `timezone=auto`, while the same single-location query with `Europe/Madrid` or `GMT`
returned HTTP 200. This is an observed endpoint failure, not a claim about every client or
request. The model now URL-encodes an explicit zone. Model and panel contract regressions
live in `weather-model.test.mjs` and `calendar-weather.test.mjs`.

Reference VM validation, 2026-11-17: published the installed runtime plus only the two weather
file changes through `install-runtime`, verified its manifest and restarted `mirroros-shell.service`.
The generated combined request returned current conditions and four forecast dates for both saved
locations using the system zone. The panel opened through native IPC; the maintainer confirmed
that temperature and forecast displayed correctly. Shell Node tests: 229 passed, 11 skipped,
zero failures. This validates the bounded weather repair, not unrelated worktree changes.

## Defaults, preferences and private state (DEC-024/025)

| Concern | Owner | Location |
|---|---|---|
| Common shell defaults | MirrorOS, versioned, updated by configure | `defaults.json` beside `shell.qml` |
| Personal preferences | The user; written only by the shell interface or by hand | `$XDG_CONFIG_HOME/mirroros/shell.json` (fallback `~/.config`) |
| Private runtime state | The shell, per user; never in the repository or evidence | `$XDG_STATE_HOME/mirroros/shell/` (fallback `~/.local/state`) |

Personal preferences are sparse overrides of the defaults' shape:

- An option absent from `shell.json` follows the current `defaults.json`.
- Objects merge by explicitly present keys; a list (for example a bar layout
  section) replaces the whole default list.
- Saving a preference records only the paths that change; unrelated effective
  defaults are never copied. Deleting a key from `shell.json` restores the
  current default.
- A missing file means defaults; the shell does not create it at startup.
- Malformed, unsupported (`version` other than 1, unknown top-level keys,
  mismatched kinds) or prototype-pollution keys (`__proto__`, `constructor`,
  `prototype`) make the file invalid. The shell reports it, uses the defaults
  and never overwrites it; personal prototype state is not migrated.
- Writes are atomic, private (`umask 077`) and refused when the file changed on
  disk since the shell last read it. Symlinked files are written through.

Configure delivers `defaults.json` and never reads or rewrites `shell.json` or
the private state. Promotion of a personal choice into the common defaults is a
reviewed repository change, not an automatic operation.

## Format justification (NFR37/NFR38)

The recurring need is the single-maintainer multi-device workflow of DEC-025:
common defaults evolve in the repository while each device keeps a few
deliberate exceptions, and interface changes must not freeze unrelated defaults.

- **Complete upstream snapshots** (Omarchy's `shell.json` replaces all defaults
  and the shell persists the complete configuration): simplest, but any saved
  preference forks every default on that device. Rejected by DEC-025.
- **Executable QML user preferences**: would make personal data code loaded
  into the shell process, with no safe validation or interface write path.
- **Qt `Settings`/`QSettings`**: an INI store keyed by flat paths; it cannot
  express whole-list replacement of the existing JSON layout shape, and would
  add a second format beside the upstream data model.

The retained format is the reviewed upstream version-1 JSON application
preference shape, read sparsely. MirrorOS adds only the merge rule and its
validation (`services/ShellPreferences.js`); it is shell-local, not a universal
configuration schema, synchronization service or configuration manager.

## Wallpaper selection state (ADR 0020)

Selection is the shell-managed symlink `$XDG_STATE_HOME/mirroros/current/background` (fallback
`~/.local/state`), read with `readlink -f` at startup and on `refresh`. The theme configure step initializes it
only when absent. `services/wallpaper-set`, adapted from Omarchy, resolves any existing file and uses plain
`ln -nsf` before display. An existing non-symlink file or directory at the selection path is preserved and
reported. There is no JSON schema, lock, exact-read conflict check, atomic replacement, all-output save barrier,
rollback or automatic fallback. Concurrent writers and external edits are not detected. Obsolete prototype JSON
state is neither read, migrated nor removed. Images are never copied, changed or deleted by selection.

`WallpaperLibrary.qml` resolves `current/theme` on each request. Theme images come from its `backgrounds/`;
personal images come from `$XDG_CONFIG_HOME/mirroros/backgrounds/<resolved-theme-name>/` (fallback `~/.config`).
The scanner resolves directories before enumeration so catalog paths match the saved real path. `next` scans
every time and retains all entries; the picker deduplicates by basename, first sorted path wins, as Omarchy does.
Only Install > Style > Background creates the personal folder and opens it with `xdg-open` (xdg-utils), which
resolves `inode/directory` through the `mimeapps.list` owned by `desktop/portal`; the file manager is owned by
`desktop/files`.

`services/wallpaper-thumbnails` adapts Omarchy's libvips generation: 1536x864 centre-cropped JPEG, Q82 with metadata
stripped, single-threaded generators fanned out in parallel. The disposable cache is
`$XDG_CACHE_HOME/mirroros/image-selector/` (fallback `~/.cache`); its index uses path and size/mtime signatures,
per-thumbnail locks and stale-partial cleanup. Path keys are base64 inside the TSV index; internal image/thumbnail
pairs use NUL records to preserve tabs and newlines. External selector protocol, row/preload caches, labels and
filter modes are unnecessary for the integrated background-only picker. Cache failures do not change selection.
`libvips` is declared from official Arch `extra`; `util-linux` supplies `flock`. No image downloads or daemon are added.

## Audio availability

The OSD and existing audio bar widget reject WirePlumber's `auto_null` fallback as an unavailable output,
not a measured hardware volume. Other virtual sinks, including processing and network outputs, are not rejected
merely for being virtual. A dummy output shows the existing unavailable glyph/reason and accepts no bar volume
writes; normal missing-sink and provider-startup behavior is unchanged. This bounded MirrorOS correction follows
the Story 4.4 reference-VM finding on 2026-11-05; regression coverage is in
`tests/capabilities/desktop/shell/audio-availability.test.mjs`. It adds no panel or service.

## Authentication agent

`polkit/PolkitAgent.qml` is the session's polkit authentication agent, adapted from Omarchy over
`Quickshell.Services.Polkit` and bounded by
[ADR 0030](../../../docs/adr/0030-shell-hosted-polkit-agent-and-fingerprint.md):

- `shell.qml` instantiates it once as an isolated sibling; it registers at `/org/mirroros/PolkitAgent`,
  receives no shell references and is not exposed to other components.
- It stores, persists and logs no flow data (message, prompt or response). Its only log is a warning when
  registration fails.
- Its only process is `/usr/share/mirroros/hardware/lid-closed` with fixed argv (exit 0 means the lid is
  closed); it runs no `bash -c`. It reads `/etc/pam.d/polkit-1` read-only to decide whether to offer the
  fingerprint mode.
- Colors come from `Color.polkit`, derived from the selected theme; strings are the English `polkit.*` keys.
- No shell means no agent: polkit requests then fail closed. hyprlock is unchanged.

### Single owner

Polkit accepts one authentication agent per session and agents own no bus name, so `cfg_dbus_service_owner_unique`
does not apply. A competing agent is detected by what starts it. The postcondition `cfg_session_agent_unique`
(`capabilities/lib/files.sh`) fails the step with outcome `4`, naming each file, its package (or "not owned by a
package") and the next action, when:

- an active XDG autostart entry in `/etc/xdg/autostart` or the selected user's `~/.config/autostart` has an `Exec`
  whose executable basename is listed in `polkit-check/agents`; a user entry shadows the system entry of the same
  name, and `Hidden=true` entries are inactive;
- a user unit enabled globally (`/etc/systemd/user/*.wants`) or for the selected user
  (`~/.config/systemd/user/*.wants`) has an `ExecStart` whose executable basename is listed.

Configure never removes, hides or disables a competitor. `OnlyShowIn` and `NotShowIn` are not evaluated: an entry
for another desktop still counts. Personal Hyprland `autostart.lua` is never parsed; an agent started from it fails
`polkit-check` in the session only.

`agents` lists, one executable basename per line, the polkit authentication agents packaged for Arch that ship an
XDG autostart entry or a user unit and register with polkit as a session agent: polkit-gnome, lxsession's lxpolkit,
polkit-kde-agent, mate-polkit, lxqt-policykit, xfce-polkit and hyprpolkitagent (plan 02-36 residue). Agents hosted
inside another process cannot be listed by executable and are outside this check.

### Session check

`polkit-check` is a read-only command in the style of `portal-check`, run by the session user after a new login. It
prints `ok:` and `FAIL:` lines and exits 0 when `mirroros-shell.service` is active and no listed agent process runs
for the user, and 1 otherwise. Full command lines are matched because process names are truncated to 15 characters.
Registration of the shell-hosted agent is evidenced by attended prompts, not by this check.

### Session action challenge

When logind answers `challenge` for a session action, `services/SessionActions.qml` makes the row available with
"<Label> asks for authorization." and runs the same fixed argv, so the agent shows the prompt. The shell probes no
agent unit, never handles credentials and neither retries nor reports a cancelled or denied prompt (fail-closed,
ADR 0012). Coverage: `tests/capabilities/desktop/shell/check-menu.sh`.

## Clipboard picker (plan 02-38)

The clipboard surface and pure model adapt Omarchy quattro
`520c3ed969d30b58defe03eb19d603f32b4cb002` (MIT, David Heinemeier Hansson),
`shell/plugins/clipboard/Clipboard.qml` and `ClipboardHistory.js`. The confirmation
and bounded raster image components derive from `shell/Ui/ConfirmDialog.qml` and
`SizedImage.qml` at the same revision. Per-file changes are in [UPSTREAM.md](UPSTREAM.md).

- `shell.qml` composes one `services/Clipboard.qml`, exposed as `mirroros.clipboard`,
  and one picker. `mirroros:clipboard` toggles it; native IPC target `clipboard`
  accepts `open` and `toggle`.
- Every history operation uses `/usr/share/mirroros/clipboard/clipboard-history`
  with separate argv elements. The capability's [sources](../clipboard/sources.md)
  govern provider versions, RAM storage, approved resident watchers and drop rules.
  The shell neither starts watchers nor reads a database or file directly.
- Each opening requests one `list`. Filtering and successful delete/clear updates
  are local; external copies become visible on the next opening. There is no
  polling, FileView, file watching or startup process in the clipboard service.
  Close discards the in-memory list and preview paths; generation checks ignore
  stale results after reopening. Failed list/mutation operations show a retry
  message without logging content.
- Display uses cliphist's summarized list text, capped at 8192 characters per row;
  the text preview is that summary, not a full decode. All text is plain. Enter
  copies and closes without pasting; Alt+Enter delegates opening to the command.
  Shift+Enter does nothing. Shift+Delete asks for confirmation with Cancel selected.
- PNG previews are requested only for selected or visible rows, deduplicated per
  opening and decoded serially through `preview <id>`. Only the expected path
  under `$XDG_RUNTIME_DIR/mirroros/clipboard/previews/` is accepted. The command
  owns pruning; QML writes nothing and uses no persistent image cache of its own.
  Image decoding is bounded to the displayed physical-pixel size; very thin
  images have no special retry fallback in this PNG-only component.
- The pure model and command-adapter behavior have Node contract coverage in
  `tests/capabilities/desktop/shell/clipboard-model.test.mjs`. Live keyboard,
  focus, image and open-handler acceptance belongs to the reference-VM campaign.
- Corrective Task 3 warning review uses the reference VM's qt6-declarative
  6.12.0-4 (`qmllint` 6.12.0) and quickshell 0.3.2-1. The service uses explicit
  root process-property access without duplicate object ids and block-local
  constants; those avoidable diagnostics are not baseline exceptions. The 17
  remaining style diagnostics name members declared in the QtObject-typed
  `Commons/Style.qml` font/spacing and `Commons/Color.qml` menu objects. Keep
  those reactive bindings rather than replacing tokens or changing shared types.
  The added GlobalShortcut has the existing Quickshell.Hyprland re-export
  limitation; the existing PostReloadHook diagnostic only moves its context key.
  Each retained diagnostic is recorded in the test baseline; no category is disabled.

## Delivery and lifecycle

The `desktop/shell` configure step (`apply`) installs `packages`, publishes the
runtime with `install-runtime` and enables the user unit. `apply`, `packages`,
`install-runtime`, `systemd/` and `polkit-check/` are not part of the runtime.

- The runtime is published to `/usr/share/mirroros/shell` as one tree with
  unchanged bytes (executable files `0755`, others `0644`) and a
  `.mirroros-manifest`. It is staged beside the destination, verified and
  exchanged atomically, so an interrupted run leaves the previous or the new
  complete tree. A link, an unknown directory or a delivery edited in place is
  a conflict: configure fails without overwriting it. Configure evidence
  records the source manifest digest, not file contents.
- `systemd/mirroros-shell.service` is delivered to
  `/etc/systemd/user/mirroros-shell.service` (a tracked delivery: local edits
  are conflicts) and enabled for the selected user only, offline, by its
  `graphical-session.target.wants` link. It is the single startup and restart
  owner (DEC-023): bounded `on-failure` restarts, journal logging, no Hyprland
  autostart and no supervision script. It does not depend on hypridle or
  hyprlock.
- `polkit-check/polkit-check` (`0755`) and `polkit-check/agents` (`0644`) are
  delivered to `/usr/share/mirroros/polkit/`; `cfg_session_agent_unique` reads
  the source list during configure.
- Configure never starts, restarts or reloads the shell. A running session
  picks up a new unit at its next login; to switch earlier, run
  `systemctl --user daemon-reload` and `systemctl --user restart
  mirroros-shell.service` deliberately.
