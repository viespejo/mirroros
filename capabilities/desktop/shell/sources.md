# Desktop shell sources and configuration ownership

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
