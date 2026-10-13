# Story 2.6 — Hardware adaptation and installation postconditions: decision log

## DEC-001
- **Question**: Is the Framework Laptop 13 Pro available to capture its hardware topology during this plan?
- **Context/Nuances**: `targets/framework-13-pro-amd/target.json` is `pending_capture`; ADR 0005 makes Framework hardware rules depend on the captured topology. Only the QEMU reference VM is available (`-cpu host`, virtual GPU).
- **User Response**: Not available; testing happens only in the QEMU VM.
- **Decision**: All Story 2.6 work in this plan is validated only in the QEMU reference VM. Framework capture and Framework-specific hardware rules move to a later plan.
- **Status**: Accepted

## DEC-002
- **Question**: Should hardware-dependent decisions come from discovery or be handled by the engine?
- **Context/Nuances**: Discovery is read-only and only observes facts. ADR 0008 and DEC-013 of Story 2.5 forbid the engine from reading policy or making decisions; it executes only the approved plan. Plans currently list graphics, battery, virtualization, and CPU vendor as `not_evaluated` with `next_story: "2.6"`; `hardware/rules/` does not exist.
- **User Response**: Accepted after explanation.
- **Decision**: Discovery observes; rules under `hardware/rules/` decide during plan generation and their selections are visible in the plan before confirmation; the engine executes only the approved plan.
- **Status**: Accepted

## DEC-003
- **Question**: Should MirrorOS install drivers for NVIDIA and AMD dedicated GPUs?
- **Context/Nuances**: The maintainer initially wanted both. ADR 0005 marks NVIDIA and hybrid graphics as not applicable; the MVP excludes broad hardware support; QEMU cannot qualify real GPUs; NVIDIA adds driver-generation variants, hybrid PRIME handling, and hibernation requirements (`nvidia-hibernate`, video-memory preservation). The base system still boots with in-kernel `amdgpu` or `nouveau`.
- **User Response**: Leave dedicated GPUs out; users can install drivers after installation.
- **Decision**: This plan installs no driver for NVIDIA or AMD dedicated GPUs. ADR 0005 stands; no new ADR is needed. Users may install such drivers after installation without a MirrorOS guarantee. What the plan shows when a dedicated GPU is detected remains open.
- **Status**: Accepted

## TODO-001
- **Question**: Should dedicated-GPU drivers become an optional capability module?
- **Context/Nuances**: Possible future optional module in Epics 3/4, independent of the installer.
- **Status**: Pending

## DEC-004
- **Question**: What does the plan show when it detects a dedicated or unknown GPU?
- **Context/Nuances**: Options were blocking, warning in review, or informational only. Kernel drivers (`amdgpu`, `i915`/`xe`, `nouveau`, `virtio_gpu`/`bochs`) ship inside the `linux` package and their firmware in `linux-firmware`; nothing is installed for them. Discovery only records the vendor, not integrated versus dedicated, so the rule classifies by vendor. The story requires an explicit outcome rather than an unsafe guess.
- **User Response**: Accepted.
- **Decision**: Classify by vendor. AMD, Intel, and QEMU virtual: the plan shows "kernel driver, nothing additional" without a warning. NVIDIA: a review warning that `nouveau` (in-kernel) will be used and the NVIDIA driver may be installed afterwards without a MirrorOS guarantee. Unknown vendor: a review warning that MirrorOS does not recognize the GPU. Installation is never blocked on graphics.
- **Status**: Accepted

## DEC-005
- **Question**: Should MirrorOS blacklist or otherwise alter `nouveau`?
- **Context/Nuances**: `nouveau` is part of the `linux` package and cannot be omitted. Arch's `nvidia-utils` blacklists `nouveau` when the user installs the NVIDIA driver. Blacklisting it up front would leave NVIDIA-only machines on a basic firmware framebuffer.
- **User Response**: Accepted.
- **Decision**: MirrorOS neither blacklists nor modifies `nouveau`; the NVIDIA package replaces it through the normal Arch mechanism if the user installs it.
- **Status**: Accepted

## TODO-002
- **Question**: Where are Mesa, Vulkan, and VA-API selected?
- **Context/Nuances**: The Epic 2 result is console-only; graphics userspace is first used by the desktop and browser in Epic 4 and depends on the vendor (`vulkan-radeon`, `vulkan-intel`).
- **Status**: Pending — out of Story 2.6; an Epic 4 hardware rule must select them by vendor.

## DEC-006
- **Question**: Should the plan select CPU microcode from the detected CPU vendor?
- **Context/Nuances**: The fixed package list installs no microcode today, while Arch recommends it. The default mkinitcpio hooks, and the MirrorOS Limine hook set, include `microcode`, so installing the package embeds early microcode into the initramfs with no extra boot configuration; the engine only installs one more package. The reference VM uses `-cpu host`, so the rule and its initramfs effect are testable in QEMU, although the guest does not apply microcode updates itself.
- **User Response**: Accepted.
- **Decision**: AMD CPU (`AuthenticAMD`) adds `amd-ucode`; Intel CPU (`GenuineIntel`) adds `intel-ucode`; both with provenance `hardware_detection`. Any other or undetected vendor adds no package and produces a review warning without blocking. The selection is visible in the plan but not editable.
- **Status**: Accepted

## DEC-008
- **Question**: Where do the pre-restart installation postconditions run?
- **Context/Nuances**: The engine checks each operation's immediate effect, unmounts the target in its terminal path, and returns `installed`/0 with a message that postconditions are not verified (Story 2.6). Architecture requires verification to be read-only and defines exit `4` as verification not ready, distinct from `5` (execution failure). Options: (A) a final phase inside the engine, mixing mutation and verification; (B) a separate component run by the assistant after the engine, which would need to remount the target; (C) a separate read-only component that the engine invokes before unmounting.
- **User Response**: Accepted option C.
- **Decision**: Postconditions live in a separate read-only component (proposed `install/postconditions/`), reusable later by Epic 5, invoked by the engine as its final phase while the target is still mounted. All checks passing yields `installed`/0 and the "not verified" message disappears. Any failing check yields a new outcome (proposed `not_verified`) with exit `4`, naming the failed check; the target is still unmounted through the normal cleanup and records are retained for diagnosis.
- **Status**: Accepted

## DEC-009
- **Question**: What do the pre-restart postconditions check, given that the installed system has never booted?
- **Context/Nuances**: Before the first restart only on-disk configuration can be checked; runtime state (active zram, effective sysctl, network connectivity, real hibernate/resume) needs the installed system to boot. `qualify-install` already boots from disk and records a non-gating observation of mounts, swap, zram, command line, and snapshots.
- **User Response**: Accepted.
- **Decision**: Engine postconditions are configuration checks covering every item the story lists — bootloader, mounts, installed kernel, network prerequisites, zram and memory settings, and swapfile/resume when hibernation is enabled — plus the microcode selection (DEC-006). They also check cross-component consistency (for example the boot entry's root UUID matches the root filesystem, and the command-line `resume_offset` matches the actual swapfile offset). Runtime checks stay in VM qualification: selected first-boot observations become gating in the reference VM (active zram, zswap disabled, effective memory sysctl values, expected swap). Full post-boot readiness verification belongs to Epic 5.
- **Status**: Accepted

## DEC-010
- **Question**: How are hardware rules organized, and what happens to the architecture's planned rule directories?
- **Context/Nuances**: The architecture tree lists `amd-integrated-graphics`, `nvidia-discrete-graphics` and `hybrid-graphics` (both not applicable under ADR 0005), `battery`, and `virtualization`; none exists yet. DEC-004 uses one vendor-based graphics rule and DEC-006 adds a CPU microcode rule. ADR 0005 explicitly leaves to Story 2.6 whether to remove the NVIDIA and hybrid rule entries.
- **User Response**: Accepted.
- **Decision**: Create four rules — `hardware/rules/graphics/`, `hardware/rules/cpu-microcode/`, `hardware/rules/battery/`, and `hardware/rules/virtualization/` — each a small JavaScript ESM module with one shared shape (detected facts in; packages, warnings, and plan-visible explanation out). Plan generation evaluates all rules generically without rule-specific knowledge, and an automated test demonstrates that adding a rule touches no portable module (FR36). Remove the NVIDIA and hybrid entries from the architecture tree and replace the planned rules with the four real ones through a narrow `docs/architecture.md` amendment; ADR 0005 receives only a forward note that Story 2.6 made this decision, with its decisions unchanged.
- **Status**: Accepted

## DEC-011
- **Question**: May target overrides alter hardware-rule selections?
- **Context/Nuances**: Precedence is portable baseline < detected < target override < runtime private. Overrides apply only to a verified profile match (today only `reference-vm`); they never override detected facts. Existing overrides: plan `hostname` and the discovery keys (`minimum_disk_bytes`, HTTPS probe URL and timeout). A rule applies to any machine with given hardware; an override applies to one known model (for example a model-specific kernel parameter). No real case for overriding rules exists yet (NFR37).
- **User Response**: Accepted after explanation.
- **Decision**: No new override keys; rules cannot be overridden per target in this plan and the existing override allowlists are unchanged. Separation is demonstrated instead: the plan shows each decision's origin, and tests prove that rules do not modify `install/plan/policy.json` or target overrides and that target overrides do not change rule outcomes. A real override need (likely from the Framework capture) is added in that plan.
- **Status**: Accepted

## DEC-012
- **Question**: How do rule outcomes appear in the plan, and which document formats change?
- **Context/Nuances**: Plan format 3 has a fixed `packages` list (personal preference), a `warnings` list already shown in review, and informational `hardware_selections.detected_capabilities` marked `not_evaluated` / `next_story: "2.6"`. Each document has its own version constant; older inputs are rejected with regeneration guidance, never migrated.
- **User Response**: Accepted.
- **Decision**: Plan format 4: `detected_capabilities` becomes a list of rule outcomes (rule, fact, detected value, outcome, explanation); rule-added packages are kept in a separate list from the personal package list and the engine installs both; NVIDIA, unknown-GPU, and unknown-CPU warnings join the existing `warnings` list. Engine records advance to format 2 (per-postcondition results and the `not_verified` outcome, exit 4); confirmation records advance to format 5 to accept that outcome. Format 3 plans are rejected with regeneration guidance. Target facts stay at format 2.
- **Status**: Accepted

## DEC-013
- **Question**: How is Story 2.6 qualified in the reference VM?
- **Context/Nuances**: Story 2.5 qualified six counted cases on a clean artifact (default, limine-nohib, ext4, btrfs-rescue, injected mirror failure, password cancellation) plus an attended review and double-based tests. Inducing a real postcondition failure would require tampering with the artifact, which cannot count. The VM cannot show NVIDIA, a different CPU vendor than the host, or a battery.
- **User Response**: Accepted.
- **Decision**: Rerun the six counted cases on a clean artifact; the four installation cases must pass every postcondition and the newly gating runtime checks (active zram, zswap disabled, effective memory sysctl values, expected swap), and the host CPU's microcode must be present in the initramfs. The `not_verified` outcome is proved only by automated double-based tests (for example a missing kernel yields exit 4 naming that check). Rules the VM cannot exhibit (NVIDIA, unknown GPU, the other CPU vendor, battery) and the add-a-rule independence are proved with simulated facts. A short attended review covers the rule outcomes and warnings in plan review, the new success message, and the `not_verified` screen shown on an uncounted development artifact.
- **Status**: Accepted

## DEC-014
- **Question**: Are the Story 2.5 caveats (failure-screen overflow, VirtIO GPU resume black console) in scope?
- **Context/Nuances**: The new `not_verified` screen will likely resemble the failure screen and show long messages (for example mismatching `resume_offset` values), inheriting the horizontal overflow. The VirtIO resume issue is a laboratory investigation with unknown root cause, unrelated to the installed system; standard VGA resume works.
- **User Response**: Accepted.
- **Decision**: Include only a scoped fix wrapping long lines to the terminal width on the failure and `not_verified` screens, checked in the attended review, with no other UI changes. The VirtIO resume issue stays out of scope; VM hibernation checks keep using standard VGA.
- **Status**: Accepted

## DEC-015
- **Question**: In what order is the work done, and when are normative documents approved?
- **Context/Nuances**: Story 2.5 drafted normative changes, obtained maintainer approval before any engine code, ratified, then implemented in slices. Story 2.6 changes contracts (plan format 4, engine records format 2, confirmation records format 5, a new postconditions contract), the architecture (rule tree from DEC-010 and the "postconditions gated to Story 2.6" text), and adds a forward note to ADR 0005. No new ADR is needed (DEC-003); `docs/epics.md` likely needs no change.
- **User Response**: Accepted.
- **Decision**: Follow the Story 2.5 sequence: Task 1 drafts the contract and architecture amendments and the ADR 0005 note; Task 2 is a maintainer checkpoint and no code is written before approval; later tasks implement in slices — rules and plan format 4; postconditions and engine; screens and the overflow fix; counted qualification; attended review; summary.
- **Status**: Accepted

## DEC-016
- **Question**: One plan or two?
- **Context/Nuances**: Size is comparable to Story 2.5 (one plan, nine tasks). Splitting would require an intermediate clean artifact and qualification, or leave the first plan without real evidence; the normative checkpoint already provides a pause.
- **User Response**: One plan (A); materialize directly without a draft preview.
- **Decision**: A single plan `02-11` covers all of Story 2.6 within the scope of DEC-001; counted qualification happens once at the end.
- **Status**: Accepted
