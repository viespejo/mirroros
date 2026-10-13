# Story 2.6 — Hardware adaptation and installation postconditions: consolidated plan

## Scope and validation environment

Story 2.6 has two halves: hardware rules that turn detected facts into inspectable installation selections, and the pre-restart postcondition suite that the engine contract explicitly leaves out of `installed`. Without access to the Framework Laptop 13 Pro, this plan is validated only in the QEMU reference VM; capturing the Framework topology and writing its specific rules belong to a later plan. [DEC-001]

## Responsibility boundaries

Discovery stays read-only and only observes facts. New rules under `hardware/rules/` are evaluated during plan generation, replacing today's `not_evaluated` entries, so every hardware-derived selection is visible in the plan before confirmation. The engine remains a pure executor of the approved plan under ADR 0008 and never decides on its own. [DEC-002]

## Graphics scope

MirrorOS does not install drivers for NVIDIA or AMD dedicated GPUs in this plan, keeping ADR 0005 unchanged without a new ADR. Such systems still boot through in-kernel drivers, and users may install vendor drivers afterwards without a MirrorOS guarantee; NVIDIA hibernation support in particular would be their responsibility. A future optional capability module may cover this. How the plan presents a detected dedicated GPU is still open. [DEC-003, TODO-001]

The graphics rule classifies the detected GPU by vendor, because discovery does not distinguish integrated from dedicated devices and every relevant kernel driver already ships in `linux` with its firmware in `linux-firmware`. AMD, Intel, and the QEMU virtual GPU appear in the plan as "kernel driver, nothing additional" without a warning. An NVIDIA GPU produces a review warning stating that the in-kernel `nouveau` driver will be used and that the NVIDIA driver may be installed afterwards without a MirrorOS guarantee; an unknown vendor produces a warning that MirrorOS does not recognize the GPU. Graphics never blocks installation. [DEC-004]

MirrorOS leaves `nouveau` untouched: it does not blacklist or configure it, so that installing the NVIDIA driver later replaces it through the standard Arch packaging mechanism, and NVIDIA-only machines keep a working kernel driver meanwhile. [DEC-005]

Graphics userspace (Mesa, Vulkan, VA-API) is out of Story 2.6 because the installed base is console-only; an Epic 4 hardware rule must select it by vendor. [TODO-002]

## CPU microcode

A CPU rule selects early microcode from the detected vendor: `amd-ucode` for AMD and `intel-ucode` for Intel, added to the planned packages with `hardware_detection` provenance, visible in review and not editable. Any other or undetected vendor adds nothing and produces a non-blocking review warning. Because the existing mkinitcpio hook sets already include `microcode`, the engine needs no new boot configuration, and the rule plus its initramfs effect can be exercised in the reference VM thanks to `-cpu host`. [DEC-006]

## Installation postconditions

The pre-restart postconditions live in a separate, read-only component (proposed `install/postconditions/`) so that verification never mutates the target and Epic 5 can later reuse its checks. The engine invokes it as its final phase, after the last plan operation and before its terminal cleanup unmounts the target, which avoids remounting from the assistant. When every check passes the engine reports `installed` with exit `0` and the success screen stops saying that postconditions are unverified; when any check fails the run ends with a new outcome (proposed `not_verified`) and exit `4`, distinct from execution failure `5`, naming the failed check, while cleanup still unmounts the target and all records remain available for diagnosis. [DEC-008]

Because the installed system has never booted when the postconditions run, they verify configuration rather than runtime state. They cover every item the story names — bootloader, mounts, installed kernel, network prerequisites, zram and memory settings, and swapfile and resume when hibernation is enabled — together with the microcode selection, and they check consistency across components, such as the boot entry's root UUID matching the root filesystem and the command-line `resume_offset` matching the actual swapfile, which per-operation immediate checks cannot see. Runtime behavior is covered by VM qualification instead: selected first-boot observations of `qualify-install` (active zram, disabled zswap, effective memory sysctl values, expected swap) become gating in the reference VM, while full post-boot readiness verification remains Epic 5 work. [DEC-009]

## Rule organization

Hardware rules live as four small JavaScript ESM modules — `hardware/rules/graphics/`, `hardware/rules/cpu-microcode/`, `hardware/rules/battery/`, and `hardware/rules/virtualization/` — sharing one shape: they receive detected facts and return packages, warnings, and the explanation shown in the plan. Plan generation evaluates them generically without knowing any rule's details, so adding a capability such as future VM desktop integration only touches its own rule, and an automated test demonstrates that no portable module changes (FR36). The architecture tree is narrowly amended to replace the planned `amd-integrated-graphics`, `nvidia-discrete-graphics`, and `hybrid-graphics` entries with these four rules, and ADR 0005 only gains a forward note recording that Story 2.6 took the removal decision it had deferred. [DEC-010]

## Target overrides

Target overrides remain one-machine exceptions applied only after a verified profile match, above detected selections in precedence and never contradicting detected facts. This plan adds no override keys and does not let a target override a hardware rule, because no real case exists yet; the first likely need, such as a model-specific kernel parameter, belongs to the Framework capture plan. Separation is instead made visible and tested: the plan shows the origin of each decision, rules never modify `install/plan/policy.json` or target overrides, and target overrides never change rule outcomes. [DEC-011]

## Document formats

The installation plan advances to format 4. Its informational `detected_capabilities` becomes a list of rule outcomes recording the rule, the fact it read, the detected value, the outcome, and the explanation shown in review; rule-added packages stay in a list separate from the personal package list so their layer remains visible, and the engine installs both; the NVIDIA, unknown-GPU, and unknown-CPU warnings use the existing `warnings` list. Engine records advance to format 2 to carry per-postcondition results and the `not_verified` outcome with exit `4`, and confirmation records advance to format 5 to accept that outcome. Format 3 plans are rejected with regeneration guidance rather than migrated, and target facts remain at format 2 because they already contain every input the rules need. [DEC-012]

## Qualification

The six counted cases of Story 2.5 are rerun on a clean artifact. The four installation cases must now pass every postcondition and the newly gating first-boot checks — active zram, disabled zswap, effective memory sysctl values, and the expected swap — and the host CPU's microcode must be present in the initramfs, which the reference VM can show because of `-cpu host`. The `not_verified` outcome is proved only through automated tests with doubles, such as a missing kernel yielding exit `4` that names the failed check, because inducing a real failure would require tampering with the artifact. Simulated facts cover what the VM cannot exhibit — NVIDIA, an unknown GPU, the other CPU vendor, and a battery — together with the test that adding a rule leaves portable modules untouched. A short attended review checks the rule outcomes and warnings in plan review, the new success message, and the `not_verified` screen on an uncounted development artifact. [DEC-013]

## Inherited caveats

Because the `not_verified` screen will show long diagnostic lines, this plan includes a scoped fix that wraps long lines to the terminal width on both the failure and `not_verified` screens, verified during the attended review and without other interface changes. The VirtIO GPU resume black console remains a separate laboratory investigation outside this plan, and VM hibernation checks continue to use standard VGA. [DEC-014]

## Work sequence

Work follows the Story 2.5 pattern. First the contract amendments (plan format 4, engine records format 2, confirmation records format 5, and a new postconditions contract), the architecture amendments, and the ADR 0005 forward note are drafted; then the maintainer reviews and approves them at a checkpoint before any code is written. Implementation then proceeds in slices: hardware rules with plan format 4, the postconditions component with its engine integration, the screens with the overflow fix, counted qualification, the attended review, and the summary. No new ADR is required, and `docs/epics.md` is expected to remain unchanged. [DEC-015]

The whole story is delivered as a single plan, `02-11`, so counted qualification runs once against the integrated result; the normative checkpoint provides the intermediate pause. [DEC-016]
