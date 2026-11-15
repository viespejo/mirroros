# Story 4.5 — Polkit QML agent (option A): consolidated plan

## Scope

Plan 02-37 resolves the open polkit row of `docs/mvp-scope.md` with option A: an authentication agent whose UI is
QML inside the MirrorOS-owned Quickshell shell, adapted from Omarchy's agent and driven by the native
`Quickshell.Services.Polkit` agent. Option B failed G1 in plan 02-36, which meets the brainstorm's escalation
condition; option C (a packaged GTK3 agent) is not evaluated [DEC-001].

## Governance

Because ADR 0012 and 0025 state that authentication is never project-owned QML, and `docs/mvp-scope.md` names that
as its one frozen principle, the work requires a new ADR amending both ADRs, the scope principle and the QML clause
of `docs/architecture.md`. The ADR is deliberately narrow: QML presents the dialog only, PAM runs through
`polkit-agent-helper-1`, nothing is stored or logged, and hyprlock is unchanged [DEC-001]. The ADR is drafted in this
plan as Proposed and accepted only after the laboratory gates pass [DEC-002].

The widened scope adds a second exception, MirrorOS-owned code inside PAM stacks, which runs against ADR 0012's rule
that authentication surfaces are not project-owned code and the architecture's statement that PAM owns user
authentication. Both exceptions go into one ADR,
`docs/adr/0030-shell-hosted-polkit-agent-and-fingerprint.md`, which partially amends ADR 0012 and 0025. It bounds
the agent (no stored or logged flow data, no `bash -c`, only the lid probe with fixed argv, not exposed to other
components) and the fingerprint stack (unconditional `fprintd`, gated `polkit-1` and `sudo`, `lid-closed` as the only
owned code in PAM, read-only, with a bounded logind timeout and a literal root-owned path, and enrollment that never
writes `/etc`). It leaves hyprlock, SDDM and any first-run framework out, records the shell-uptime risk and the
password fall-through when the probe fails, and reopens on failed gates or hyprlock fingerprint. ADR 0023's context
line that MirrorOS adds no `fprintd` is handled by an index note, not a supersession [DEC-012].

## Risks accepted

Privilege prompts depend on the shell being up; if the shell is down there is no registered agent and requests fail
closed [DEC-001].

## Reuse from plan 02-36

The single-owner check (`cfg_session_agent_unique`), `polkit-check`, the agent-conditional `challenge` in
`SessionActions.qml` and the T14s G2 fingerprint procedure are reused, generalized from `hyprpolkitagent.service` to
the shell-hosted agent [DEC-001]. The hyprtoolkit palette loses its consumer [TODO-002], and the uncommitted working
tree and candidate ref need a preservation and cleanup decision [TODO-003].

## Delivery workflow

The ADR is drafted inside this plan as `docs/adr/0030-shell-hosted-polkit-agent-and-fingerprint.md` with status Proposed, alongside
draft amendments to `docs/mvp-scope.md`, `docs/architecture.md` and the ADR index, and is reviewed at a blocking
checkpoint before any code is written. The agent is then built as a candidate on
`refs/mirroros-candidates/02-37-*` and exercised by laboratory gates G1 (visual coherence), G2 (T14s fingerprint
with password fallback) and G3 (`pkexec`, cancel, session menu, `admin://`). Only if the gates pass does the ADR
become Accepted, with ADR, amendments and code committed together; otherwise the ADR stays Proposed or is Rejected
and nothing reaches `main`, mirroring plan 02-36 [DEC-002].

## Placement

The agent lives in `capabilities/desktop/shell/polkit/` as `PolkitAgent.qml` and `PolkitModel.js`, adapted from
Omarchy revision `7075b61` and recorded per file in the shell's `UPSTREAM.md`; Omarchy's plugin manifest is dropped
because the MirrorOS shell has no plugin system. `shell.qml` instantiates it directly as an isolated sibling, never
publishing it to other components, so the session menu learns about the agent only through an external signal still
to be decided. The agent is part of the `desktop/shell` capability rather than a separate `desktop/polkit`
capability with its own package or unit; reuse of the 02-36 skeleton is still open [DEC-003].

## Agent behavior

The adapted agent keeps Omarchy's read-only detection of `pam_fprintd` in `/etc/pam.d/polkit-1`, its cancel path
through `flow.cancelAuthenticationRequest()` (which G3 must prove returns 126, the defect that sank option B), and its
timers, shake, error flash and "checking" state, which cover B's missing feedback. Its D-Bus object path becomes
`/org/mirroros/PolkitAgent`, and the only log line kept is the warning that the agent failed to register because
another one may be running; no flow data is ever logged [DEC-004].

## Fingerprint

Fingerprint enablement is part of this plan rather than deferred target-laptop work. Omarchy's
`omarchy-hw-laptop-closed` is adapted as a MirrorOS-owned lid probe serving both a PAM clamshell gate placed before
`pam_fprintd` and the agent's `laptopClosed` hint, so a closed lid goes straight to the password. Because `pam_exec`
runs it as root, the probe is authentication code in its own right. The fingerprint reader moves out of the pending
target-laptop section of `docs/mvp-scope.md`. The 02-36 G2 evidence covers only `polkit-1` without a gate, so the
remaining stacks and the closed lid are exercised here [DEC-004].

Fingerprint reaches the `polkit-1` and `sudo` stacks, each with the clamshell gate ahead of
`sufficient pam_fprintd.so`. `/etc/pam.d/polkit-1` becomes a managed file (gate, `pam_fprintd`, then
`include system-auth`), since the vendor ships only `/usr/lib/pam.d/polkit-1`. Both stacks are complete files
delivered by `cfg_tracked_file`: the package-owned `/etc/pam.d/sudo` (a pacman backup file) is replaced only when it
still holds the exact packaged content, identified by its recorded SHA256, while a locally edited file stops
configure with exit 4 and is never overwritten; `sources.md` records the source `sudo` version and the `.pacnew`
review after upstream changes [DEC-010]. hyprlock fingerprint is deferred and recorded as pending in
`docs/mvp-scope.md`, because it touches `desktop/lock` and ADR 0021 without evidence and the lock is the session
boundary; SDDM is excluded because fingerprint login does not unlock the keyring [DEC-005].

Enablement is unconditional, following `system/bluetooth`: configure always installs Arch's `fprintd` and
`libfprint` (about 3.5 MiB, the stock build that passed G2) and manages the gated PAM entries, so no new
hardware-conditioned package pattern or target-context `/sys` exception is introduced. Without enrolled prints
`pam_fprintd` steps aside and the password is asked as today, which the laboratory must show adds no perceptible
delay. Omarchy's on-demand experience is kept where it does not create a second owner of system files: a one-time
first-session invitation and a "Fingerprint" session-menu row appear only when a sysfs reader probe, adapted from
`omarchy-hw-fingerprint`, finds a reader, and enrollment itself never changes system files [DEC-006].

Enrollment is an owned `fingerprint-setup` command at `/usr/share/mirroros/hardware/fingerprint-setup`, adapted
from the enroll and verify part of Omarchy's setup script and launched in foot by the shell, as `vpn-connect` is.
It checks the reader, enrolls and verifies the current user's print, and on later runs offers re-enrollment or
deletion; it never installs packages, edits PAM, touches services or calls `sudo`. fprintd asks polkit to authorize
enrollment, so the new agent's dialog appears in the flow and doubles as a live G3 case. Removing fingerprint means
deleting prints; configure keeps packages and PAM, which then fall through to the password [DEC-007].

The session menu gains Omarchy's `setup` › `setup.security` › `setup.security.fingerprint` rows, with the same ids,
labels and icons as the pinned revision, a new closed action `fingerprint:setup` that `Menu.qml` turns into a fixed
foot argv, and a `when` guard on the reader probe alone, so the row stays available for re-enrollment and deletion.
The invitation follows Omarchy's semantics without its generic first-run framework: a oneshot user unit,
`mirroros-fingerprint-invite.service` in `graphical-session.target`, invites only when a reader exists, the user has
no prints and the invitation marker is absent. It waits, with a bound, for the shell's notification server, writes
the marker just before sending so the invitation happens once, and opens `fingerprint-setup` from the notification's
action. Being a short-lived unit outside the shell, it is neither a welcome application nor a resident shell service,
and it is independent of the Hyprland provider's autostart [DEC-008]. Placement is settled under Capability layout
[DEC-009]; ADR coverage is settled under Governance [DEC-012].

## Capability layout

Fingerprint lives in a new `system/fingerprint` step, placed after `system/power` and before `system/network` so it
precedes the shell that references its commands, and shaped like `system/bluetooth`. It installs Arch's `fprintd` and
`libfprint`, owns the managed `/etc/pam.d/polkit-1`, and delivers three adapted Omarchy scripts to
`/usr/share/mirroros/hardware/`: `lid-closed` (ACPI with a bounded logind fallback, called by `pam_exec` by literal
path and by the agent with fixed argv), `fingerprint-reader` (USB sysfs only, with a test path override) and
`fingerprint-setup`, plus the `fingerprint-invite` script and its user unit, a read-only `check`, `sources.md` and
`OMARCHY-LICENSE`. The agent in `desktop/shell` only consumes the lid probe and reads `polkit-1`; the 02-36
`desktop/polkit` skeleton hosts nothing fingerprint-related [DEC-009]. Reuse of the single-owner check and
`polkit-check` is settled under Single owner and verification [DEC-011].

## Single owner and verification

The generic single-owner postcondition from plan 02-36 returns to `capabilities/lib/files.sh` and is required by
`desktop/shell`, with an agent list that now names `hyprpolkitagent` alongside the six packaged agents, so any
competing autostart entry or enabled user unit stops configure with exit 4 and a next action, never remediated. A
generalized `polkit-check` ships with the shell and confirms that `mirroros-shell.service` runs and that no listed
agent does; because polkit offers no way to list registered agents, actual registration is evidenced by the attended
G3 prompts. The session menu no longer probes an agent unit: the agent lives in the same process, so `challenge` rows
are always offered with the "asks for authorization" hint, and `check-menu.sh` follows. The rest of the 02-36
`desktop/polkit` capability, including its step, package list and hyprtoolkit file, is not reused [DEC-011].

## Visual adaptation and G1

The dialog takes its colors from a new `polkit` section in the shell's `Commons/Color.qml`, carrying Omarchy's seven
roles and derivations, so it follows the selected theme like the menu and notifications without any new theme file,
and its five English strings join `Commons/i18n-en.json`; the invitation's text stays inside `fingerprint-invite`.
Omarchy's compact card, justification pill, square fingerprint mode, `•` mask, shake and error flash are kept as
they are. G1 is the maintainer's verdict in the reference VM against the session menu, a notification and hyprlock,
in the empty, checking and error states (fingerprint state on the T14s), at scales 1.6 and 1.25. Style values may be
iterated inside the plan, fine refinement belongs to Story 4.8, and a final rejection after iteration is a gate
failure handled as in plan 02-36 [DEC-013].

## Starting point and 02-36 residue

Work starts by preserving the whole 02-36 working tree as `refs/mirroros-candidates/02-36-b` through a temporary
index, then returning the tree to `main`, keeping only the four interview artifacts untracked. Reused pieces come
back selectively from that ref: the single-owner helpers, `polkit-check` and its agent list (now under
`desktop/shell/polkit/`), the simplified `challenge` handling and their tests, with the step-list tests revised for
`system/fingerprint`, which keeps the total at 24 steps. The hyprtoolkit palette, its test and its theme provenance
section stay only in the ref. The 02-36 interview artifacts reach `main` with this plan's documentation commit, and
both candidate refs survive until 02-37 is adopted, or indefinitely if it stops at the gate [DEC-014].

## Laboratory gates

The reference VM covers G1 and G3. Its leftover hyprpolkitagent unit should make the first candidate configure stop
with exit 4, exercising the single-owner check live before the maintainer removes it and reruns twice. A new login
then runs `polkit-check`, `pkexec true` with correct, wrong-then-correct and cancelled attempts (cancel must return
126), `sudo true` and `pkexec` without a reader to show no added delay, a session-menu `challenge` where one occurs,
Strata `admin:///etc`, a shell restart with a pending request (fail-closed), the #69 hyprlock overlap as a recorded
observation, and the visual verdict. The T14s MirrorOS partition covers G2 with the product stack itself: replaced
`sudo` and new `polkit-1` with no delay before enrollment, a single invitation that leads to `fingerprint-setup`
(whose enrollment raises the agent's own dialog), the menu row, fingerprint success, fallback to the password and
cancel in both stacks, the closed lid with an external monitor going straight to the password, and deletion
returning to password-only. G4 and hyprlock are not run. Evidence lives under `evidence/polkit/lab-02-37/` with
checksums and the maintainer's written verdict. G1, cancel 126, fingerprint with fallback in both stacks, the closed
lid and the absence of delay are blocking and lead to the DEC-002 checkpoint; anything else is fixed in the plan
[DEC-015].

## Tests and verification

Each change carries its own tests. The fingerprint step gets a contract suite proving the four `sudo` delivery cases,
the created `polkit-1` and that the gate sits immediately before `pam_fprintd` with the literal probe path, and its
four scripts get a hardware suite driven by sysfs and ACPI fixtures and doubles for `busctl`, `fprintd-*` and
`notify-send`. The step insertion is checked by the target and hardware contracts, the restored helpers by the
mechanism contract, and the agent's pure logic by a new `polkit-model.test.mjs`, alongside the shell's palette, i18n,
coupling, provenance and qmllint checks. The shell's configure contract absorbs the 02-36 exit-4 cases and
`polkit-check.bats` moves next to it; the menu changes are covered by `menu-model.test.mjs` and, in the VM,
`check-menu.sh`. New scripts pass `shellcheck`. Verification follows plan 02-36: linked tests per task, a final
impact analysis, and full suites only with maintainer approval. Because `lib/files.sh` is shared, the final run
already includes every configure contract that sources it [DEC-016].

## Documentation and commits

Documentation moves with the change it governs: ADR 0030 and its index entry; `docs/mvp-scope.md`, whose frozen
principle now names the ADR 0030 exception, whose polkit row is resolved, which gains a fingerprint row, and whose
pending target-laptop list loses the fingerprint reader while hyprlock fingerprint stays pending; the QML and
Authentication & Security statements of `docs/architecture.md`; the step list in `capabilities/README.md`; the
provenance files of both capabilities and `docs/attribution.md`; the configure and hardware procedures; and both
interviews. The work is prepared as four commits on a `02-37` candidate ref and reaches `main` only at adoption: the
ADR with its normative amendments first, so every later commit is governed, then fingerprint, then the shell agent,
then the remaining documentation, each exported tree running its linked tests and nothing pushed. A stop at the gate
leaves `main` untouched and the ADR Proposed on the ref [DEC-017].

## Execution findings

Plan 02-37 adopted option A on 2026-11-15: every blocking gate passed on candidate `a7068c6` in the reference VM and
on the T14s, and ADR 0030 is Accepted. The laboratory found and fixed four defects within the plan: packaged `sudo`
facts taken from the development host (the managed `sudo` keeps the four lines of `sudo 1.9.17.p2-6`, not three), PAM
supplementary messages missing from the dialog, an invitation that expired unseen, and a fingerprint-mode flash
without prints. A reader held for up to 30 seconds after a cancelled prompt is an accepted, documented limitation.
Deviations, observations and follow-ups are recorded in the
[decision log](story-4-5-polkit-qml-agent_log.md#execution-findings--2026-11-15-plan-02-37).
