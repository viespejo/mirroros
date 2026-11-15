# Story 4.5 — Polkit QML agent (option A): decision log

Technical interview for plan 02-37, the follow-up to plan 02-36, whose option B (hyprpolkitagent themed through
hyprtoolkit) stopped at the gate checkpoint after failing G1. Primary inputs:
`.agents/plans/02-36-story-4-5-polkit-agent-SUMMARY.md`, `docs/technical-interviews/story-4-5-polkit-agent_log.md`
(DEC-001…DEC-014 and its execution findings) and the Area 2 section of
`.sheaf/brainstorming/brainstorming-session-2026-11-11-2353.md`.

## DEC-001
- **Question**: Does the next plan pursue option A (ADR for an adapted Omarchy QML agent) or option C (a packaged
  neutral agent such as polkit-gnome)?
- **Context/Nuances**: The brainstorm allowed A only through an ADR and only if B failed G1 or G2; B failed G1, so the
  escalation condition is met. A conflicts with ADR 0012/0025, the "one frozen principle" of `docs/mvp-scope.md` and
  `docs/architecture.md` (QML never authenticates). C (polkit-gnome) would inherit the `MirrorOS-default` GTK theme
  (#89) without an ADR; the assistant recommended C. A couples privilege prompts to shell uptime (#78). G2 showed
  fingerprint depends on PAM, not on the agent.
- **User Response**: A.
- **Decision**: Plan 02-37 covers option A: a polkit authentication agent written in QML, adapted from Omarchy's,
  hosted in the MirrorOS Quickshell shell over the native `Quickshell.Services.Polkit` agent. It requires a new ADR
  amending ADR 0012 and 0025, plus amendments to the frozen principle in `docs/mvp-scope.md` and to
  `docs/architecture.md`. The ADR follows the narrow shape of brainstorm #72: QML UI only, PAM through
  `polkit-agent-helper-1`, no storage or logging, hyprlock unchanged. Shell-uptime coupling (#78) is an accepted
  risk (no shell → no agent → fail-closed). C is not evaluated. Reusable 02-36 work: the generalized single-owner
  check, `polkit-check`, the agent-conditional `challenge` in `SessionActions.qml`, and the T14s G2 procedure.
- **Status**: Accepted

## TODO-001
- Whether the ADR is drafted and accepted inside plan 02-37 (gated first task) or in a separate preceding plan.

## TODO-002
- Fate of `visual/theme/default/hyprtoolkit.conf` and its palette test, which lose their consumer.

## TODO-003
- Preservation and cleanup of the dirty working tree and `refs/mirroros-candidates/02-36-a`.

## DEC-002
- **Question**: Is the ADR drafted and accepted inside plan 02-37, or in a separate preceding plan? (resolves
  TODO-001)
- **Context/Nuances**: Precedents 02-04, 02-09 and 02-23 drafted the ADR inside the implementing plan as Proposed,
  with a blocking checkpoint before product contracts or code; 02-23 exercised it with a lab prototype first. A
  separate ADR-only plan would force accepting an exception to a frozen principle without evidence, or leave the ADR
  Proposed between plans. Option B failed G1 in 02-36, so A must prove itself against the same gates before the
  exception becomes authoritative.
- **User Response**: Yes.
- **Decision**: The ADR lives in plan 02-37, following the 02-23 pattern. Task 1 drafts
  `docs/adr/0030-shell-hosted-polkit-agent.md` as Proposed in the narrow #72 shape, together with draft amendments
  to `docs/mvp-scope.md` (frozen principle and polkit row), `docs/architecture.md` (QML clause) and the ADR index
  references to ADR 0012/0025, without rewriting accepted ADRs. A blocking checkpoint reviews the ADR text. The
  agent is then built as a candidate on `refs/mirroros-candidates/02-37-*` and exercised by laboratory gates (G1
  visual, G2 T14s fingerprint, G3 `pkexec`, cancel, session menu, `admin://`). At the adoption checkpoint, passing
  gates set the ADR to Accepted and the ADR, amendments and code are committed together; failing gates leave the
  ADR Proposed or Rejected and nothing reaches `main`, as in 02-36.
- **Status**: Accepted

## DEC-003
- **Question**: Where does the agent live in the shell and how is it loaded?
- **Context/Nuances**: The MirrorOS shell has no plugin system; components such as `osd/`, `notifications/` and
  `reminders/` are instantiated directly from `shell.qml`. Omarchy's agent (`shell/plugins/polkit/PolkitAgent.qml`,
  `PolkitModel.js`, `manifest.json`) is identical at the pinned revision `7075b61` and at HEAD. Its UI dependencies
  (`Commons/{Style,Color,I18n,Border,Util}`, `Ui/BorderSurface.qml`, `Ui/OpticalGlyph.qml`) exist in MirrorOS;
  `Color.polkit` and the `polkit.*` i18n keys do not. Omarchy's `shell.qml:964` keeps lock and polkit out of the
  shared services map.
- **User Response**: Yes.
- **Decision**: A new `capabilities/desktop/shell/polkit/` directory holds `PolkitAgent.qml` and `PolkitModel.js`,
  adapted from Omarchy `7075b61` with per-file provenance in `UPSTREAM.md`; `manifest.json` is not carried over.
  The agent is instantiated directly in `shell.qml` as an isolated sibling in `ShellRoot` and is never exposed to
  other components; `SessionActions.qml` does not import it and learns about the agent through an external signal
  decided later. The agent belongs to the `desktop/shell` capability; no `desktop/polkit` capability with its own
  package or unit is created. Which parts of the 02-36 `desktop/polkit` skeleton (single-owner check,
  `polkit-check`) are reused is decided later.
- **Status**: Accepted

## DEC-004
- **Question**: Which behavioral adaptations does `PolkitAgent.qml` receive (lid probe, PAM detection, D-Bus path,
  logging, cancel, feedback states)?
- **Context/Nuances**: Omarchy handles the lid twice with `omarchy-hw-laptop-closed` (ACPI lid state, logind
  `LidClosed` fallback through `busctl --timeout=2`): a PAM clamshell gate
  (`auth [success=1 default=ignore] pam_exec.so quiet /usr/bin/omarchy-hw-laptop-closed` before `pam_fprintd`) and
  the agent's `laptopClosed` presentation hint. MirrorOS has no equivalent script. The assistant proposed dropping
  the lid probe (#80, redundant with PAM, dead code without `pam_fprintd`); the maintainer chose to adapt it and to
  bring fingerprint enablement into this plan, citing the 02-36 G2 evidence. That evidence covers only
  `/etc/pam.d/polkit-1` with `auth sufficient pam_fprintd.so` and no clamshell gate; `sudo`, hyprlock and the closed
  lid were not exercised. `docs/mvp-scope.md:212` lists the fingerprint reader under "Pending target-laptop
  availability"; ADR 0023:56 notes that MirrorOS adds no `fprintd` and keeps Finding 3 (fingerprint-session
  behavior on Omarchy, `TODO-582784b9`) open. Run by `pam_exec` as root, the probe becomes MirrorOS-owned
  authentication code.
- **User Response**: Change (a): adapt the script and add fingerprint in this plan; (b)–(f) accepted.
- **Decision**: (a) `omarchy-hw-laptop-closed` is adapted as a MirrorOS-owned lid probe used both by a PAM clamshell
  gate (`pam_exec` before `pam_fprintd`) and by the agent's `laptopClosed` hint, as in Omarchy. Fingerprint
  enablement (`fprintd`/`libfprint`, PAM entries, clamshell gate) enters plan 02-37, with an amendment moving the
  fingerprint reader out of the pending section of `docs/mvp-scope.md`. (b) The read-only `FileView` on
  `/etc/pam.d/polkit-1` detecting `pam_fprintd` is kept. (c) The D-Bus object path becomes
  `/org/mirroros/PolkitAgent`. (d) Only the "not registered; another agent may be running" warning is kept; no flow
  data (message, prompt, response) is ever logged. (e) Cancel keeps `flow.cancelAuthenticationRequest()` and G3
  requires exit 126. (f) Timers, shake, error flash and the "checking" state are kept. Stacks, lid and closed-lid
  behavior beyond the 02-36 G2 evidence are exercised in this plan.
- **Status**: Accepted

## TODO-004
- Which PAM stacks receive fingerprint (`polkit-1`, `sudo`, hyprlock, SDDM).

## TODO-005
- Hardware conditioning of fingerprint enablement (T14s recognized profile, reader presence, or unconditional).

## TODO-006
- Enrollment (attended, user-run, never automated) and behavior with no enrolled prints.

## TODO-007
- Lid probe placement, name and execution (owning capability, absolute path for `pam_exec`, `busctl` dependency).

## TODO-008
- Whether ADR 0030 also covers fingerprint/PAM, or the scope amendment plus `sources.md` suffice.

## DEC-005
- **Question**: Which PAM stacks receive fingerprint? (resolves TODO-004)
- **Context/Nuances**: Omarchy's `omarchy-setup-security-fingerprint` adds the clamshell gate and
  `auth sufficient pam_fprintd.so` to `/etc/pam.d/sudo` and `/etc/pam.d/polkit-1` (creating the latter with
  `include system-auth`), and configures its own QML lock through dedicated PAM services
  (`omarchy-lock-password`, `omarchy-lock-fingerprint` from `omarchy-apply-lock`), not hyprlock. MirrorOS locks with
  hyprlock and its packaged `/etc/pam.d/hyprlock` (ADR 0021, Story 4.3). The host ships only
  `/usr/lib/pam.d/polkit-1`, so `/etc/pam.d/polkit-1` is free; `/etc/pam.d/sudo` belongs to the `sudo` package.
  hyprlock offers native fingerprint (`auth { fingerprint { enabled } }` over fprintd D-Bus, in parallel with the
  password) or PAM; either touches `desktop/lock`, ADR 0021's "password field only" and ADR 0023 Finding 3, with no
  evidence, and the lock is the session boundary (#73). Fingerprint at SDDM login does not unlock the keyring (#70)
  and the greeter is neutral (ADR 0021).
- **User Response**: Yes.
- **Decision**: Fingerprint is enabled in `polkit-1` and `sudo`, each with the clamshell gate before
  `sufficient pam_fprintd.so`. `/etc/pam.d/polkit-1` is a managed file: gate, `pam_fprintd`, then
  `include system-auth` for auth, account, password and session. The mechanism for the package-owned
  `/etc/pam.d/sudo` is decided separately. hyprlock fingerprint is deferred to a later plan and recorded as pending
  in `docs/mvp-scope.md`; SDDM is excluded.
- **Status**: Accepted

## TODO-009
- Mechanism for adding the gate and `pam_fprintd` to the package-owned `/etc/pam.d/sudo`.

## DEC-006
- **Question**: How is fingerprint enablement conditioned on hardware? (resolves TODO-005)
- **Context/Nuances**: Omarchy installs nothing at install time: `omarchy-hw-fingerprint` detects a reader from sysfs
  (USB vendor list including Synaptics `06cb`, plus platform readers) without fprintd; a first-run hook sends a
  one-time critical notification and the menu shows "Setup › Security › Fingerprint" only when a reader is detected;
  both open `omarchy-setup-security-fingerprint`, which installs `libfprint-git`/`fprintd`/`usbutils` on demand,
  enrolls, verifies and only then writes PAM. In MirrorOS configure is the declarative owner of system files, so a
  user command writing `/etc/pam.d` would create a second owner. Configure reads no hardware profile; `system/bluetooth`
  installs BlueZ unconditionally and only conditions starting the service on `/sys/class/bluetooth`. Conditioning
  packages on detection would be a new pattern, require all-or-nothing PAM (`pam_fprintd.so` ships in `fprintd`), and
  read the live `/sys` in target context. The 02-36 G2 delta shows fingerprint adds only `fprintd`, `libfprint` and
  `libgusb` (about 3.5 MiB).
- **User Response**: Unconditional, with invitation and menu.
- **Decision**: Configure always installs `fprintd` and `libfprint` from Arch `extra` (the stock build that passed G2,
  not Omarchy's `libfprint-git`) and manages the gated PAM entries in `polkit-1` and `sudo`, with no hardware
  condition. Without enrolled prints `pam_fprintd` returns `PAM_AUTHINFO_UNAVAIL` and authentication falls through to
  the password; the laboratory proves no perceptible delay in the VM (no reader) and on the T14s without
  enrollment. A one-time first-session invitation notification and a "Fingerprint" session-menu row appear only when
  a sysfs reader probe, adapted from `omarchy-hw-fingerprint`, detects a reader. Enrollment never changes system
  files. The reader probe joins TODO-007; invitation, menu and enrollment command are TODO-006.
- **Status**: Accepted

## DEC-007
- **Question**: What is the enrollment command? (TODO-006, part 1)
- **Context/Nuances**: `vpn-connect` is the precedent: an owned command in `/usr/share/mirroros/hardware/` launched by
  the shell through `uwsm app -- foot -e …`, so no credential passes through QML (ADR 0025). Omarchy's
  `omarchy-setup-security-fingerprint` installs packages, uses `sudo fprintd-enroll`, verifies and writes PAM; under
  DEC-006 configure owns packages and PAM. fprintd authorizes enrollment through polkit
  (`net.reactivated.fprint.device.enroll`), whose exact default policy is to be verified in the laboratory.
- **User Response**: Yes.
- **Decision**: An owned `fingerprint-setup` command, adapted from the enroll and verify part of
  `omarchy-setup-security-fingerprint` with recorded provenance, is delivered at
  `/usr/share/mirroros/hardware/fingerprint-setup` by the capability that hosts fingerprint (TODO-007) and launched
  in foot from the shell through `uwsm app -- foot -e`. It checks the reader with the sysfs probe, runs
  `fprintd-enroll` for the current user with progress messages adapted from Omarchy, then `fprintd-verify`; with
  prints already enrolled it offers re-enrollment or deletion (`fprintd-delete`). It never runs `pacman`, writes
  `/etc/pam.d`, changes services or calls `sudo`; fprintd requests enrollment authorization through polkit, so the
  QML agent's dialog appears during enrollment and serves as a live G3 case. There is no system-level fingerprint
  removal: deleting prints returns authentication to password-only while configure keeps packages and PAM.
- **Status**: Accepted

## DEC-008
- **Question**: How are the fingerprint menu row and the one-time invitation delivered? (TODO-006, part 2; resolves
  TODO-006)
- **Context/Nuances**: `MirrorMenu.js` copies ids, labels and icons from Omarchy `7075b61`, restricted to Apps,
  Learn › Keybindings, System and the background rows; actions are closed-table ids interpreted by `Menu.qml`, never
  command text; `MenuModel.js` already supports `when` guards. Omarchy has `setup` › `setup.security` ›
  `setup.security.fingerprint` guarded by `omarchy-hw-fingerprint`. Omarchy's invitation runs from a generic
  first-run framework: `autostart.lua` runs `omarchy-provision-first-run` every login (marker `first-run-user`,
  retried on failure, own log); after `omarchy-notification-wait`, a detached step waits for the network
  (`nm-online`, because its setup installs packages) and runs `setup-fingerprint.hook`, which checks the reader,
  that fingerprint is not set up, and `omarchy-done ensure fingerprint-setup-invitation`, then sends a critical
  notification whose action opens the setup terminal. MirrorOS has no first-run framework, needs no network wait
  (DEC-006), must wait for the shell's notification server, and avoids coupling to the Hyprland provider's
  autostart. ADR 0025 and the PRD exclude a welcome application and a resident shell-owned background service.
- **User Response**: Yes.
- **Decision**: Menu: `setup` › `setup.security` › `setup.security.fingerprint` with Omarchy `7075b61` ids, labels
  and icons, the difference recorded in the `MirrorMenu.js` header; a new closed action `fingerprint:setup` that
  `Menu.qml` maps to the fixed argv `uwsm app -- foot -e /usr/share/mirroros/hardware/fingerprint-setup`; a `when`
  guard running the reader probe with fixed argv, independent of enrolled prints so the row also serves
  re-enrollment and deletion. Invitation: a oneshot user unit `mirroros-fingerprint-invite.service` in
  `graphical-session.target`, delivered and enabled by the fingerprint capability, runs a script that exits if the
  marker `~/.local/state/mirroros/fingerprint-invited` exists, if no reader is detected, or if the user already has
  prints (`fprintd-list`); it waits with a bound for `org.freedesktop.Notifications` on the session bus, exiting
  without the marker if it never appears (retry next login); it writes the marker immediately before sending, then
  runs `notify-send --wait` with one action that launches `uwsm app -- foot -e …/fingerprint-setup`. No generic
  first-run framework is introduced; the unit is not resident and the shell holds no first-run logic.
- **Status**: Accepted

## DEC-009
- **Question**: Where do fingerprint enablement, the lid probe and the reader probe live? (resolves TODO-007)
- **Context/Nuances**: `system/bluetooth` and `system/power` are the model: `packages`, commands delivered to
  `/usr/share/mirroros/hardware/` with `cfg_tracked_file … 0755`, a `mirroros-*.service` user unit enabled in
  `graphical-session.target`, a `check` script, `sources.md` and `OMARCHY-LICENSE` for copied material.
  `/etc/pam.d/polkit-1` changes only because of fingerprint. `pam_exec` needs a literal absolute path to a
  root-owned executable.
- **User Response**: Yes.
- **Decision**: A new `system/fingerprint` step is inserted in `configure-steps` after `system/power` and before
  `system/network`, ahead of `desktop/shell`. It holds: `packages` (`fprintd extra`, `libfprint extra`);
  `lid-closed` → `/usr/share/mirroros/hardware/lid-closed` (0755, root), adapted from `omarchy-hw-laptop-closed`
  (ACPI lid state, logind `busctl --timeout=2` fallback), called by `pam_exec` by literal path and by the QML agent
  with fixed argv (no `bash -c`); `fingerprint-reader` → `/usr/share/mirroros/hardware/fingerprint-reader`, adapted
  from `omarchy-hw-fingerprint`, USB sysfs only (no platform readers), with a sysfs path override for tests;
  `fingerprint-setup` (DEC-007); `fingerprint-invite` and `mirroros-fingerprint-invite.service` (DEC-008); the
  managed `/etc/pam.d/polkit-1` (DEC-005); the `sudo` change (TODO-009); a read-only `check`; `sources.md` and
  `OMARCHY-LICENSE`. The QML agent in `desktop/shell` only consumes `lid-closed` and reads `polkit-1`. The 02-36
  `desktop/polkit` skeleton hosts nothing fingerprint-related; reuse of its single-owner check and `polkit-check`
  is decided separately.
- **Status**: Accepted

## TODO-010
- Reuse of the 02-36 single-owner check (`cfg_session_agent_unique`) and `polkit-check` for the shell-hosted agent.

## DEC-010
- **Question**: How are the package-owned `/etc/pam.d/sudo` and the new `/etc/pam.d/polkit-1` delivered? (resolves
  TODO-009)
- **Context/Nuances**: The `sudo` package ships `/etc/pam.d/sudo` (three `include system-auth` lines) as a pacman
  backup file, so a changed upstream version arrives as `.pacnew` and never overwrites the local file.
  `cfg_system_file` leaves an existing file without the managed header untouched ("user-owned"), so fingerprint
  would silently never reach `sudo`. `cfg_tracked_file` replaces a destination only when it matches the recorded
  previous delivery or one of the SHA256 values passed as legacy arguments, exits 4 on any other content without
  overwriting, records the delivered SHA256 under `/var/lib/mirroros/configure/delivered/`, and requires a managed
  header (a `#` comment is valid PAM). Omarchy edits the stacks line by line with `sed`.
- **User Response**: Yes.
- **Decision**: Both stacks are complete managed files delivered with `cfg_tracked_file`; no line editing and no new
  helper. `sudo`: managed header, clamshell gate, `sufficient pam_fprintd.so` and the three vendor lines, with the
  SHA256 of the packaged `/etc/pam.d/sudo` passed as a legacy argument so exactly that content is replaced; an edited
  file fails with exit 4 naming the file and nothing is changed. `polkit-1`: created by the same helper. `sources.md`
  records the `sudo` package version the SHA256 comes from, that a later `sudo` update changing the file yields a
  `.pacnew` to review, and the action on conflict. Tests cover vendor content (replaced), previous delivery
  (unchanged), edited (exit 4) and absent (created).
- **Status**: Accepted

## DEC-011
- **Question**: What is reused from the 02-36 single-owner check and `polkit-check`, and what signal does the session
  menu use? (resolves TODO-010)
- **Context/Nuances**: `desktop/shell` has no `check`; the shell runs as `mirroros-shell.service`
  (`qs -p /usr/share/mirroros/shell`, `graphical-session.target`). `cfg_session_agent_unique` is generic over an
  executable list and exits 4 without remediating. The 02-36 `agents` list omits `hyprpolkitagent`, which is now a
  competitor and is still installed and enabled in the reference VM. The 02-36 `polkit-check` checks the
  `hyprpolkitagent` unit, competing processes (`pgrep -f`) and the hyprtoolkit file. polkit exposes no list of
  registered agents. The `challenge` logic in `SessionActions.qml` runs in the same process as the agent: if the menu
  is shown the agent exists, and if another agent won registration it still authorizes, so the unit probe is moot.
- **User Response**: Yes.
- **Decision**: (1) `cfg_session_agent_unique`, `CFG_AGENT_PARSER`, `cfg_agent_unit_file` and `cfg_agent_conflict`
  are restored from the 02-36 work into `capabilities/lib/files.sh` and called by `desktop/shell/apply` as a
  `cfg_require` with `desktop/shell/polkit/agents`, holding the six 02-36 agents plus `hyprpolkitagent`; a competitor
  makes configure exit 4 naming the file, package and next action. (2) `polkit-check` is generalized and delivered by
  `desktop/shell` to `/usr/share/mirroros/polkit/polkit-check`: it checks that `mirroros-shell.service` is active and
  that no listed agent runs; the hyprtoolkit check is dropped; actual registration is proven by attended G3, not by
  the check. (3) `SessionActions.qml` drops the unit probe: `challenge` rows are available with "<Label> asks for
  authorization.", the "start the polkit agent" reason disappears and `check-menu.sh` is adjusted. (4) Nothing else
  from `desktop/polkit` is reused: no capability, step, `packages` or `hyprtoolkit.conf`, and that step does not
  enter `configure-steps`.
- **Status**: Accepted

## DEC-012
- **Question**: What does the ADR cover: the QML agent only, or fingerprint and PAM as well? (resolves TODO-008)
- **Context/Nuances**: The widened scope carries two normative exceptions: authenticating QML (ADR 0012/0025, the
  frozen principle of `docs/mvp-scope.md`, `docs/architecture.md:702`) and MirrorOS-owned code in PAM stacks
  (`lid-closed` run as root by `pam_exec`, and a replaced `/etc/pam.d/sudo`), against ADR 0012:38 ("Authentication
  surfaces carry security risk and must not be project-owned code") and `docs/architecture.md:310` ("Linux accounts
  and PAM own user authentication"). ADR 0023:56 states in its context that MirrorOS adds no `fprintd`; it is context,
  not a decision, so an index note suffices.
- **User Response**: Yes.
- **Decision**: One ADR, renamed `docs/adr/0030-shell-hosted-polkit-agent-and-fingerprint.md` (amends the file name
  in DEC-002), partially amending ADR 0012/0025. It decides: the QML agent UI over `Quickshell.Services.Polkit` with
  its bounds (no storage or logging of flow data, no `bash -c`, only `lid-closed` with fixed argv, not exposed to
  other components, hyprlock unchanged); unconditional `fprintd`, the gated `polkit-1` and `sudo` stacks,
  `lid-closed` as the only MirrorOS-owned code in PAM with its contract (read-only, writes nothing, bounded logind
  timeout, literal root:root 0755 path), and user-run enrollment that never writes `/etc`. Out of scope: hyprlock,
  SDDM and a first-run framework. Risks: shell-uptime coupling (#78) and a failing `lid-closed` falling through to
  the password (`default=ignore`). Reopening: failed gates or future hyprlock fingerprint. Both exceptions pass the
  same gated acceptance (DEC-002); the ADR index notes the ADR 0023 context line.
- **Status**: Accepted

## DEC-013
- **Question**: How is the agent adapted visually (colors, strings, shape) and how is G1 judged?
- **Context/Nuances**: Omarchy's `Commons/Color.qml:109-119` defines a `polkit` QtObject with seven roles
  (`background`, `text`, `textError`, `border`, `borderError`, `accent`, `scrim`) derived through `pick`/`composed`;
  MirrorOS's `Color.qml` uses the same mechanism for `bar`, `popups`, `tooltip`, `notifications` and `menu` and
  defines `root.urgent` from the palette red. The agent uses five strings (`polkit.authenticationNeeded`,
  `polkit.authorizeRunning`, `polkit.checking`, `polkit.enterPassword`, `polkit.wrong`) from Omarchy's
  `default/i18n/*/shell.json`; MirrorOS has only `Commons/i18n-en.json`. The lock and fingerprint glyphs are Nerd
  Font codepoints already used by the shell (the `system.lock` row uses `\uF023`). Plan 02-36 judged G1 in the
  reference VM at scales 1.6 and 1.25.
- **User Response**: Yes.
- **Decision**: (1) `Commons/Color.qml` gains a `polkit` section with the same seven roles and derivations as Omarchy
  `7075b61`, with recorded provenance, so the dialog follows the selected theme like the menu and notifications, with
  no new theme file; the `polkit.*` keys can be overridden through the surface settings like other sections.
  (2) `Commons/i18n-en.json` gains the five English `polkit.*` strings copied from Omarchy; the invitation title and
  body are fixed English text in `fingerprint-invite`, not shell strings. (3) The shape is Omarchy's, unchanged:
  compact card with lock glyph and field, justification pill above, square fingerprint mode, `•` mask, shake and
  error flash. (4) G1 is judged by the maintainer in the reference VM, comparing the dialog with the session menu, a
  notification and hyprlock in the empty, checking, error and (T14s only) fingerprint states, at scale 1.6 and 1.25;
  style values (sizes, alpha) may be iterated within the plan without architectural change; fine visual refinement
  stays in Story 4.8; a final "no" after iteration is a gate failure (DEC-002).
- **Status**: Accepted

## DEC-014
- **Question**: What happens to the uncommitted 02-36 work, its candidate ref and the hyprtoolkit palette? (resolves
  TODO-003 and TODO-002)
- **Context/Nuances**: The working tree holds 12 modified files and 6 untracked paths from 02-36;
  `refs/mirroros-candidates/02-36-a` (`e59561e`) lacks the Task 7 findings. The 02-36 summary proposed preserving the
  full tree as `02-36-b` with a temporary `GIT_INDEX_FILE` and restoring reused paths with
  `git checkout 02-36-b -- <paths>`. 02-36 inserted `desktop/polkit` (23→24 steps); `main` has 23, and
  `system/fingerprint` brings it to 24 at a different position. The hyprtoolkit palette has no consumer after
  DEC-011.
- **User Response**: Yes.
- **Decision**: (1) Task 0 preserves the full working tree as `refs/mirroros-candidates/02-36-b` through a temporary
  `GIT_INDEX_FILE`, without touching `main` or the real index, then cleans the working tree (`git restore` of
  modified files, removal of untracked paths) except the two 02-36 and two 02-37 interview artifacts, which stay
  untracked until the docs commit. (2) Only reused paths are restored with `git checkout 02-36-b -- <paths>`: the
  `lib/files.sh` helpers, `polkit-check` and `agents` (moved to `desktop/shell/polkit/`), the `challenge` handling
  (simplified per DEC-011) and the related tests (`tests/capabilities/desktop/polkit/`, adapted); restored step-list
  tests (`target`, `hardware`) are reviewed because the new step is `system/fingerprint` at another position, still
  24 in total. (3) The hyprtoolkit palette is not restored: `visual/theme/default/hyprtoolkit.conf`, its test and the
  `## Agent dialog colors` section of `visual/theme/sources.md` remain only in `02-36-b`. (4) The 02-36 interview
  artifacts land on `main` in this plan's `docs(polkit)` commit with the 02-37 ones, which cite them. (5) `02-36-a`
  and `02-36-b` are kept until 02-37 is adopted, then deleted with maintainer confirmation as in 02-35; if 02-37
  stops at the gate they are kept.
- **Status**: Accepted

## DEC-015
- **Question**: Which laboratory gates run, where, with what evidence, and which ones block adoption?
- **Context/Nuances**: The reference VM still has hyprpolkitagent installed and its unit enabled from candidate
  `02-36-a`, so under DEC-011 the first candidate configure should exit 4 naming it, giving the live competing-agent
  case 02-36 never ran. The T14s MirrorOS partition hosted the 02-36 G2 run; closed-lid testing needs an external
  monitor. G4 (another wlroots compositor) adds nothing for a shell-hosted agent. DEC-002 routes blocking failures
  to the adoption checkpoint.
- **User Response**: Yes.
- **Decision**: VM (G1, G3), in a real session after candidate configure: (1) configure with the residue exits 4
  naming unit, package and next action; the maintainer disables or removes hyprpolkitagent; rerun exits 0 and a third
  run is unchanged; (2) after a new login `polkit-check` exits 0; (3) `pkexec true`: correct password 0, wrong then
  correct 0 with shake and flash, Escape cancel 126; (4) without a reader the password prompt appears with no
  perceptible delay in `pkexec` and `sudo true`; (5) a session-menu `challenge` row if any action triggers one in the
  VM, and Strata `admin:///etc`; (6) shell restart with a pending request ends it without granting, and a prompt
  open while hyprlock activates (#69) is recorded; (7) the G1 verdict per DEC-013. T14s (G2, MirrorOS partition,
  candidate configure): (1) the vendor `/etc/pam.d/sudo` is replaced and `polkit-1` created; before enrollment
  `sudo` and `pkexec` prompt for the password with no delay; (2) the invitation appears once after login, its action
  opens `fingerprint-setup`, enrollment shows the agent dialog (G3 case), and a second login shows no invitation;
  (3) the menu row appears and serves re-enrollment and deletion; (4) with a print, in `pkexec` and `sudo`: correct
  finger 0, wrong finger or timeout falls back to the password 0, cancel 126; (5) closed lid with an external
  monitor: password directly in both stacks and no fingerprint mode in the dialog; (6) deleting prints returns to
  password only. Not run: G4 (Sway) and hyprlock. Evidence under `evidence/polkit/lab-02-37/` (`checkpoint.md`,
  `t14s/g2.md`, `SHA256SUMS`) with the maintainer's written verdict. Blocking (DEC-002 on failure): G1, cancel 126,
  fingerprint plus password fallback in both stacks, closed lid, and no delay without enrollment; other findings are
  defects fixed within the plan.
- **Status**: Accepted

## DEC-016
- **Question**: Which tests are added or adjusted, and what verification policy applies?
- **Context/Nuances**: Existing suites: `tests/capabilities/system/` (`hardware.contract.bats`, per-command
  `hardware-*.bats`, a `busctl` double), `tests/capabilities/target.contract.bats`, `mechanism.contract.bats`, and the
  shell suites (`configure.contract.bats`, `menu-model.test.mjs`, `surface-palette.test.mjs`, `check-i18n.mjs`,
  `no-omarchy-coupling.test.mjs`, `check-provenance.mjs`, `qmllint-check.mjs`, `check-menu.sh`). The 02-36 work left
  `tests/capabilities/desktop/polkit/{configure.contract.bats,polkit-check.bats}`. Plan 02-36 DEC-013/014 set the
  linked-tests policy with a final impact analysis.
- **User Response**: Yes.
- **Decision**: Change→test map: `system/fingerprint/apply` → new `tests/capabilities/system/fingerprint.contract.bats`
  (packages; `sudo` vendor replaced, delivered unchanged, edited exit 4, absent created; `polkit-1` created; the gate
  immediately before `pam_fprintd` with the literal `/usr/share/mirroros/hardware/lid-closed` path in both files;
  commands 0755; invitation unit enabled). `lid-closed`, `fingerprint-reader`, `fingerprint-setup`,
  `fingerprint-invite` → new `tests/capabilities/system/hardware-fingerprint.bats` with sysfs/ACPI fixtures and
  `busctl`, `fprintd-*` and `notify-send` doubles (lid open/closed, bounded logind fallback, reader present/absent,
  enroll ok, verify failure, re-enroll and delete, invitation marker, no reader, existing prints, no notification
  server leaves no marker). Step insertion → `target.contract.bats`, `system/hardware.contract.bats`. Restored
  `lib/files.sh` helpers → `mechanism.contract.bats`. `PolkitModel.js` → new `desktop/shell/polkit-model.test.mjs`
  (pure functions, including `pam_fprintd` detection with the gate line first). `Color.qml`, i18n, `shell.qml` →
  `surface-palette.test.mjs`, `check-i18n.mjs`, `no-omarchy-coupling.test.mjs` (`/org/mirroros` path),
  `check-provenance.mjs`, `qmllint-check.mjs`. `desktop/shell/apply` → `desktop/shell/configure.contract.bats`,
  absorbing the exit-4 cases of the former `desktop/polkit/configure.contract.bats`; `polkit-check.bats` moves to
  `tests/capabilities/desktop/shell/`. Menu (`MirrorMenu.js`, `Menu.qml`, `SessionActions.qml`) →
  `menu-model.test.mjs` (`setup.*` rows, `when` guard) and `check-menu.sh` in the VM (`challenge` always available,
  fingerprint row). New scripts → `shellcheck`. Policy: as 02-36 DEC-013/014 — each task runs only its linked tests;
  a final impact analysis on the delivered diff; full suites only if impact cannot be bounded, with maintainer
  approval, once, on the final tree. Because `lib/files.sh` is a shared helper, the final run includes the extended
  subset of every `configure.contract.bats` that sources it.
- **Status**: Accepted

## DEC-017
- **Question**: Which documents change, and how is the work committed?
- **Context/Nuances**: AGENTS.md requires attribution, tests and documentation to change with what they govern.
  DEC-002 makes the ADR Accepted only at adoption, with ADR, amendments and code landing together; 02-35 and 02-36
  prepared commits on candidate refs with a temporary `GIT_INDEX_FILE` and did not push.
- **User Response**: Yes; materialize the plan directly without a chat draft.
- **Decision**: Documents: `docs/adr/0030-shell-hosted-polkit-agent-and-fingerprint.md` (Accepted at adoption) and
  its `docs/adr/README.md` entry with the ADR 0023 context note; `docs/mvp-scope.md` (frozen principle restated with
  the ADR 0030 exception, polkit row resolved, a fingerprint row, fingerprint removed from "Pending target-laptop
  availability", hyprlock fingerprint pending); `docs/architecture.md` (QML clause at line 702 and an Authentication
  & Security line on `lid-closed` and managed PAM); `capabilities/README.md` (numbered `system/fingerprint` step and
  the agent under `desktop/shell`); `capabilities/system/fingerprint/sources.md` with `OMARCHY-LICENSE`;
  `capabilities/desktop/shell/UPSTREAM.md` and `sources.md`; `docs/attribution.md`; `docs/procedures/configure.md`
  (exit-4 conflict and remedy); `docs/procedures/hardware.md` (enrollment, deletion, closed lid, `sudo` `.pacnew`);
  the 02-36 and 02-37 interview artifacts. Commits are prepared on `refs/mirroros-candidates/02-37-*` and reach
  `main` only at adoption, in order, each exported tree running its linked tests: (1) `docs(adr)` ADR 0030, index
  and normative amendments (`mvp-scope`, `architecture`); (2) `feat(fingerprint)` the step, four scripts, unit,
  tests, `configure-steps` insertion, `sources.md` and license; (3) `feat(shell)` the agent, `Color.polkit`, i18n,
  `shell.qml`, the `lib/files.sh` single-owner helpers, `polkit-check`, the `challenge` simplification, menu rows
  and tests; (4) `docs(polkit)` `capabilities/README.md`, procedures, attribution and interview artifacts. No push.
  If the plan stops at the gate nothing reaches `main` and the ADR stays Proposed on the ref only.
- **Status**: Accepted

## Execution findings — 2026-11-15 (plan 02-37)

These findings supplement, and do not rewrite, DEC-001 to DEC-017. Records (ignored):
`evidence/polkit/lab-02-37/checkpoint.md` (reference VM) and `evidence/polkit/lab-02-37/t14s/g2.md` (T14s), each
with `SHA256SUMS`.

- Outcome: **option A adopted** at the adoption checkpoint (DEC-002). Every blocking gate of DEC-015 passed on the
  final candidate `refs/mirroros-candidates/02-37-f` (`a7068c6`): G1 approved by the maintainer at scales 1.6 and
  1.25 without style iteration, cancel 126 in the VM and on the T14s, fingerprint with password fallback in
  `polkit-1` and `sudo`, the closed lid going straight to the password, and no added delay or fingerprint flash
  without enrollment. ADR 0030 is Accepted (2026-11-15). Candidates `02-37-a` to `02-37-f` record each fix below;
  `02-36-a`, `02-36-b` and `02-37-*` are kept until the maintainer confirms their deletion after the commits.
- VM (G1, G3): the residual `hyprpolkitagent` unit made the first configure exit 4 at `desktop/shell` naming the
  starter, its package and the next action; after the maintainer-authorized disable, reruns were unchanged (24/24).
  `polkit-check` 0 after a new login; `pkexec true` 0, wrong then correct 0 with shake and error flash, Escape 126;
  Strata `admin:///etc` prompted through the agent; a shell restart with a pending request ended it `Not authorized`
  (rc 127, nothing granted); with a prompt open hyprlock covered it and the dialog completed after unlock (#69).
  A live session-menu `challenge` was not reproducible, because logind answers `yes` in the active graphical session;
  AC-8 rests on `check-menu.sh` (71 PASS).
- T14s (G2, Synaptics `06cb:00bd`, MirrorOS partition): package delta `fprintd`, `libfprint`, `libgusb` only; `sudo`
  replaced and `polkit-1` created with the gate before `pam_fprintd`; every DEC-015 step passed on `a7068c6`. No prints
  remain enrolled; the fingerprint stack stays as product state.
- Defect D-1 (fixed): the packaged `/etc/pam.d/sudo` content and hash had been taken from the outdated development
  host (`sudo 1.9.16.p2-2`). The reference VM ships `1.9.17.p2-6` with a fourth line
  `session optional pam_systemd.so class=none`, so DEC-010's "three vendor lines" is outdated: the managed `sudo`
  keeps the four packaged lines byte for byte and only the VM-derived hash is accepted. `AGENTS.md` gained the rule
  to derive vendor package facts from the reference VM or the current Arch repositories (maintainer-approved scope
  expansion).
- Defect F-1 (fixed): the agent, like Omarchy `7075b61`, kept PAM supplementary messages but never displayed them, so
  a `pam_faillock` lockout looked like a rejected correct password. The dialog now shows them in a plain-text pill,
  error-colored for errors, never logged or stored. Fingerprint-mode policy settled in G2: show every `pam_fprintd`
  message.
- Defect G2-1 (fixed): the invitation used normal urgency, expired unseen after about 10 seconds and, the marker being
  written first, never repeated. It now uses critical urgency as upstream does.
- Defect G2-2 (fixed): the dialog flashed fingerprint mode before the password prompt for users without prints,
  because ADR 0030 carries `pam_fprintd` unconditionally while upstream adds it only after enrollment. Fingerprint mode
  now requires a `pam_fprintd` scan message; a pending-method state (card transparent for at most 1.5 seconds) avoids
  the password-to-fingerprint jump when prints exist.
- Limitation L-1 (accepted by the maintainer): after Escape, `polkit-agent-helper-1` keeps the reader claimed until
  the 30-second `pam_fprintd` timeout, so authentications in that window fall back to the password. Fail-safe and
  upstream; documented in `docs/procedures/hardware.md` and ADR 0030, with no timeout change.
- Observations, not blocking: O-1 stock `pam_faillock` (`deny=3`, 600 s) counts cancellations and requests ended by a
  shell restart, which locked the account during free testing (documented); O-2 every authentication with an open or
  absent lid logs a `pam_exec` "failed: exit code 1" line for `lid-closed`; O-3 `pam_fprintd` D-Bus-activates fprintd
  on every authentication without a reader, which exits after about 30 seconds; O-4 the configure console names only
  the failed postcondition, while the conflict detail is in the root-only `configure.log`; O-5 Qt portal-registration
  and text-input warnings in the shell journal, without flow data or functional effect.
- Approved implementation deviations: `agents` and `polkit-check` live in `capabilities/desktop/shell/polkit-check/`,
  not `polkit/`, so `install-runtime` excludes the delivery directory from the published runtime (its contract test
  changed accordingly); `Commons/i18n-en.json` gains four `polkit.*` keys, not five, because the generated subset
  omits `polkit.authorizeRunning`, used only in `PolkitModel.js` with an identical English fallback; `SurfacePalette.js`
  has no `polkit` section, so, unlike DEC-013, the polkit roles always follow the theme without personal overrides;
  the qmllint baseline was regenerated in the VM with 30 justified entries for the agent beyond missing-module ones
  (no new category); the step's `check` passes in target context like `system/power`, with content integrity from
  tracked hashes; the `fprintd-*` and `uwsm` doubles are one `fingerprint-tool`; polkit 128 ships its stack as
  `/usr/lib/pam.d/polkit-1`, which the created `/etc/pam.d/polkit-1` overrides with the same includes.
- Not run: G4 (another compositor) and hyprlock fingerprint, as planned.
- Follow-up candidates: the T14s target notes still say the profile adds no `fprintd` (true of the profile, now
  delivered generically by `system/fingerprint`); `check-menu.sh` does not cover the reader-present row; the local
  Omarchy clone is at a later HEAD, so the optional upstream check of `menu-model.test.mjs` needs the `7075b61` pin;
  laboratory guest leftovers under `/tmp` on the VM and the T14s.
