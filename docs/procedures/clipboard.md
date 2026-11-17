# Clipboard and history procedure

**Availability:** Story 4.5 source and configure delivery are integrated in plan 02-38. Live session acceptance,
clipboard round trips and watcher logout behavior remain pending its blocking reference-VM laboratory checkpoint.
No hardware qualification is claimed.

## Ownership and lifecycle

The `desktop/clipboard` capability declares `cliphist`, `wl-clipboard` and `fzf` from Arch `extra`. It runs
immediately before `desktop/shell` in the 25-step configure sequence. Configure installs the tracked command
`/usr/share/mirroros/clipboard/clipboard-history` (0755) and two tracked user units under `/etc/systemd/user`:

- `mirroros-clipboard-text.service`: `wl-paste --type text --watch`, invoking `clipboard-history store text`.
- `mirroros-clipboard-image.service`: `wl-paste --type image/png --watch`, invoking `clipboard-history store image/png`.

These two watchers are the approved resident service, not a management daemon. Configure enables them for the
selected user's `graphical-session.target` **without starting them**. They start at the next graphical login,
are ordered after and stop with that target (`PartOf`), and restart on failure after two seconds. A configure
rerun should report the step unchanged. Tracked local edits, unknown files and symlinks are preserved as conflicts;
restore the delivery or move the conflicting file aside deliberately before rerunning configure.

Every provider invocation sets `-db-path "$XDG_RUNTIME_DIR/mirroros/clipboard/db"`, `-max-items 200` and
`-config-path /dev/null`. The runtime directories are 0700; temporary, preview and open files are 0600. The standard
logind user runtime directory is tmpfs. Its lifetime is the user's runtime lifetime, not necessarily one graphical
session: multiple sessions or lingering can keep files after graphical logout even though the watchers stop with
the graphical target. There is no explicit logout wipe.

The shell's `mirroros.clipboard` service is an on-demand command adapter, not another capture service. Each picker
opening requests one list; filtering and successful delete/clear updates are local. Copies made while it is open
appear on the next opening. It has no polling, file watching or startup process.

## Command interface

Use the owned command in a graphical user session with `XDG_RUNTIME_DIR` and Wayland access:

```bash
history=/usr/share/mirroros/clipboard/clipboard-history
"$history" list
"$history" pick
```

| Subcommand | Behavior |
|---|---|
| `store text` / `store image/png` | Read stdin and capture subject to the limits below; normally invoked by the units |
| `list` | List numeric ids and summarized text/binary markers; prune orphan PNG previews |
| `decode <id>` | Write the original entry bytes to stdout |
| `copy <id>` | Restore PNG as `image/png`, otherwise `text/plain;charset=utf-8`; never paste |
| `delete <id>` | Remove the entry, its preview and its open file; prune orphan previews |
| `clear` | Wipe/compact history and remove all preview/open files; destructive, no command-line confirmation |
| `preview <id>` | Decode a PNG on demand to `previews/<id>.png` and print its runtime path |
| `open <id>` | Open a runtime PNG/URL through `xdg-open`, or a private text file through its existing desktop association |
| `pick` | Select through terminal `fzf` and copy, without pasting |

Paths in the table are relative to `$XDG_RUNTIME_DIR/mirroros/clipboard/`. `list` never prunes `open/`, since an
editor may still be using a file. Usage errors return 2; upstream failures remain failures. `decode` emits content:
do not redirect it to persistent storage or include it in diagnostics/evidence. The command itself never writes
clipboard bytes outside the runtime tree, but a caller or external handler can save them independently.

**Do not run bare `cliphist`.** Its default database is `$XDG_CACHE_HOME/cliphist/db` (normally
`~/.cache/cliphist/db`) on disk. All consumers must use `clipboard-history`; no global environment override is
installed. A pre-existing disk database is not removed by configure: inspect and handle it privately, never copy
its contents into evidence.

## Keys and picker

| Key | Action |
|---|---|
| `SUPER+C` / `SUPER+V` | Copy/paste: `CTRL+SHIFT+C/V` for terminal-tagged Foot windows, `CTRL+C/V` otherwise |
| `SUPER+X` / `SUPER+A` | Send `CTRL+X` / `CTRL+A` everywhere, including terminals |
| `SUPER+CTRL+V` | Toggle the clipboard picker |

Only Foot (`foot` and `org.codeberg.dnkl.foot`) receives the product's `+terminal` tag. Select-all and cut are
not terminal-specific translations and need not have GUI semantics in a terminal application. Synthesized keys
use explicit down/up events separated by 50 ms, without a window target, so focused shell fields can receive them.
The `clipboard.*` actions are in the registry and keyboard help (`SUPER+K`).

Known Hyprland risk (#114): an update may cause stuck synthetic modifiers or key-not-found errors. Release and
re-press the modifiers; if needed, deliberately run `hyprctl reload` after reviewing personal configuration.
Native application shortcuts, including Foot's `CTRL+SHIFT+C/V`, remain the permanent fallback. Configure does not
reload Hyprland; new bindings require a new login or an explicitly authorized reload.

In the picker, typing filters; arrows, PageUp/PageDown and Home/End move selection. Enter copies and closes without
pasting; Alt+Enter opens and closes. Delete removes the selected entry. Shift+Delete asks to clear all history,
with Cancel selected initially. Escape clears a nonempty filter, otherwise closes. Shift+Enter has no action.
Text rows and previews render only plain text, using cliphist's list summary capped at 8192 characters per row,
not a full decode. PNG previews are requested only for selected or visible rows and stored under the runtime tree.

The shell exposes `mirroros:clipboard` as a GlobalShortcut and native IPC target `clipboard` with `open` and
`toggle` (returning `ok`):

```bash
qs ipc -p /usr/share/mirroros/shell call clipboard open
qs ipc -p /usr/share/mirroros/shell call clipboard toggle
```

`open` chooses the first HTTP(S) URL anywhere in text, otherwise prefixes a domain-only entry with `https://`.
Other text is written unchanged to `open/<id>.txt` (0600); PNG uses its runtime preview. URL and PNG use
`xdg-open`. Text queries the existing `text/plain` association with `xdg-mime` and launches that desktop entry via
`uwsm app -t service`, honoring `Terminal=true` and the existing terminal preference list. This is the approved
plan 02-38 laboratory amendment: the reference VM's generic `xdg-open` launched its existing Neovim handler
without a visible terminal. No specific editor or terminal is selected here.

The history lock is released before querying or launching an application, so a busy opener cannot block listing
or capture. The query and launcher each have a 10-second timeout plus a 2-second kill grace, with stdin disconnected;
the service-launched editor is not limited to that lifetime. An absent/invalid handler, query/launch failure or
timeout sends a normal-urgency transient notification stating the next action: check the default handler in
`mimeapps.list` and the terminal configuration, then retry. This capability adds no association and chooses no
browser, editor or image viewer; association ownership remains with the
[portals and files procedure](portals-and-files.md). Successful startup does not guarantee later application
health. External applications can retain their own state or copies; runtime-only history does not constrain them.

## Capture limits and privacy

- At most 200 entries. Text above **1 MiB (1,048,576 bytes)** and PNG above **5,000,000 bytes** are dropped whole.
  The PNG cap is the approved Task 1 amendment to the planned 32 MiB: cliphist 0.7.0 silently rejects larger
  inputs and has no configurable store-size option. See the [capability sources](../../capabilities/desktop/clipboard/sources.md).
- Text is stored as valid UTF-8 without NUL bytes. UTF-16 with a BOM is normalized; BOM-less UTF-16 is normalized
  only when its NUL-padding pattern identifies the byte order conservatively. Ambiguous, malformed or non-text
  input is dropped whole, without content in the log. BOM-less UTF-16 without sufficient padding is not supported.
  Both the received and normalized text must fit the 1 MiB cap; conversion is bounded and rechecks runtime space.
  This fixes the UTF-16 URL seen alongside a Chromium image copy in the plan 02-38 laboratory. Previously captured
  corrupt entries are not repaired: delete them and copy again after deployment.
- Capture also drops an entry if staging/storage would breach the 25% runtime-filesystem free-space reserve.
  Input staging is bounded and rejected streams are drained. Each drop logs only `type=<type> size=<bytes>` to
  stderr, collected by the watcher journal; it never logs the content. Encoding rejection reports the received
  size; a conversion limit or space rejection reports the full normalized size.
- This free-space check is a guard, not a quota: other writers can race it, and bbolt allocates pages and retains
  a high-water file size after ordinary deletion. `clear` uses cliphist's wipe/compaction.
- Only PNG images are captured; images not offered as `image/png` do not enter history.
- `CLIPBOARD_STATE=sensitive` reaches cliphist without spooling the bytes and prevents storage. `clear` preserves
  cliphist's delete-last behavior even under low space. Sensitivity is advisory: applications that do not mark
  secrets cannot be detected. Chromium password-manager sensitivity remains laboratory data, not a guarantee.
- RAM-only paths are not encrypted history. Hibernation and lower-priority fallback swap can write runtime pages
  to the unencrypted swapfile ([ADR 0007](../adr/0007-zram-and-hibernation-policy.md)). This residual risk belongs
  to the pending disk-encryption decision. There is no wipe on suspend/hibernate and no system-sleep hook.
- History pause, disk persistence and pinned entries are deferred. There is no pause setting or check command.

## Manual watcher control

To stop capture deliberately, run as the session user (not with `sudo`):

```bash
systemctl --user stop mirroros-clipboard-text.service mirroros-clipboard-image.service
```

This does not erase history or the current selection and is not a persistent pause policy. To resume capture:

```bash
systemctl --user start mirroros-clipboard-text.service mirroros-clipboard-image.service
```

Only run these state-changing commands when intended. After new unit delivery, prefer a new graphical login;
manual unit reload/start is an explicit operator action, never configure behavior.

## Session verification

After configure succeeds, rerun it and confirm `desktop/clipboard` is unchanged, then log out and back in.
Run these read-only checks as that user in the new graphical session:

```bash
systemctl --user is-enabled mirroros-clipboard-text.service mirroros-clipboard-image.service
systemctl --user is-active mirroros-clipboard-text.service mirroros-clipboard-image.service
findmnt -T "$XDG_RUNTIME_DIR" -o TARGET,FSTYPE,OPTIONS
df -h -- "$XDG_RUNTIME_DIR"
test ! -e "${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/db"
```

Copy a disposable test string before checking that the runtime database exists:

```bash
test -f "$XDG_RUNTIME_DIR/mirroros/clipboard/db"
stat -c '%a %n' "$XDG_RUNTIME_DIR/mirroros/clipboard"
journalctl --user -u mirroros-clipboard-text.service -u mirroros-clipboard-image.service --since today
```

Verify the keys and picker with disposable text/PNG only; use `clipboard-history pick` in Foot. A disposable
`wl-copy --sensitive` selection must never appear in history. For a restored PNG, `wl-paste --list-types` must
offer `image/png`, and a real GUI paste must succeed. After graphical logout, inspect the user manager from a
separate non-graphical session: both units must be inactive and no matching `wl-paste --watch` process may remain
(`systemctl --user status ...` and `pgrep -af wl-paste`). Account for other graphical sessions before attributing
runtime files or processes to a lifecycle failure.

The blocking plan 02-38 laboratory campaign also covers terminal/GUI round trips, missing handlers, oversize
drops and screenshot-size observations. Evidence belongs only under ignored `evidence/clipboard/lab-02-38/` with
`SHA256SUMS`, using disposable strings and no secrets. Contract tests do not establish these live results.

## Provenance

Provider facts, ownership and command design: [clipboard sources](../../capabilities/desktop/clipboard/sources.md).
UI/model/components: [shell upstream record](../../capabilities/desktop/shell/UPSTREAM.md).
Universal keys and recovery: [Hyprland upstream record](../../capabilities/desktop/compositor/providers/hyprland/UPSTREAM.md#story-45-clipboard-additions).
Incorporation notices: [attribution](../attribution.md).
