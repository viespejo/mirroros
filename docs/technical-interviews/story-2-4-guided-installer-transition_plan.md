# Story 2.4 — Guided Installer Transition: Consolidated Interview Plan

## Transition from the existing implementation

Replace the interface direction of plan 02-06, whose execution stopped at Task 7, without treating it as completed or continuing to Task 8. Preserve its execution records and existing implementation changes. Assess discovery, planning, validation, digests, safety comparisons, and evidence machinery for reuse, distinguishing implemented behavior from behavior that has not yet been qualified. [DEC-001]

## Reference experience and integration fidelity

The interactive live installer must faithfully reproduce the visual style and workflow of `tmp/mirroros-ux-demo/omarchy-style/`, including screens, order, text, navigation, layout, logo, colors, and widget behavior. A merely equivalent or reinterpreted interface is not an acceptable substitute. The maintainer successfully tested all prototype screens in the Omarchy ISO; the integrated experience must be verified on the MirrorOS ISO. [DEC-002]

Account for any necessary preparation of the MirrorOS live ISO to reproduce the reference experience. Fidelity applies to observable presentation and behavior, not to copying Omarchy's internal implementation. Review each prototype functionality individually with the maintainer before agreeing its integration. Explain and obtain explicit approval for any necessary deviation, while preserving safety guarantees. [DEC-002]

## Machine admission and internal qualification profiles

The end user does not select a machine profile. MirrorOS checks technical requirements and identifies known profiles internally. Retain profiles for repeatable qualification, evidence, and machine-specific adjustments; apply those adjustments only when the identified machine matches. [DEC-003]

Allow unqualified machines to attempt installation through an explicitly experimental path, without a compatibility guarantee or support commitment. Passing checked requirements does not establish hardware qualification. All machines retain the same safety guarantees, and the experimental path cannot bypass requirements. [DEC-003]

This direction expands the previous scope and requires formal review of affected contracts and normative documents, not just removal of the target menu. [DEC-003]

## Password interface and engine hand-over

Define the real password screen and its protected delivery contract as part of this plan, but activate actual collection when the installation engine is connected in Story 2.5. Until then, retain an explicit explanatory screen without asking for a password value. This is an approved temporary adaptation of the reference workflow; password entry remains part of the intended guided interface. [DEC-004]

The interface owns protected password entry and confirmation, while the engine consumes the runtime input without providing its own interaction model. Password values must never enter installation plans, process arguments, logs, or retained evidence. The shared user/root password policy follows DEC-005; collection timing remains governed by DEC-004. [DEC-004, DEC-005]

## User and root account policy

Keep root locked by default and provide administration through the user's sudo access. If root password access is enabled, root receives the same password as the user; no separate root password is requested. Explain that the shared password does not constitute an independent recovery credential. [DEC-005]

The installation plan declares one account-password requirement consumed by the user-account operation and, only when root password access is enabled, by the root-account operation as well. No password value enters the plan. Align the affected contracts, generation, validation, review, and tests with this policy. The exact requirement identifier remains unspecified, and actual collection follows the timing agreed in DEC-004. [DEC-004, DEC-005]

## Language and regional formats

Reproduce the prototype's separate choices for system language, regional formats, and keyboard. Offer English (US) and Spanish (Spain) as system languages, with formats that follow the system language or explicitly use Spain or the United States. Following language is the initial regional setting and remains dynamic when language changes, unless the user chooses an explicit region. [DEC-006]

Derive the required locales automatically as the unique union of the language and formats locales instead of exposing a technical locale-list management step. Resolve LC_TIME, LC_NUMERIC, LC_MONETARY, and LC_MEASUREMENT from the formats locale; other categories inherit LANG, and LC_ALL is not set. Explain the distinction between language, formats, and keyboard, including that applications may have their own preferences or ignore these settings. [DEC-006]

Represent and validate the regional selection and its resolved effects in the real installation plan, aligning policy, resolution, generation, validation, rendering, documentation, and tests. Presentation code is not an independent authority for configuration semantics. Concrete new field names remain unspecified; installation-plan versioning follows DEC-020. [DEC-006, DEC-020]

## Live and installed-system keyboard settings

Preserve the prototype's welcome-screen option to change the live console keyboard and its separate installed-system keyboard step. The live adjustment facilitates input and affects only the live session's virtual consoles; it does not automatically change the installed-system keyboard choice. Cancelling installation does not revert this console adjustment and does not imply a modification to the installation disk. [DEC-007]

Perform the live keyboard adjustment within the live-root installer privilege boundary agreed in DEC-025. The implementer may recommend wording improvements to keep the distinction between live and installed-system settings clear, with deviations from reference text explicitly approved as required by DEC-002. [DEC-002, DEC-007, DEC-025]

## Live connectivity preparation

Reproduce the prototype's live connectivity preparation. Check connectivity and continue without asking for a connection method when it already works. Otherwise, offer Ethernet guidance or instructions for configuring Wi-Fi through iwctl in another live console, with connection retries. [DEC-008]

Keep this preparation separate from installed-system network configuration. The assistant must not request or retain Wi-Fi credentials in the installation plan or evidence, and live connections must not be copied into the installed system. Preparatory checks and guidance do not replace discovery's authoritative validation of its connectivity requirement. [DEC-008]

## Technical admission independent of profile identity

Retain discovery's existing technical and safety checks for architecture, firmware, connectivity, and eligible disks, including the policy's 20 GiB minimum disk size and planning's complete-layout fit validation. Preserve existing warnings. Do not add arbitrary RAM, CPU, or GPU requirements in this transition. [DEC-009]

Failure to identify a known profile leads to the experimental path rather than blocking admission. A profile with pending identity capture is not considered identified and cannot enable profile-specific adjustments. Passing technical checks remains distinct from hardware qualification or a compatibility guarantee. [DEC-003, DEC-009]

## Live clock readiness

Rely on automatic time synchronization enabled by the live ISO and verify that image preparation during build and qualification. Do not add a clock configuration screen or reactivate the service from the assistant. An enabled service is not proof of runtime synchronization, so perform a brief bounded readiness check during live preparation. Show help only when readiness cannot be established, allowing retry or cancellation rather than silently proceeding. [DEC-010]

Accurate live time is needed for TLS certificate and package signature verification, as documented in the Arch Linux Installation Guide (https://wiki.archlinux.org/title/Installation_guide#Update_the_system_clock). Account for clock errors affecting HTTPS connectivity probes rather than reporting every such failure as a generic network problem. Do not bypass TLS or signature checks. Keep discovery read-only if it observes or records clock state, and distinguish live clock readiness from the installed-system timezone choice. The exact check interface and wait bound remain unspecified. [DEC-010]

## Compact review and complete-plan inspection

Preserve the guided assistant's compact review and provide optional complete-plan inspection through a pager. Exiting the pager returns to the review without losing answers or granting authorization. The detail includes disk identity and current layout, all resolved options with provenance and source, destructive operations, warnings, secret requirements without values, and the plan reference. [DEC-011]

Present the digest as a plan reference, not something users must memorize or type. Complete fit within 80x25 is not required for now. Use gum pager with its accepted search limitation and without a dedicated pager feature-verification gate. [DEC-011, DEC-012]

## Pager implementation

Use gum pager for complete-plan inspection even if its previously observed search defect persists. Accept that limitation without requiring a dedicated pager test or a fix as an adoption gate, and do not develop or substitute another pager. This resolves the concrete pager selection and supersedes the conditional pager feature-verification gate left open in DEC-011. [DEC-012]

Keep assistant safety tests: optional inspection does not authorize installation, and leaving the pager preserves the user's answers. Accepting a pager search limitation does not waive these safety guarantees. [DEC-011, DEC-012]

## Real destructive-operation confirmation

Replace the prototype's simulated confirmation with real authorization bound to the concrete disk and plan digest, while preserving its presentation style. Display the disk to be erased and the plan reference, ask for confirmation with No initially selected, and then request the kernel device name, such as vda or nvme0n1. A mismatch cancels without an in-run retry. Do not ask users to type the digest. [DEC-013]

Revalidate the disk and plan after confirmation and before engine hand-over. The reference shown to the user identifies the plan; the full digest binding and safety comparisons remain automatic safeguards. [DEC-013]

## Navigation and cancellation

Preserve the prototype's backward navigation for configuration: Back or Esc returns without applying an incomplete answer and retains previously confirmed answers. Leaving the pager returns to review. Cancel or Ctrl+C during interaction terminates with status 3 without installation-disk operations. [DEC-014]

Real authorization prompts are distinct: No or Esc cancels instead of navigating backward. If answers change after returning to a configuration step, generate and review the updated plan before requiring fresh confirmation. [DEC-013, DEC-014]

## Pre-execution phase failures

Present failures with the phase, cause, and next action in the assistant's visual style. Components remain authoritative for their results; presentation must not ignore validation or represent a failure as success. Allow correction or retry only when the component indicates a recoverable problem, retaining only answers that remain valid. Stop on unexpected failures and preserve diagnostics in evidence. [DEC-015]

A disk or plan change invalidates approval and requires renewed review and confirmation. Distinguish failures and invalidation from explicit cancellation, whose exit status remains 3. Recovery from partially executed installation belongs to the engine rather than ordinary backward navigation in the assistant. [DEC-014, DEC-015]

## Public command entry point

Use mirroros-install without a subcommand as the habitual entry point to the guided installer, corresponding to operations/install in the repository. Preserve discover and plan as independently invocable technical subcommands. --help prints help without starting the assistant. Remove the public apply subcommand without a compatibility alias, and update help, procedures, and qualification references accordingly. Preserve the internal install/engine/apply boundary name; public interaction and internal plan execution are different responsibilities. [DEC-016, DEC-017]

## Execution hand-over sequence

The assistant owns the complete interaction sequence: collect choices, generate and review the plan, obtain destructive-operation confirmation, request and confirm the password when real installation is available, revalidate the disk and plan, and invoke the engine once for execution. The engine consumes prepared inputs without requesting prompts or returning control for password collection. Cancelling password entry prevents engine startup. Place final revalidation after password entry so time spent answering cannot make approval silently stale. [DEC-013, DEC-018]

Deliver runtime secrets through a protected channel, never arguments or environment variables, and retain no values in plans, logs, or evidence. The concrete channel implementation remains unspecified. This delivery retains the explanatory password screen and engine-unavailable boundary, without real secret collection, engine implementation, or installation-disk operations. Story 2.5 replaces that explanation with real password input and connects the protected channel to the engine. [DEC-004, DEC-018]

## Existing-plan technical entry point

Retain mirroros-install --plan <file> for technical inspection, tests, and qualification. Check the live environment, validate the supplied plan, and compare it with fresh discovery before entering review without repeating every configuration question. Reject stale or mismatched plans rather than silently adapting them to another machine, disk state, or policy. [DEC-019]

Preserve the original file. Editing generates a new plan and requires renewed confirmation; an unchanged valid plan also requires fresh confirmation. Persisted plans contain no secret values or reusable authorization. The habitual user experience remains mirroros-install with the full guided workflow. [DEC-016, DEC-019]

## Installation-plan contract versioning

Introduce a new installation-plan contract version to represent regional formats and the shared account-password requirement without silently reinterpreting the current version. Newly generated plans declare the new version. --plan rejects older installation-plan versions with a clear regeneration instruction; no automatic migration changes prior choices without review. [DEC-006, DEC-005, DEC-020]

Align the plan contract, generator, validators, and fixtures with the new version, which is shared by the assistant and future engine. This installation-plan versioning decision does not change the separate requirement to keep legacy workflow plan files readable. [DEC-020]

## Automatic discovery and explicit profile assertions

Add discovery without --target for the habitual guided flow: inspect the machine, identify a known profile only when a verifiable match exists, and report an unqualified machine otherwise. Do not infer profiles with pending identity capture or apply their specific adjustments. Identification remains distinct from qualification evidence. [DEC-003, DEC-009, DEC-021]

Preserve discover --target <id> as an optional technical assertion for tests and qualification. A machine that contradicts the requested profile still fails that check. Removing user-facing profile selection does not weaken explicit qualification assertions. [DEC-021]

## Machine facts independent of profile identity

Represent the actual inspected machine identity and facts independently of an optional identified profile, with an explicit unqualified condition when no profile matches. Do not invent a generic profile merely to satisfy validators. Planning and confirmation remain bound to the actual machine and disk whether or not a known profile exists. [DEC-003, DEC-021, DEC-022]

Introduce a new target-facts contract version and update consumers together, rather than silently reinterpreting the existing target_id-based contract. Concrete new field names remain unspecified by this decision. [DEC-022]

## Stable prototype reference and attribution

Preserve a versioned reference in prototypes/frontend/guided-installer/ without modifying the original tmp/ prototype. Include relevant sources, logo, instructions, synthetic fixtures, tests, and existing licenses and attribution, excluding personal paths, credentials, and generated outputs. Document dependencies on the Omarchy ISO presentation code and the maintainer's attended trial. Do not assume that preserving the sources makes the prototype standalone or qualifies MirrorOS integration. [DEC-023]

Keep synthetic fixtures explicitly separate from real discovery and authorization evidence. Production implementation remains under install/ and reproduces the reference experience using real MirrorOS components; it must not source prototype code or depend on the Omarchy configurator. [DEC-002, DEC-023]

## VM verification of recognized and experimental admission

Verify the integrated flow in two real VM situations: one matching reference-vm, and one with a different identity that matches no known profile but passes technical requirements. Exercise review, confirmation, cancellation, and invalidation in both paths without executing a real installation. Fixture-only coverage is insufficient for this admission change. [DEC-024]

These runs do not establish physical-hardware qualification or a support commitment for additional machines. Define the exact VM identity configuration and evidence matrix as implementation details. [DEC-003, DEC-024]

## Live installer privilege boundary

Keep the live session and guided installer running as root, consistent with the Arch live ISO and reference prototype. Do not introduce an additional live account or artificial elevation between installer phases. Root privileges do not authorize destructive operations: validated planning, explicit confirmation, and revalidation remain mandatory. [DEC-025]

Keep installed-user configuration separate from live-root installation privileges; it must not inherit root privileges for convenience. This decision does not automatically alter build or other command privilege boundaries. Formalize the live-installer distinction through a new ADR and update the architecture's overly broad wording. It supersedes only the live-keyboard elevation clause of DEC-007, not the separation between live and installed-system settings. [DEC-007, DEC-025]

Ensure mirroros-install and its executable entry-point targets are executable on the live medium, using the image profile's file-permission mechanism where applicable. Executable modes are distinct from elevation grants; this model requires neither setuid nor a new permission to become root. [DEC-025]

## Provenance of accepted proposals

Advancing through a screen without changing the proposed value preserves its provenance and source, whether policy, hardware detection, or a profile-specific adjustment. Record modifications as user choices rather than relabeling every value merely because it passed through an interactive widget. The persisted plan must still explain which values came from MirrorOS and which the user changed. [DEC-026]

## Supported presentation surface

Focus this delivery on the colored interactive console of the live ISO, reproducing the reference's palette and presentation. Do not implement an additional colorless presentation profile. Clearly reject terminals outside that scope rather than rendering an unqualified alternative or confirming automatically; absence of an interactive terminal remains a hard failure. [DEC-027]

Reconcile this narrower live-installer scope explicitly with the current architecture and ADR 0004 terminal and wrapper requirements through the applicable ADR and normative-document review. Do not silently ignore those requirements or claim unsupported terminal modes are qualified. Reviewed published Omarchy source corroborates its colored VT approach, but was not extracted from the exact 4.0.4 ISO used in the maintainer's trial. [DEC-027]

## Live ISO startup

Automatically open the assistant's welcome screen on tty1 when the live ISO starts. Cancellation returns to the shell, and mirroros-install can launch the assistant again. Leave other consoles available for Wi-Fi setup, diagnostics, and recovery. Automatic startup grants no authorization for installation-disk operations. [DEC-028]

Coordinate qualification with automatic startup to avoid concurrent assistants. Any test coordination must preserve the interactive confirmation safeguards rather than introducing an authorization bypass. [DEC-013, DEC-028]

## Plan generation timing

Collect answers through the guided screens with per-step value validation, and generate the first installation plan when entering review, where the complete combination is validated. Do not generate intermediate plans merely for passing through each screen. [DEC-029]

After backward navigation and answer changes, generate a new plan version before review and confirmation. If the combination is invalid, explain the cause and allow correction while preserving the last valid plan and granting no authorization. [DEC-014, DEC-015, DEC-029]

## New run evidence names

Use install-run.json and install.log for new guided-installer executions. Retain approval-record.json as non-authorizing evidence, initial/final discovery artifacts, and numbered plan directories. Preserve private permissions, ANSI-free logs, and exclusion of secret values. Do not rename or transform historical evidence; align contracts, tests, and qualification with the new names. [DEC-030]

## Delivery structure

Deliver the complete transition in one implementation plan, with separate tasks and blocking internal checkpoints. Review normative changes and contracts before implementing discovery and planning, then integrate the guided assistant and live ISO, and finish with attended verification and automated qualification. Do not leave the agreed interface objective to a later independent plan. [DEC-031]

## Recoverable implementation transition

Start execution by inventorying the dirty working tree and separating unrelated changes. Review and secret-scan the product and interview material to preserve, exclude generated outputs and local tooling, and request explicit execution-time approval for a checkpoint commit named chore(install): checkpoint unfinished confirmation implementation. Do not stage indiscriminately or discard existing changes. Record the checkpoint identity and verification limitations without claiming the existing implementation is completed or qualified. [DEC-032]

Close the previous execution as cancelled or superseded using supported plan-management mechanisms, without marking it completed or rewriting its execution history. Request operator handling if the runtime cannot express that state directly. Implement the transition from the recoverable baseline and retain the final clean-build and qualification commit. Plan materialization alone performs neither the Git checkpoint nor the previous plan-state change. [DEC-001, DEC-032]
