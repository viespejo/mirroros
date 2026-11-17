# Clipboard sources and ownership

## Packages and reference facts

The capability owns `cliphist`, `wl-clipboard` and `fzf` from official Arch `extra`. Configure records resolved
versions in `packages.tsv`; these observations are not pins.

Read-only reference VM query on 2026-11-16, through `ssh -p 2222 viespejo@127.0.0.1`:

- `pacman -Q wl-clipboard`: `wl-clipboard 1:2.3.0-1`.
- `pacman -Q cliphist`: not installed at this checkpoint.
- `pacman -Si cliphist wl-clipboard`: `extra/cliphist 1:0.7.0-2` and `extra/wl-clipboard 1:2.3.0-1`
  in the guest's repository databases. Recheck the installed cliphist version during the laboratory campaign.

The [cliphist v0.7.0 source](https://github.com/sentriz/cliphist/blob/v0.7.0/cliphist.go) and
[Arch recipe](https://gitlab.archlinux.org/archlinux/packaging/packages/cliphist/-/blob/main/PKGBUILD), inspected on
2026-11-16, show an unpatched, hard-coded `len(input) > 5*1e6` rejection. There is no `max-store-size` option.
**Execution amendment approved by the maintainer for plan 02-38 Task 1:** replace the planned 32 MiB image limit
with **5,000,000 bytes** (decimal, not 5 MiB), so the wrapper logs oversize drops instead of letting cliphist silently
lose entries below the advertised limit. Text remains limited to 1 MiB. No patched provider is delivered.

`CLIPBOARD_STATE=sensitive` causes cliphist to skip storage; `clear` deletes its last entry. wl-clipboard 2.3.0
propagates sensitive selections when offered `x-kde-passwordManagerHint`, but does not export `CLIPBOARD_TYPE`.
The two units therefore specify the capture type explicitly. Provider sensitivity is advisory: applications that
do not mark secrets cannot be identified by this command.

During the plan 02-38 reference-VM laboratory, Chromium 156.0.8078.79-1 image-copy history included a BOM-less
UTF-16LE URL alongside the PNG. Restoring those bytes as UTF-8 produced corrupt text. The
[wl-clipboard v2.3.0 source](https://github.com/bugaevc/wl-clipboard/blob/v2.3.0/src/wl-paste.c), inspected on
2026-11-16, confirms that `--type text` prefers UTF-8/plain text but falls back to another offered text type;
it does not transcode the payload. The watcher remains unchanged; `store text` now normalizes before storage.

The same VM reports `xdg-utils 1.2.1-2` (required by `qt6-base` and `openconnect`, as well as laboratory Chromium)
and `util-linux 2.42.4-1`. `xdg-open` is supplied by `xdg-utils` in the configured desktop's dependency closure;
`notify-send` is already owned by `system/power` (`libnotify`). `flock` comes from `util-linux` (also declared by
`desktop/shell`); Bash,
coreutils, grep and awk are base-system tools. A further read-only VM query during the laboratory confirmed
`/usr/bin/iconv` belongs to `glibc 2.44+r50+g1848099f063e-1`, `/usr/bin/od` to `coreutils 9.12-2`, and `/usr/bin/awk`
to `gawk 5.4.1-1`. The normalization uses these existing base tools; no additional management daemon or parser
dependency is introduced.

A read-only reference-VM query during the text-open laboratory failure reports `uwsm 0.27.1-1`,
`xdg-utils 1.2.1-2` and `coreutils 9.12-2`. The packaged `/usr/bin/xdg-open` generic `search_desktop_file`
executes the desktop entry's command without handling `Terminal=true`; the existing `text/plain` default was
`nvim.desktop` from `neovim 0.12.6-1`. That launched Neovim without a visible terminal and left the history lock
held while it waited. The maintainer explicitly approved an exception to the original all-`xdg-open` plan:
non-URL text uses `xdg-mime query default text/plain`, then `uwsm app -t service -- <desktop-id> <runtime-file>`.
This applies the shell's established desktop-entry launcher and desktop/terminal's `xdg-terminals.list` policy,
not a new editor or terminal selection. The VM's packaged `/usr/share/uwsm/modules/uwsm/main.py` constructs a
`Type=exec`, `ExitType=cgroup` service for this mode, without `--wait`; scope mode instead uses `--scope` and
waits for the application. Service mode therefore bounds launcher startup without timing out an editor's lifetime.
No new management daemon, unit enablement or MIME association is introduced.

## Approved resident service

- **Processes:** two `wl-paste --watch` processes, capturing `text` and `image/png` respectively, invoking
  `/usr/share/mirroros/clipboard/clipboard-history store <type>` for each selection.
- **Starters:** `mirroros-clipboard-text.service` and `mirroros-clipboard-image.service`, delivered into
  `/etc/systemd/user` and enabled for the selected user in `graphical-session.target.wants`.
- **Content:** ordinary copied text and PNG bytes only, at most 200 entries; sensitive selections are delegated to
  cliphist without spooling their contents. A `clear` state keeps cliphist's delete-last semantics even under low space.
- **Location:** `${XDG_RUNTIME_DIR}/mirroros/clipboard/db`, directory mode 0700. Temporary, preview and open files
  use mode 0600, exclusively under that runtime tree. Every cliphist invocation sets `-db-path`, `-max-items 200`
  and `-config-path /dev/null`; user cliphist configuration cannot redirect this command to disk.
- **Lifecycle:** enable-only during configure, start at the next graphical login, `PartOf` and ordered after
  `graphical-session.target`, stop with that target, restart on failure after two seconds. No shell-owned capture
  process, polling, duplicate-owner check, or pause state is introduced. Runtime files follow logind's user-runtime
  lifetime; with multiple sessions or lingering, graphical logout need not remove the runtime directory immediately.

## Command and storage boundaries

`clipboard-history` owns `store`, `list`, `decode`, `copy`, `delete`, `clear`, `preview`, `open` and terminal `pick`.
It serializes access with a runtime lock (released while fzf waits and before querying or launching an opener)
and preserves child failures. A new empty
history lists successfully without creating a disk database. Usage errors return 2.

Capture drops the whole entry above 1,048,576 text bytes or 5,000,000 PNG bytes, or if the runtime filesystem would
have less than 25% free space after the prospective write. Staging is bounded by the smaller of the entry cap plus
one byte and half the available headroom above that reserve; rejected streams are drained without retaining their
contents. The free-space check is repeated after staging. Drops write only `type=<type> size=<bytes>` to stderr,
which the watcher unit sends to the journal. Size checks log the full received or normalized byte count, never
just the retained prefix.

Text capture preserves valid UTF-8 without NUL bytes. UTF-16 with a BOM is converted using `iconv`; without a
BOM, conversion requires an even byte count, NUL padding in at least three quarters of one byte lane and fewer
than one quarter in the other. This detection heuristic is independently reimplemented from Omarchy's
`shell/plugins/clipboard/capture.sh` at the reference below, using Bash/awk rather than its Perl code. Heuristic
conversions containing non-text control bytes, ambiguous NUL-containing input and malformed encodings are dropped
whole. BOM-less UTF-16 with insufficient padding cannot be reliably inferred and is not supported. Sensitive/clear
states bypass normalization. Both received and normalized text must fit 1 MiB. Conversion output is bounded by
that cap plus one byte and the current free-space headroom; overflow is drained, and the reserve is rechecked
before storage. Conversion uses private runtime files only. Encoding drops log the input size; conversion size or
space drops log the normalized byte count, always with type and size only. Existing history entries are never
rewritten: delete a previously corrupt entry and copy it again after deployment.

This is a capture guard, not a filesystem quota: unrelated runtime users can race the check, and bbolt allocates in
pages and can grow beyond an entry's exact size. Its high-water file does not shrink on ordinary deletes;
`clear` uses cliphist's `wipe` (which also compacts). Entry count alone is not a byte bound.

Copy checks the decoded PNG signature and uses `wl-copy --type image/png`, otherwise
`wl-copy --type 'text/plain;charset=utf-8'`. No MIME inference, `file`, auto-paste or `wtype` is used.
`preview <id>` decodes on demand to `previews/<id>.png`. `list` and `delete` prune orphan PNG previews;
`delete` removes that entry's open file, and `clear` removes all preview/open files. `list` never prunes `open/`
because an editor can still have a file open. The command emits paths rather than embedding image bytes in its UI.

Open uses `xdg-open` on a PNG preview, the first HTTP(S) URL anywhere in text, or a domain-only entry prefixed
with `https://`. Other text is retained in a private `open/<id>.txt` and launched through its existing desktop
association using `uwsm app -t service`, as approved above. Empty, option-like, path-like, action-bearing or
multiline handler responses are rejected rather than executed. Both the MIME query and application launcher have
a 10-second timeout with a further 2-second kill grace; stdin is `/dev/null` and the history lock/descriptor is
released before either operation. Listing and capture remain available while an opener is busy. Missing handlers,
query/launch failures or timeouts trigger a normal-urgency transient notification with the next action (check the
handler in `mimeapps.list` and the terminal configuration), and return nonzero. No association or named
browser/editor/viewer fallback is installed. A successful service start does not guarantee later application
health. External handlers own their subsequent behavior; this command cannot prevent an application from saving
a file or URL to its own state.

## Known limits and deferred policy

- PNG only: images offered without `image/png` are not captured. There is no second MIME metadata store.
- Bare `cliphist` still targets `$XDG_CACHE_HOME/cliphist/db` (normally `~/.cache/cliphist/db`) on disk. Consumers
  must use the owned command; the units do not set global cliphist environment variables.
- RAM-only paths assume the standard logind runtime tmpfs. Hibernation and lower-priority fallback swap can expose
  those pages on the unencrypted swapfile (ADR 0007). There is no wipe on suspend/hibernate or system-sleep hook;
  this residual risk belongs to the pending disk-encryption decision, not to a claim of encrypted history.
- Pause, disk persistence and pinned entries are deferred. Manual unit stop/start is the operator path.
- No hardware qualification is implied. Session lifecycle, MIME round trips and sensitivity require the reference
  VM laboratory campaign; command doubles alone do not establish them.

## Omarchy reference

Inspected local reference: `~/code/omarchy`, branch `quattro`, commit
`520c3ed969d30b58defe03eb19d603f32b4cb002` (MIT, David Heinemeier Hansson).
`bin/omarchy-clipboard-open` supplies the URL/domain heuristic; `shell/plugins/clipboard/capture.sh`,
`bin/omarchy-clipboard-paste-file` and `shell/plugins/clipboard/Clipboard.qml` inform the explicit PNG/text
capture/restore interface and the UTF-16 detection heuristic. The owned command implements the heuristics
independently with shell tools; no Omarchy script or source block is copied. Unlike that reference, it uses cliphist, private runtime files, `xdg-open`, bounded
capture, and no JSON store, capture script, auto-paste or named application launcher. UI and keybinding adaptations
are recorded separately by their owning shell and compositor provenance files when delivered.
