# Story 4.5 clipboard and history — Decision Log

Technical interview for Story 4.5 Area 3 (clipboard and history). Primary input: the local brainstorming record
`.sheaf/brainstorming/brainstorming-session-2026-11-11-2353.md` (Area 3 — Clipboard and history), its decisions,
boundary table and interview handoff. Planned as 02-38 after plans 02-36 and 02-37 (polkit area).

## DEC-001
- **Question**: Do the shell clipboard history picker and the resident clipboard watchers need a new ADR, or a
  bounded scope change?
- **Context/Nuances**: `desktop.clipboard` already exists in the architecture (identifier and
  `capabilities/desktop/clipboard/`); "Open the clipboard history" is a frozen frequent action; `docs/mvp-scope.md`
  assigns the provider choice to Story 4.5. The Story 4.5 acceptance criterion anticipates an *approved* resident
  service. The architecture and PRD exclude a management daemon or background management service, and ADR 0025
  excludes a resident shell daemon; `wl-paste --watch` user units are provider processes (like `bt-agent` under ADR
  0025 or PipeWire), not system management and not shell-owned. ADR 0012 admits a new shell surface through a scope
  change in `docs/mvp-scope.md`; quick reminders (plan 02-34) set the no-ADR precedent, but had no provider or
  resident process.
- **User Response**: Agreed with the recommendation.
- **Decision**: No new ADR. Record a scope change in the `docs/mvp-scope.md` "Clipboard and history" row naming
  cliphist, the two watchers as the approved clipboard resident service (process, starter, content, RAM location,
  lifecycle bound to `graphical-session.target`) and the picker as a bounded shell surface. Provenance goes in
  `capabilities/desktop/clipboard/sources.md` and the shell `UPSTREAM.md`. Disk persistence or pinned entries (#104)
  would require an ADR because they change the secrets-at-rest posture.
- **Status**: Accepted

## DEC-002
- **Question**: How is the RAM history bounded with cliphist 0.7.0, which lacks `max-store-size`?
- **Context/Nuances**: The history lives in `$XDG_RUNTIME_DIR`, a logind tmpfs sized by default at 10% of RAM
  (about 1.6 GB on the 16 GB T14s) and shared with the Wayland socket, PipeWire and other runtime files; filling it
  breaks unrelated components. cliphist's bbolt file never shrinks after deletes. `max-items` bounds entries, not
  bytes. `wl-paste --watch` cannot filter by size, so dropping at capture time (#110) needs a small owned Bash wrapper
  between `wl-paste` and `cliphist store`. References: Omarchy 500 entries without size limits, community forks
  16 KiB text / 10 MiB image, cliphist default 750. Alternatives: `max-items` only (no byte bound); `max-items` plus
  per-entry caps (selected); plus a total-size pruning cap (more code, bbolt keeps its high-water mark anyway).
- **User Response**: Accepted the recommendation and values.
- **Decision**: `max-items 200`. An owned wrapper `clipboard-store` reads the entry from stdin and drops it (never
  truncates) when text exceeds 1 MiB, an image exceeds 8 MiB, or the runtime tmpfs would keep less than 25% free
  space (checked with `df`). Drops are silent to the user and logged to the journal with type and size only, never
  content. The wrapper is covered by bats contract tests.
- **Status**: Accepted (image cap amended to 32 MiB by DEC-008; wrapper becomes `clipboard-history store` by DEC-009)

## DEC-003
- **Question**: How is the correct MIME type restored when an image is selected from history, given that
  wl-clipboard 2.3.0 does not export `CLIPBOARD_TYPE` and cliphist stores bytes without a MIME type?
- **Context/Nuances**: `cliphist decode | wl-copy` without `--type` relies on wl-copy inference (`xdg-mime` or
  `file`), which may offer `text/plain` or `application/octet-stream`. Options considered: (A) inference plus a
  declared `file`/`xdg-utils` dependency; (B) map the `cliphist list` binary format to a MIME type at selection;
  (C) detect and store the MIME type in the wrapper (a second store). Omarchy (`~/code/omarchy` `quattro`
  `520c3ed96`, 2026-11-16; `shell/plugins/clipboard/Clipboard.qml:302`, `capture.sh`,
  `bin/omarchy-clipboard-paste-file`) fixes the type at capture: the image watcher listens only to `image/png`,
  passes the MIME type as an argument, and restores with `wl-copy --type "$mime"`; text restores as `text/plain`.
- **User Response**: Asked how Omarchy does it, then accepted option D (Omarchy-style).
- **Decision**: Option D. The image watcher is `wl-paste --type image/png --watch clipboard-store image/png` and the
  text watcher passes its type the same way. Every binary history entry is PNG by construction; selection restores
  images with `cliphist decode <id> | wl-copy --type image/png` and text with
  `wl-copy --type 'text/plain;charset=utf-8'`. No format mapping, no `file`/`xdg-mime` dependency. Images offered
  without `image/png` do not enter history; this known limit is documented in `sources.md`. Laboratory check: copy
  an image from Chrome or Strata, select it from history, confirm `wl-paste --list-types` offers `image/png`, and
  paste it into a graphical application.
- **Status**: Accepted (supersedes the initially proposed option B before acceptance; selection runs through
  `clipboard-history copy` by DEC-009)

## DEC-004
- **Question**: Is the history wiped before hibernation, and what happens on suspend (#103)?
- **Context/Nuances**: ADR 0007: zram (priority 100) is everyday swap; the unencrypted swapfile (priority 0) holds
  the hibernation image and also serves as fallback swap, so tmpfs pages can reach it under memory pressure
  regardless of any pre-hibernate wipe. Hibernation is user-initiated (session menu `SessionActions.qml` or
  `systemctl hibernate`); the lid uses the logind default (suspend); UPower may HybridSleep on critical battery.
  hypridle's `before_sleep_cmd` runs for both suspend and hibernate. Hibernation writes all RAM (browser, terminals,
  unlocked gnome-keyring secrets), so the history is a marginal extra exposure; the real fix is the pending disk
  encryption decision (#102). Alternatives: (B) root `system-sleep` hook running `cliphist wipe` per user session,
  crossing the privilege boundary and missing fallback swap; (C) wipe only in the session-menu Hibernate action,
  partial and misleading; (D) wipe on every sleep through hypridle, losing history on each lid close.
- **User Response**: Accepted option A.
- **Decision**: No wipe on hibernate or suspend. The residual risk (hibernation image and fallback swap on an
  unencrypted swapfile may contain clipboard history) is documented in `capabilities/desktop/clipboard/sources.md`
  and the `docs/mvp-scope.md` row, and tied to the pending disk encryption decision. A stricter policy later would
  be option B through an ADR, since it crosses the privilege boundary.
- **Status**: Accepted

## DEC-005
- **Question**: How are the universal `SUPER+C/V/X/A` keys and `SUPER+CTRL+V` implemented?
- **Context/Nuances**: Omarchy `default/hypr/bindings/clipboard.lua` (`520c3ed96`) sends `hl.dsp.send_key_state`
  with explicit mods and no window target (reaching layer-shell panels), avoids `wtype` (the held SUPER merges into
  an injected chord), splits down/up by 50 ms against stuck synthetic keys (Hyprland discussion #14099), and detects
  terminals through a `+terminal` window tag (`apps/terminals.lua`). Mapping: `SUPER+C` → `CTRL+C` or
  `CTRL+SHIFT+C` in terminals; `SUPER+V` → `CTRL+V` or `CTRL+SHIFT+V`; `SUPER+X` → `CTRL+X`; `SUPER+A` → `CTRL+A`;
  `SUPER+CTRL+V` → clipboard panel. In MirrorOS these keys are free and listed as reserved for clipboard in the
  Hyprland provider `UPSTREAM.md`; no `terminal` tag exists; Foot is the only terminal; panels open through
  `hl.dsp.global("mirroros:<name>")`; the `MirrorOSKeys` registry feeds the keybinding help and tests.
- **User Response**: Accepted.
- **Decision**: A new `clipboard-bindings.lua` in the Hyprland provider adapts Omarchy's `clipboard.lua` (same
  mapping and 50 ms down/up split) with `clipboard.*` entries in `MirrorOSKeys`; synthetic keys are
  compositor-bound, so a compositor replacement reimplements only this file. Terminal detection uses a `+terminal`
  window tag in `defaults.lua` matching only Foot classes (`foot|org\.codeberg\.dnkl\.foot`). `SUPER+CTRL+V`
  dispatches `hl.dsp.global("mirroros:clipboard")`. Known risk (#114) — stuck modifiers or key-not-found after a
  Hyprland update — is documented in `UPSTREAM.md` and the procedure with a recovery note (release and re-press
  modifiers, `hyprctl reload`); native shortcuts (`CTRL+C/V`, Foot `CTRL+SHIFT+C/V`) remain the permanent fallback.
  Tests: update the bindings test, registry counts and keybinding ambiguity test; a terminal/non-terminal mapping
  test through the Lua stub if feasible; clipboard keys move from reserved to bound in `UPSTREAM.md`. Laboratory:
  the five keys in Foot (including tmux and Neovim), in Chrome or Strata, and in a shell panel field.
- **Status**: Accepted

## DEC-006
- **Question**: (Maintainer directive) What test scope does plan execution run?
- **Context/Nuances**: Raised by the maintainer while accepting DEC-005.
- **User Response**: Tests should focus only on what the changes affect, not on every suite.
- **Decision**: Task verification and the final verification run only the test files and checks affected by the
  changed files (for example the clipboard capability tests, the Hyprland bindings and keybinding tests, the touched
  shell model tests, `mechanism.contract.bats` and `target.contract.bats` when the step list changes, and qmllint or
  `check-menu.sh` for touched QML). Full-suite runs are not part of this plan.
- **Status**: Accepted

## DEC-007
- **Question**: What are the history pause semantics (handoff #6), and is a pause worth its cost?
- **Context/Nuances**: The brainstorming placed a pause with a bar indicator in scope (#109, Omarchy discussion
  #6099; Omarchy has no pause). A full pause (owned command with pause/resume/toggle/status, shell service, bar
  indicator, picker toggle, IPC refresh, partial-state handling, tests) costs roughly 150–250 owned lines plus tests
  and a new bar surface. Real use cases: secrets copied from sources that do not mark them sensitive (Chrome password
  manager, terminal tokens), screen sharing, bulk sensitive data. With a RAM history bound to the session and
  sensitive copies already dropped, pausing *before* costs the same attention as deleting or clearing *after*, and a
  forgotten pause silently disables history (which is what forces an indicator). Screen sharing is not solved by a
  pause. Options: (A) no pause; (B) minimal picker toggle without indicator; (C) full pause.
- **User Response**: Asked for real daily use cases to weigh cost against value, then chose A.
- **Decision**: No history pause in this plan; it moves to Deferred in the boundary. Delete entry and clear history
  in the picker cover the real use case. The procedure documents the manual path
  (`systemctl --user stop`/`start` of the watcher units). The watcher units stay always active during the session,
  with no intermediate state. A full pause can be added later as a bounded change if daily use shows the need.
  Supersedes the brainstorming's "History pause: In" decision.
- **Status**: Accepted

## DEC-010
- **Question**: What is the capability layout, the watcher unit design and the configure step position?
- **Context/Nuances**: Plan 02-37 is committed (`025a20c`..`5737e9b`); `capabilities/configure-steps` has 24 steps.
  `wl-clipboard` is declared in `desktop/shell` and `workflow/tmux`, `fzf` in `workflow/shell`. User units follow
  `mirroros-bt-agent.service`: `cfg_tracked_file` into `/etc/systemd/user`, `cfg_user_unit_enable …
  graphical-session.target`, enable-only, starting at the next graphical login. Precedents for read-only session
  checks exist (`portal-check`, `polkit-check`) and for single-owner checks (`cfg_session_agent_unique`).
- **User Response**: Accepted.
- **Decision**: New `capabilities/desktop/clipboard/` (the architecture's planned path) with `apply`; `packages`
  (`cliphist`, `wl-clipboard`, `fzf`, all `extra`, declared as the capability's own dependencies);
  `clipboard-history` installed to `/usr/share/mirroros/clipboard/clipboard-history` 0755; new
  `mirroros-clipboard-text.service` and `mirroros-clipboard-image.service` in `/etc/systemd/user`
  (`ExecStart=/usr/bin/wl-paste --type text|image/png --watch …/clipboard-history store <type>`,
  `PartOf=`/`After=graphical-session.target`, `Restart=on-failure`, `RestartSec=2`,
  `WantedBy=graphical-session.target`), enabled only; and `sources.md` (provenance, cliphist version from the
  reference VM, approved resident, known limits: PNG only, hibernation risk, bare `cliphist` on disk). The step
  `desktop/clipboard` goes right before `desktop/shell`, giving 25 steps; the mechanism and target contracts are
  updated. No `clipboard-check` command: the procedure verifies the session with `systemctl --user is-active`, the
  database under `$XDG_RUNTIME_DIR` and no `~/.cache/cliphist/db`. No single-owner check against other clipboard
  managers (none installed; a duplicate only doubles history); it can reuse `cfg_session_agent_unique` later.
- **Status**: Accepted

## DEC-011
- **Question**: How is the shell history picker designed?
- **Context/Nuances**: Omarchy implements the clipboard as a centered overlay (`Clipboard.qml` 617 lines,
  `ClipboardHistory.js` 239), not a bar panel: type to filter, arrows/PageUp/PageDown/Home/End, Enter pastes through
  `wtype`, Shift+Enter copies only, Alt+Enter opens (`omarchy-clipboard-open`), Delete removes an entry,
  Shift+Delete clears with confirmation, Escape clears the filter or closes; single-line rows with image thumbnails
  and a large preview of the active row. MirrorOS already has `OverlayWindow`, `FilterInput`, `PointerMoveGate`,
  `BorderSurface` and `TextField`, but no `ConfirmDialog` or `SizedImage`.
- **User Response**: Accepted, but the open actions are kept.
- **Decision**: An overlay adapted from Omarchy's UI and keyboard model, with its data layer replaced by
  `clipboard-history`; opened through the `mirroros:clipboard` GlobalShortcut, a `clipboard` IPC target
  (`open`/`toggle`) and a first-party service id. One `clipboard-history list` per open; no `FileView`, watching or
  polling. Enter copies (`copy <id>`) and closes; Alt+Enter opens the entry (semantics decided in the next question);
  Shift+Enter is dropped because Enter already copies only. Delete removes an entry, Shift+Delete clears with
  confirmation, Escape clears the filter or closes. Rows and preview render as plain text (`Text.PlainText`, #111).
  A new subcommand `clipboard-history preview <id>` decodes on demand to
  `$XDG_RUNTIME_DIR/mirroros/clipboard/previews/<id>.png`; `list`, `delete` and `clear` prune orphan previews
  (#115); only the active row and visible thumbnails are decoded. A pure JS model adapted from `ClipboardHistory.js`
  (parsing, filtering, labels, selection) is tested with `node:test`; provenance goes to the shell `UPSTREAM.md` and
  `docs/attribution.md`. Missing `ConfirmDialog`/`SizedImage` equivalents are adapted or replaced. Extends DEC-009
  with `preview`.
- **Status**: Accepted

## DEC-012
- **Question**: What does the open action (Alt+Enter) do?
- **Context/Nuances**: Omarchy `bin/omarchy-clipboard-open` (`520c3ed96`): images → `omasnap --notify <path>`
  (the Area 4 annotator); text with a URL (first `http(s)://…`, or text that is only a domain, turned into
  `https://`) → `omarchy-launch-browser`; other text → a file under `~/.local/state/omarchy/clipboard-open/` (on
  disk) opened with `omarchy-launch-editor`. The MirrorOS system `mimeapps.list` currently maps only
  `inode/directory` to Strata; viewers (Area 7) and the browser (Area 6) do not exist yet.
- **User Response**: Accepted.
- **Decision**: A provider-neutral `clipboard-history open <id>`: images → `xdg-open` on the runtime preview
  (`previews/<id>.png`), the handler coming later from Area 7 or Area 4 through `mimeapps.list`; text with a URL
  (Omarchy's heuristic) → `xdg-open <url>`; other text → a 0600 file in
  `$XDG_RUNTIME_DIR/mirroros/clipboard/open/<id>.txt` (RAM, not disk) → `xdg-open` (the `text/plain` handler, for
  example `nvim.desktop` through the terminal launch path). When `xdg-open` fails, a normal-urgency transient
  notification states the next action (set a default in `mimeapps.list`); no named application fallback. Files under
  `open/` are removed by `delete`/`clear` of their entry and at session end, never pruned by `list` (an editor may
  hold them). This plan adds no MIME associations (owned by Areas 6 and 7). The URL heuristic, the image path and the
  RAM text path are covered by bats tests. Extends DEC-009 with `open`.
- **Status**: Accepted

## DEC-013
- **Question**: What is the laboratory campaign and evidence for this plan?
- **Context/Nuances**: Plan 02-35 used the reference VM, candidate delivery through
  `refs/mirroros-candidates/02-xx-lab-*`, blocking `human-verify` checkpoints, and `extra/chromium` as separately
  authorized laboratory drift removed afterwards; plan 02-37 used the T14s only for fingerprint. Evidence lives under
  `evidence/<area>/lab-02-xx/` (ignored) with `SHA256SUMS`.
- **User Response**: Accepted.
- **Decision**: One blocking laboratory checkpoint on the reference VM (`ssh -p 2222 viespejo@127.0.0.1`): candidate
  `refs/mirroros-candidates/02-38-lab-*`, `sudo mirroros-configure`, an unchanged rerun and a new login. Checks:
  resident (both units active, database under `$XDG_RUNTIME_DIR/mirroros/clipboard/`, no `~/.cache/cliphist/db`, no
  process after logout); the five universal keys in Foot, tmux, Neovim, Strata, Chromium and a shell panel field;
  terminal ↔ GUI end-to-end (#100: Foot, tmux OSC 52, Neovim provider, Pi, Chromium, both directions); sensitive
  copies (#95: a `wl-copy --sensitive` notification code never enters history; Chromium's password manager marking
  recorded as data, #96, no value recorded); picker (open, filter, copy, delete, clear, plain text with copied HTML,
  image preview, open URL/text/image, missing-handler notification); PNG round trip and the full-screen photographic
  screenshot size as data; size and tmpfs-guard drops (bats plus one manual >1 MiB text); `clipboard-history pick`.
  Chromium is separately authorized laboratory drift, removed afterwards (Chrome belongs to Area 6). No T14s step
  (nothing hardware-dependent); informal T14s use carries no qualification value. Evidence under
  `evidence/clipboard/lab-02-38/` with `SHA256SUMS`, containing no clipboard content beyond disposable test strings.
- **Status**: Accepted

## DEC-014
- **Question**: Where does the documentation go, and how is the work delivered?
- **Context/Nuances**: Area 1 has its own procedure (`portals-and-files.md`); reminders were documented as a section
  of `desktop-shell.md`. Plan 02-35 committed by concern after approved checkpoints using a temporary
  `GIT_INDEX_FILE` and cleaned candidate refs.
- **User Response**: Accepted.
- **Decision**: A new `docs/procedures/clipboard.md` (approved resident and lifecycle; `clipboard-history` usage
  including `pick`; the bare `cliphist` warning; manual stop/start of the units per DEC-007; keys and recovery note
  per DEC-005; known limits: PNG only, hibernation risk, drops; session verification per DEC-010), linked from
  `desktop-shell.md` (picker and IPC) and `configure.md` (new step). `docs/mvp-scope.md`: the "Clipboard and
  history" row moves from open to cliphist, the approved resident and the picker (DEC-001), linking the procedure,
  with pause and disk persistence noted as deferred. `docs/attribution.md`: entries for the Omarchy adaptations
  (`clipboard.lua`, `Clipboard.qml`, `ClipboardHistory.js`, the `omarchy-clipboard-open` heuristic).
  `capabilities/README.md`: the new capability line if the index lists capabilities. Commits by concern only after
  the approved checkpoint, through a temporary `GIT_INDEX_FILE`; candidate refs `refs/mirroros-candidates/02-38-lab-*`
  are cleaned at the end; the plan closes with its `-SUMMARY.md`.
- **Status**: Accepted

## Execution findings — approved laboratory checkpoint

The maintainer accepted Tasks 1–5 and explicitly approved the complete reference-VM checkpoint. The execution
record is authoritative for approval: the retained checkpoint narrative still contains earlier pending-gate wording.
Final deployed candidate: `c63eb328bad38bf12c2521ebc21c41de87a1ec76` (lab-e).

- **DEC-002 / DEC-008 amendment:** PNG capture is capped at **5,000,000 bytes**, not 32 MiB. Arch cliphist
  `1:0.7.0-2` has an upstream input-size limit; the maintainer approved matching it. Text remains capped at 1 MiB,
  history at 200 entries, with the 25% runtime free-space guard. The guard is not a filesystem quota; bbolt retains
  its high-water allocation.
- **Capture correction:** Chromium offered BOM-less UTF-16LE text. Capture now normalizes recognized UTF-16 to
  UTF-8, preserves valid UTF-8 and rejects malformed/ambiguous input, with bounded runtime conversion and regression
  tests. Existing malformed entries were not migrated or silently deleted.
- **DEC-012 amendment:** packaged xdg-open did not honor the existing Terminal=true text handler and blocked
  history access. Non-URL text now queries the existing MIME association and uses `uwsm app -t service`; URLs and
  PNG previews retain xdg-open. Locks are released before launch, stdin is disconnected, and external queries and
  launches have a 10-second timeout plus 2-second kill grace. No MIME association or application choice changed.
- **DEC-013 amendment:** Chromium remains installed at the maintainer's explicit request as laboratory drift until
  a future browser area addresses replacement. This is neither a product browser selection nor permission to install
  Chrome. Superseded lab-b accidentally included concurrent weather work, was never installed, and must not be reused.
- **Approved migration scope:** the previous owned Hyprland entry-point hash was added to prepare-hyprland with
  affected tests; edited files and links remain preserved. Registry counts are 170 bindings / 162 exported entries.
- **QML correction:** duplicate Process ids and block-local var diagnostics were fixed. The reviewed baseline adds
  17 genuine shared-token static-typing limitations, one known GlobalShortcut diagnostic and a relocated existing
  PostReloadHook key. No lint category was disabled. Improving shared typing/type metadata is follow-up work.
- **Verification:** final command/configure contracts passed 171 Bats cases (170 pass, one pre-existing tmux 3.8
  skip); ShellCheck passed. The reference VM passed all 38 affected Node tests without skips, qmllint on 91 QML
  files with 2494 reviewed diagnostics and no new/stale keys, i18n checks and 151-file provenance coverage.
  Configure reran 25/25 unchanged. Post-capture logout stopped both watchers; new login restored the expected units
  and a mode-0600 tmpfs database without a default disk database.
- **Observed behavior:** terminal/GUI routes, universal keys, copy-only picker, deletion/confirmation, plain-text
  rendering, PNG previews/paste/type, URL/image/text opening and fzf selection passed the attended campaign. Pi output
  uses the tested Foot/tmux transport, not a separate clipboard mechanism. wl-copy --sensitive was excluded, while a
  disposable Chromium password-manager copy appeared in history; no password value was retained.
- **Evidence limits:** reserve rejection used process-local df injection rather than real memory exhaustion;
  missing-handler behavior used a process-local MIME double and a real notification, without changing associations.
  A photographic 1920x1080 PNG measured 2,293,215 bytes; the temporary image was deleted. Evidence under ignored
  `evidence/clipboard/lab-02-38/` passed secret scanning and SHA256 verification of 84 retained files. Known legacy
  bar model extras were left untouched. No hardware qualification or full-suite run is claimed.
