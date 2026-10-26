# Greeter and Plymouth — Decision Log

## DEC-001
- **Question**: Does “Look” refer to the existing hyprlock screen, and what should the initial planning scope record?
- **Context/Nuances**: MirrorOS currently uses SDDM for login and hyprlock for locking. The requested change should be quick and visually simple. The maintainer requested studying Omarchy before choosing an implementation and explicitly activated interview persistence. Omarchy revision `1801adc1983b06f6ab218f8060e430cb3477d8d0` has a small SDDM QML theme with a centered logo and password field, last-user selection and a preference for an uwsm session. Its Plymouth script has a centered logo, password dialogue and mixed simulated/real progress. Its installer also enables autologin and changes keyring-related PAM configuration; these are separate from visual styling. MirrorOS architecture currently limits QML to the owned desktop shell, so a SDDM QML theme requires resolving that boundary before implementation.
- **User Response**: Confirmed that “Look” means hyprlock; asked to study Omarchy before deciding, activated persistence, and explicitly answered “yes” to creating both interview artifacts with this registration.
- **Decision**: Use the existing hyprlock screen as the visual reference for a simple greeter, and plan Plymouth with MirrorOS branding. Study Omarchy before selecting the implementation. No greeter provider choice, autologin, PAM changes or simulated progress policy is approved. Persistence is active; the final implementation plan remains subject to separate draft approval.
- **Status**: Accepted

## TODO-001
- **Question**: Which implementation should deliver the greeter appearance?
- **Context/Nuances**: Retaining SDDM and changing its theme is a recommendation only. A QML theme must respect or explicitly amend the normative language boundary.
- **User Response**: Requested upstream comparison before deciding.
- **Decision**: Resolved by DEC-002 below; retained here as the original pending record.
- **Status**: Accepted

## TODO-002
- **Question**: What visual scope and integration should Plymouth deliver?
- **Context/Nuances**: Logo source, supported boot paths, installation/configure ownership, diagnostics and validation remain unresolved. Omarchy is a reference, not authorization to copy its installation policy.
- **User Response**: Requested Plymouth with the MirrorOS logo, in the spirit of Omarchy.
- **Decision**: Pending.
- **Status**: Pending

## DEC-002
- **Question**: Should MirrorOS retain SDDM and create a minimal owned theme following Omarchy's approach but matching the existing hyprlock appearance?
- **Context/Nuances**: Keeping SDDM avoids replacing the login provider. The change is limited to presentation, retaining existing authentication without autologin or PAM modifications. The normative architecture currently permits QML only for the owned desktop shell; implementation therefore requires a narrowly scoped ADR authorizing QML for SDDM themes and a corresponding architecture update. This does not authorize a general QML application framework or custom authentication.
- **User Response**: “yes, registra directamente la decisión” — explicitly approved the proposal and requested direct registration.
- **Decision**: Retain SDDM and deliver a minimal MirrorOS-owned theme inspired by the existing hyprlock appearance, using Omarchy as an implementation reference. Preserve existing authentication, with no autologin or PAM modifications. Route the bounded QML language exception through an ADR and update the architecture before adopting the theme. Exact visual content and interactions remain to be agreed.
- **Status**: Accepted

## DEC-003
- **Question**: What should replace the greeter clock, and which branding reference should be used?
- **Context/Nuances**: The maintainer requested a logo in place of the greeter clock, in the same white style, with the remaining lock-inspired layout unchanged. Inspection found the block-letter MIRROROS wordmark in `install/confirmation/banner.txt`, also present in the installer prototype. A graphical adaptation avoids depending on terminal glyph rendering and provides a scalable resource reusable by the greeter and Plymouth. This is not a brand redesign; sizing and spacing may be adjusted for graphical presentation.
- **User Response**: Requested using the installer idea while remaining open to proposals, then explicitly approved the graphical adaptation with “yes, registra directamente la decisión”.
- **Decision**: Adapt the existing installer wordmark silhouette into a monochrome, scalable graphical resource, using the current hyprlock clock's off-white color. Center it in place of the greeter clock, without shadows or animation, and make it reusable in the greeter and Plymouth for visual continuity. Preserve the dark background, password field and keyboard-layout indicator inspired by the existing hyprlock. Do not modify hyprlock. Exact asset format and delivery details remain implementation questions.
- **Status**: Accepted

## DEC-004
- **Question**: Should the greeter expose the selected user with a discreet way to change users, or show only the last user's password field as Omarchy does?
- **Context/Nuances**: A password-only interface can make the selected account ambiguous, especially on first login. A visible selected account and a discreet user-switching control preserve simplicity without inheriting Omarchy's last-user-only presentation. The existing configured Hyprland/uwsm session remains the session choice; this decision does not introduce a new session provider.
- **User Response**: “yes, registra directamente la decisión” — explicitly approved the recommendation and requested direct registration.
- **Decision**: Display the selected user and provide a discreet control to change users. Retain the existing configured Hyprland/uwsm session. Exact control styling and first-login selection behavior remain to be specified or established through inspection of existing native SDDM behavior.
- **Status**: Accepted

## DEC-005
- **Question**: Should Plymouth show only the centered logo on the same dark background, without a progress bar or animation?
- **Context/Nuances**: Omarchy's Plymouth theme combines simulated and real progress. MirrorOS can preserve visual continuity with the greeter using a static presentation, without importing that progress mechanism or delaying boot to keep the branding visible. This decision specifies the normal splash appearance, not failure-diagnostic handling or boot-path coverage.
- **User Response**: “yes, registra directamente la decisión” — explicitly approved the recommendation and requested direct registration.
- **Decision**: Plymouth's normal splash will show only the centered MirrorOS logo on the same dark background as the greeter, without a progress bar, animation or artificial delay. Reuse the branding direction accepted in DEC-003. Diagnostic behavior and integration scope remain unresolved.
- **Status**: Accepted

## DEC-006
- **Question**: Should Plymouth be added only to the installed system, leaving the live ISO boot and installer presentation unchanged?
- **Context/Nuances**: The maintainer requested clarification of the installed-system versus live-media distinction. The installed system boots from the destination disk; the live ISO is the installation/rescue USB environment. Limiting visual changes to the installed system keeps this work bounded. Reusing the installer wordmark does not require changing the installer's appearance. Source or packaging changes needed to deliver installed-system behavior through installation are not excluded by this visual boundary.
- **User Response**: After clarification, “yes, registra directamente la decisión” — explicitly approved installed-system-only visual scope and requested direct registration.
- **Decision**: Apply the greeter changes and Plymouth branding to the installed system only. Leave live ISO boot visuals and the installer presentation unchanged. Reuse the installer branding reference without redesigning its existing presentation.
- **Status**: Accepted

## DEC-007
- **Question**: Should Plymouth cover both supported bootloader options, Limine and systemd-boot?
- **Context/Nuances**: Supporting both avoids making installed-system branding depend on the installation's bootloader selection. Existing installation code has distinct Limine and systemd-boot integration paths. Coverage must preserve the selected bootloader and existing hibernation configuration; this decision does not prescribe the exact hook ordering or kernel-command-line implementation.
- **User Response**: “yes, registra directamente la decisión” — explicitly approved the recommendation and requested direct registration.
- **Decision**: Integrate Plymouth with both Limine and systemd-boot across the supported installed-system storage options. Preserve the selected bootloader and existing hibernation configuration. Exact native integration and validation details remain to be established through code and upstream inspection.
- **Status**: Accepted

## DEC-008
- **Question**: Should users retain access to boot messages with Esc and have a documented way to boot without the splash for diagnosis?
- **Context/Nuances**: Branding must not prevent investigation of a boot failure. Esc behavior must be tested in the actual integration rather than assumed from upstream defaults. A documented no-splash boot path provides an independent diagnostic alternative; this does not authorize suppressing upstream failures or replacing their diagnostics.
- **User Response**: “yes, registra directamente la decisión” — explicitly approved the recommendation and requested direct registration.
- **Decision**: Preserve access to boot messages through Esc, verify that behavior during validation, and document how to boot without the splash for troubleshooting. Do not claim Esc compatibility without evidence or conceal boot failures behind branding.
- **Status**: Accepted

## DEC-009
- **Question**: Should the change also apply to existing installations through `mirroros-configure`, rather than only new installations?
- **Context/Nuances**: Plymouth requires initramfs and boot-parameter integration in addition to installing its theme. Supporting existing installations must be bounded to recognized MirrorOS boot configurations; incompatible local changes must be reported and preserved instead of overwritten. Configure must not restart the display manager or reboot the machine. The new boot presentation takes effect on the next boot.
- **User Response**: “yes, registra directamente la decisión” — explicitly approved the recommendation and requested direct registration.
- **Decision**: Deliver the change on new installations and through `mirroros-configure` on existing installations. Limit boot convergence to recognized MirrorOS configurations. Stop with actionable diagnostics on incompatible local changes, preserving them. Do not restart SDDM or reboot automatically; the boot result is observed on the next boot. Exact ownership and safe native regeneration mechanisms remain implementation details to resolve through inspection.
- **Status**: Accepted

## DEC-010
- **Question**: Should this plan close with VM validation without touching the laptop yet?
- **Context/Nuances**: The proposed validation covers all three supported installation storage schemes, updating an existing installation, an unchanged second configure run and real graphical login. Hibernation parameters must be preserved, but VM evidence does not establish hardware hibernation readiness. In the same response the maintainer requested considering an additional ThinkPad target; that scope extension has not yet been agreed.
- **User Response**: “yes, registra directamente la decisión”, followed by a request to incorporate a ThinkPad T14s G1 with Ryzen 7 Pro, 16 GB RAM and 256 GB storage, expecting limited changes.
- **Decision**: Validate the greeter/Plymouth plan in VMs across all three supported installation schemes, an existing-installation update, an unchanged second configure run and real graphical login. Do not touch the laptop under this validation scope or claim hardware hibernation readiness. The additional physical-target request remains pending separate scope clarification.
- **Status**: Accepted

## TODO-003
- **Question**: Should the ThinkPad T14s G1 be admitted as an additional target, and should that work belong to this plan or a separate plan?
- **Context/Nuances**: Maintainer-provided description: ThinkPad T14s G1, Ryzen 7 Pro, 16 GB RAM, 256 GB storage. Exact hardware identity, qualification requirements, normative support-boundary changes and plan coupling require inspection and explicit agreement. No hardware probing, installation or qualification is authorized by this request alone.
- **User Response**: Suggested that this is a good time to incorporate the device and expected little change.
- **Decision**: Pending.
- **Status**: Pending

## DEC-011
- **Question**: Should adding the ThinkPad T14s G1 be handled in a separate plan rather than expanding the greeter/Plymouth plan?
- **Context/Nuances**: Discovery already loads target definitions from `targets/` and current vendor-based rules cover AMD, so profile admission may require little code. Recognition is not qualification. ADR 0005 and the architecture currently limit the MVP to one reference VM and one Framework laptop. Adding another physical target requires revisiting that normative boundary through an ADR, capturing actual hardware identity without inventing DMI data, and performing separate qualification. No claim of hardware compatibility follows from the CPU, RAM and disk description alone.
- **User Response**: “yes, registra directamente la decisión” — explicitly approved the separate-plan recommendation and requested direct registration.
- **Decision**: Handle ThinkPad T14s G1 admission and hardware capture in a separate plan, with its own normative support-boundary review and subsequent qualification. Keep this plan focused on greeter/Plymouth and its accepted VM-only validation boundary. No ThinkPad source changes or physical hardware operations are included here. This resolves TODO-003's scope-routing question; the separate plan has not been drafted, approved or materialized.
- **Status**: Accepted

## DEC-012
- **Question**: Should configure be the sole owner of Plymouth theme delivery and boot integration for both new and existing installations?
- **Context/Nuances**: The installation engine already invokes target-context configure after preparing and verifying the base system. Separate installation-time and running-system implementations would duplicate integration logic. A configure-owned visual layer must identify the bootloader, preserve storage and hibernation parameters, and regenerate boot artifacts when required. Base-installation contracts and tests must explicitly distinguish the verified base boot configuration from the subsequently applied visual layer; silently weakening checks or rewriting an approved installation plan is not acceptable.
- **User Response**: “yes, registra directamente la decisión” — explicitly approved the recommendation and requested direct registration.
- **Decision**: Configure is the sole owner of Plymouth theme delivery and boot integration in both target and running contexts. Detect the supported bootloader, preserve storage and hibernation parameters, and regenerate the required boot artifacts when necessary. Do not modify the approved installation plan. Update contracts and tests to distinguish the visual overlay from the base boot configuration while preserving safety-relevant checks. No duplicate installation-engine implementation of Plymouth is introduced.
- **Status**: Accepted

## DEC-013
- **Question**: Should Omarchy serve only as a reference, with independently written minimal MirrorOS themes rather than copied upstream code?
- **Context/Nuances**: The agreed greeter adds selected-user visibility and switching, while the agreed Plymouth appearance excludes Omarchy's progress and password-dialogue complexity. Independent native themes can implement the bounded requirements without importing unused upstream logic or assets. The inspected upstream revision should still be cited as an idea reference.
- **User Response**: “yes, registra directamente la decisión” — explicitly approved the recommendation and requested direct registration.
- **Decision**: Write the minimal SDDM and Plymouth themes independently. Use Omarchy as an idea and implementation-pattern reference only; do not copy its theme code or graphical resources. Document the upstream reference and the MirrorOS-owned installer wordmark origin.
- **Status**: Accepted

## DEC-014
- **Question**: Should the normal boot use `quiet splash` while retaining logs and access to boot messages through Esc?
- **Context/Nuances**: A clean normal splash requires the corresponding kernel parameters. More aggressive suppression, such as `loglevel=0`, disabling logs or hiding errors through scripts, is unnecessary and would weaken diagnosis. The existing diagnostic-access requirement remains binding.
- **User Response**: “yes, registra directamente la decisión” — explicitly approved the recommendation and requested direct registration.
- **Decision**: Add `quiet splash` for the normal branded boot while retaining logs and Esc access to messages. Do not add aggressive diagnostic suppression such as `loglevel=0`, log disabling or error-hiding scripts. Preserve all storage and hibernation parameters and the documented no-splash diagnostic path.
- **Status**: Accepted

## DEC-015
- **Question**: Approve this plan draft for materialization? (yes/no)
- **Context/Nuances**: The complete in-chat draft retained DEC-001–014, the selected dependencies, VM-only validation and separate ThinkPad routing. It proposed a font-independent SVG source with a configure-generated PNG using official librsvg, a dedicated branding capability, bounded native-format authority, explicit SDDM first-user/unavailable-state behavior, safe configure-owned boot convergence and three implementation/qualification tasks. Both plan references were read during finalization and reread after approval. Materialization is not runtime implementation or permission for disruptive VM operations.
- **User Response**: “yes” to the exact draft approval gate.
- **Decision**: Approve the presented draft and its technical details for materialization as `.agents/plans/02-20-greeter-plymouth.md`, phase `02-new-phase`, plan `20`, date `2026-10-25`, status `pending`, with exactly the two selected dependency slugs. The approved plan was materialized without starting implementation. Further physical-target work and disruptive operations retain their separate approval requirements.
- **Status**: Accepted
