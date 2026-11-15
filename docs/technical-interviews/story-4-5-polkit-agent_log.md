# Story 4.5 — Polkit agent: decision log

Technical interview for the second Story 4.5 plan. Primary input: the brainstorming session
`.sheaf/brainstorming/brainstorming-session-2026-11-11-2353.md` (Area 2 — Polkit agent), whose Decisions and
Boundary rows are maintainer decisions; its interview handoff items are treated as open questions here. Shipped
dependency behavior is taken from `.agents/plans/02-35-story-4-5-portals-file-manager-SUMMARY.md`.

## DEC-001
- **Question**: Does plan 02-36 cover only Area 2 (polkit agent), depending on 02-35, as 02-35 covered only Area 1?
- **Context/Nuances**: Portals DEC-001 cut Story 4.5 into one plan per area as each brainstorming area closes. Area 2
  decided B (hyprpolkitagent from extra, themed through a `hyprtoolkit.conf` derived from the MirrorOS theme) as
  prototype-gated, A (adapted Omarchy QML agent) only through an ADR if B fails G1 or G2, and C (temporary neutral
  agent) as a deferred decision. Fingerprint enablement and lid handling are out. Whether gate G2 (T14s fingerprint)
  belongs to this plan is asked separately.
- **User Response**: Yes.
- **Decision**: Plan 02-36 (`02-36-story-4-5-polkit-agent`) covers only Area 2 and depends on 02-35: the
  hyprpolkitagent package and packaged user unit in a new `desktop/polkit` capability, its theming for hyprtoolkit,
  the single-owner check, the aligned session-menu message, and the laboratory gates. Fingerprint enablement stays
  out.
- **Status**: Accepted

## DEC-002
- **Question**: Is gate G2 (fingerprint on the T14s with password fallback) part of this plan, and under which PAM
  state?
- **Context/Nuances**: G2 is one of the two gates whose failure escalates to A through an ADR; deferring it would
  leave B provisional. Fingerprint enablement in the product is out (target-laptop work), so G2 cannot rely on
  MirrorOS-managed PAM. The T14s runs Omarchy today with working fingerprint; its `/etc/pam.d/polkit-1` already has
  `pam_fprintd` behind the clamshell gate, and Omarchy's QML agent runs inside its shell (polkit accepts one
  registered agent per session). The reference VM has no fingerprint reader; a libfprint virtual device in the Arch
  package is unverified. Options: (a) supervised T14s session on its current Omarchy state; (b) VM with a virtual
  libfprint device; (c) defer G2 to the fingerprint work.
- **User Response**: (a).
- **Decision**: G2 is in this plan as a supervised T14s session on its current Omarchy state: Omarchy's shell polkit
  agent is temporarily disabled, hyprpolkitagent 0.2.0 is run by hand, and fingerprint success, password fallback
  and cancellation are exercised through `pkexec true`; the prior state is restored afterwards. It is evidence only
  and changes nothing in the product.
- **Status**: Accepted

## DEC-003
- **Question**: How is gate G1 (visual coherence with the shell and hyprlock) judged and evidenced?
- **Context/Nuances**: The brainstorm leaves G1 to maintainer judgment. Plan 02-35 kept ignored evidence under
  `evidence/portals/lab-02-35/` (checkpoint, bundles, `SHA256SUMS`). The reference VM runs at scale 1.25, which
  caused size/position findings in 02-35 (D3). hyprtoolkit hot-reloads its theme. The T14s G2 run uses Omarchy's
  theme, not MirrorOS's, so it cannot judge G1.
- **User Response**: Yes.
- **Decision**: G1 is judged by the maintainer in the reference VM, in a real MirrorOS session after configure,
  comparing the `pkexec true` dialog with the shell session menu, a notification and hyprlock, in the empty,
  wrong-password and authenticating states. Evidence is screenshots under `evidence/polkit/lab-02-36/` with
  `SHA256SUMS` and the maintainer's written verdict in the checkpoint. Theme values (colors, rounding, font, sizes)
  may be iterated within the plan before the verdict, without architectural change; a final "no" after iteration
  is a G1 failure, whose consequence is decided separately.
- **Status**: Accepted

## DEC-004
- **Question**: What does the plan do when a gate fails?
- **Context/Nuances**: The brainstorm allows A only through an ADR and only if B fails G1 or G2; G4 is informative;
  if gates are not ready in time the choice between waiting and a temporary neutral agent C is taken at that
  moment. AGENTS.md routes prototype-gated decisions through an ADR. Plan 02-35 evaluated candidates on
  `refs/mirroros-candidates/02-35-*` and committed to `main` only after selection.
- **User Response**: Yes.
- **Decision**: B is implemented and evaluated as a candidate on `refs/mirroros-candidates/02-36-*`, with nothing
  committed to `main` until the blocking gates pass. If G1 or G2 fails, the plan stops at a decision checkpoint: B
  is not committed, `docs/mvp-scope.md` stays open, and the maintainer chooses between an ADR for A (amending ADR
  0012/0025) in a later plan and an approved temporary agent C in a separate plan; this plan neither drafts that ADR
  nor implements C, and only records evidence and findings. G3 (`pkexec true`, session menu, Strata `admin://`)
  failures are defects fixed within the plan, unless intrinsic to the agent, in which case they are blocking and
  reach the same checkpoint. G4 is recorded and never blocks.
- **Status**: Accepted

## DEC-005
- **Question**: Who owns the hyprtoolkit theming and how is `hyprtoolkit.conf` produced (brainstorm #81, #83)?
- **Context/Nuances**: Per-application palettes are static theme files today: `visual/theme/default/hyprlock.conf`
  holds variables only and the managed lock config sources it through
  `~/.local/state/mirroros/current/theme/hyprlock.conf`; there is no runtime generator. `~/.config/hypr/
  hyprtoolkit.conf` is hyprlang (supports `source`) with keys `background`, `base`, `alternate_base`, `text`,
  `bright_text`, `accent`, `accent_secondary`, font sizes, `font_family`, `font_family_monospace`, `icon_theme`,
  `rounding_large`, `rounding_small` (hyprland-wiki @ `5e1782bd`). It is read by every hyprtoolkit application
  (hyprlauncher, hyprpwcenter…), not only the agent. `visual/gtk3` is the precedent for toolkit-wide theming.
- **User Response**: Yes.
- **Decision**: Follow the hyprlock pattern with no generator. `visual/theme/default/hyprtoolkit.conf` is a static
  per-theme file mapping `colors.toml` to hyprtoolkit color keys, checked against `colors.toml` by a palette test.
  `~/.config/hypr/hyprtoolkit.conf` is a managed `cfg_user_file` that sources the current theme's file and sets
  non-color values (font, rounding, sizes aligned with the shell); a user-owned copy is preserved. `desktop/polkit`
  owns that user file while it is the only consumer, with its `sources.md` stating that every hyprtoolkit
  application reads it; a second consumer moves it to a `visual/hyprtoolkit` capability. Theme changes reach the
  agent through the `current` link at its next start, or by hot reload if hyprtoolkit follows sourced files, which
  the laboratory records without blocking. Visual refinement stays in Story 4.8.
- **Status**: Accepted

## DEC-006
- **Question**: How is the single-owner rule for the authentication agent expressed (brainstorm #64, #65)?
- **Context/Nuances**: polkit agents register per session through `RegisterAuthenticationAgent`; they own no D-Bus
  name, so `cfg_dbus_service_owner_unique` does not apply and a second agent is detected only by what starts it:
  XDG autostart (`/etc/xdg/autostart`, `~/.config/autostart`), enabled user units, or the personal Hyprland
  `autostart.lua`. Alternative agents (polkit-gnome, lxpolkit, polkit-kde, mate-polkit) mostly ship autostart
  entries. Whether uwsm runs `xdg-desktop-autostart.target` in MirrorOS sessions is unverified; the gnome-keyring
  autostart entries from 02-35 are a witness in the VM.
- **User Response**: Yes.
- **Decision**: Configure checks declared state and fails with exit 4, naming the file, its package and the next
  action, when an active autostart entry (system or user, not `Hidden=true`) has an `Exec` naming a known polkit
  agent from a list kept in `sources.md`, or when another polkit agent user unit is enabled; it never uninstalls or
  hides anything. A read-only `polkit-check`, in the style of `portal-check` (`ok:`/`notice:`/`FAIL:`, exit 0/1),
  checks after login that `hyprpolkitagent.service` is active and no other known agent process runs for the user;
  an agent started from personal `autostart.lua` is a session `FAIL` only, since configure does not parse personal
  Lua. The laboratory records whether uwsm runs XDG autostart (#65); the autostart check stays as defense either
  way and is documented accordingly.
- **Status**: Accepted

## DEC-007
- **Question**: How do the shell's session-menu rows behave and read once an agent exists (brainstorm #63)?
- **Context/Nuances**: `SessionActions.qml` marks a row unavailable on a logind `challenge` answer with
  "<Label> needs authorization (no polkit agent)." and `run()` refuses unavailable rows; `check-menu.sh` pins that
  text. With an agent, `challenge` means the action will prompt: the fixed `systemctl` argv triggers the agent's
  dialog and the shell never handles credentials (ADR 0012). The lock row already checks a concrete provider
  (`systemctl --user is-active hypridle.service`) and gives an actionable reason.
- **User Response**: Yes.
- **Decision**: `challenge` becomes agent-conditional. With `hyprpolkitagent.service` active (`systemctl --user
  is-active --quiet`), the row is available with the hint "<Label> asks for authorization." and runs the same fixed
  argv; with it inactive, the row stays unavailable with "<Label> needs authorization; start the polkit agent."
  The `yes`, `no`/`na` and error answers are unchanged. `check-menu.sh` (and any matching Node model test) covers
  both `challenge` cases. A cancelled or denied prompt is fail-closed: the shell neither retries nor shows its own
  message; G3 verifies the menu does not hang.
- **Status**: Accepted

## DEC-008
- **Question**: What does gate G3 contain, and how is brainstorm edge case #69 (prompt open while hyprlock
  activates) handled?
- **Context/Nuances**: `gvfs` is already declared by `desktop/files` (Strata dependency) and carries the `admin`
  backend (`gvfsd-admin`, polkit action `org.gtk.vfs.file-operations`); Strata's acceptance of `admin://` locations
  is unverified. logind answers `challenge` (auth_admin) for reboot or poweroff when other sessions are open.
- **User Response**: Yes.
- **Decision**: G3 runs in the reference VM after configure, in a new session: (1) `pkexec true` with correct
  password (exit 0), wrong password then retry, and cancel (exit 126), reusing the G1 states; (2) a real logind
  `challenge` for a session-menu action, provoked by a second open session (for example a TTY login), checking the
  dialog, cancel without a hung menu, and confirmation running the action; (3) Strata `admin:///etc` showing the
  dialog and allowing reading, where missing Strata support is a non-blocking Strata finding substituted by
  `gio mount admin:///`; (4) `polkit-check` exit 0, and the configure postcondition returning exit 4 against a
  laboratory competing autostart entry. Edge case #69 is recorded informatively (whether the dialog stays under the
  lock and is usable after unlock) and never blocks; any issue goes to the brainstorm's closing cross-cutting pass.
- **Status**: Accepted

## DEC-009
- **Question**: How is gate G4 (run under another wlroots compositor) executed?
- **Context/Nuances**: G4 is informative; it supports the Story 4.5 "provider replaced" criterion by showing the
  agent does not depend on Hyprland. Static analysis (#85) found only `xdg-shell` and `wlr-layer-shell`. Running it
  live needs a temporary compositor on the reference VM (guest drift, as with Chromium in 02-35). `cage` shows a
  single application, so a separate agent surface may not be representative.
- **User Response**: Yes.
- **Decision**: G4 runs in the reference VM with `sway` installed temporarily: a Sway session from a TTY, the agent
  started by hand, and `pkexec true` exercised; afterwards `sudo pacman -Rns sway` and the cleanup is recorded. The
  outcome is informative and never blocks.
- **Status**: Accepted

## DEC-010
- **Question**: What is the shape of the `desktop/polkit` step and its position in `CFG_STEPS`?
- **Context/Nuances**: The packaged unit at hyprpolkitagent v0.2.0 (`assets/hyprpolkitagent-service.in`) has
  `PartOf=`/`After=graphical-session.target`, `ConditionEnvironment=WAYLAND_DISPLAY`, `Slice=session.slice`,
  `TimeoutStopSec=5sec`, `Restart=on-failure`, `WantedBy=graphical-session.target`, and runs the agent from
  libexec. `desktop/lock` is the precedent: packages, `cfg_user_file` native config, `cfg_system_file` helper,
  `cfg_user_unit_enable … graphical-session.target`, nothing started.
- **User Response**: Yes.
- **Decision**: `capabilities/desktop/polkit/` holds `apply`, `packages` (`hyprpolkitagent extra`), the managed
  `hyprtoolkit.conf`, `polkit-check`, an `agents` list of known polkit agents for the single-owner check, and
  `sources.md`. `apply` follows `desktop/lock`: `cfg_packages_ensure`; `cfg_user_file` for
  `~/.config/hypr/hyprtoolkit.conf`; `cfg_system_file` for `/usr/share/mirroros/polkit/polkit-check`;
  `cfg_user_unit_enable hyprpolkitagent.service /usr/lib/systemd/user/hyprpolkitagent.service
  graphical-session.target`; the single-owner postcondition; matching `cfg_require` lines. Nothing is started or
  restarted; the next login picks it up. No unit drop-in; laboratory issues (for example at shutdown) are findings.
  The step goes right after `desktop/lock` in `CFG_STEPS`, with `visual/theme` as prerequisite. The shell's
  `hyprpolkitagent.service` check (DEC-007) is a provider coupling documented in `sources.md`, as with hypridle.
- **Status**: Accepted

## DEC-011
- **Question**: Which records, procedure and provenance does the plan update?
- **Context/Nuances**: Plan 02-35 added a dedicated procedure (`docs/procedures/portals-and-files.md`), updated
  `docs/mvp-scope.md` rows, appended execution findings to its interview artifacts and an implementation note to
  the brainstorm. B applies accepted decisions (ADR 0012/0025: authentication is never project-owned QML).
- **User Response**: Yes.
- **Decision**: Applied only when G1 and G2 pass (otherwise DEC-004's checkpoint). `docs/mvp-scope.md`: the
  "Polkit authentication agent" row names hyprpolkitagent (Story 4.5, plan 02-36) with notes on theming from the
  MirrorOS palette, single owner, `polkit-check` and fingerprint out of scope. New `docs/procedures/polkit-agent.md`:
  ownership and `polkit-check`, conflicting agents and their remedy, keyring unlock at login vs polkit prompt (#70),
  theming and reload, gate evidence, and the repeatable T14s G2 procedure. `capabilities/desktop/polkit/sources.md`:
  provenance of the v0.2.0 unit and hyprtoolkit keys (wiki @ `5e1782bd`), the grouped Hypr ecosystem risk (#86),
  the Arch package's stale Qt dependencies (#87, non-blocking), and the agent-list criteria.
  `visual/theme/sources.md`: a `hyprtoolkit.conf` row. Execution findings are appended to these interview artifacts
  and an Area 2 implementation note to the brainstorm. No ADR.
- **Status**: Accepted

## DEC-012
- **Question**: Which tests are added and how is the work committed?
- **Context/Nuances**: Plan 02-35 split commits with a temporary `GIT_INDEX_FILE`, ran the full suites on each
  exported tree, used candidate refs deleted after confirmation, and did not push.
- **User Response**: Yes.
- **Decision**: Tests: `tests/capabilities/desktop/polkit/configure.contract.bats` for `apply` (packages, user and
  system files, unit, exit 4 with a competing autostart entry including `Hidden=true` and user-entry cases);
  `polkit-check.bats` with `systemctl` and `pgrep` doubles; a palette test for
  `visual/theme/default/hyprtoolkit.conf`; `check-menu.sh` extended with both `challenge` cases. Commits follow the
  02-35 pattern, in order: `feat(theme)` publish `hyprtoolkit.conf`; `feat(polkit)` `desktop/polkit`, step,
  `polkit-check` and single owner; `feat(shell)` agent-conditional `challenge`; `docs(polkit)` records, procedure
  and interview. The candidate lives on `refs/mirroros-candidates/02-36-*`, deleted after confirmation; no push.
- **Status**: Accepted

## DEC-013
- **Question**: Should verification run the full suites, or only the tests linked to what each change affects?
- **Context/Nuances**: The materialized plan ran `node --test tests/capabilities/` and `bats -r tests/capabilities`
  in Tasks 2, 3 and 8 and in `<verification>`, following DEC-012 and the 02-35 pattern. Mapping the changes to their
  consumers: the theme file affects `visual/theme/{palette.test.mjs,install-theme.test.mjs,configure.contract.bats}`
  (the last publishes the real default tree and needs a `cmp` line); `desktop/polkit/*` its two new suites; the step
  insertion `target.contract.bats` (real step list, position and total) and `system/hardware.contract.bats` (sources
  the real list); the `cfg_exec pacman -Qqo` consumer `mechanism.contract.bats`; `SessionActions.qml` `check-menu.sh`
  (VM), `desktop/shell/no-omarchy-coupling.test.mjs` (walks the shell sources) and `qmllint-check.mjs`; docs no test.
- **User Response**: Yes (no full-suite run, not even an optional final one).
- **Decision**: Amends DEC-012. Each task verifies only with the tests linked to what it changes, per the map above;
  in Task 8 each committed tree runs the union of the tests linked to that commit's files. `<verification>` carries
  the change→test map for traceability. No full-suite run is part of the plan; an unseen coupling outside the map is
  an accepted risk.
- **Status**: Accepted

## DEC-014
- **Question**: Is there any full-suite run at all, and when?
- **Context/Nuances**: DEC-013 removed full-suite runs, accepting that a coupling outside the change-to-test map
  would go unnoticed. The maintainer wants a full run only at the end, and only when really needed after
  re-analysing what was actually delivered.
- **User Response**: Yes.
- **Decision**: Amends DEC-013. After Task 8 (or at closing under option-b), a final impact analysis reviews the
  delivered diff (`git diff --stat` and touched files) against the change-to-test map: files outside the map,
  shared helpers touched (`capabilities/lib/*`, `tests/**/support.bash`), laboratory-driven changes beyond the plan,
  and tests reading affected trees generically (`rg` of the changed paths in `tests/`). No finding → no full-suite
  run, with the justification recorded. A finding → an extended linked subset is proposed first; full suites
  (`node --test tests/capabilities/`, `bats -r tests/capabilities`) are proposed only if the impact cannot be
  bounded, and always run only with maintainer approval. Any run is single, on the final tree, not per commit; a
  failure means fixing and re-splitting the affected commits.
- **Status**: Accepted

## Execution findings — 2026-11-13 (plan 02-36)

These findings supplement, and do not rewrite, DEC-001 to DEC-014. Records (ignored):
`evidence/polkit/lab-02-36/checkpoint.md` (reference VM) and `evidence/polkit/lab-02-36/t14s/g2.md` (T14s).

- Outcome: **option B stops at the gate checkpoint** (DEC-004). G1 failed by maintainer verdict; nothing reached
  `main`, the polkit row in `docs/mvp-scope.md` stays open and no procedure was written. The choice between an ADR
  for the adapted QML agent (A) and a temporary neutral agent (C) is left to a later plan. Candidate
  `refs/mirroros-candidates/02-36-a` (`e59561e`) holds Tasks 1–3 and is kept until the maintainer decides.
- G1 (DEC-003) failed in the reference VM. Judged at the maintainer's runtime scale 1.6 (1.25 also tried), not only
  at the planned 1.25. The palette reached the dialog through `source =` (AC-2 colors), but no theme values gave a
  coherent dialog: text is ellipsized with any JetBrainsMono variant regardless of width and scale, and not with Noto
  Sans (F5); the eye glyph is correct only with `JetBrainsMono Nerd Font Propo` (F4); the `*` password mask (F1), the
  missing in-progress state (F2), a fixed red error kept while retyping (F3), a fixed cramped layout (F6), a
  trembling button row at some scales with ~23 % CPU while a dialog is open (F7) and verbose `DEBUG` journal output
  (F9) are fixed upstream behavior. Font changes do not re-render an open dialog. The agent's own undocumented
  `~/.config/hyprpolkitagent/hyprpolkitagent.conf` widths made truncation worse and were rejected.
- G2 (DEC-002) deviated in place: the T14s now has separate Omarchy and MirrorOS partitions, and the maintainer chose
  not to touch Omarchy. G2 ran on the MirrorOS partition with a lab-only fingerprint setup approved as a boundary
  override (`fprintd`, enrollment, a temporary `/etc/pam.d/polkit-1` with `auth sufficient pam_fprintd.so` before the
  vendor `system-auth` include), all reverted afterwards. Fingerprint success and password fallback returned 0;
  hyprpolkitagent handles stock `pam_fprintd` cues on real hardware (Synaptics `06cb:00bd`). The agent was then
  removed from the laptop by maintainer decision.
- G3 (DEC-008) was partial: a correct password returned 0; cancel (button or Escape) returned 127 instead of 126 in
  the VM and on the T14s, because the agent replies to a user cancel as a completed, failed authentication instead
  of `Error.Cancelled` (F8, hyprpolkitagent `src/core/PolkitListener.cpp:602-613`). It fails closed (polkitd
  "FAILED to authenticate", nothing granted) but is intrinsic to the agent. Restarting the agent with a request
  pending ended the request without granting it. The session-menu `challenge`, Strata `admin:///etc`, the planted
  competing autostart entry, `check-menu.sh` and the qmllint baseline were not run after G1 failed; G4 (Sway) and the
  #65 and #69 observations were not run either.
- Delivered behavior confirmed live, reusable by A or C: configure installs and enables the packaged unit without
  starting it and a rerun is unchanged (AC-1, VM and T14s); after a new login `polkit-check` exits 0 (AC-4 positive
  path, VM and T14s). The single-owner postcondition and the agent-conditional session-menu reasons are verified
  only by their contract suites and fixtures.
- Implementation deviations approved during the plan (Task 2): the single-owner logic is a shared helper
  (`cfg_session_agent_unique` in `capabilities/lib/files.sh`), because the mechanism contract forbids `pacman` and
  `cfg_exec` in `apply`; the agent list is also published for `polkit-check`; `polkit-check` matches agent processes
  with `pgrep -f` and an anchored pattern, because `comm` truncates to 15 characters.
- Configure on the T14s failed at `desktop/files` while `nautilus` was installed (02-35 single-owner rule, as
  designed); the maintainer removed it with `pacman -Rns`. Configure never removes packages, which the maintainer
  had assumed it did.
- Considerations for the A-or-C plan: G2 shows that fingerprint depends on PAM, not on a specific agent, so any agent
  driving `polkit-agent-helper-1` should work once fingerprint is enabled; F8 and the G1 defects belong to
  hyprpolkitagent 0.2.0 and hyprtoolkit 0.6.0 and may change upstream; brainstorm #89 (GTK3 agents inherit the
  MirrorOS GTK theme) makes C a peer of B on coherence. The reference VM still has hyprpolkitagent installed and
  its unit enabled from candidate a.
