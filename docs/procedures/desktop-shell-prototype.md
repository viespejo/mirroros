# Desktop shell prototype (Story 4.3 exploration)

This procedure records the bounded, guest-assisted exploration for Story 4.3.
It is a laboratory prototype, not production configure delivery, clean
reconstruction qualification or complete Story 4.3 acceptance. Production
implementation stays blocked until the prototype and its outstanding choices
are explicitly approved by the maintainer.

Governing sources: [architecture](../architecture.md),
[ADR 0012](../adr/0012-owned-quickshell-desktop-shell.md) and the
[development workbench](development-workbench.md). The workbench record is a
reference, not proof of current machine state.

## Responsibilities and authorization boundaries

| Area | Guest (`mirroros-lab`) | Host |
| --- | --- | --- |
| Prototype source | Isolated checkout, local commits | Review checkout, integration after approval |
| Experiments | Inspection, QML/Bash edits and tests in scope | Maintainer review of results |
| Handoff | Git bundle, checksum, selected evidence | Retrieval over existing SSH, verification, secret scan |
| Publication | Never | Only with explicit authorization |

Guest access does not authorize any of the following. Each needs a specific
authorization and is recorded in the chronological log:

- package installation, privilege elevation, service restarts and session
  termination;
- changing keyboard bindings, and individual disruptive session actions;
- publication, integration into the active host branch or credential transfer.

The guest has no access to the host and nothing is synchronized automatically.
No third exploration VM is created. A separate clean VM remains required for
host-driven reconstruction acceptance.

## Laboratory baseline

- Laboratory VM: `mirroros-lab` (QEMU/KVM, 2 vCPUs, 4 GiB), SSH on
  `127.0.0.1:2222`, dedicated key, no agent forwarding.
- Guest hostname `mirroros-ref`, user `viespejo`, Arch Linux, kernel
  7.2.11-arch1-1, Hyprland 0.56.2-4, uwsm 0.27.1-1, git 2.56.0-1,
  qt6-declarative 6.12.0-2. `quickshell` is not installed.
- Installed MirrorOS runtime identity: `d9edb3dc`, clean, with no Git checkout
  in the guest. Guest `~/code/pi-config` is at `37ae549a` and `~/code/nvim` at
  `b0208048`.
- Guest disk: 30 GiB with about 21 GiB free; 3.9 GiB RAM.

### Recoverable checkpoint

The pre-existing `after-plan-17` checkpoint differed from the live disk, so it
was discarded and recreated with the same name after the maintainer shut the
guest down. The guest disk and UEFI store compared byte-identical to the new
copy, and `qemu-img check` reported no errors.

- Location: `~/qemu/mirroros-lab/checkpoints/after-plan-17/` (host, outside the
  repository).
- Created 2026-10-22T14:58:35Z.
- SHA256 `disk.qcow2`:
  `8e834a5c30dfafc6671d2642274e5bfc007f389b6c313f5079d04186afa68fb2`.
- SHA256 `OVMF_VARS.fd`:
  `0f3f09173c09271aeca29e5f23a34f323796ae776c7c8b20bccaba2f0e492df2`.
- Restore with `~/qemu/mirroros-lab/vm restore after-plan-17` (requires QEMU to
  have exited and an interactive confirmation).

Known drift after the checkpoint: the maintainer authorized the dedicated host
public key in the guest `~/.ssh/authorized_keys`, entering the password
personally. A restore removes that key; repeat the authorization if needed.

## Prototype checkout

- Base commit: `08f17de9943730050d4787c50d1cc138c83f5bf5` (host `main`). It
  differs from the installed runtime identity `d9edb3dc` only in
  `capabilities/workflow/pi/defaults/APPEND_SYSTEM.md`, which does not affect
  the runtime.
- Transfer: host `git bundle` of `HEAD` with SHA256
  `1588579418ab47b7e7907040d72b803fc21b7ea3776d22d9c6b6f69c87455883`, copied
  over SSH to the guest. The guest verified the checksum and cloned it.
- Guest workspace (ignored, outside authoritative source control):
  `~/mirroros/build/story-4-3-prototype/`
  - `incoming/` bundle and checksum;
  - `mirroros/` isolated clone on branch `story-4-3-prototype`, clean at the
    base commit;
  - `omarchy-src/` read-only reference clone of Omarchy.
- Host transfer directory (ignored): `build/story-4-3-prototype-transfer/`.

## Discovery inputs

### Omarchy

- Repository: `https://github.com/omacom/omarchy`, cloned inside the guest.
- Revision used for all experiments: `7075b61c6aaa5d8589f6e816867508fc96dc49d9`
  (detached checkout). The `quattro` branch has since advanced to `3c7027db`;
  that newer revision is not the verified source.
- License: MIT, `Copyright (c) David Heinemeier Hansson`. Any reused fragment
  needs recorded provenance and attribution before incorporation.
- Its complete installer is not run and its dotfiles are not imported.

Structure observed (read-only):

- `shell/shell.qml` entry point, with `Commons/` (state, IPC registry, style),
  `Ui/` (shared components), `services/` and first-party `plugins/`
  (`bar`, `menu`, `notifications`, `osd`, `lock`, `panels`, `polkit`,
  `reminders`, among others). 176 QML files, about 53,400 lines in total.
- Bash layer in `bin/`: `omarchy-launch-shell` (journal-logged Quickshell
  launch, file watcher and reload disabled), `omarchy-restart-shell`
  (refuses to restart while the session is locked), `omarchy-shell` (IPC
  forwarder), `omarchy-osd`, `omarchy-notification-send`,
  `omarchy-system-lock`, `omarchy-menu*`.
- Hyprland bindings in `default/hypr/bindings/*.lua` use an `omarchy` helper
  library, so they are not directly reusable at the MirrorOS provider boundary.
- `quickshell` is the shell-related package in `install/omarchy-base.packages`;
  the full dependency inventory is completed in Task 2.

### i3 reference

Only binding-related lines of `~/.config/i3/config` were inspected; no private
configuration was copied. Binding categories relevant to the shell surfaces
(modifier `$mod`):

| Action | i3 binding |
| --- | --- |
| Terminal | `$mod+Return` |
| Launcher | `$mod+d` (rofi run) |
| Lock | `$mod+x` (custom script) |
| Close window | `$mod+Shift+q` |
| Restart WM | `$mod+Shift+r` |
| Hibernate | `$mod+Shift+F4` |
| Volume/mic/brightness keys | `XF86Audio*`, `XF86MonBrightness*` |
| Media keys | `XF86AudioPlay/Next/Prev` |

i3 has no bindings for notification dismissal/history, an on-screen display
or a session menu; these are new surfaces. Omarchy equivalents observed for the
comparison: `SUPER+Space` menu, `SUPER+Escape` system menu, `SUPER+Ctrl+L`
lock, `SUPER+K` keybinding help, `SUPER+,` family for notifications,
`SUPER+W`/`SUPER+Q` close. The action-level i3, Omarchy and proposed MirrorOS
table is produced in Task 2.

## Chronological log

- 2026-10-22: guest identity confirmed over SSH (read-only); checkpoint
  recreated and verified; prototype checkout and Omarchy reference prepared;
  discovery inputs inventoried.
- 2026-10-22: execution model for Task 2 set to a host-directed, guest-executed
  hybrid. The host prepares bounded briefs (kept in the ignored
  `build/story-4-3-prototype-transfer/` directory) and reviews results; guest
  Pi builds and diagnoses within each brief. The maintainer relays results and
  authorizations. `brief-1.md` (SHA256
  `9b66154efe9503536087279a23453e1f2119bd6e4925e0ffa08800e63fdd063b`) was
  copied to the guest `incoming/` directory over SSH with the maintainer's
  authorization and verified by checksum on both sides. The brief was then
  revised to follow Omarchy as closely as is reasonable (DEC-007): study first,
  reuse by default, appearance close to its menu. The revised `brief-1.md`
  (SHA256 `a2084cbd06649d7d1b3a0fb576b283bab0bc14827c0a698b88a95c04ac6ef1ff`)
  overwrote the guest copy and was verified on both sides; the earlier hash is
  superseded.
- 2026-10-22: guest drift after the checkpoint, outside the prototype scope.
  Ctrl+G from Pi inside Sidekick did not reuse the running Neovim because the
  guest lacked `nvr`, which `pi-editor` uses to find the server. With specific
  maintainer authorization (PyPI download, no `sudo`), `neovim-remote==2.5.1`
  was installed in a virtual environment at
  `~/.local/pipx/venvs/neovim-remote` with `pynvim 0.6.0`, `msgpack 1.2.3`,
  `greenlet 3.5.6`, `psutil 7.2.2` and `setuptools 84.2.1`, and linked at
  `~/.local/bin/nvr`. This mirrors the host's pipx layout and version but not
  its Python (guest 3.14.8, host 3.13.1); it is not a pacman package. Checked
  with `nvr --serverlist` and a `--remote-expr` probe against a disposable
  headless Neovim, since stopped. The attended Ctrl+G round trip inside a fresh
  Sidekick session is still pending. A restore of `after-plan-17` removes this
  installation.
- 2026-10-22: Brief 1 (launcher) completed by guest Pi; host reviewed the
  evidence read-only. Commits on `story-4-3-prototype`: `423091c` (first
  approach written from scratch, superseded but kept in history by maintainer
  decision), `2e99464` (launcher rebuilt on Omarchy `7075b61c` fragments) and
  `f3589dc` (uwsm launch path, keyboard checks). Working tree clean; nothing
  pushed; no bundle yet (deferred to Task 3). Packages installed by the
  maintainer with specific authorization: `quickshell 0.3.2-1`, `wtype 0.4-2`.
  Guest evidence: `build/story-4-3-prototype/evidence/brief-1-{log,report,omarchy-study,reuse}.md`.
  - Checks: `capabilities/desktop/shell/tests/check-launcher.sh` gives 51 PASS
    and 2 FAIL. Both failures are the quiet healthy state criterion
    (`qt.qpa.wayland.textinput` warning on every re-open), traced to a Qt 6.12
    Wayland client bug reproduced with plain `qml`. Recorded as failed with an
    upstream cause; not filtered.
  - About 1030 of 1426 non-blank lines come from Omarchy; provenance per
    fragment is in `brief-1-reuse.md`.
  - Maintainer visual review at the guest console: card, font, selection,
    typing, empty state, Escape, mouse and click-outside behave as expected.
  - Launch path: `uwsm app -- <id>.desktop`. uwsm 0.27.1 resolves
    `Terminal=true` entries itself, so `xdg-terminal-exec` and `gtk-launch`
    are not needed and were not installed. Open choice for Task 3 review.
  - Without a terminal preference list uwsm picks `foot-server.desktop` and
    blocks with no window. This affects any uwsm desktop-entry launch, not
    only the shell. Production blocker; proposed owner `desktop/terminal`.
  - Deviation from AC-2, approved by the maintainer: selection is indicated by
    color only, as in Omarchy. Pending explicit Task 3 review.
  - Font family is a provisional shell-local token (JetBrainsMono Nerd Font
    in `Commons/Style.qml`). No system fontconfig rule: global typography
    belongs to Story 4.8.
  - Minor: `Icon=applications-system` (uuctl) shows no icon, as in Omarchy's
    code; icon theme belongs to Story 4.8.
  - `docs/attribution.md` on the host main branch is not changed by this plan;
    the prototype branch carries its own attribution for the bundle.
- 2026-10-22: guest drift for laboratory use only, authorized by the
  maintainer: the leftover `foot --server -e nvim` process from the visual
  review was stopped (that PID only), and `~/.config/xdg-terminals.list` was
  created with the single line `foot.desktop` so that terminal applications
  open from the launcher. This is not the production decision; the product
  location of the list stays an open choice for `desktop/terminal`. A restore
  of `after-plan-17` removes it. The maintainer then confirmed that Neovim
  opens in a Foot window from the launcher.
- 2026-10-22: `brief-2.md` (bar, notifications, OSD and attribution inside the
  prototype branch; SHA256
  `b456b30bf00e0c139be4e5dbff906b3af88331d617ca58d0b645591f179b8197`) copied
  to the guest `incoming/` directory with the maintainer's authorization and
  verified on both sides. Design direction: same appearance and interaction as
  Omarchy; color-only states follow Omarchy and are listed as AC-2 deviations
  for review; Omarchy notification persistence is reproduced only to evaluate
  it (DEC-009).
- 2026-10-22: the recurring `qt.qpa.services: Failed to register with host
  portal` warning comes from Qt registering the application with
  `xdg-desktop-portal`, which is not installed in the guest (only the unrelated
  Tracker portal service exists). It does not affect the prototype surfaces.
  Desktop portals are owned by Story 4.5 (`docs/mvp-scope.md`), so no portal
  is installed here; the warning stays recorded as environmental.
- 2026-10-22: direction for Brief 3, approved by the maintainer. Omarchy's
  `SUPER+Space` menu is a command tree (`default/omarchy/omarchy-menu.jsonc`)
  in which the launcher is only the `Apps` submenu; Brief 1 extracted that
  branch alone. The dropped parts include what the remaining surfaces need:
  the `System` submenu (lock, suspend, hibernate, logout, reboot, shutdown,
  opened directly by `SUPER+Escape`) is the session menu, its `when:` guards
  provide real availability (DEC-005), `Learn > Keybindings` is the keyboard
  help, and the tree gives submenus, back navigation and root search. Brief 3
  therefore reuses Omarchy's menu engine (`plugins/menu/Menu.qml`,
  `MenuModel.js`) as the common base for launcher, session menu and keyboard
  help, with a MirrorOS-owned model limited to `Apps`, `System` and
  `Learn > Keybindings`. Excluded: control-panel entries (`Appearance`,
  `Setup`, `Install`, `Remove`, `Update`, `Trigger`, `About`; PRD and ADR
  0012), uninstall, Omarchy plugin lifecycle and IPC. Whether unavailable
  entries are hidden or shown with a reason is left for review. Brief 2 is not
  affected. The Brief 1 extraction approach is recorded as superseded for the
  menu surfaces.
- 2026-10-22: Brief 2 study delivered by guest Pi
  (`evidence/brief-2-omarchy-study.md`); host answers to its open decisions,
  confirmed by the maintainer, sent as `brief-2-answers.md` (SHA256
  `0838eec7a8aeb4231786a6a0d10d8c5290daec0990a14afd68f234f89c01ef03`) and
  verified on both sides. Guest facts: no notification server, no PipeWire,
  BlueZ or UPower, no battery or backlight, NetworkManager active on ethernet,
  one layout (`us`), no tray item. Answers:
  - color-only states follow Omarchy by default (DEC-015);
  - laboratory drift allowed on request: `pipewire`, `wireplumber`, `upower`,
    optionally `bluez` without enabling its service, and
    `xdg-desktop-portal` with `xdg-desktop-portal-hyprland` (Story 4.4 and
    4.5 own the product choices); no VM sound device;
  - absent-device rule, open for review: missing provider shows unavailable
    with a reason, present provider without device hides the module;
  - tray and keyboard-layout modules included; layouts tested only with a
    reverted runtime `hyprctl keyword` change; product target `us` plus `es`
    (DEC-017);
  - Omarchy bar panels not implemented; studied per panel as evidence for an
    ADR and Story 4.4 (DEC-016);
  - Omarchy `shell.json` evaluated at a prototype-only state path; configure
    reapplication, NFR38 and coupling remain open;
  - screen-share snooze offer included, with one bounded attempt to exercise
    the sharing case;
  - Omapager notice (Neil Jagdish Patel, MIT) kept and attributed; its
    original license text is unverified;
  - `omarchy-exec-argv` executed as in Omarchy (option A). Reading Omarchy
    `7075b61c` showed a deliberate design: argv passed as positional
    parameters and never re-parsed, structural validation in `Security.js`,
    and an explicit same-user threat model. The residual risk for sandboxed
    senders with direct notification access stays an open choice for review.
- 2026-10-23: maintainer authorized an intermediate host backup before guest
  shutdown, not the final Task 3 handoff. Host location (ignored):
  `evidence/desktop-shell-prototype/backup-20261023T004951Z/`.
  - Source: `fb04d2efdd760ee44736fd58df03dd371e8d2141`, clean guest branch
    `story-4-3-prototype`. No push, active-branch integration or VM shutdown.
  - `prototype.bundle` is incremental and requires base
    `08f17de9943730050d4787c50d1cc138c83f5bf5`, confirmed present in the host
    repository. Restore only in a repository containing that base.
  - Guest and host bundle SHA256 matched:
    `3dc94f75c9eb3692b0c5ee9f40025a2335911cf160399a7b95b14d23d8a53b5e`.
    Host `git bundle verify` passed; `sha256sum -c SHA256SUMS` passed for all
    eight recorded files. `MANIFEST.json` lists the 24 selected evidence files
    in `selected-evidence.tar`, including reports, studies, reuse records,
    final check outputs and synthetic visual-review scripts. No screenshots,
    private configuration, Pi sessions or notification state were exported.
  - Before export, host Gitleaks scanned the prototype commit-range patches
    and selected evidence with default rules and redacted output: no findings.
    An initial whole-history scan flagged four matches in pre-prototype
    installer test fixtures; its redacted report is retained. No whole-history
    bundle was exported and no scanner rules were disabled.
  - This backup does not qualify Task 3 acceptance, a final evidence export,
    ShellCheck completion or production delivery. Task 2 remains open.
- Brief 3 decision review: the maintainer approved the shared menu layout,
  direct Apps/System entry points and retaining Omarchy's dmenu selector mode
  (CLI compatibility remains to be verified). Availability uses fixed argv
  probes without generated Bash; unavailable actions remain visible with
  reasons, including in search. Keyboard help uses the guest-approved Lua
  dispatcher registry, pending an authorized persistence check. Session
  dispatch has a test-only dry-run mode and no extra confirmation dialog,
  following Omarchy. Lock/idle files belong in `capabilities/desktop/lock/`,
  without `prototype/`; hyprlock/hypridle are approved laboratory candidates.
  - Binding choices: root `SUPER+Space`; Apps both `SUPER+D` and
    `SUPER+Alt+Space`; System `SUPER+Escape`; help `SUPER+F1`; layout switch
    `SUPER+Ctrl+Space` with `compose:ralt` retained and no `grp:alts_toggle`.
    Existing `SUPER+Shift+E` logout stays for now. i3 focus-mode/sticky
    replacements and the floating/bar-toggle conflict remain unresolved.
  - The host supplied only the bounded i3 binding inventory. The final
    proposal must group actions and show i3, pinned Omarchy, proposed MirrorOS,
    actual guest bindings, conflicts, alternatives and approval/test status.
  - `brief-3-answers.md` was copied to guest `incoming/` and SHA256 matched:
    `c787dc5545fe9eafc11e4c81936a18ff663b46e2be942571744c27a3e3c5904d`.
    Installation, idle service activation, temporary binding/layout changes
    and each disruptive session test still require separate authorization.
    Further decisions are reviewed one at a time; no production integration
    or task completion is implied.
- Brief 3 host review: guest HEAD `765b30f023f0a30b99adf56956d616a52d74c857`
  was clean; its delta from regression-tested `5d43922` is a comment and README
  text only. Host reran provenance (98 files), I18n generator contracts and
  commit-range whitespace checks successfully; no attended checks were rerun.
  Later guest-recorded maintainer decisions supersede the initial keyboard
  proposals: Omarchy-first families, help `SUPER+K`, layouts `SUPER+I` and
  `SUPER+Shift+I`, with explicit exceptions in `brief-3-keyboard-table.md`.
  - Maintainer approved a bounded menu-cursor repair: preserve selection by
    action identity as availability changes, never activate a different action
    when the selected one becomes unavailable, and add a regression. No extra
    confirmation dialog or appearance change. Implementation is pending.
  - Runtime binding removal crashed Hyprland once; cause unknown. Do not
    repeat it now or patch by conjecture. Dynamic removal remains blocked for
    production pending investigation; launchable keyboard help stays a candidate.
  - Suspend/resume remains failed in this VM, with virtio_gpu as an indication,
    not a proven cause. No repeat now; laptop validation is pending. Hibernate,
    logout, reboot and shutdown remain unverified.
  - Maintainer chose not to rerun the attended launcher/dmenu/layout and
    idle-lock-from-ES matrix now. Retain historical tested identities and carry
    gaps to subsequent acceptance. Run the approved cursor regression only.
  - Host ShellCheck and Gitleaks checks of corrected source and selected
    evidence were approved, without automatic repairs; execution is pending.
  - With authorization for external research, host verified Omapager's original
    MIT license at repository `omacom/omapager` (the former `njpatel/omapager`
    redirects there), revision `c389e73516828d18f26e8efec2127c0c3dc3cb97`:
    https://raw.githubusercontent.com/omacom/omapager/c389e73516828d18f26e8efec2127c0c3dc3cb97/LICENSE
    It carries `Copyright (c) 2026 Neil Jagdish Patel` and the MIT grant,
    inclusion condition and disclaimer. Preserve that full notice with the
    prototype's incorporation and update stale unverified-license statements.
    This verifies the original license at the cited revision, not exact code
    ancestry or a comprehensive licensing audit. No guest files changed here.
- Maintainer approved retaining the current code volume for evaluation, without
  pruning now. Maintenance cost and upstream tracking require explicit Task 3
  review; this is not production adoption. A bounded amendment was then sent
  to guest `incoming/brief-3-review-amendment.md` (SHA256
  `9dfdd3e36da0af38f5b01b47a52df5a43aaa970ad39692603cdb95c65db6923c`).
  It requests the cursor repair/regression, Omapager attribution updates and
  explicit deferred-check/incident notes. The host also supplied
  `incoming/Omapager-LICENSE.txt` (SHA256
  `a2fe33052045a78c35a7a53ec452562e622a425ef7303c2cb631f07b2fd9e05d`),
  transcribed from the pinned original license fetched above. Both transfer
  checksums matched. Guest checkout was still clean at `765b30f`.
  No new session changes or deferred attended reruns are authorized. The
  correction, host ShellCheck/Gitleaks checks and Task 2 review remain pending.
- Host review of the delivered amendment: guest branch clean at
  `6d7314fbed2c2db0db5794529479669320fc6687`, parent `765b30f`.
  Reviewed menu selection by stable `selectedId` and the synthetic dry-run
  regression. Guest evidence records eight failures against the old menu and
  passing repaired checks, including earlier-row availability, selected-row
  unavailability and an app insertion. These runtime results were not rerun
  by the host; whitespace checks passed. Product now has 16,013 lines.
  - Omapager's full notice was added as `LICENSE.omapager`; provenance now
    pins its hash. Guest reports provenance PASS for 99 files, model PASS for
    12 checks, and lint-baseline PASS (57 QML files, 826 known diagnostics).
    Deferred attended tests remain historical, not final-source qualification.
  - Authorized host static review stored in ignored
    `evidence/desktop-shell-prototype/review-6d7314f-20261024T234859Z/`.
    Only selected shell/lock/Hyprland-provider source, attribution and 12
    current evidence files were retrieved; no bundle or integration.
  - Host Gitleaks default rules, redacted, ignoring allow comments: source,
    selected evidence and prototype history (`08f17de..6d7314f`) all passed
    before archives were retained. This does not cover all disposable evidence
    or replace the final Task 3 selected-export check.
  - Host ShellCheck scanned nine Bash files and exited 1: seven diagnostics,
    all in tests. `check-dmenu.sh`: SC2016 twice (deferred shell/JavaScript
    expansion), SC1010 twice (`done` used as output text);
    `check-launcher.sh`: SC2034 (loop counter), SC2015 (test-result chain);
    `check-menu.sh`: SC2034 (loop counter). No product Bash diagnostics.
    The host reviewed representative contexts; no automatic changes or global
    suppressions. The maintainer accepted retaining these test diagnostics
    as documented prototype limitations, without another repair round.
    ShellCheck is not recorded as passed; production must resolve or justify
    each diagnostic individually, without global suppression.
- Task 2 post-apply review: maintainer selected A (Accept), accepting the
  experimental result at `6d7314fbed2c2db0db5794529479669320fc6687` with
  documented defects, deferred verification, color-only deviations and open
  production choices. This is not production adoption, Story 4.3 completion
  or final Task 3 handoff acceptance. The runtime execution-log tool was
  initially unavailable; once restored, the host recorded Task 2 through
  `plan_log_task_terminal` as `agent_applied` / `accepted`, including the
  verification results, deviations, deferred checks and production blockers.
  No direct execution-JSONL edits were made.
- Expanded i3 inventory: with maintainer authorization, the host extracted
  160 bindings from the declared i3 config (no includes encountered), retaining
  native navigation, workspace, scratchpad, resize and mode actions. Exec
  commands and subsequent chained actions were omitted; personal workspace
  labels and mode names were withheld/anonymized. Direction aliases remain.
  Reviewed artifacts `i3-bindings.txt` and `i3-bindings-notes.md` were scanned
  with Gitleaks (no findings), copied to guest `incoming/`, and SHA256 verified:
  `365b21a426c364170081cd176c2261bf3c9ad21497f7fc2469aba6fc2179a02e`
  and `09b49b3871efff220ce2b4f622c6ffb4e4939016f05511c8a4af89bdf0206c49`.
  The guest must complete the grouped keyboard proposal, not omit navigation
  because the earlier A8 inventory was incomplete. No binding activation was
  authorized. New conflict: approved help binding `SUPER+F1` already has an
  omitted exec action in host i3; its reassignment requires explicit review.
- Follow-up: the maintainer supplied the guest's list of unknown exec actions.
  The host inspected only those bindings, their variable definitions and
  directly referenced scripts, without executing them. Functional descriptions
  (no personal commands, script paths or profiles) were exported as
  `incoming/i3-exec-actions.md`, Gitleaks passed and SHA256 matched:
  `466387146554b0ce709e1e34ca6309b394819d1481909f4d9347f54ec18b444b`.
  `SUPER+F1` opens the i3 guide PDF, so the approved MirrorOS live-help binding
  preserves its purpose rather than replacing an unknown unrelated action.
  The composite stop/hide binding contains two undefined mute/pause variables;
  those meanings remain unresolved. Monitor profile contents were not read.
  Descriptions establish configured intent, not runtime qualification, and do
  not authorize importing scripts or implementing later-story capabilities.
- 2026-10-23: authorized real Suspend test during Brief 3 resumed at the system
  level (journal: 22:21:04 suspend, 22:21:08 return), but the viewer lost display
  output. SSH remained responsive, Hyprland and hyprlock alive, Virtual-1
  enabled with DPMS true. Reconnecting SPICE and an authorized Lua DPMS enable
  did not recover the image. Authorized temporary mode requests returned ok
  but did not change the observed resolution; no actual modeset was verified.
  Root cause remains unknown (host uses VirtIO GL/SPICE GL). Source was clean
  at `3601f3c9f88a5807c472ac04a8284a41d71df759`. No lock bypass or compositor
  termination was attempted. The maintainer explicitly authorized recording
  the incident and an orderly guest reboot; recovery outcome pending.
  Detailed report: guest `evidence/brief-3-suspend-recovery-incident.md`, with
  host copy in ignored `build/story-4-3-prototype-transfer/`. Suspension is NOT
  fully qualified: system resume demonstrated, graphical recovery failed.

## Task 3 maintainer review

### Accepted prototype directions

- Architecture and maintenance (DEC-018): the maintainer explicitly accepted
  the explicit QML composition without Omarchy's plugin system or supervisor,
  with Hyprland integration and lock/idle kept separate. Retain the current
  16,013 product lines without pruning now and review upstream updates using
  per-file provenance. This accepts a prototype direction and its visible
  maintenance cost, not production adoption or integration.

- Guest-supervised experimental result (DEC-019): the maintainer confirmed
  that the guest prototype work was monitored and approved there, and
  authorized proceeding without repeating individual approvals of those
  recorded experimental choices. This includes hyprlock + hypridle as the
  proposed lock/idle providers, with authentication kept in system PAM rather
  than project-owned QML. Preserve the guest reports' accepted and rejected
  directions, defects and deferred checks; this confirmation does not select
  alternatives that those reports explicitly leave unresolved.
- Proceed with the final selected-evidence and Git-bundle handoff under the
  existing host-driven SSH approach. No production integration, publication,
  disruptive retest or credential transfer is authorized by this review.

### Rejected choices

No new rejection has been recorded during Task 3 so far. Historical rejected
experiments remain documented in the selected guest reports.

### Unresolved choices and verification

Lock/idle production ownership, notification policy, shell lifecycle ownership,
keyboard-help safety and other documented production blockers remain open.
The final bundle handoff is verified below. The maintainer selected A (Accept)
for the overall Task 3 post-apply review, recorded through the runtime execution
log. This accepts the bounded experimental result and verified handoff;
deferred tests remain deferred and failed behavior remains failed.

## Final host handoff

- Product source: `6d7314fbed2c2db0db5794529479669320fc6687`.
- Handoff commit: `87f4cbde9d2a0a54dd0064662d5e034605a8fd48`, local guest
  branch `story-4-3-prototype`. Its sole delta from product source is the
  211-line experimental recipe at `docs/procedures/desktop-shell-prototype.md`.
  No product change or attended rerun accompanied that documentation commit.
- Bundle prerequisite: `08f17de9943730050d4787c50d1cc138c83f5bf5`.
  This is an incremental bundle, not a self-contained full-history clone.
- Guest bundle directory:
  `~/mirroros/build/story-4-3-prototype/handoff-87f4cbd/`.
- Host evidence (ignored):
  `evidence/desktop-shell-prototype/handoff-6d7314f/`.
  `review/` is the isolated review repository, clean at the handoff commit;
  `selected-evidence/` contains the 42 allowlisted guest artifacts.
- `prototype.bundle` SHA256:
  `de50dd85060d8f71184017393906224d337d80d7b39cc79b5588aac469754fa5`.
- `evidence-files.txt` defines the selection; `selected-evidence.sha256`
  records independently obtained guest hashes, all matching on the host.
  Reports, source studies, synthetic outputs and two evidence-only scripts
  were selected. No private configuration trees, credentials, Pi sessions,
  screenshots or real notification state were exported.
- Host retrieval used the dedicated laboratory SSH key, strict host-key
  checking, batch mode, no agent forwarding and no guest access to the host.
  No synchronization, push or integration into the active branch occurred.
- `guest-recipe.md` is byte-identical to the committed guest recipe. It
  records package observations, context, commands, source/test identities,
  failures, recovery and fresh-authorization requirements. The isolated
  checkout carries the source and notices; selected reports supply detailed
  behavior and limitations. `VERIFICATION.md` records the handoff commands
  and results; `MANIFEST.json` and `SHA256SUMS` inventory retained artifacts.

### Checks performed during Task 3

| Check | Actual result |
| --- | --- |
| Guest identity, source and Omarchy revision | Confirmed; guest checkout clean before and after recipe commit |
| Prototype range paths/statistics and whitespace | Reviewed; no unrelated or production configure changes; `git diff --check <base> <handoff>` passed |
| Guest/host bundle SHA256 | Matched; `sha256sum -c prototype.bundle.sha256` passed |
| `git bundle verify` | Passed in guest, active host repository (read-only) and isolated host repository with the base present |
| Isolated review identity | Exact handoff commit, clean; only recipe differs from `6d7314f` |
| Selected evidence archive and hashes | Exact 42-file allowlist; every host file matched its guest hash |
| Gitleaks | Prototype history before/after recipe, recipe, pre-export evidence stream, retained evidence and selected source passed default-rule redacted scans; no rule disabling |
| Retained checkpoint | Disk and UEFI SHA256 still match the pre-experiment baseline; live VM disk untouched |
| Guest non-graphical checks at `87f4cbd` | Model PASS 12 including upstream extraction boundary; provenance PASS 99 files; i18n contracts and catalog `--check` PASS |
| Host non-graphical checks | Model PASS 11 without upstream extraction check; i18n contracts PASS |
| Host ShellCheck, nine Bash files | Exit 1, seven known test-only diagnostics; no product Bash diagnostics; not passed or suppressed |
| QML and graphical runtime | Not rerun in Task 3; historical identities and limitations retained |

The first SSH identity attempt without an explicit key was rejected; the
explicit dedicated-key attempt succeeded. The first non-graphical test
attempt failed with `node` absent from non-interactive PATH (127); retry used
`~/.nvm/versions/node/v24.22.0/bin` explicitly without sourcing private shell
configuration. Neither failed attempt is counted as a passing check.
Host tools: Gitleaks package `8.30.1-1`, ShellCheck package
`shellcheck-bin 0.11.0-1`, Node `v24.15.0`, Git `2.48.1`.
The incremental-range scans do not erase the earlier four pre-prototype
installer-fixture findings from the intermediate backup's whole-history scan.

### Reviewed result by surface

| Surface | Demonstrated or reported historical result | Retained limits |
| --- | --- | --- |
| Bar | Composition, actual layer, wired network state, absent-provider/device handling, keyboard-layout display, configuration persistence | One output only; visible tray/menu and real hardware unqualified; control panels studied, not implemented |
| Launcher/shared menu | Root/Apps/System routes, navigation/search, unavailable reasons, application launch via uwsm, minimal-style fixture; menu selection-identity repair regression at `6d7314f` | Final-source attended reruns deferred; terminal preference ownership open; Qt warnings; selector pending-request replacement defect |
| Notifications | Synthetic popup/history, clear-all deletion, age/count retention, quiet modes and restart; lock matrix showed no content on lock surface while delivery/persistence continued | No per-entry history deletion; normal cards expired unseen while locked; persistence/while-away and sandbox argv policy open; DND-panel lifetime defect |
| OSD | Controlled levels/messages/timers, unavailable real-source reasons, no keyboard focus | Synthetic levels do not qualify hardware or volume/brightness control |
| Session menu | Fixed-argv availability/dispatch, real lock/unlock and attended lock-before-sleep | Suspend graphical resume failed in VM; hibernate/logout/reboot/shutdown unqualified; dry-run dispatch is not real-action acceptance |

Architecture, dependency inventory, orchestration alternatives and reuse
assessment are in selected `brief-3-architecture.md`; the final grouped
comparison and approval/test status are in `brief-3-keyboard-table.md`.
Later Omarchy-first choices supersede earlier SUPER+F1 and layout proposals.
Final product size: 16,013 physical lines. Earlier 15,970-line measurements
reported about 92% textual upstream matches, not semantic ownership or effort.
Known unused branches in unmodified copies were retained, not silently pruned.

Historical performance at `7e35b68`: five warm starts 501-516 ms (median 506),
RSS 173,448 kB/PSS 131,474 kB after 30 seconds, CPU 0/1/0/0/0 ticks over five
60-second windows at 100 Hz. Fixture had almost no application/notification
load, no running locker and no experimental bindings. Polling produces upper
bounds; first-run decimal-comma timing was invalid and excluded. No cold-start,
laptop or final-source performance qualification and no invented thresholds.

### Outstanding production blockers and acceptance assessment

- Notification persistence/retention, while-away behavior and sandbox argv
  execution require explicit policy. No memory-only or upstream-default
  policy was silently selected.
- Shell/idle service ownership, config location, terminal preferences,
  configure/idempotency and NFR38 justification remain open.
- Keyboard registry runtime unbind crashed Hyprland once, cause unknown.
  Dynamic removal remains blocked; launchable-help safety, drag/Alt+Tab
  issues, standard-keyboard chords and zoom ergonomics need follow-up.
- Color-only cues remain the approved AC-2 deviation (DEC-015), not compliance
  with unchanged Story 4.3 criteria. Panels require the future ADR (DEC-016).
- Deferred final-source attended launcher/dmenu/layout/idle-lock-from-ES,
  multi-output/lockdead/hardware and disruptive-action checks remain pending.
  QML baseline PASS still means 826 reviewed diagnostics across 57 files.
  Qt warnings, DND/selector defects and seven test ShellCheck diagnostics
  remain recorded, not repaired or hidden.

AC-1's baseline and authorization record are supported, with checkpoint
integrity rechecked. AC-2/AC-3 have bounded evidence and explicit failures,
blockers and approved deviations, not an all-green runtime claim. AC-4's
source, recipe, integrity and selected-export checks passed. AC-5's explicit
maintainer directions and unresolved choices are recorded; overall post-apply
review was accepted. No production implementation plan, configure delivery,
clean reconstruction or complete Story 4.3 acceptance is claimed. Future full
story acceptance must retain all three DEC-010 validation levels.
