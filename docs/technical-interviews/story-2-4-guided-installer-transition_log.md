# Story 2.4 — Guided Installer Transition: Decision Log

## DEC-001
- **Question**: How should the new plan relate to plan 02-06 and its existing implementation?
- **Context/Nuances**: Execution of 02-06 stopped at Task 7 after the maintainer found that the rendered interface did not match the desired experience and developed an alternative prototype. Existing work is not completed qualification, and its execution history must remain intact.
- **User Response**: Approved replacing the previous interface direction while preserving reusable work.
- **Decision**: Replace the interface direction of 02-06 without continuing its execution to Task 8 or treating it as completed. Preserve and assess existing discovery, planning, validation, digests, safety comparisons, and evidence machinery for reuse. Distinguish implemented behavior from behavior that has not yet been qualified. Preserve previous execution records and do not discard existing implementation changes.
- **Status**: Accepted

## DEC-002
- **Question**: How closely must the MirrorOS live installer reproduce the prototype?
- **Context/Nuances**: The maintainer successfully tested all prototype screens in the Omarchy ISO. This is attended usability evidence for the prototype, not qualification of its integration into MirrorOS. Fidelity concerns the observable experience, not copying Omarchy's internal implementation. Prototype functionality must be reconciled with real MirrorOS components and safety guarantees.
- **User Response**: Approved faithful reproduction of the prototype, necessary preparation of the MirrorOS ISO, and individual review of functionality integration.
- **Decision**: Use `tmp/mirroros-ux-demo/omarchy-style/` as the reference for the interactive installer's visual style and workflow: screens, order, text, navigation, layout, logo, colors, and widget behavior. Do not replace it with a merely equivalent interface. Account for preparation of the MirrorOS live ISO needed to reproduce that experience. Review each prototype functionality with the maintainer before agreeing its integration. Explain and obtain explicit approval for any necessary difference, while preserving safety guarantees. Verify the integrated experience on the MirrorOS ISO.
- **Status**: Accepted

## DEC-003
- **Question**: Should end users select a machine profile, and may unqualified machines attempt installation?
- **Context/Nuances**: Existing targets combine qualification identity with installation admission. Passing technical checks does not establish full hardware compatibility. The previous scope excludes hardware beyond the reference VM and Framework laptop, so this direction requires formal scope and normative-document review rather than merely removing a menu.
- **User Response**: Approved internal profile identification and experimental installation on unqualified machines without a compatibility guarantee or support commitment.
- **Decision**: End users do not select a machine profile. MirrorOS checks technical requirements and identifies known profiles internally. Retain profiles for qualification, evidence, and machine-specific adjustments, applying adjustments only when the identified machine matches. Unqualified machines may proceed through an explicitly experimental path without a compatibility guarantee or support commitment. All machines retain the same safety guarantees; no requirement bypass is introduced. Checked requirements and qualified hardware remain distinct claims.
- **Status**: Accepted

## DEC-004
- **Question**: Does password collection belong to the interface, and should this delivery collect real passwords before the installation engine exists?
- **Context/Nuances**: Presentation and consumption are separate responsibilities: the guided interface requests and confirms a password through a protected prompt, and the engine consumes it through a protected runtime channel without providing its own interaction model. Collecting a real password without a real consumer introduces secret handling with no installation benefit. Deferring collection is a temporary, explicitly approved adaptation of the reference workflow, not removal of the password step from the intended experience.
- **User Response**: Accepted the recommendation to define the interface and delivery contract now, activate real collection with the engine, and directly register the decision ("tu recomendacion mejor...agrega directamente la decision").
- **Decision**: Define the real password screen and its protected delivery contract in this plan. Activate real password collection when the installation engine is connected in Story 2.5. Until then, retain an explicit explanatory screen without requesting a password value. The interface owns protected password entry and confirmation; the engine only consumes the runtime input. Password values must never enter installation plans, process arguments, logs, or retained evidence. This decision does not settle the separate account-policy question of whether user and root share a password.
- **Status**: Accepted

## DEC-005
- **Question**: Should the user and root have separate password requirements or share the password as proposed by the prototype?
- **Context/Nuances**: The current installation plan declares user_password and conditional root_password separately. The prototype defaults to locked root with administration through sudo, and reuses the user's password if root password access is enabled. A shared password is not an independent recovery credential. Actual collection remains deferred under DEC-004.
- **User Response**: Approved the proposed account policy and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Keep root locked by default and retain user administration through sudo. When root password access is enabled, assign root the same password as the user, without requesting a separate root password. Represent one account-password requirement in the installation plan with the user-account operation as a consumer and the root-account operation as an additional consumer only when root password access is enabled. The plan contains no password value. Explain that sharing the password does not provide an independent recovery credential. Update the affected contracts, generation, validation, review, and tests consistently; the exact requirement identifier is not selected by this decision.
- **Status**: Accepted

## DEC-006
- **Question**: Should system language, regional formats, and keyboard remain separate choices, with required locales derived automatically as in the prototype?
- **Context/Nuances**: The current installation plan models lang and locales but does not declare separate regional formats. The prototype offers English (US) and Spanish (Spain) as system languages, and regional formats that follow the system language or explicitly use Spain or the United States. Its required locales are the unique union of the language and formats locales. Regional behavior must be represented and validated in the real plan rather than implemented only in presentation code.
- **User Response**: Approved the behavior exactly as in the prototype and requested direct registration ("yes, tal cual el prototipo, agrega directamente la decision").
- **Decision**: Preserve separate system-language, regional-formats, and keyboard choices. Regional formats initially follow the system language and continue to follow subsequent language changes unless an explicit regional choice is selected. Preserve the prototype's language and regional options. Derive the required locales automatically as the unique union of the language and formats locales, without asking users to manage a technical locale list. Apply the formats locale to LC_TIME, LC_NUMERIC, LC_MONETARY, and LC_MEASUREMENT; other categories inherit LANG, and LC_ALL is not set. Declare and validate the regional selection and its resolved effects in the installation plan, aligning policy, resolution, generation, validation, rendering, documentation, and tests. Applications may use their own preferences or ignore these settings. The concrete new field names and format compatibility strategy are not selected by this decision.
- **Status**: Accepted

## DEC-007
- **Question**: Should the welcome screen allow changing the live console keyboard independently of the installed-system keyboard?
- **Context/Nuances**: The prototype offers a live keyboard adjustment from the welcome screen and a separate installed-system keyboard step. Changing the live keymap affects virtual consoles in the live session, not the installation disk. The privilege boundary must remain narrow rather than running the entire guided flow as root for convenience. Clear wording is necessary to avoid conflating the two settings.
- **User Response**: Approved the prototype behavior and requested direct registration. Authorized the implementer to recommend wording improvements when needed so users remain aware of the distinction.
- **Decision**: Preserve the prototype's welcome-screen live keyboard adjustment and its separation from the installed-system keyboard choice. The live setting facilitates input and affects only the live session's virtual consoles; it does not automatically change the installed-system keyboard choice. Cancelling installation does not revert the live console adjustment and does not imply that the installation disk was modified. Use narrowly scoped privileges for the adjustment, not a root session for the entire assistant. The implementer may propose wording improvements that make the live-versus-installed distinction clearer; necessary deviations from reference text remain subject to explicit approval under DEC-002.
- **Status**: Accepted

## DEC-008
- **Question**: Should live network preparation follow the prototype's automatic check and Ethernet/Wi-Fi guidance?
- **Context/Nuances**: The prototype checks connectivity before proceeding, skips connection-method selection when connectivity is already available, and otherwise offers Ethernet guidance or Wi-Fi instructions using iwctl in another live console. Preparing the live environment must remain separate from configuring the installed system. Discovery remains authoritative for its connectivity requirement.
- **User Response**: Approved the behavior exactly as in the prototype and requested direct registration ("yes, tal cual el prototipo, agrega directamente la decision").
- **Decision**: Preserve the prototype's live connectivity preparation: check the connection, proceed without a connection-method question when it works, and otherwise offer Ethernet guidance or instructions for configuring Wi-Fi with iwctl in another console, with connection retries. Prepare only the live environment. Do not request or retain Wi-Fi credentials in the assistant, installation plan, or evidence, and do not copy live connections into the installed system. The preparatory check and guidance do not replace discovery's authoritative connectivity validation.
- **Status**: Accepted

## DEC-009
- **Question**: Which existing checks should govern machine admission independently of qualification profiles?
- **Context/Nuances**: Discovery already checks x86_64 architecture, UEFI-related conditions, connectivity, and eligible disks. The discovery policy sets a 20 GiB minimum disk size, and planning additionally checks whether the complete layout fits. These real checks are distinct from the prototype's synthetic presentation. The maintainer raised a concern about the live system clock and Arch Linux installation guidance affecting package retrieval; its relevance and responsibility assignment require verification and are not decided here.
- **User Response**: Approved retaining the proposed technical admission base and requested direct registration. Asked to verify the clock concern against Arch Linux guidance rather than assume whether it is a requirement or a discovery responsibility.
- **Decision**: Retain existing technical and safety checks as the admission base while separating them from profile identity. Failure to identify a known profile leads to the experimental path rather than blocking admission. Profiles with pending identity capture are not considered identified and cannot enable profile-specific adjustments. Preserve existing warnings and layout-fit validation. Do not introduce arbitrary RAM, CPU, or GPU requirements in this transition. Passing these checks does not guarantee hardware compatibility. The clock concern remains unapproved as an implementation change pending source verification.
- **Status**: Accepted

## DEC-010
- **Question**: Can the installer rely on the live ISO's enabled time synchronization rather than configure it again?
- **Context/Nuances**: The Arch Linux Installation Guide states that accurate live system time prevents package signature verification failures and TLS certificate errors, and recommends checking synchronization with timedatectl (https://wiki.archlinux.org/title/Installation_guide#Update_the_system_clock). The MirrorOS image profile already enables systemd-timesyncd through sysinit.target.wants. Enabled service configuration does not establish successful runtime synchronization, which depends on connectivity and time-server availability. An inaccurate clock can also cause the HTTPS connectivity probe to fail. Live clock readiness is distinct from installed-system timezone selection.
- **User Response**: Asked whether the prepared ISO's activation could be trusted, then approved relying on that activation with a brief bounded runtime check and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Rely on the live ISO to enable automatic time synchronization and verify that preparation during image build and qualification. Do not add a clock configuration screen or reactivate the service from the assistant. Check runtime synchronization briefly with a bounded wait during live preparation; present help only when readiness cannot be established, with retry or cancellation rather than silently proceeding. Distinguish clock-related failures from generic network failures and account for their effect on HTTPS probes. Keep discovery read-only: any observation or recording of clock state must not configure the clock. Do not bypass TLS or package signature verification. This preparation is independent of the installed-system timezone choice; the exact check interface and wait bound are not selected here.
- **Status**: Accepted

## DEC-011
- **Question**: How should users inspect the complete installation plan without turning the prototype's compact review into a technical dashboard?
- **Context/Nuances**: The prototype review already contains thirteen value rows in addition to its eight-row logo, margins, title, explanatory text, and navigation. Simultaneous fit within 80x25 has not been established. The maintainer does not require that fit for now and prefers a pager for optional full-plan inspection. A search defect was previously observed in gum pager, so approving a pager does not select that implementation.
- **User Response**: Approved the registration and requested direct addition ("yes, agrega directamente la decision").
- **Decision**: Preserve a compact guided review and provide optional complete-plan inspection through a pager. Leaving the pager returns to the review without losing answers or granting authorization. The detail includes disk identity and current layout, all resolved options with provenance and source, destructive operations, warnings, secret requirements without values, and the plan reference. Present the digest as a plan reference rather than asking users to memorize or type it. Do not impose complete 80x25 fit for now. The concrete pager remains to be selected after checking its behavior, including the previously observed gum pager search defect.
- **Status**: Accepted

## DEC-012
- **Question**: Should gum pager adoption depend on verifying or fixing its previously observed search defect?
- **Context/Nuances**: DEC-011 approved optional complete-plan inspection through a pager but left the implementation open. The prototype already uses gum pager for Wi-Fi instructions. The maintainer explicitly accepts the previously observed search limitation and rejects a dedicated pager qualification test as an adoption gate. Assistant safety behavior remains distinct from pager feature qualification.
- **User Response**: Requested using gum pager even if the defect persists, without a specific test, then approved the registration ("si").
- **Decision**: Use gum pager for complete-plan inspection even if the previously observed search defect persists. Do not require a dedicated pager test or make adoption conditional on fixing that defect. Accept the search limitation rather than developing or substituting another pager. Preserve assistant safety tests: inspecting the plan grants no authorization, and leaving the pager preserves answers. This decision resolves the concrete pager selection and removes the conditional feature-verification gate previously left open in DEC-011.
- **Status**: Accepted

## DEC-013
- **Question**: How should the prototype's simulated confirmation become real authorization of destructive installation operations?
- **Context/Nuances**: The prototype does not authorize anything. The existing confirmation implementation binds approval to the plan digest and concrete disk, asks for an explicit safe-default confirmation and the device name, then revalidates. The digest is an automatic integrity binding, not text the user must type. Replacing the simulation with these real safeguards is an approved functional integration while retaining the prototype's presentation style.
- **User Response**: Approved the two-step confirmation and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Display the disk to be erased and the plan reference. Require confirmation with No initially selected, followed by entry of the kernel device name, such as vda or nvme0n1. A wrong device name cancels without an in-run retry. Do not require typing the digest. Revalidate the disk and plan after confirmation and before engine hand-over. Preserve the prototype's visual style while replacing its simulated confirmation with this real, target- and digest-bound authorization.
- **Status**: Accepted

## DEC-014
- **Question**: How should Back, Esc, and cancellation behave across configuration, plan inspection, and real authorization?
- **Context/Nuances**: The prototype uses backward navigation that retains confirmed answers. Real authorization has stricter semantics than ordinary configuration widgets. The maintainer also noted that the interface interacts with installation phases that can fail; this concern requires a separate failure-handling decision and is not resolved by navigation rules.
- **User Response**: Approved the proposed navigation and cancellation rules and requested direct registration. Asked whether the installation phases invoked by the interface can fail.
- **Decision**: In configuration steps, Back or Esc returns without applying an incomplete answer and preserves previously confirmed answers. Leaving the pager returns to review. Cancel or Ctrl+C during interaction exits with status 3 without installation-disk operations. In real authorization prompts, No or Esc cancels rather than navigating backward. Changes made after navigating back require generation and review of the updated plan before confirmation. These authorization-specific Esc semantics preserve the existing confirmation safety guarantees.
- **Status**: Accepted

## DEC-015
- **Question**: How should the guided interface handle failures in installation phases before execution?
- **Context/Nuances**: Live preparation, discovery, planning, and revalidation can fail for different reasons. Components remain authoritative for their validation and failure results; the interface cannot ignore checks or turn failures into success. A future engine failure may leave partial changes and cannot be handled as ordinary backward navigation.
- **User Response**: Approved the proposed pre-execution failure policy and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Present the failed phase, cause, and next action using the assistant's style. Allow correction or retry when the component indicates a recoverable problem, retaining only answers that remain valid. Stop on unexpected failures and retain diagnostics in evidence. A disk or plan change invalidates approval and requires renewed review and confirmation. Keep failure and invalidation distinct from explicit cancellation, which exits 3. Handling partially executed installation belongs to the engine and is not a simple Back action in the assistant.
- **Status**: Accepted

## DEC-016
- **Question**: What public command should launch the complete guided installation experience?
- **Context/Nuances**: The maintainer previously questioned the name apply because the command represents a guided installation experience rather than only execution of a prepared plan. The live medium already exposes mirroros-install as a symlink to operations/install. Technical discovery and planning entry points remain useful independently of the interactive assistant.
- **User Response**: Approved the proposed entry point and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Launch the assistant through mirroros-install without a subcommand, corresponding to operations/install in the repository. Preserve discover and plan as independently invocable technical subcommands. Keep --help non-interactive and free of assistant startup effects. Compatibility handling for the existing apply subcommand is not settled by this decision.
- **Status**: Accepted

## DEC-017
- **Question**: Should the existing public apply subcommand remain as a compatibility alias for the guided installer?
- **Context/Nuances**: Public apply belongs to the not-yet-qualified implementation from 02-06. DEC-016 selects mirroros-install without a subcommand as the guided entry point. The internal engine path serves a different responsibility: applying a validated plan, not presenting the guided experience.
- **User Response**: Approved removing the public subcommand without an alias and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Remove the public apply subcommand without a compatibility alias. Use mirroros-install as the assistant entry point and update help, procedures, and qualification references accordingly. This does not rename the internal install/engine/apply boundary, whose name correctly describes plan execution.
- **Status**: Accepted

## DEC-018
- **Question**: How will the password interface interact with the future installation engine?
- **Context/Nuances**: The maintainer questioned whether the engine would start, request a password from the interface, and then resume. The plan already declares required runtime secrets, so the interface can prepare them before execution. Final revalidation must account for time spent entering a password. The engine must not own prompts or trigger a back-and-forth interaction protocol.
- **User Response**: Confirmed understanding that Story 2.5 replaces the explanatory screen with real input and a protected channel, accepted the proposed separation, and requested direct registration.
- **Decision**: The assistant collects choices, generates and reviews the plan, obtains destructive-operation confirmation, then requests and confirms the password once real installation is available. It revalidates the disk and plan after password entry and invokes the engine once for execution with the plan and protected runtime inputs. The engine consumes inputs without issuing password prompts or returning control to request them. Cancelling password entry prevents engine startup. Passwords are not passed in arguments or environment variables and are not retained in plans, logs, or evidence; the concrete protected-channel implementation remains to be defined. In this delivery, retain an explanatory password screen and the engine-unavailable boundary without collecting secrets, implementing the engine, or performing installation-disk operations. Story 2.5 activates real input and connects its protected channel to the engine.
- **Status**: Accepted

## DEC-019
- **Question**: Should the guided installer retain an optional entry point for an existing installation plan?
- **Context/Nuances**: The habitual flow starts from choices collected through the prototype's screens. The existing --plan option is useful for inspection, tests, and qualification of valid, tampered, or stale plans. A persisted plan contains neither secret values nor reusable authorization, and must not be silently adapted to a different machine or state.
- **User Response**: Requested clarification, then approved retaining the technical option and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Retain mirroros-install --plan <file> as an optional technical entry point. Check the live environment, validate the plan, and compare it with fresh discovery before entering review without repeating all configuration questions. Reject plans that no longer correspond to the current disk, machine, or policy rather than silently adapting them. Preserve the original file. Any edit generates a new plan and requires renewed confirmation; a valid unchanged plan also requires fresh confirmation. Keep mirroros-install without a subcommand or --plan as the habitual complete guided experience.
- **Status**: Accepted

## DEC-020
- **Question**: How should installation-plan format compatibility be handled after introducing regional formats and a shared account-password requirement?
- **Context/Nuances**: These changes alter the content and semantics of the current installation-plan contract. Reusing its format version would silently give the same version different meanings. Automatic conversion could change prior decisions without informed review. This concerns installation-plan documents, not the separate requirement to retain readability of legacy workflow plan files.
- **User Response**: Approved a new contract version and regeneration of old installation plans, and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Introduce a new installation-plan contract version for the revised model. Newly generated plans declare that version explicitly. The --plan entry point rejects older installation-plan versions with a clear instruction to regenerate them. Do not automatically migrate old plans or reinterpret the existing version. Align contracts, generation, validation, and fixtures with the new version, and require the assistant and future engine to share that contract.
- **Status**: Accepted

## DEC-021
- **Question**: How should automatic machine discovery coexist with explicit profile checks used by tests and qualification?
- **Context/Nuances**: The guided flow no longer asks users to select a profile, but discover --target <id> remains useful for strict checks on qualification machines. Automatic identification requires verifiable matches and must not guess identities that remain pending capture. Profile identification does not itself establish qualification evidence for an individual machine.
- **User Response**: Approved the proposed automatic mode and optional explicit profile check, and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Add discovery without --target to inspect the machine, identify a known profile when a verifiable match exists, and report an unqualified machine otherwise. Preserve --target <id> as an optional technical assertion: the machine must match the requested profile and a contradiction remains an error. Do not infer profiles with pending identity capture or apply their specific adjustments. Use automatic discovery for the habitual guided flow while retaining strict explicit assertions for tests and qualification.
- **Status**: Accepted

## DEC-022
- **Question**: How should discovery documents represent machines that do not match a known profile?
- **Context/Nuances**: The existing target-facts contract binds source metadata to a target_id. Making the CLI argument optional alone does not provide a sound representation of unknown machines. Machine identity, profile identification, and qualification claims are distinct, while confirmation must remain bound to the actual machine and disk.
- **User Response**: Approved the separation and new facts format, and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Represent the actual inspected machine identity and facts independently of an optional identified profile. Explicitly represent the unqualified condition when no profile matches. Do not invent a generic profile merely to satisfy existing validators. Keep planning and confirmation bound to the real machine and disk even without a profile. Introduce a new target-facts contract version rather than silently reinterpreting the current version, and update its consumers together. Concrete new field names are not selected by this decision.
- **Status**: Accepted

## DEC-023
- **Question**: How should the prototype be preserved as a stable implementation and fidelity reference?
- **Context/Nuances**: The prototype resides under tmp/ and the guest presentation extracts a function from the Omarchy ISO's /root/configurator. A repository copy alone does not guarantee standalone execution. Synthetic fixtures are presentation data, not discovery or authorization evidence. Reference preservation is separate from production integration and must retain attribution.
- **User Response**: Requested clarification, then approved the proposed reference copy and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Preserve a versioned reference under prototypes/frontend/guided-installer/ while leaving the original tmp/ prototype intact. Include relevant sources, logo, instructions, synthetic fixtures, tests, and existing licenses and attribution; exclude personal paths, credentials, and generated outputs. Document the Omarchy dependencies and the maintainer's attended prototype trial without claiming that the copy is standalone or that MirrorOS integration is qualified. Production remains under install/, reproduces the reference experience through real components, and must not source prototype code or depend on the Omarchy configurator.
- **Status**: Accepted

## DEC-024
- **Question**: Should the recognized-profile and experimental admission paths both be verified on real virtual machines?
- **Context/Nuances**: Fixtures alone do not demonstrate that unknown machine identity no longer blocks admission without weakening safety. A second VM identity can exercise the experimental path without a physical-machine run or a support commitment. This delivery does not execute a real installation.
- **User Response**: Approved verification of both paths and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Verify two real VM situations: a machine matching reference-vm and a machine with a different identity that matches no known profile but passes technical requirements. Check review, confirmation, cancellation, and invalidation in both paths without executing a real installation. Do not infer physical-hardware qualification or broader support from these runs. The exact VM identity configuration and evidence matrix remain implementation details to define.
- **Status**: Accepted

## DEC-025
- **Question**: Should the live installer use the standard Arch live-root model instead of introducing an unprivileged live account?
- **Context/Nuances**: The current architecture says lifecycle orchestration begins unprivileged and stages elevate independently. Applied literally to a root live console, this would require additional privilege machinery not present in the reference experience. The maintainer requested correcting the overly broad rule; its original intent is not assumed. This changes only the live installer privilege boundary, not every lifecycle command. The maintainer also noted that mirroros-install must have executable permissions on the live medium.
- **User Response**: Approved the live-root model, its architectural formalization, and the consolidated update, and requested direct registration. Raised the need for executable permissions for mirroros-install in the live ISO.
- **Decision**: Keep the live session and guided installer running as root, consistent with the Arch live ISO and prototype. Do not introduce an additional live account or artificial elevation between installer phases. Root privileges do not authorize destructive operations: retain validated planning, explicit confirmation, and revalidation. Installed-user configuration must not inherit root privileges for convenience. Do not automatically change build or other command privilege boundaries. Formalize this distinction through a new ADR and update the architecture. Supersede only DEC-007's narrowly scoped live-keyboard elevation requirement; retain its separation of live and installed keyboard settings. Ensure the live command and its executable entry-point targets have appropriate executable modes; this does not require setuid or a new elevation grant.
- **Status**: Accepted

## DEC-026
- **Question**: Should accepting an unchanged proposed value through an interactive screen turn it into an explicit user choice?
- **Context/Nuances**: The guided flow presents every configurable value, but passing through a widget alone does not mean the value originated from the user. Existing plans distinguish policy, detection, profile overrides, and explicit choices. Losing this distinction would weaken the explanation of defaults.
- **User Response**: Approved preserving the origin of unchanged proposals and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Advancing through a configuration screen without changing its proposed value preserves the proposal's provenance and source, whether policy, detection, or a profile-specific adjustment. Record modifications as user choices. Do not relabel every displayed value as user-selected merely because it was accepted through an interactive widget.
- **Status**: Accepted

## DEC-027
- **Question**: Should this delivery implement a separate colorless presentation instead of focusing on the prototype's colored live-console experience?
- **Context/Nuances**: The maintainer wants the experience tested in Omarchy and does not want unnecessary alternative interfaces for a personal distribution. The prototype sets the Tokyo Night VT palette and forces color. Reviewed Omarchy source at commit 8b17699997460b260e2320807602f50025cd3b4e (configs/airootfs/root/.automated_script.sh and configurator) sets the palette and CLICOLOR_FORCE/FORCE_COLOR without a dedicated NO_COLOR or TERM=dumb presentation path in those files. This was a source review, not extraction or execution of the exact tested 4.0.4 ISO. Existing MirrorOS architecture and ADR 0004 promise broader terminal behavior and therefore require explicit normative reconciliation.
- **User Response**: Approved focusing on the colored interactive live console without an additional colorless variant and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Scope this delivery's guided presentation to the colored interactive console of the live ISO, reproducing the reference experience. Do not implement an additional colorless presentation profile. Clearly reject terminals outside that scope rather than attempting an unqualified alternative or confirming automatically; missing interactive terminals remain a hard failure. Formally reconcile the narrower live-installer scope with the existing terminal and Gum-wrapper requirements through the applicable ADR and normative-document review. Do not silently ignore those requirements or claim unsupported terminal modes are qualified.
- **Status**: Accepted

## DEC-028
- **Question**: Should the live ISO start the guided installer automatically on its first console?
- **Context/Nuances**: Omarchy starts its interactive flow from the first console, while the existing MirrorOS profile retains the usual shell entry. Automatic assistant startup is not authorization to modify disks. Qualification must coordinate startup rather than accidentally run two assistants at once.
- **User Response**: Approved automatic welcome startup on the first console and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Automatically open the assistant's welcome screen on tty1 when the live ISO starts. Cancellation returns control to the shell, and mirroros-install can start the assistant again. Keep other consoles available for Wi-Fi setup, diagnostics, and recovery. Starting the assistant grants no authorization for installation-disk operations. Coordinate automated qualification with this startup so it does not launch concurrent assistants.
- **Status**: Accepted

## DEC-029
- **Question**: When should the guided workflow generate and regenerate installation plans?
- **Context/Nuances**: The prototype collects answers before presenting review. Generating a plan for every screen would introduce unnecessary intermediate artifacts. Individual-value validation and complete-combination validation are distinct responsibilities, and invalid regeneration must never replace a valid reviewed plan or grant approval.
- **User Response**: Approved the proposed generation timing and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Collect answers while validating each step's values, then generate the first installation plan when entering review and validate the complete combination there. After backward navigation and answer changes, generate a new plan version before review and confirmation. If the combination is invalid, present the cause and allow correction without replacing the last valid plan or authorizing anything. Do not generate intermediate plans merely for passing through each configuration screen.
- **Status**: Accepted

## DEC-030
- **Question**: Should new run evidence retain apply-oriented filenames after removing the public apply command?
- **Context/Nuances**: The current records use apply-run.json and apply.log. Public interaction is now mirroros-install, while internal engine application retains its separate boundary name. Historical evidence must not be rewritten to resemble the new contract.
- **User Response**: Approved install-oriented names for new evidence and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Use install-run.json and install.log for new guided-installer runs. Retain approval-record.json as non-authorizing evidence, initial/final discovery artifacts, and numbered plan directories. Preserve private directory/file permissions, ANSI-free logs, and exclusion of secret values. Do not rename or transform historical evidence. Update contracts, tests, and qualification together with the new evidence names.
- **Status**: Accepted

## DEC-031
- **Question**: Should the implementation be split into separate foundations and guided-installer plans, or remain one complete transition with internal checkpoints?
- **Context/Nuances**: The scope includes normative changes, versioned facts and plan contracts, automatic discovery, planning, guided presentation, live ISO preparation, and VM qualification. Separate plans could isolate contract migrations but would leave the visible experience for another delivery. Internal checkpoints can retain one coherent objective while reviewing foundational changes before integration.
- **User Response**: Approved one plan with internal checkpoints and requested direct registration ("yes, agrega directamente la decision").
- **Decision**: Deliver the complete transition in one implementation plan with separate tasks and blocking internal checkpoints. Order the work as normative and contract approval, discovery and planning implementation, guided-assistant and ISO integration, then attended verification and automated qualification. Do not split the agreed interface objective into a later independent plan.
- **Status**: Accepted

## DEC-032
- **Question**: How should implementation transition from the unfinished 02-06 dirty working tree to the new plan?
- **Context/Nuances**: Existing changes include reusable implementation and interview artifacts; rejecting the dashboard direction does not justify discarding all work. A Git checkpoint preserves a recoverable baseline without claiming completion or qualification. Git history and workflow-plan status are independent. Sensitive execution operations still require explicit approval.
- **User Response**: Asked whether to commit, cancel, or reject the existing changes, then requested adding the proposed initial transition task and directly materializing the revised plan.
- **Decision**: Begin execution with a reviewed repository-transition task. Inventory tracked and untracked changes, separate unrelated work, check for secrets and generated outputs, and obtain explicit execution-time authorization for a checkpoint commit named chore(install): checkpoint unfinished confirmation implementation. Do not stage indiscriminately or discard changes. Record the checkpoint identity and verification limitations. Close the previous execution as cancelled or superseded through supported plan-management mechanisms, preserving its reviewed tasks and execution history and never marking it completed. If the runtime cannot express that state directly, request operator handling rather than inventing a status or rewriting execution logs. Implement the new plan from that preserved baseline; retain the separate final clean-build and qualification commit. Materializing this plan does not itself perform the checkpoint or change the previous plan's status.
- **Status**: Accepted
