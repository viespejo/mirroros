# ThinkPad T14s Gen 1 AMD recognized target and hibernate mode — consolidated plan

## Problem

On the ThinkPad T14s Gen 1 AMD (BIOS R1CET84W 1.53, latest available), hibernation in systemd's default `platform` mode aborts with `Wakeup pending. Abort CPU freeze`: the embedded controller raises a wakeup event during ACPI S4 entry. The behaviour is firmware-level and reproduces on Omarchy with another kernel. `HibernateMode=shutdown` hibernates and resumes correctly, at the cost of firmware S4 wake sources. MirrorOS has no way today to apply that adjustment to this machine only (local todo `TODO-582784b9`).

## Target status

The T14s Gen 1 AMD becomes a recognized but unqualified profile. It gets a target definition with a `defined` DMI identity, so discovery classifies it as `matched` and its target-specific adjustments apply. It does not count toward NFR27, does not block MVP completion or promotion to `target-laptop-eligible`, and the Framework Laptop 13 Pro remains the only qualified laptop; ADR 0005 is unchanged. Failures observed on the T14s are findings, not MVP blockers. Because this introduces a profile category that the accepted documents do not define, it is routed through a new ADR [DEC-001].

The maintainer intends MirrorOS to work on all of their laptops, for the MVP and beyond, so recognized profiles must scale to further machines without redesign, although this plan adds only the T14s. Whether NFR27 or the qualification boundary should later extend to several laptops is left to a future ADR after the MVP [DEC-001, TODO-001].

## Profile identity

The profile is `targets/thinkpad-t14s-gen1-amd/target.json` with a `defined` identity, `virtualization: none`, and the DMI values `sys_vendor: LENOVO` and `product_name: 20UJ001RMX`, taken from the local evidence of the exploratory installation. Recognition keeps the existing exact-equality rule, so the target definition format, the identification algorithm, and the discovery contract do not change. Because Lenovo's `product_name` is the machine type model of the exact SKU, only this machine and identical ones are recognized; `product_version` is not used because the Intel T14s Gen 1 shares it, and family matching by MTM prefix would need a format change and its own ADR. Each future laptop of the maintainer gets its own target with its exact MTM [DEC-003, DEC-001].

## Adjustment mechanism

A target expresses the need through a typed plan override: the `targets/<id>/overrides/plan.json` allowlist gains `hibernate_mode`, with closed values `platform` and `shutdown`. As with `hostname`, the override is read only for a `matched` profile, so an unqualified machine never receives it, and the review shows the value with `source: override` [DEC-002].

When the effective value is `shutdown`, the plan emits a new explicit operation, provisionally `configure_hibernate_mode`, that delivers a project-owned drop-in from `install/plan/assets/usr/lib/systemd/sleep.conf.d/` to `/usr/lib/systemd/sleep.conf.d/` and carries the asset's SHA-256 under the plan digest, following the zram and sysctl pattern of ADR 0007; `/etc` remains reserved for administrator overrides. Arbitrary per-target files were rejected because they break allowlisted, reviewable overrides, and a catalog of adjustment ids was rejected under NFR37 until several typed keys exist [DEC-002].

The installation policy declares the baseline: `hibernate_mode` has the value `platform`, systemd's default, with provenance `arch_guidance`, and is not editable. Users cannot change it in the assistant or through a choices file; only the override of a recognized target can. With `platform` the plan emits no operation and no asset, so the Framework, the reference VM, and unqualified machines install exactly as today apart from the new resolved key, and the guided assistant gains no stage. A machine that later needs `shutdown` gets its own target rather than a user choice, which keeps the loss of firmware S4 wake sources confined to machines whose firmware requires it [DEC-004].

The operation exists only when hibernation is enabled and the effective mode is `shutdown`; with hibernation disabled nothing is installed, consistent with ADR 0007's rule that a plan without hibernation carries no hibernation artifact. The validator rejects every incoherent combination: the operation with hibernation disabled extends `hibernation_plan_mismatch`, and the operation with `platform`, or its absence with hibernation enabled and `shutdown`, is rejected with a mismatch code named during implementation. The resolved key still reads `shutdown` with `source: override` when hibernation is disabled, because it describes the profile rather than an applied change [DEC-005].

## Operation, asset, and postconditions

The operation is named `configure_hibernate_mode` and sits immediately after `create_swapfile`, grouping hibernation work without changing the relative order of the other operations. It carries `destination`, `source_sha256`, and `hibernate_mode`, and the engine delivers it the way it delivers the zram drop-in. The asset is `install/plan/assets/usr/lib/systemd/sleep.conf.d/60-mirroros-hibernate-mode.conf`: a header naming the governing ADR and the `/etc/systemd/sleep.conf.d/` administrator override, a `[Sleep]` section, and `HibernateMode=shutdown` [DEC-007].

Postconditions mirror the `swapfile`/`swap_absent` pair. When the operation is planned, `hibernate_mode_configuration` checks that the destination exists, matches `source_sha256`, and contains `HibernateMode=shutdown`; otherwise `hibernate_mode_absent` checks that no file exists at the destination, which proves that machines without the adjustment never receive it. Whether systemd actually uses `shutdown` at runtime is not a postcondition, as with zram and sysctl, because postconditions inspect the installed tree without booting it [DEC-007].

## Review visibility

The person installing sees the adjustment on the screen they confirm: when the plan contains `configure_hibernate_mode`, the review summary's hibernation label adds the hibernate mode and that it comes from the target profile, while every other plan keeps the current label. This is a presentation deviation from the frozen prototype, recorded in the confirmation contract's difference inventory and covered by tests; the prototype itself is unchanged, and the full plan still lists `hibernate_mode` with its provenance [DEC-010].

## Format versions

Following the Story 2.6 precedent, the installation plan advances from format 4 to 5 and the installation policy from 3 to 4; earlier plans are rejected with regeneration guidance and never migrated. Choices stay at format 3 because `hibernate_mode` is not editable, and target facts, target definitions, the install-run record, and the approval record are unchanged unless implementation finds that one of them embeds the plan version, in which case it is adjusted and documented in the same change. An optional key with an implicit `platform` was rejected because the project's validators never reinterpret missing content [DEC-006].

## ADR and normative amendments

One ADR, number 0023 and titled *Recognized Unqualified Targets and Target Hibernate Mode*, records the profile category, the T14s identity, and the typed hibernate-mode override with its delivery; it starts `Proposed` and becomes `Accepted` after the maintainer's review. It references ADRs 0005, 0006, and 0007 as related without superseding or rewriting them. The architecture receives two narrow amendments: the *Hardware and Target Boundaries* list names `targets/thinkpad-t14s-gen1-amd/` as a recognized unqualified profile, and the MVP support boundary states that a recognized profile is not qualification. The ADR index is updated. The number assumes that ADR 0022, uncommitted in the main working directory, lands first, so it is checked for collisions before merging [DEC-008].

## Verification

Logic is verified deterministically with synthetic fixtures carrying the T14s DMI: discovery recognizes the profile and stops recognizing it when `product_name` differs, plan generation resolves `hibernate_mode` by profile and emits the operation only with hibernation enabled, the validator rejects incoherent combinations, format 4 plans, and `hibernate_mode` in choices, the engine delivers the asset, and the postcondition pair behaves as specified. A reference VM installation with plan format 5 shows that `hibernate_mode_absent` passes and nothing else changes, because the VM can never match the T14s [DEC-009].

The effect on real hardware is shown without destroying anything: the new ISO's read-only discovery and plan generation on the T14s confirm the `matched` profile and the planned operation, and on the installed MirrorOS the product drop-in under `/usr/lib` replaces the local `/etc` workaround and hibernation resumes in the same boot. A full reinstallation waits until installer coexistence has landed, so that Omarchy survives [DEC-009, TODO-002].

## Documentation set

Documentation moves with the change it governs. The new target directory carries its definition, a README that states the recognized unqualified status, the DMI provenance, and known findings such as the `mt7921e` restore error, and an override file containing only the hibernate mode; the drop-in asset and ADR 0023 are new as well. The installation plan, engine, postconditions, and confirmation contracts describe the key, the operation, the format 5 plan, the check pair, and the new presentation difference, and the contracts index follows if it lists versions. The architecture receives its two amendments, the ADR index its entry, and the install procedure and the discovery help text the new target id; the test procedure changes only if scenarios do. The target facts contract, the frozen prototype, and ADRs 0005, 0006, and 0007 stay unchanged. When the plan closes, the local finding todo is updated to point at ADR 0023 while the Wi-Fi and fingerprint findings remain open [DEC-011].

## Open branches

None. Follow-ups: TODO-001 (post-MVP qualification boundary) and TODO-002 (full T14s reinstallation after installer coexistence lands).
