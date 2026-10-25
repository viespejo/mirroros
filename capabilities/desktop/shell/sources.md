# Desktop shell sources and configuration ownership

## Upstream material

Per-file provenance, licenses and the pinned Omarchy revision are recorded in
[UPSTREAM.md](UPSTREAM.md). Unchanged reused files stay byte-identical to that
revision and carry no MirrorOS header. MirrorOS tests and tooling live under
`tests/capabilities/desktop/shell/` and are not part of the delivered runtime.

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

## Delivery and lifecycle

The `desktop/shell` configure step (`apply`) installs `packages`, publishes the
runtime with `install-runtime` and enables the user unit. `apply`, `packages`,
`install-runtime` and `systemd/` are not part of the runtime.

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
- Configure never starts, restarts or reloads the shell. A running session
  picks up a new unit at its next login; to switch earlier, run
  `systemctl --user daemon-reload` and `systemctl --user restart
  mirroros-shell.service` deliberately.
