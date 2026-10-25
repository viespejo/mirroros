# Story 4.3 Guest–Host Planning — Consolidated Plan

## Scope and execution approach

Plan 02-18 will deliver the Story 4.3 prototype and reviewed design decisions, not production implementation or complete story acceptance. It remains tied to the real desktop-shell need rather than becoming a standalone agent-coordination project. Guest Pi provides exploration and diagnosis; the host reviews the handoff and retains future production integration and reconstruction validation. Successful laboratory experiments do not establish clean reconstruction acceptance. No new coordination infrastructure has been selected. This narrows the original full-story scope without discarding its execution boundaries. [DEC-001, DEC-014]

## Plan identity

The implementation plan will use phase metadata `02-new-phase`, plan metadata `18`, and the sole dependency `02-17-reproducible-development-workbench`. The final plan remains subject to a separate in-chat draft and explicit materialization approval. Persistent interview tracking is active. [DEC-001]

## Open design questions

Exact guest–host responsibilities, handoff deliverables and transfer channels remain to be resolved during the interview. Subsequent decisions must preserve the distinction between laboratory results and host-driven clean reconstruction validation. [DEC-001]

## Guest autonomy and authorization

Guest Pi may inspect the environment, edit configuration and execute tests within the agreed scope. Package installation, privilege elevation, service restarts and session termination require specific authorization; access to the laboratory alone does not grant it. Publishing changes and transferring credentials must not occur on the agent's own initiative. These limits protect the active session while allowing useful local investigation. [DEC-002]

## Guest-to-host handoff

The guest may create local commits for handoff without publishing them. The host retrieves a Git bundle with a checksum using the existing SSH/bundle approach, together with a report describing the exact recipe, results and limitations. Only selected, reviewed and secret-scanned evidence is exported; private guest state is not a handoff artifact. The host reviews before integration, and publication and integration require authorization. No automatic synchronization or guest access to the host is introduced. This preserves tested source identity without depending on a published remote. [DEC-003]

## Exploration gate and implementation stages

Execution starts with a guest prototype covering the five ADR 0012 surfaces: bar, launcher, notifications, on-screen display and session menu. Guest exploration also proposes existing screen-lock/idle providers and exercises the keyboard bindings. Its handoff includes exact configuration, results and limitations. Host-side reproducible implementation begins only after the maintainer reviews and approves the prototype and outstanding choices. The plan defines requirements and tests without speculatively choosing what laboratory evidence must establish. Global visual coherence remains in Story 4.8. [DEC-004]

## Cross-story capability boundaries

Story 4.3 delivers its shell surfaces and session actions backed by existing support, without taking over the complete hardware, browser or file-manager capabilities owned by other stories. Availability and displayed status reflect actual support; missing dependencies are identified as unavailable with a reason, and incomplete actions are not executed. Documented integration points allow later slices to connect their capabilities without redesigning the shell. Controlled OSD events validate presentation behavior only and must not be reported as real hardware validation. [DEC-005]

## Keyboard discovery and comparison

The current i3 reference is ~/.config/i3; inspection is limited to binding-related files and pertinent includes, not unrelated private configuration. Research Omarchy's bindings and record the consulted revision. The exploration delivers an action-by-action comparison of current i3 bindings, Omarchy bindings and proposed MirrorOS bindings, identifying conflicts and behavioral differences. Existing muscle memory remains the starting point, while alternatives from Omarchy may be selected after guest testing and maintainer approval. No binding change or wholesale copy of personal configuration is authorized by this discovery decision. [DEC-006]

## Omarchy relationship and architectural ownership

The shell seeks an appearance and interaction experience close to Omarchy across its five surfaces. Architectural similarities are welcome where they enable selective reuse; MirrorOS need not invent a wholly different structure, but retains control over QML organization, shared components and shell composition. Evaluate each candidate piece for utility, dependencies and maintenance cost, and review and record license, provenance and attribution before incorporation. This remains selective reuse, not a fork or wholesale shell import, preserving ADR 0012. Exact orchestrator responsibilities remain to be defined. [DEC-007]

## Orchestration research and prototype proposal

Study both Omarchy's QML composition and its Bash launch, IPC and restart integration. The prototype proposes a MirrorOS-owned structure and selective reuse after checking actual needs against existing supported mechanisms. No decision yet adopts Omarchy's supervisor, plugin system or IPC protocol. Omarchy's authentication integration is not inherited: authentication remains in existing supported components rather than project-owned QML, under ADR 0012. [DEC-008]

Research consulted the Omarchy quattro branch documentation and launch/IPC/restart scripts; the observed branch head was 7075b61c6aaa5d8589f6e816867508fc96dc49d9. Files were fetched from mutable branch URLs, not verified as a commit-pinned snapshot. Prototype source review must establish the exact revision of any compared or reused material. [DEC-008]

## Notification behavior exploration

Evaluate Omarchy's notification behavior in the guest with synthetic messages, covering shell restart, deletion, retention and screen lock. Review the results before selecting MirrorOS persistence policy; the previously suggested memory-only policy is not an accepted decision. No Omarchy persistence, retention, verification-code bypass or authentication behavior is adopted by this exploration decision. [DEC-009]

Source inspection at Omarchy revision 7075b61c6aaa5d8589f6e816867508fc96dc49d9 found separate live/history/quiet state files, a 100-entry history bound and a default 24-hour retention with 0/1/24/168-hour choices. Verification-code redaction is heuristic, and disabling history does not necessarily disable live-row persistence. Lock-screen behavior remains unverified. These findings inform the prototype rather than constitute runtime acceptance or a MirrorOS privacy guarantee. [DEC-009]

## Mandatory story acceptance levels

Complete Story 4.3 acceptance, in the subsequent implementation plan, requires host-side automated contracts, QML validation and configuration tests, followed by a clean-VM installation and configure run, a second configure run without unnecessary changes, and shell startup/integration checks. Maintainer-attended acceptance additionally covers keyboard paths, visual interaction, lock/unlock and failure recovery. Graphical automation complements but does not replace that attended gate. Tests use synthetic data and retain no credentials; capabilities that cannot be exercised in the VM remain explicitly pending rather than approved. [DEC-010]

## Source ownership boundaries

Place the owned Quickshell shell, including QML and Quickshell-specific integration, under capabilities/desktop/shell/. Keyboard bindings and Hyprland adaptation remain under capabilities/desktop/compositor/providers/hyprland/. Lock and idle remain separate responsibilities from the shell; concrete source locations will be selected alongside their providers. Internal QML organization remains subject to the prototype proposal, preserving the agreed architectural exploration rather than fixing its component tree in advance. [DEC-011]

## Laboratory and clean-validation environments

Use the existing laboratory guest for Pi-assisted exploration after taking a recoverable snapshot or backup. Do not create a third VM solely to explore Omarchy. A separate clean VM remains necessary for host-driven reconstruction acceptance, so accumulated laboratory state cannot substitute for reproducibility. Evaluate selected Omarchy components without running its complete installer or importing its dotfiles wholesale. [DEC-012]

## Performance and maintenance evidence

The guest prototype report must include shell startup, memory and idle CPU measurements, dependencies, and the volume of owned and reused code. Review these results as part of the prototype approval gate before implementation. Numerical thresholds are not selected without a measured baseline. [DEC-013]

## Plan split and current completion boundary

Plan 02-18 delivers the laboratory prototype, i3/Omarchy comparison, QML/Bash architecture proposal, notification experiments, performance/maintenance report and verifiable host handoff. A subsequent plan will specify production implementation and full acceptance after prototype approval. This explicitly supersedes the full-story scope of DEC-001 for 02-18 only; its sole dependency remains 02-17-reproducible-development-workbench. The three validation levels above govern complete Story 4.3 acceptance, not completion of this prototype plan. [DEC-014]

## Color-only state cues

Where Omarchy conveys a shell state by color alone, the prototype follows Omarchy rather than adding non-color cues, and this is the default for similar future choices. Each affected state is recorded as a deviation from plan 02-18 AC-2. The Story 4.3 criterion that color is not the sole means of communicating state is not amended by this decision; the subsequent production plan must amend it explicitly or revisit the choice, and the conflict blocks production implementation until then. [DEC-015]

## Bar panels

The maintainer wants Omarchy's bar panels (audio, network, Bluetooth, display, power, calendar) in the shell. Plan 02-18 keeps the indicators identical, documents their click targets as integration points, and studies each panel as evidence. Implementation needs an ADR amending the ADR 0012 scope and is planned with Story 4.4, where hardware can be validated. [DEC-016]

## Keyboard layouts

The product provides `us` and Spanish (Spain) `es` layouts with a documented switching binding. Where the layout list is declared is selected by the subsequent production plan; the prototype tests the layout module only through a reverted runtime change. [DEC-017]

## Reviewed prototype architecture and maintenance

The maintainer accepted explicit QML composition without Omarchy's plugin system or supervisor, with Hyprland integration and lock/idle responsibilities kept separate, as the prototype's candidate direction. Retain the current 16,013 product lines without pruning now and review upstream updates using per-file provenance. This accepts the visible maintenance cost for prototype evaluation, not production adoption or integration. Outstanding choices and verification gaps remain production blockers. [DEC-018]

## Confirmation of supervised guest results

The maintainer confirmed monitoring and approving the guest prototype work and authorized proceeding without repeating individual approvals of its recorded experimental choices. This includes hyprlock + hypridle as the proposed providers, retaining system PAM authentication. Proceed with the final selected-evidence and Git-bundle handoff through host-driven SSH. Preserve accepted directions, rejected experiments, defects, unresolved alternatives and deferred checks exactly as such; this confirmation neither selects unspecified alternatives nor qualifies unperformed tests. Production integration, publication, disruptive retests and credential transfer remain unauthorized. [DEC-019]

## Verified handoff and future planning input

The host has the incremental bundle at ignored `evidence/desktop-shell-prototype/handoff-6d7314f/`, verified against the guest checksum and with `git bundle verify`. Product source is `6d7314fbed2c2db0db5794529479669320fc6687`; handoff commit `87f4cbde9d2a0a54dd0064662d5e034605a8fd48` adds only the committed experimental recipe. Restoration requires base `08f17de9943730050d4787c50d1cc138c83f5bf5`. The isolated host review checkout is clean at the handoff commit; no product integration occurred.

The 42 selected evidence files matched guest hashes and passed secret scans, alongside prototype history and selected source. The procedure records commands, measurements, accepted/rejected/unresolved directions and actual check scope. Non-graphical model/provenance/i18n checks passed; ShellCheck retains seven test-only diagnostics. Historical runtime and QML results were not rerun during the handoff. The maintainer selected A (Accept) for the overall Task 3 post-apply review, accepting the bounded experimental result and verified handoff without production adoption.

Future planning must resolve notification/privacy and configuration/lifecycle ownership, keyboard-help safety, retained defects, approved criterion conflicts and deferred qualification. The maintainer's acceptance of supervised experiments is not acceptance of unspecified policies or complete Story 4.3. Retain all three DEC-010 validation levels; this task creates no production implementation plan.

## Accepted notification persistence policy

MirrorOS adopts the persistence behavior demonstrated by the prototype: default history retention of 24 hours, a maximum of 100 history entries, restoration of active notifications and private state files. Notification content is private runtime state and must not enter the repository or retained evidence. Verification-code redaction remains heuristic, not a confidentiality guarantee. This resolves DEC-009's persistence-policy deferral and supersedes older statements that persistence is wholly undecided; while-away behavior and notification action execution remain open. Production implementation and validation are still required, and this policy decision alone does not authorize integration or runtime mutation. [DEC-020]

## Conditional while-away notification count

A discreet count of notifications received during lock may appear in the existing bar indicator on return, conditional on a bounded experiment demonstrating reliability and low complexity. Do not expose notification content on the lock surface, replay every card or create an extra notification. Reuse existing lock/idle and shell mechanisms rather than adding a service or authentication logic. If the low-complexity condition cannot be met, report back rather than expanding the implementation silently. Counter lifecycle and reset semantics remain unspecified. [DEC-021]

Source review of hypridle v0.1.8 src/core/Hypridle.cpp confirms compositor-driven general:on_lock_cmd and general:on_unlock_cmd hooks, offering a candidate path to the existing Quickshell IPC. This is source evidence only, not guest validation. The known-unreliable logind LockedHint is not the selected signal; shell restart during lock and event/state reconciliation must be tested before support is claimed. [DEC-021]

## While-away count reset

If the conditionally approved counter is implemented, clear it when notification history is opened rather than on session unlock, so returning to the desktop does not erase the indication before it can be consulted. Resetting the count does not delete history or change retention, and DEC-021's reliability and low-complexity gate still applies. [DEC-022]

## Production session lifecycle ownership

Use separate systemd user services tied to the uwsm graphical session. MirrorOS owns the shell unit, with bounded on-failure restarts and journal logging; reuse the packaged hypridle unit with a drop-in only when needed. Restarting the shell must neither restart hypridle nor terminate hyprlock. Do not duplicate startup through Hyprland or introduce a Bash supervision loop. Configure prepares startup without automatically restarting the active desktop, and target-root configuration never starts services. Validate concrete unit dependencies and packaged-unit behavior in both execution contexts; the prototype's transient units are not production lifecycle evidence. [DEC-023]

## Shell configuration ownership

MirrorOS owns version-controlled defaults and updates them through configure. User-owned personal preferences are preserved when configuration is reapplied; the shell interface modifies only those preferences, not the version-controlled defaults. Private runtime state, including notification history and counters, remains separate from configuration and outside the repository. Concrete locations and formats must implement these boundaries and resolve the outstanding shell.json justification without introducing a universal configuration schema. This ownership decision does not itself select merge semantics or a new format. [DEC-024]

## Common defaults, local overrides and explicit promotion

Implement the DEC-024 ownership boundary with version-controlled common MirrorOS defaults and small, explicit local overrides per option. Uncustomized options follow updated defaults, customized options retain their chosen values, and removing an override restores the current default. Lists, including bar layouts, replace the corresponding list completely rather than merging elements. Saving a personal choice must not copy unrelated effective defaults into the user's configuration. This intentionally departs from Omarchy's full personal-file replacement semantics to avoid accidental per-device forks of common defaults. [DEC-025]

The expected workflow is to experiment on the daily device, explicitly review and promote desired common changes into the repository, review those versioned changes on another device, and apply them through configure while retaining deliberate local exceptions. Promotion is manual or agent-assisted, never an automatic consequence of an interface edit. Configure converges MirrorOS-owned files and preserves local overrides; manually modified managed files produce a visible conflict rather than silent replacement. No synchronization service, automatic promotion tool or new configuration manager is selected. Concrete paths and format justification remain outstanding, and the override model stays shell-local rather than becoming a universal schema. [DEC-025]

## Story color-criterion alignment without a new ADR

The production plan will directly amend Story 4.3's color criterion in docs/epics.md to reflect the approved Omarchy-style visual states, with traceability to DEC-015 and corresponding test/documentation alignment. No new ADR is required because this is a story acceptance-criterion adjustment, not a change to architecture or an existing ADR. Preserve historical prototype deviations and check outcomes without retroactive compliance claims; installer, CLI and verification requirements remain unchanged. Panel expansion still requires its separately agreed ADR 0012 scope amendment. The actual story edit has not been performed by this registration. [DEC-026]

## Selector replacement and cancellation

Keep one active selector request. Before a new selector or regular menu replaces it, complete the previous request as cancelled and communicate termination to its requester without executing its selection. Do not add a request queue or change appearance. Test that asynchronous result delivery cannot be lost or overwritten by the replacement. This addresses the inherited abandoned-request defect, not the separate action-identity selection defect already repaired at 6d7314f; retain that repair and regression coverage. No runtime fix has been applied by this registration. [DEC-027]

## Production plan identity and direct materialization

The subsequent production plan is 02-19, phase metadata 02-new-phase, with the sole direct dependency 02-18-desktop-shell-guest-prototype. Its three tasks cover reviewed runtime and bounded fixes, configure/session integration, and clean-VM/idempotency/attended acceptance. The maintainer explicitly authorized direct materialization without an in-chat draft; this applies to planning artifacts only, not execution or disruptive operations. The plan is .agents/plans/02-19-desktop-shell-production.md and inherits approved prototype choices and the counter's conditional gate. [DEC-028]

## Production verification continuation

Plan 02-19 Tasks 1/2 are accepted; Task 3 received A (Accept) for its bounded evidence and listed limits. The
[execution checkpoint](story-4-3-guest-host_log.md#production-execution-checkpoint--2026-10-25) and
[active procedure](../procedures/desktop-shell.md#final-source-verification-checkpoint) record the actual
candidate `8c3c3cc`, target/running identities, selected suites, attended outcomes and failed/blocked attempts.
These later execution results supersede historical pending-choice lists without rewriting prototype outcomes.

Clean reconstruction, unchanged repeated running configure, qualified bounded production counter behavior,
Terminal=true, native reload, one-failure shell recovery and attended session stop/start now have evidence.
Sparse overrides and notification retention/restoration/privacy/literal argv completed functional tests on copied
installed runtime. Quiet-log assertions still fail; reviewed QML baseline success still includes 829 warnings.
A maintainer-owned display-only QEMU exception was preserved, not promoted to common defaults. Temporary idle
inhibition was bounded and is confirmed absent.

DEC-029 accepts a reference-VM-only exception for the two mouse-drag failures and no identical retest without a
new hypothesis or comparative hardware scenario. Both results remain failed; QEMU causality is unproven and
hardware qualification pending. DEC-030 accepts a temporary exception only for observed PipeWire/UPower/portal
absent-provider diagnostics until Stories 4.4/4.5 deliver their owners; original exit-1 outcomes and logs remain.
No new diagnostic, unrelated defect or QML-baseline waiver follows from that exception.
Keep unperformed idle timing/from-es reset, remaining standard-keyboard, tray/multi-output,
actual restart-limit exhaustion and changed-runtime reload checks distinct from existing passes. Hardware-owned
checks and original suspend failure stay with their owners. Do not repeat disruptive tests or reopen approved
prototype choices merely to accumulate passes. Final Task 3 review accepted the bounded result; its SUMMARY
records what is delivered and still unverified. Complete Story 4.3 closure is not claimed. Publication and
target-laptop migration are separate operations; the maintainer owns the final plan-status change.
