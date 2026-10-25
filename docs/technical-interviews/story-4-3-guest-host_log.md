# Story 4.3 Guest–Host Planning — Decision Log

## DEC-001
- **Question**: Should plan 02-18 deliver Story 4.3 with guest-assisted exploration, or only establish a guest–host collaboration workflow?
- **Context/Nuances**: The completed development workbench already provides Pi in the guest. Guest exploration and diagnosis can inform implementation, but do not establish clean reconstruction acceptance. No coordination infrastructure is selected by this decision. The final implementation plan requires separate draft approval.
- **User Response**: "yes, registra directamente la decisión en los artefactos. activa la persistencia para ello."
- **Decision**: Plan Story 4.3 with guest-assisted exploration and diagnosis, and host-side integration and reconstruction validation. Use numbering 02-18, phase metadata 02-new-phase, plan metadata 18, and the sole dependency 02-17-reproducible-development-workbench. Keep exact responsibilities, handoff deliverables and transfer channels open for the interview. Activate persistent interview tracking with this accepted registration.
- **Status**: Accepted

## DEC-002
- **Question**: What autonomy should Pi have inside the guest laboratory?
- **Context/Nuances**: Guest-side investigation should be useful without silently expanding scope or interrupting the maintainer's graphical session. General guest access is not blanket authorization for privileged or disruptive actions.
- **User Response**: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Guest Pi may explore, edit configuration and run tests within the agreed scope. Installing packages, elevating privileges, restarting services or ending the session requires specific authorization. Pi must not publish changes or transfer credentials on its own initiative.
- **Status**: Accepted

## DEC-003
- **Question**: How should guest work be handed off to the host?
- **Context/Nuances**: Existing procedures use SSH and verified Git bundles. The handoff must preserve the exact tested source identity without requiring publication or granting the guest access to the host. Evidence must not become an unrestricted export of guest state.
- **User Response**: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Permit guest-side local commits for handoff. Deliver a Git bundle with a checksum, accompanied by a report containing the recipe, results and limitations, and only selected, reviewed and secret-scanned evidence. Use the existing SSH/bundle approach, with host-side retrieval and review before integration. Do not introduce automatic synchronization or guest access to the host. Publication and integration require authorization.
- **Status**: Accepted

## DEC-004
- **Question**: Should guest exploration have an explicit approval gate before reproducible implementation?
- **Context/Nuances**: ADR 0012 selects an owned Quickshell shell, but no shell prototype exists yet. Screen-lock and idle providers remain open. Laboratory findings must inform choices rather than being replaced by speculative plan decisions. Global visual coherence remains owned by Story 4.8.
- **User Response**: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Execute the plan in two stages. First prototype the five Quickshell surfaces in the guest, propose screen-lock/idle providers and exercise keyboard bindings, then deliver exact configuration, results and limitations. Begin host-side reproducible implementation only after the maintainer reviews and approves the prototype and outstanding choices. Define requirements and tests in the plan without preselecting choices that require laboratory evidence. Keep global visual coherence in Story 4.8.
- **Status**: Accepted

## DEC-005
- **Question**: How should the shell handle actions whose underlying capabilities belong to later stories?
- **Context/Nuances**: The frequent-action inventory includes volume, brightness, suspend, hibernate, browser and file-manager actions whose complete implementation is not owned by Story 4.3. Shell delivery must neither silently expand that scope nor imply that missing capabilities work.
- **User Response**: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Story 4.3 implements its surfaces and session actions with existing support. Display real states, not simulated capability availability. Mark missing dependencies as unavailable with a reason and do not execute incomplete actions. Document integration points so subsequent stories can connect their capabilities without redesigning the shell. Test OSD using controlled events without claiming real hardware validation.
- **Status**: Accepted

## DEC-006
- **Question**: How should the maintainer's i3 bindings and Omarchy bindings inform MirrorOS keyboard conventions?
- **Context/Nuances**: The maintainer identified ~/.config/i3 as the current configuration and also wants to discover Omarchy's bindings. Story 4.1 makes i3 muscle memory the primary reference, but this does not require importing its complete scheme or rejecting reviewed alternatives. Private configuration must not be copied wholesale.
- **User Response**: The maintainer supplied ~/.config/i3 and requested Omarchy discovery, then confirmed: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Consult binding-related files under ~/.config/i3 and follow only pertinent includes. Research Omarchy bindings and record the consulted revision. Prepare an action-by-action comparison of current i3, Omarchy and the proposed MirrorOS binding, including conflicts and behavioral differences. Start from existing muscle memory while allowing Omarchy alternatives approved after guest testing. This decision does not yet authorize changing bindings or copying the complete personal configuration.
- **Status**: Accepted

## DEC-007
- **Question**: What experience and architectural relationship should the owned shell have with Omarchy?
- **Context/Nuances**: The maintainer wants an experience close to Omarchy and control over QML file structure and orchestration, while also seeking architectural similarities that make suitable Omarchy components reusable. This is not a requirement to invent a completely different architecture or inherit Omarchy's complete structure. ADR 0012 still forbids a fork or wholesale shell import.
- **User Response**: The maintainer clarified the desire for architectural similarity where useful for reuse, then confirmed the revised proposal: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Use Omarchy as the appearance and interaction reference for the five shell surfaces. Seek architectural similarities where they facilitate selective reuse, while MirrorOS controls QML organization, shared components and shell composition. Evaluate each reused piece for utility, dependencies and maintenance cost, and review and record its license, provenance and attribution. Do not fork or import the complete shell. Exact orchestrator responsibilities remain open.
- **Status**: Accepted

## DEC-008
- **Question**: Which Omarchy orchestration layers should inform the prototype?
- **Context/Nuances**: Source inspection of Omarchy's quattro branch identified QML shell composition and Bash integration: omarchy-launch-shell starts Quickshell, journals output and bounds relaunch attempts; omarchy-shell forwards IPC; omarchy-restart-shell coordinates restart/readiness. The branch head observed during research was 7075b61c6aaa5d8589f6e816867508fc96dc49d9; individual files were fetched via mutable branch URLs, so this is not a verified commit-pinned source snapshot. References: https://github.com/omacom/omarchy/blob/quattro/docs/omarchy-shell.md and https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-launch-shell . Omarchy's authentication integration does not override ADR 0012.
- **User Response**: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Study both QML composition and Bash integration as references. The prototype must propose a MirrorOS-owned structure and selective reuse, first checking actual needs and existing supported mechanisms. Do not yet adopt Omarchy's supervisor, plugin system or IPC protocol. Authentication remains provided by existing supported components, not project-owned QML, as required by ADR 0012.
- **Status**: Accepted

## DEC-009
- **Question**: Should MirrorOS select notification persistence now or first evaluate Omarchy's behavior in the guest?
- **Context/Nuances**: Inspection of Omarchy revision 7075b61c6aaa5d8589f6e816867508fc96dc49d9 found live.json, history.json and quiet.json under ~/.local/state/omarchy/notifications/. History defaults to 24 hours, supports 0/1/24/168 hours and is bounded to 100 entries. The implementation uses private directory/file permissions and attempts to redact detected verification-code notifications before persistence. This detection is not a guarantee against retaining other sensitive content. Disabling history does not necessarily disable live-row persistence. Lock-screen notification behavior was not verified. References: shell/plugins/notifications/{Service.qml,Store.js,Settings.js} at that revision. The earlier memory-only proposal was not accepted.
- **User Response**: "yes, registra directamente la decisión en los artefactos."
- **Decision**: First evaluate Omarchy notification behavior in the guest using synthetic notifications, including shell restart, deletion, retention and screen-lock scenarios. Leave MirrorOS notification persistence policy open until the maintainer reviews the results. This does not authorize adoption of Omarchy's persistence, retention, verification-code bypass or authentication implementation.
- **Status**: Accepted

## DEC-010
- **Question**: Which validation levels are mandatory for Story 4.3 acceptance?
- **Context/Nuances**: Source contracts alone cannot demonstrate a usable graphical session; an accumulated laboratory cannot demonstrate clean reconstruction. Graphical automation complements rather than replaces attended acceptance. Capabilities that cannot be exercised in the VM must not be represented as passed.
- **User Response**: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Require three validation levels: (1) host-side automated contracts, QML validation and configuration tests; (2) clean-VM installation and configure, an unnecessary-change-free second configure run, and shell startup/integration checks; (3) maintainer-attended keyboard, visual interaction, lock/unlock and failure-recovery acceptance. Tests use synthetic data and retain no credentials. Graphical automation does not replace attended acceptance. Mark capabilities not exercisable in the VM as explicitly pending rather than approved.
- **Status**: Accepted

## DEC-011
- **Question**: Where should the owned shell live, and how should its responsibilities be separated from the compositor and authentication components?
- **Context/Nuances**: Hyprland already has a provider boundary at capabilities/desktop/compositor/providers/hyprland/. The owned shell must not force unrelated shell responsibilities into that provider or make all shell behavior directly dependent on Hyprland. The prototype still owns the proposal for internal QML organization and outstanding provider choices.
- **User Response**: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Place the owned Quickshell shell and its specific integration under capabilities/desktop/shell/. Keep keyboard bindings and Hyprland adaptation under the existing Hyprland provider. Keep lock and idle responsibility separate from the shell; select their concrete locations alongside their providers. Leave internal QML structure for the prototype proposal.
- **Status**: Accepted

## DEC-012
- **Question**: Does Omarchy exploration require another disposable clone, or should it use the existing laboratory guest?
- **Context/Nuances**: The maintainer requested clarification about an extra exploration VM and rejected multiplying environments. The final proposal uses the current laboratory with a recoverable snapshot or backup, while preserving a separate clean reconstruction VM. No additional exploration clone is required.
- **User Response**: "si, no multipliquemos"
- **Decision**: Use the existing laboratory VM as the guest for Pi-assisted exploration, with a recoverable snapshot or backup taken before experimentation. Keep a separate clean VM for host-driven reproducible reconstruction acceptance. Do not create a third VM merely for exploration. Evaluate selected Omarchy components without running its complete installer or importing its dotfiles wholesale.
- **Status**: Accepted

## DEC-013
- **Question**: What performance and maintenance evidence must accompany the prototype approval gate?
- **Context/Nuances**: There is no measured shell baseline from which to choose quantitative thresholds. The owned shell and selective reuse introduce maintenance responsibilities that must be visible before implementation approval.
- **User Response**: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Require guest measurements of shell startup, memory and idle CPU, together with documented dependencies and the volume of owned and reused code. Review this report at the prototype approval gate before approving implementation. Do not invent numerical thresholds without a measured baseline.
- **Status**: Accepted

## DEC-014
- **Question**: Should the broad Story 4.3 effort be split into a prototype/design plan and a later reproducible implementation plan?
- **Context/Nuances**: The planning references require bounded executable tasks. Provider choices, notification persistence and QML/Bash structure still need prototype evidence. A full implementation plan now would require oversized tasks or speculative decisions. This explicitly narrows DEC-001's scope for plan 02-18; other accepted boundaries remain applicable to the owning stage.
- **User Response**: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Limit plan 02-18 to the Story 4.3 prototype and reviewed decisions: guest exploration, i3/Omarchy comparison, QML/Bash architecture proposal, notification experiments, measurements and verifiable host handoff. Define a subsequent production implementation and complete acceptance plan after prototype approval. Keep the sole dependency of 02-18 as 02-17-reproducible-development-workbench. The three mandatory validation levels remain required for complete story acceptance, not as a claim that prototype completion closes the story.
- **Status**: Accepted

## DEC-015
- **Question**: Should the shell follow Omarchy where Omarchy conveys state by color alone?
- **Context/Nuances**: Raised during plan 02-18 Task 2 execution. Omarchy indicates some states, such as the selected launcher row, by color only. Plan 02-18 AC-2 and the Story 4.3 acceptance criteria in docs/epics.md require that color is not the sole means of communicating state. The maintainer approved color-only selection in Brief 1 and asked that the deviation guide similar future decisions. This decision does not amend docs/epics.md.
- **User Response**: "quiero mantener solo color, de hecho, quiero mantener esta parte desde Omarchy. deja registro para que se tenga en cuenta esta desviación, incluso para futuras decisiones parecidas."
- **Decision**: Where Omarchy conveys a shell state by color alone, follow Omarchy instead of adding non-color cues. Apply this as the default for similar choices in the prototype and record each affected state as a deviation from AC-2. The subsequent production implementation plan must either amend the Story 4.3 color criterion explicitly or revisit this decision; until then the conflict remains an open production blocker.
- **Status**: Accepted

## DEC-016
- **Question**: Should the shell include Omarchy's bar panels for audio, network, Bluetooth, display, power and calendar?
- **Context/Nuances**: Raised during plan 02-18 Task 2 execution. In Omarchy, bar icons open panels with real controls, about 8,300 QML/JS lines plus panel infrastructure and Omarchy scripts that would need replacing. ADR 0012 bounds the shell to five surfaces and excludes control-panel functionality; Story 4.4 owns audio, Bluetooth, brightness and power, and decides whether Wi-Fi and Bluetooth connect through the shell or a terminal interface. Plan 02-18 excludes implementing capabilities owned elsewhere. The laboratory VM has no Wi-Fi, Bluetooth adapter, sound device or backlight.
- **User Response**: The maintainer wants the panels in the shell and accepted the recommendation: "seguimos tu recomendacion".
- **Decision**: Record the maintainer's intent to provide these panels in the shell. Plan 02-18 keeps the bar indicators identical to Omarchy, documents their click targets as integration points, and studies each panel (dependencies, scripts to replace, line counts, VM or laptop testability, containing surface) as evidence. Implementation requires an ADR that amends the ADR 0012 scope and is planned with Story 4.4, where hardware can be validated.
- **Status**: Accepted

## DEC-017
- **Question**: Which keyboard layouts should the product provide?
- **Context/Nuances**: Raised while reviewing the bar keyboard-layout module. The maintainer uses `us`, with a Ferris Sweep providing a Unicode layer for Spanish characters, and needs a Spanish layout when that keyboard is absent. Keyboard conventions belong to Story 4.3; the resolved layout belongs to installation and configure policy. This decision does not authorize changing laboratory keyboard configuration beyond a temporary runtime test.
- **User Response**: "por supuesto \"us\" pero cuando no tengo mi Ferris Sweep (con mi capa unicode para teclas especiales en Español) tambien nos gustaría tener es_ES layout si es posible (en el producto)"
- **Decision**: The product provides the `us` layout and a Spanish (Spain) `es` layout, with a documented switching binding in the keyboard table. The subsequent production plan selects where the layout list is declared. The prototype may test the layout module only through a temporary runtime change that is reverted afterwards.
- **Status**: Accepted

## DEC-018
- **Question**: Should the prototype's explicit QML composition and current selective-reuse maintenance approach remain the candidate direction after host review?
- **Context/Nuances**: Raised during plan 02-18 Task 3. The clean guest checkout was confirmed at `6d7314fbed2c2db0db5794529479669320fc6687`. The prototype has 16,013 product lines; retaining reused code exposes a substantial maintenance responsibility. This review does not resolve other production blockers or authorize integration.
- **User Response**: The maintainer explicitly accepted the proposed architecture and maintenance direction.
- **Decision**: Accept explicit QML composition without Omarchy's plugin system or supervisor, with Hyprland integration and lock/idle responsibilities kept separate, as the prototype's candidate direction. Retain the current reused code without pruning now and review upstream updates using per-file provenance. Accept the visible maintenance cost for prototype evaluation only; production adoption and integration remain gated by explicit approval and resolution of outstanding choices.
- **Status**: Accepted

## DEC-019
- **Question**: Must the host repeat individual approvals of experimental choices already supervised and approved by the maintainer in the guest?
- **Context/Nuances**: Raised during Task 3 while reviewing hyprlock + hypridle as the proposed providers. The maintainer confirmed monitoring and approving the guest prototype work and authorized proceeding. Guest reports distinguish accepted directions, rejected experiments, unresolved alternatives, failed behavior and deferred checks.
- **User Response**: The maintainer explicitly confirmed global approval of the supervised guest prototype work and authorization to proceed.
- **Decision**: Accept the supervised guest experimental result without repeating individual approvals of its recorded choices, including hyprlock + hypridle as the proposed providers with system PAM authentication. Proceed with the final selected-evidence and Git-bundle handoff using host-driven SSH. Preserve the reports' rejected experiments, defects, unresolved alternatives and verification gaps; global approval does not select unspecified alternatives or establish unperformed tests. No production integration, publication, disruptive retest or credential transfer is authorized.
- **Status**: Accepted

## DEC-020
- **Question**: Should MirrorOS adopt the notification persistence behavior demonstrated by the prototype?
- **Context/Nuances**: DEC-009 deferred production policy until the experiments were reviewed. Guest reports demonstrate persistence, restoration, age/count retention and clear-all deletion. Historical pending lists do not reopen choices already resolved by later decisions. Verification-code redaction remains heuristic, not a confidentiality guarantee. While-away behavior and notification action execution are separate unresolved policies.
- **User Response**: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Adopt the demonstrated persistence behavior for MirrorOS: default history retention of 24 hours, at most 100 history entries, restoration of active notifications and private state files. Notification content remains private runtime state, excluded from the repository and retained evidence. This resolves the persistence-policy deferral in DEC-009, but does not select while-away behavior or authorize notification action execution. Production implementation and validation remain required; this decision does not authorize integration or runtime changes by itself.
- **Status**: Accepted

## DEC-021
- **Question**: Should MirrorOS show a discreet count of notifications received while locked when the user returns?
- **Context/Nuances**: The prototype demonstrated that normal notifications expire unseen while locked and remain in history, while critical cards survive. The proposed enhancement adds a count to the existing bar indicator, without lock-screen content, replaying all cards or producing an extra notification. The maintainer made approval conditional on low complexity. Source review of hypridle v0.1.8 src/core/Hypridle.cpp confirms compositor lock-notification callbacks that execute general:on_lock_cmd and general:on_unlock_cmd; these are a candidate for forwarding state through existing Quickshell IPC, not a validated integration. The prototype's logind LockedHint is not reliable. Startup/restart reconciliation and missed events remain unverified.
- **User Response**: "si podemos tener ese contador sin mucha complejidad...adelante."
- **Decision**: Conditionally approve a discreet count in the existing bar indicator for notifications received during lock, visible on return, provided a bounded test demonstrates a reliable, low-complexity implementation. Do not display notification content on the lock surface, replay every card or generate an additional notification. Prefer existing lock/idle and shell mechanisms rather than introducing a new service or authentication logic. Validate shell restart during lock and event reconciliation before treating the feature as supported. Do not turn this conditional approval into an unconditional delivery requirement or silently introduce a more complex solution; report back if the condition cannot be met. Exact counter lifecycle and reset semantics are not selected by this decision.
- **Status**: Accepted

## DEC-022
- **Question**: When should the conditionally approved while-away notification count be cleared?
- **Context/Nuances**: Clearing the count merely on unlock could remove it before the maintainer has consulted the notifications. The feature remains conditional on DEC-021's reliability and low-complexity gate. Clearing the count is not deletion of notification history.
- **User Response**: "yes, registra directamente la decisión en los artefactos."
- **Decision**: If the DEC-021 counter is implemented, clear it when notification history is opened, not when the session is unlocked. This selects the reset trigger only; it does not remove the feature's conditional status or change the accepted notification retention policy.
- **Status**: Accepted

## DEC-023
- **Question**: Which mechanism should own production startup and supervision of the shell and hypridle?
- **Context/Nuances**: The prototype used disposable shell processes and a transient hypridle unit, not a production startup policy. Existing uwsm integration delegates graphical-session lifecycle to systemd user units. The accepted explicit-composition architecture excludes an Omarchy supervisor or a new Bash restart loop. Concrete unit behavior still requires validation against the installed package and both configure contexts.
- **User Response**: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Use separate systemd user services tied to the uwsm graphical session. Provide a MirrorOS shell unit with bounded on-failure restarts and journal logging. Reuse the packaged hypridle unit, adding a drop-in only if required. Keep lock lifetime independent: restarting the shell must not restart hypridle or terminate hyprlock. Do not duplicate startup in Hyprland or add Bash supervision loops. Configure prepares session startup without automatically restarting the active desktop; installer target configuration must not start services. Exact unit dependencies, package compatibility and lifecycle behavior must be implemented and verified rather than assumed.
- **Status**: Accepted

## DEC-024
- **Question**: Who should own shell defaults, personal preferences and private runtime state?
- **Context/Nuances**: The prototype persists interface preferences in shell.json. Overwriting that file during configure would lose personal choices, while treating all configuration as private mutable state could prevent versioned default updates from taking effect. Concrete locations, format justification and reconciliation behavior remain implementation-planning questions; this decision does not approve a universal schema.
- **User Response**: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Separate MirrorOS-owned version-controlled defaults, updated by configure, from user-owned personal preferences preserved on configuration reruns, and from private runtime state such as history and counters. The interface writes only personal preferences, not the version-controlled defaults. Private runtime state stays separate from configuration and outside the repository. Concrete paths and formats must preserve these boundaries and resolve the outstanding shell.json justification without inventing a universal configuration schema.
- **Status**: Accepted

## DEC-025
- **Question**: Should shell preferences follow Omarchy's complete user-file replacement semantics or use small local overrides over versioned MirrorOS defaults?
- **Context/Nuances**: The maintainer's expected single-maintainer workflow is to experiment on the daily device, promote most desired changes into the common product defaults, then apply those defaults to other MirrorOS devices while retaining deliberate device-local exceptions. At the prototype's pinned revision, Omarchy uses a valid personal shell.json as a complete replacement for defaults and persists the complete configuration. This can unintentionally freeze unrelated defaults on a customized device. The earlier suggestion to preserve Omarchy's replacement semantics was not accepted. DEC-024 established ownership but left combination semantics open.
- **User Response**: After describing the multi-device workflow and reviewing the proposed model: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Use version-controlled common MirrorOS defaults plus small, explicit local overrides per option. Uncustomized options follow current common defaults; customized options retain the user's choice; removing an override restores the current default. Replace lists, such as bar layout, as complete values rather than merging their elements. Persist personal choices without copying unrelated effective defaults into the user configuration. Promote experimental changes into common repository defaults only through an explicit, reviewed operation, manually or with agent assistance, not automatically from interface changes. Review versioned changes before application; configure converges MirrorOS-owned files while preserving local overrides and reports conflicts in manually modified managed files rather than silently overwriting them. This is an intentional, bounded deviation from Omarchy's full-file semantics, justified by multi-device evolution and reconstruction. It does not introduce a universal configuration schema, synchronization service, promotion command or new configuration manager. Exact paths, format justification and implementation remain to be specified.
- **Status**: Accepted

## DEC-026
- **Question**: Does aligning Story 4.3's color criterion with the accepted prototype direction require a new ADR?
- **Context/Nuances**: DEC-015 already approves Omarchy-style color-only visual states. The unchanged Story 4.3 criterion in docs/epics.md conflicts with that direction. The maintainer challenged the proposed ADR because this adjustment changes a story acceptance criterion, not architecture or an existing ADR. The assistant withdrew the unnecessary ADR recommendation. Future panel expansion remains different because it changes ADR 0012's explicit scope.
- **User Response**: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Update Story 4.3's color criterion directly in docs/epics.md, with traceability to DEC-015, without creating a new ADR. Include corresponding test/documentation alignment in the production plan. Preserve the prototype's historical deviations and actual results rather than retroactively claiming compliance. Do not change installer, CLI or verification requirements. This registration records the agreed planning approach; the story edit itself remains part of the future production work.
- **Status**: Accepted

## DEC-027
- **Question**: How should the shared menu handle replacing an active selector request with a new selector request or a regular menu?
- **Context/Nuances**: This is distinct from the selection-identity defect repaired at 6d7314f, where changing row availability could redirect Enter to another action. In the delivered Menu.qml, openDmenu overwrites request data and openExistingMenu clears it without first completing the active external request. Its caller may wait indefinitely because finishRequest was not called. The maintainer requested this distinction before approving the policy.
- **User Response**: After the separate defects and proposed cancellation behavior were explained: "yes, registra directamente la decisión en los artefactos."
- **Decision**: Before replacing an active selector with another selector request or a regular menu, complete the old request as cancelled and communicate its termination to the requester, without executing its selected action. Keep one active request rather than introducing a request queue or changing appearance. Implement and test cancellation/result delivery so the new request cannot overwrite or lose the old completion. Preserve the existing selection-identity repair and its regression coverage; do not treat this decision as reopening that repaired defect. This records the production behavior to implement, not a claim that the prototype is already fixed.
- **Status**: Accepted

## DEC-028
- **Question**: What dependency should the production plan declare, and should it be materialized directly?
- **Context/Nuances**: Plan 02-19 consumes the verified source and findings of 02-18, which already depends on the development workbench. The proposed production scope has three blocks: runtime and agreed corrections, configure/session integration, and clean-VM/idempotency/attended validation. Existing prototype choices are inherited rather than reopened; later-story panels and global coherence remain excluded.
- **User Response**: "si, confirmo...ve directamente a la materializacion, saltando el borrador, de manera que no consumimos contexto."
- **Decision**: Use the sole direct dependency 02-18-desktop-shell-guest-prototype for plan 02-19. Authorize direct materialization without an in-chat draft or another draft-approval turn. Materialize .agents/plans/02-19-desktop-shell-production.md after reference compliance checks. This authorizes planning artifacts, not implementation execution, publication or disruptive operations. Preserve approved guest choices and the conditional status of the while-away count.
- **Status**: Accepted

## Production execution checkpoint — 2026-10-25

This is execution context for plan 02-19 Task 3, not a new architecture decision or final acceptance. Tasks 1/2
were accepted; Task 3 remains in progress. Exact authorizations and original child outcomes are in the local
execution log; retained, scanned evidence is under
`evidence/desktop-shell-production/candidate-20261025T032813Z-amended/`.

- Clean product candidate: `8c3c3cccc46421598b1fce47a330452c78230a80`. Reconstruction used an independently
  verified base ISO plus explicit candidate input, not an unchanged final-source release ISO. Target configure
  passed; first running changed Hyprland only; identical second running changed nothing. The first rewrite's
  cause is unknown, and the maintainer reported opening the file without modifying it.
- Do not repeat supervised prototype-choice approvals (DEC-019). Earlier laboratory provider installations are
  drift, not production ownership. Clean-reference diagnostics are new verification outcomes, not inherited
  passes or blanket exceptions.
- Maintainer-attended help, Foot, menus, focus/swap, floating/fullscreen, Alt+Tab, workspaces, scratchpad,
  split/grouping, us/es and Compose checks passed for the specifically exercised chords. This is not exhaustive
  standard-keyboard, multi-output or hardware qualification.
- Explicit lock from es, deliberate wrong-password rejection and private unlock returned to us. Shell-only
  restart while locked preserved the lock and hypridle. Repeated idle locks were observed, but exact timing and
  idle-from-es reset are still unverified; no credential or private notification content was retained.
- Corrected named synthetic production counter test passed: count 0 -> 2 across a shell restart during lock,
  then 0 after history expansion/panel close. Keep the accepted reset-on-panel-close deviation and capped badge.
  Earlier notify-send stimuli were deliberately ephemeral; another pasted test exited 127; a later run blocked
  while already locked. Those outcomes remain recorded, not retroactively passed.
- Installed QML checker passed its reviewed baseline: 57 files/829 warnings, no new or stale keys. Original
  graphical quiet-log failures remain failures. Authorized diagnostic-only test copies completed sparse/default/
  reset/invalid-file and notification restoration/argv/privacy/retention assertions without suppressing diagnostics;
  both complete suites still exited 1 on quiet checks. No later-story provider was installed to force success.
- Native reload was specifically authorized. Its first precondition stopped before reload because the session
  file differed. The maintainer identified their local QEMU display adjustment; a narrow diff showed only
  `Virtual-1`, `1920x1080@60.00`, scale `1.2`. The adjustment was preserved. One actual native reload then passed
  with 116 bindings/110 unique registry matches, no errors or process restart; help/Foot worked afterwards.
- Native `Terminal=true` via uwsm opened Foot with a real TTY and no foot-server. Earlier launches were not seen
  while locked or unattended. The final explicitly requested launch and automatic close were confirmed visually.
- The maintainer requested temporary idle inhibition for attended checks. A specifically authorized unprivileged
  systemd idle inhibitor had a 60-minute maximum, changed no timeout and left explicit lock available. Its absence
  was later confirmed; it was not silently renewed.
- One separately authorized SIGKILL of the shell main process recovered automatically with exactly one restart,
  ready IPC and unchanged compositor/hypridle. The maintainer confirmed the bar and root menu recovered.
  Restart-limit exhaustion was not tested.
- One attended System logout/login was specifically authorized. At SDDM, graphical target/shell/hypridle were
  inactive and selected-user process counts were zero. Private login started exactly one of each with no errors
  or restarts; the registry matched the new instance. Expired SSH and a premature snapshot while still at SDDM
  were retained as access/precondition failures, not session-start defects. No password capture occurred.
- Both SUPER+left drag and SUPER+right drag still fail. Quiet-runtime PipeWire/UPower/portal diagnostics remain
  unresolved under Stories 4.4/4.5 ownership. No scoped exception or final Task 3 A/B review has been accepted.
  Preserve pending tray/output/keyboard coverage, upstream warnings and original suspend failure; no publication,
  laptop migration or complete Story 4.3 readiness is authorized by these bounded passes.

## DEC-029
- **Question**: Should the failed mouse-drag checks be repeated in the reference VM without a new diagnostic hypothesis?
- **Context/Nuances**: Both SUPER+left drag (move) and SUPER+right drag (resize) failed in the supervised prototype and final-source reference; keyboard resizing works. Earlier guest investigation suggested a QEMU/VM relationship but did not demonstrate causality or a safe fix. Repeating the same interaction merely to seek a pass would add no evidence. The proposed exception was limited to the VM, retaining a failed result and pending comparative hardware qualification.
- **User Response**: The maintainer recalled the guest investigation and asked whether repeating it was worthwhile, then answered "yes" to documenting the bounded exception and not repeating the test now.
- **Decision**: Accept a reference-VM-only mouse-drag exception and defer further identical retesting until a concrete new hypothesis or a comparative hardware scenario exists. Keep both drag checks classified as failed, not passed. Treat QEMU involvement as plausible but unproven; do not claim that physical hardware works. Carry comparative qualification as pending, without authorizing laptop migration or hardware operations. This exception neither accepts quiet-runtime diagnostics nor waives other unresolved checks or grants final Task 3/Story 4.3 acceptance.
- **Status**: Accepted

## DEC-030
- **Question**: How should final-source quiet-log failures caused by not-yet-delivered PipeWire, UPower and portal providers be reviewed without expanding Story 4.3?
- **Context/Nuances**: The clean reference lacks these later-story providers. Original graphical suites fail their quiet-log checks; authorized diagnostic-only continuations completed functional assertions but still exited 1. Production journal review confirmed the provider diagnostic categories, not merely private-bus fixture artifacts. Historical laboratory package installations do not qualify production ownership or waive current failures.
- **User Response**: The maintainer answered "yes" to a temporary exception limited to those absent-provider diagnostics, retaining visible failures and requiring review of any new diagnostic.
- **Decision**: Accept a temporary Story 4.3 verification exception only for the observed PipeWire context, unavailable UPower and portal warnings attributable to providers not yet delivered by Stories 4.4/4.5. Preserve original suite exit 1, raw diagnostic outcomes and explicit unavailable capability states; do not suppress logs, mark whole suites green or install later-story providers to satisfy the tests. Revisit the exception when the owning providers are delivered. New diagnostics, unrelated runtime defects and the reviewed QML baseline are outside this exception. Private-bus inability to activate the real user manager remains a fixture limitation, not production readiness evidence. This does not grant final Task 3 acceptance, full-MVP readiness or hardware qualification.
- **Status**: Accepted

## Final plan 02-19 Task 3 review

The maintainer selected A (Accept) after reviewing the bounded final-source evidence, DEC-029/030 exceptions and
explicit unverified checks. This accepts the execution result, not complete Story 4.3, full-MVP or laptop
readiness. Exact idle timing/from-es linkage, remaining keyboard/tray/output coverage, actual restart-limit
exhaustion and changed-runtime live reload were not verified; no implicit passes are recorded. Existing
explicit-lock and observed idle-lock tests must not be repeated just to fill a historical evidence detail.
Publication and target-laptop migration remain separate operations. The plan SUMMARY preserves the three task
outcomes and future work; plan status is left for the maintainer to change.
