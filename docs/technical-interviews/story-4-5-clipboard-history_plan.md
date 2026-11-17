# Story 4.5 clipboard and history — Consolidated Plan

## Scope and inputs

This plan delivers Story 4.5 Area 3, clipboard and history, as plan 02-38 following the polkit area (plans 02-36
and 02-37). The brainstorming record's Area 3 decisions are the starting point: cliphist from `extra` as the store,
a shell picker adapted from Omarchy's UI with its data layer replaced by `cliphist list`/`decode`, a RAM history,
two watcher user units, copy-only selection, a history pause, universal `SUPER+C/V/X/A` and `SUPER+CTRL+V` for the
history. The interview resolves its handoff questions.

## Governance

The area enters without a new ADR. The `docs/mvp-scope.md` "Clipboard and history" row records the scope change:
cliphist as provider, the two `wl-paste --watch` user units as the approved clipboard resident service (process,
starter, content, RAM location, and lifecycle bound to `graphical-session.target`), and the picker as a bounded shell
surface under ADR 0012's scope-change rule. Provenance lives in `capabilities/desktop/clipboard/sources.md` and the
shell `UPSTREAM.md`. Disk persistence or pinned entries remain out of scope and would require an ADR because they
change the secrets-at-rest posture [DEC-001].

## Storage bounds

The history keeps at most 200 entries through cliphist's `max-items`. Because cliphist 0.7.0 cannot bound bytes and
its bbolt file never shrinks, an owned Bash wrapper, `clipboard-history store` [DEC-009], sits between each
`wl-paste --watch` and `cliphist store`. It reads the entry from stdin and drops it whole, without truncating, when text exceeds 1 MiB, an
image exceeds 32 MiB [DEC-008], or storing it would leave the runtime tmpfs with less than 25% free space. That last guard
protects the shared `$XDG_RUNTIME_DIR` (about 1.6 GB on the 16 GB T14s) for the Wayland socket and other session
components, without adding pruning code. Drops are silent to the user and appear in the journal with type and size
only, never content. Bats contract tests cover every drop rule [DEC-002].

## Capture and restore types

The MIME type is fixed at capture time, following Omarchy (`Clipboard.qml`, `capture.sh`,
`omarchy-clipboard-paste-file` at `520c3ed96`). The image watcher listens only to `image/png` and passes that type
to `clipboard-history store` as an argument; the text watcher does the same for text. Every binary entry in the
history is therefore PNG, so selection (`clipboard-history copy <id>` [DEC-009]) restores images with
`wl-copy --type image/png` and text with `wl-copy --type 'text/plain;charset=utf-8'`, with no format mapping and no dependency on `file` or `xdg-mime`
inference. Images offered without `image/png` (rare JPEG- or WebP-only sources) do not enter history, a known limit
recorded in `capabilities/desktop/clipboard/sources.md`. The laboratory confirms the round trip: an image copied from
Chrome or Strata, selected from history, is offered as `image/png` and pastes into a graphical application
[DEC-003].

## Sleep and hibernation

The history is not wiped on suspend or hibernate. Suspend keeps RAM in RAM. Hibernation (user-initiated from the
session menu or `systemctl hibernate`, or HybridSleep on critical battery) writes all of RAM to the unencrypted
swapfile of ADR 0007, and that swapfile also receives fallback swap. A pre-hibernate wipe would therefore protect
only part of the exposure, while the browser, terminals and unlocked keyring secrets reach disk anyway. The residual
risk is stated in `capabilities/desktop/clipboard/sources.md` and the `docs/mvp-scope.md` row and handed to the
pending disk encryption decision. A stricter policy would be a root `system-sleep` hook, which needs an ADR because it
crosses the privilege boundary [DEC-004].

## Universal keys

The universal keys live in a new `clipboard-bindings.lua` in the Hyprland provider, adapted from Omarchy's
`clipboard.lua`. `SUPER+C` and `SUPER+V` send `CTRL+C`/`CTRL+V`, or `CTRL+SHIFT+C`/`CTRL+SHIFT+V` when the focused
window carries the `terminal` tag; `SUPER+X` sends `CTRL+X` and `SUPER+A` sends `CTRL+A`. Keys go through
`hl.dsp.send_key_state` with explicit mods and no window target, so they also reach shell panels, with Omarchy's
50 ms down/up split against stuck synthetic keys. A single `+terminal` window tag in `defaults.lua` matches Foot's
classes. `SUPER+CTRL+V` opens the history through `hl.dsp.global("mirroros:clipboard")`. All entries are registered
in `MirrorOSKeys` as `clipboard.*`, and the clipboard keys move from reserved to bound in the provider `UPSTREAM.md`.
Because synthetic keys are compositor-bound, a compositor replacement touches only this file [DEC-005].

Stuck modifiers or key-not-found errors after a Hyprland update are a known risk (#114). `UPSTREAM.md` and the
procedure carry a recovery note (release and re-press the modifiers, `hyprctl reload`), and the native shortcuts
remain the permanent fallback. The laboratory exercises the five keys in Foot (also inside tmux and Neovim), in
Chrome or Strata, and in a shell panel field [DEC-005].

## Test scope

Verification runs only the tests affected by the changed files: the clipboard capability tests, the Hyprland
bindings and keybinding tests, the touched shell model tests, the mechanism and target contracts when the configure
step list changes, and qmllint or `check-menu.sh` for touched QML. Full-suite runs are not part of this plan
[DEC-006].

## History pause

There is no history pause. Delete entry and clear history in the picker cover the real use case, secrets copied
from sources that do not mark them sensitive, at the same user effort as pausing beforehand. They also avoid a
forgotten pause silently disabling history and the indicator, command, IPC and state handling a pause would require.
The procedure documents the manual path, stopping and starting the watcher user units. The watchers therefore stay
always active for the session with no intermediate state. A full pause is deferred and can be added later as a
bounded change if daily use shows the need. This supersedes the brainstorming's in-scope pause [DEC-007].

## Single command interface

All history access goes through one owned command, `/usr/share/mirroros/clipboard/clipboard-history`, which always
passes the RAM `-db-path` and `-max-items 200` to cliphist. Its subcommands are:

- `store <type>`, the capture wrapper the watchers invoke;
- `list` and `decode <id>`;
- `copy <id>`, which restores with the fixed `--type`;
- `delete <id>` and `clear`;
- `pick`, the `fzf` terminal path.

The shell picker and the terminal never call `cliphist` directly, so the database path, limits and types have a
single definition, and the promise that nothing reaches disk is testable at one point. The procedure warns that bare
`cliphist` still targets its on-disk default [DEC-009].

## Capability layout

A new `capabilities/desktop/clipboard/` capability, the path the architecture already reserves, owns the clipboard
provider. Its `packages` declares `cliphist`, `wl-clipboard` and `fzf` from `extra`. `apply` installs
`clipboard-history` to `/usr/share/mirroros/clipboard/clipboard-history` and delivers two new user units to
`/etc/systemd/user`, `mirroros-clipboard-text.service` and `mirroros-clipboard-image.service`. Each runs
`wl-paste --type <type> --watch …/clipboard-history store <type>`, is `PartOf` and ordered after
`graphical-session.target`, restarts on failure and is wanted by `graphical-session.target`. Following the Bluetooth
agent pattern, `apply` only enables them, and they start at the next graphical login. `sources.md` records
provenance, the cliphist version from the reference VM, the approved resident service and the known limits [DEC-010].

The step `desktop/clipboard` runs right before `desktop/shell`, whose picker consumes the command, so configure has
25 steps and the mechanism and target contracts change accordingly. No `clipboard-check` command or single-owner
check is added. The procedure verifies the session with `systemctl --user is-active`, the database location under
`$XDG_RUNTIME_DIR` and the absence of `~/.cache/cliphist/db` [DEC-010].

## History picker

The picker is a centered shell overlay adapted from Omarchy's clipboard UI and keyboard model, with its data layer
replaced by `clipboard-history`. The `mirroros:clipboard` GlobalShortcut (`SUPER+CTRL+V`) and a `clipboard` IPC
target with `open` and `toggle` open it. Each opening runs one `clipboard-history list`, with no file watching or
polling. Keyboard behavior:

- typing filters the list;
- Enter copies the entry and closes, and the user pastes with `SUPER+V` or a native shortcut;
- Alt+Enter opens the entry;
- Delete removes the entry, and Shift+Delete clears the history after confirmation;
- Escape clears the filter or closes.

Omarchy's Shift+Enter disappears because Enter already copies without pasting. Rows and the preview render strictly
as plain text. Images are decoded on demand by `clipboard-history preview <id>` into runtime files under
`$XDG_RUNTIME_DIR/mirroros/clipboard/previews/`, only for the active row and visible thumbnails; orphan previews are
pruned on list, delete and clear [DEC-011].

The parsing, filtering, labelling and selection logic lives in a pure JavaScript model adapted from Omarchy's
`ClipboardHistory.js` and tested with `node:test`. Adaptation provenance goes to the shell `UPSTREAM.md` and
`docs/attribution.md`, and the missing confirmation dialog and sized image components are adapted or replaced
[DEC-011].

## Open action

Alt+Enter runs `clipboard-history open <id>`, a provider-neutral counterpart of Omarchy's open script:

- an image opens its runtime preview through `xdg-open`;
- text containing a URL (the first `http(s)` URL, or a text that is only a domain) opens the URL through
  `xdg-open`;
- any other text is written to a private 0600 file under `$XDG_RUNTIME_DIR/mirroros/clipboard/open/` and opened
  through `xdg-open`, keeping it in RAM where Omarchy writes it to disk.

The handlers come from `mimeapps.list` as the browser, viewer and screenshot areas extend it. This plan adds no
association and names no application. When no handler exists, a transient notification states the next action.
Open files leave with their entry's delete or clear and with the session, never on list, because an editor may still
hold them. Bats tests cover the URL heuristic and both paths [DEC-012].

## Laboratory campaign

Validation is a single blocking checkpoint on the reference VM. The candidate is delivered through
`refs/mirroros-candidates/02-38-lab-*`, configured, rerun unchanged, and exercised after a new login. The campaign
covers:

- the approved resident service: two active units, the database in `$XDG_RUNTIME_DIR`, nothing in `~/.cache`, no
  process after logout;
- the five universal keys in Foot, tmux, Neovim, Strata, Chromium and a shell panel field;
- terminal ↔ GUI round trips through Foot, tmux OSC 52, the Neovim provider, Pi and Chromium;
- sensitive copies, with a `wl-copy --sensitive` code never entering history and Chromium's password-manager
  behavior recorded as data;
- every picker action, including plain-text rendering of copied HTML and the open paths with and without a handler;
- the PNG round trip and the size of a photographic full-screen screenshot;
- the size and tmpfs guards;
- the `pick` terminal path.

Chromium is separately authorized laboratory drift and is removed afterwards. No T14s step is required because
nothing is hardware-dependent. Evidence goes to `evidence/clipboard/lab-02-38/` with `SHA256SUMS`, holding only
disposable test strings [DEC-013].

## Documentation and delivery

A new `docs/procedures/clipboard.md` documents the area. It describes the approved resident service and its
lifecycle and the `clipboard-history` command, including `pick`, with a warning about bare `cliphist`. It covers
manually stopping and starting the units, the keys and their recovery note, the known limits (PNG only, the
hibernation risk, drops) and the session verification. `desktop-shell.md` and `configure.md` link to it. The
`docs/mvp-scope.md` "Clipboard and history" row records cliphist, the approved resident service and the picker, and
notes pause and disk persistence as deferred. `docs/attribution.md` gains the Omarchy adaptations, and
`capabilities/README.md` gains the capability if its index lists capabilities [DEC-014].

Work is committed by concern only after the laboratory checkpoint is approved, through a temporary index as in plan
02-35. The candidate refs are cleaned and the plan closes with its summary [DEC-014].

## Execution outcome and approved amendments

Tasks 1–5 were accepted and the maintainer approved the complete reference-VM laboratory checkpoint on final
candidate lab-e (`c63eb328bad38bf12c2521ebc21c41de87a1ec76`). The historical design above remains the interview
record; the following approved execution findings govern the delivered behavior:

- PNG capture uses a **5,000,000-byte** cap to match cliphist 0.7.0's actual input limit, superseding 32 MiB.
  Text remains 1 MiB, history 200 entries and the free-space reserve 25%. These bounds do not make df a quota or
  shrink bbolt. Hibernation/fallback-swap exposure remains documented, with no wipe hook.
- Text capture normalizes recognized UTF-16, including conservative BOM-less detection, to UTF-8 and rejects
  malformed/ambiguous input. Conversion is bounded in runtime storage. Existing malformed entries are not migrated.
- Non-URL text opens the existing desktop association through `uwsm app -t service`, honoring Terminal=true;
  image/URL actions still use xdg-open. Launches do not retain the history lock and queries/launches are bounded
  to 10 seconds plus 2 seconds of kill grace. No MIME associations or application selections were added.
- Chromium is retained by explicit maintainer request as laboratory drift, not a product browser decision or Chrome
  installation authorization. Lab-b captured unrelated weather work but was never installed; final delivery must
  exclude it. A previous owned Hyprland entry-point migration and its tests were explicitly authorized.
- The QML correction removes avoidable Process shadowing/block-local var diagnostics and retains only reviewed
  static-tool limitations. Shared token typing and upstream type metadata remain potential follow-up work.

The final owning-task command/configure checks passed 170 of 171 Bats cases with one pre-existing tmux 3.8 skip,
plus ShellCheck. The VM passed all 38 affected Node tests without skips, qmllint (91 QML files, 2494 reviewed
warnings, no new/stale keys), i18n checks and 151-file provenance coverage. Configure reran 25/25 unchanged;
post-capture logout stopped both watchers and a fresh login restored them with a private tmpfs database and no
on-disk default database. The maintainer confirmed the interactive clipboard, picker, terminal and PNG paths.

The wl-copy sensitive probe was excluded, but a disposable Chromium password-manager copy entered history;
applications cannot be assumed to mark secrets. Pi output uses Foot/tmux rather than an independent mechanism.
The reserve boundary used injected df output, not physical tmpfs exhaustion; missing-handler testing injected an
empty MIME result without changing system associations. A photographic 1920x1080 PNG measured 2,293,215 bytes
and was immediately deleted. The ignored evidence manifest verifies 84 files and secret scanning passed. The
execution log records final approval despite older pending wording in the retained checkpoint narrative.

Delivery uses four concern-separated commits through a temporary Git index: capability, Hyprland keys, shell
picker, and documentation/interviews. Each exported tree receives the applicable affected checks; shell-consumer
integration checks run once the shell commit is present. No evidence, local workflow tooling or generated output
belongs in those commits. The local SUMMARY records final commit identities, verification and candidate-ref cleanup.
