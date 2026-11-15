# Story 4.5 — Polkit agent: consolidated plan

## Scope and source

Story 4.5 continues one plan per area; this interview covers the second area, the polkit authentication agent, as
plan 02-36, which depends on the shipped portals and file manager plan 02-35. The area's in/out boundary comes from
`.sheaf/brainstorming/brainstorming-session-2026-11-11-2353.md` (Area 2), whose decided rows are taken as given and
whose interview handoff items are resolved below [DEC-001].

The plan delivers hyprpolkitagent from the official repositories with its packaged user unit in a new
`desktop/polkit` capability, analogous to `desktop/lock`, together with its hyprtoolkit theming, a single-owner
check for the authentication agent, a session-menu message aligned with a present agent, and the laboratory gates
that decide whether the prototype-gated choice holds. Fingerprint enablement (fprintd, enrollment, PAM changes, the
clamshell gate) remains outside the plan [DEC-001].

## Gates

Gate G2 — fingerprint on the T14s with password fallback — is evaluated inside this plan rather than deferred, so
that the escalation condition for the QML agent is settled on real hardware. It runs as a supervised session on the
laptop's current Omarchy installation, whose `polkit-1` PAM stack already includes `pam_fprintd` behind the
clamshell gate: Omarchy's shell polkit agent is disabled for the session, hyprpolkitagent 0.2.0 is started by hand,
and `pkexec true` exercises fingerprint success, password fallback and cancellation before the laptop's prior state
is restored. The run is evidence only; it changes no MirrorOS product file and does not enable fingerprint in
MirrorOS, which remains target-laptop work [DEC-002].

Gate G1 — visual coherence — is judged by the maintainer in the reference VM, in a real MirrorOS session after
configure, because the T14s run carries Omarchy's theme. The `pkexec true` dialog is compared with the shell's
session menu, a notification and hyprlock in its empty, wrong-password and authenticating states, at the VM's 1.25
scale. Theme values may be iterated within the plan, using hyprtoolkit's hot reload, before the verdict is given;
no architectural change is allowed in that loop, and a final "no" counts as a G1 failure. Screenshots and the
written verdict are kept as ignored evidence under `evidence/polkit/lab-02-36/` with `SHA256SUMS` [DEC-003].

Gate G3 — functional prompts — runs in the reference VM after configure, in a new session. `pkexec true` is
exercised with a correct password, a wrong password followed by a retry, and a cancellation (exit 126). A real
logind `challenge` for a session-menu action is provoked by keeping a second session open, such as a TTY login,
and the dialog, a cancellation that leaves the menu responsive, and a confirmation that runs the action are
checked. Strata opens `admin:///etc` through gvfs's admin backend, already present as a Strata dependency; if
Strata does not accept `admin://`, that is recorded as a non-blocking Strata finding and `gio mount admin:///`
substitutes for it. `polkit-check` exits 0, and the configure postcondition exits 4 against a competing autostart
entry planted in the laboratory. The brainstorm's edge case of a prompt open while hyprlock activates is observed
and recorded without blocking, and any issue goes to the closing cross-cutting pass [DEC-008].

Gate G4 — another wlroots compositor — gives live evidence for the story's provider-replacement criterion
beyond the static finding that the agent needs only `xdg-shell` and `wlr-layer-shell`. `sway` is installed
temporarily on the reference VM, a Sway session is started from a TTY, the agent is launched by hand and
`pkexec true` is exercised; `sway` is then removed with `pacman -Rns` and the cleanup is recorded [DEC-009].

Gates G1 and G2 are blocking, G3 is functional and G4 is informative. The hyprpolkitagent delivery is built and
evaluated as a candidate on `refs/mirroros-candidates/02-36-*`, and nothing reaches `main` until the blocking gates
pass. A G1 or G2 failure stops the plan at a decision checkpoint: B is not committed, the polkit row in
`docs/mvp-scope.md` stays open, and the maintainer chooses between an ADR for the adapted QML agent (amending ADR
0012/0025) and a temporary neutral agent, each in a later plan; this plan records only the evidence and findings. A
G3 failure is a defect to fix within the plan unless it is intrinsic to the agent, in which case it reaches the
same checkpoint. G4, a run under another wlroots compositor, is recorded and never blocks [DEC-004].

## Theming

The agent follows the MirrorOS theme the same way hyprlock does, without a generator. The theme gains a static
`hyprtoolkit.conf` holding only hyprtoolkit color keys mapped from `colors.toml`, checked by a palette test, and
the managed `~/.config/hypr/hyprtoolkit.conf` sources it through `~/.local/state/mirroros/current/theme/` while
setting font, rounding and sizes aligned with the shell; a user-owned copy is preserved. Because every hyprtoolkit
application reads that file, `desktop/polkit` owns it only while it is the sole consumer, as its `sources.md`
states, and a second consumer moves it to a `visual/hyprtoolkit` capability. A theme change reaches the agent at
its next start through the `current` link, or live if hyprtoolkit reloads sourced files, which the laboratory
records without making it a gate; visual refinement remains with Story 4.8 [DEC-005].

## Single owner

polkit accepts one authentication agent per session, and agents register without owning a D-Bus name, so the
single-owner rule is enforced at the paths that start agents rather than through the D-Bus two-owner helper.
Configure fails with exit 4, naming the file, its package and the next action, when an active system or user
autostart entry starts a known polkit agent from the list kept in `sources.md`, or when another agent's user unit
is enabled; it removes and hides nothing. After login, a read-only `polkit-check` in the style of `portal-check`
confirms that `hyprpolkitagent.service` is active and that no other known agent process runs for the user, which
also catches an agent started from the personal `autostart.lua` that configure does not parse. The laboratory
records whether uwsm honours XDG autostart, using the gnome-keyring entries as a witness, and the autostart check
is kept as a defense either way [DEC-006].

## Session menu

The shell's session menu stops treating a logind `challenge` as a dead end. Following the lock row's precedent,
it checks whether `hyprpolkitagent.service` is active: if so, the row stays available, reads "<Label> asks for
authorization." and runs the same fixed `systemctl` argv, so the agent shows the dialog and the shell never sees a
credential; if not, the row remains unavailable with "<Label> needs authorization; start the polkit agent." Other
logind answers keep their current reasons, and `check-menu.sh` covers both `challenge` cases. A cancelled or denied
prompt fails closed without a retry or a shell message, and G3 confirms the menu does not hang [DEC-007].

## Capability shape

`desktop/polkit` mirrors `desktop/lock`. It declares `hyprpolkitagent` from extra, delivers the managed
`~/.config/hypr/hyprtoolkit.conf` and the read-only `/usr/share/mirroros/polkit/polkit-check`, enables the packaged
user unit for `graphical-session.target` and checks the single-owner rule against an `agents` list, with a
`sources.md` for provenance. The packaged unit already ties the agent to the graphical session, restarts it on
failure and bounds its stop time, so no drop-in is added and laboratory issues become findings. Nothing is started
or restarted; a running session gains the agent at its next login. The step runs right after `desktop/lock` and
relies on `visual/theme` for the theme's `hyprtoolkit.conf`, and the shell's check for `hyprpolkitagent.service`
is documented as a provider coupling, as hypridle already is [DEC-010].

## Records

Records follow the 02-35 pattern and are written only once G1 and G2 pass. `docs/mvp-scope.md` names hyprpolkitagent
as the polkit agent provider for Story 4.5, noting its theming from the MirrorOS palette, the single-owner rule,
`polkit-check`, and fingerprint enablement left out. A new `docs/procedures/polkit-agent.md` covers ownership and
`polkit-check`, conflicting agents and their remedy, the difference between the keyring unlock at login and a
polkit prompt, theming and reload, the gate evidence, and how to repeat the T14s G2 run. The capability's
`sources.md` records the provenance of the packaged unit and hyprtoolkit keys, the grouped risk of lock, idle and
agent sharing the Hypr ecosystem, the Arch package's stale Qt dependencies as a non-blocking note, and the criteria
for the agent list, while `visual/theme/sources.md` gains a row for `hyprtoolkit.conf`. Execution findings are
appended to this interview and an Area 2 implementation note to the brainstorm. No ADR is needed, because the
agent applies ADR 0012's rule that authentication is never project-owned QML [DEC-011].

## Tests and commits

A configure contract suite for `desktop/polkit` covers packages, the user and system files, the unit, and the exit 4
outcome for competing autostart entries, including hidden and user entries; `polkit-check` gets its own suite with
`systemctl` and `pgrep` doubles; the theme's `hyprtoolkit.conf` is checked against `colors.toml` by a palette test;
and `check-menu.sh` gains both `challenge` cases. The work is committed in four commits following the 02-35
splitting pattern: the theme file, the polkit capability, the shell change, and the records. The candidate ref under
`refs/mirroros-candidates/02-36-*` is deleted after confirmation and nothing is pushed [DEC-012].

Verification is targeted rather than full-suite. Each task runs only the tests linked to what it changes: the theme
file its palette, install and publish tests; the polkit capability its own suites plus the contracts that read the
real step list and the `cfg_exec` allowlist; the shell change `check-menu.sh` in the VM, the shell coupling scan and
qmllint; documentation only whitespace and link checks. Each committed tree runs the union of the tests linked to
its files, and the plan's verification keeps the change-to-test map. No full-suite run is included, accepting that
a coupling outside the map would go unnoticed [DEC-013].

The plan closes with a final impact analysis instead of a routine full-suite run. The delivered diff is compared
with the change-to-test map, looking for files outside it, shared helpers, laboratory-driven changes and tests that
read the affected trees generically. When nothing falls outside the map, no full suite runs and the justification is
recorded; otherwise an extended linked subset is proposed first, and the full suites only when the impact cannot be
bounded, always with the maintainer's approval and once on the final tree, at the cost of re-splitting commits if a
failure needs a fix [DEC-014].

## Execution notes (2026-11-13)

This section supplements the narrative above; the execution findings in the
[interview log](story-4-5-polkit-agent_log.md#execution-findings--2026-11-13-plan-02-36) hold the details. The plan
stopped at the gate checkpoint: G1 failed on hyprpolkitagent's own dialog, whose truncated text with the shell's
typography, fixed layout, `*` mask, missing in-progress state and render load no theme value can fix. Nothing was
committed to `main`, the polkit row in `docs/mvp-scope.md` stays open and the procedure was not written; the
candidate ref is kept for the later plan that chooses between an ADR for A and a temporary agent C. G2 ran on the
T14s's MirrorOS partition rather than on Omarchy, with a lab-only fingerprint setup reverted afterwards, and
fingerprint with password fallback passed. G3 was cut short after G1, and cancellation returned 127 instead of 126,
a defect intrinsic to the agent that still fails closed.
