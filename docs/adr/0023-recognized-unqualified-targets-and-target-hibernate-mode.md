# ADR 0023: Recognized Unqualified Targets and Target Hibernate Mode

## Identifier and title

- **Identifier:** `0023`
- **Title:** Recognized Unqualified Targets and Target Hibernate Mode

## Status

`Accepted`

## Date

`2026-10-31`

## Context and question

The maintainer intends MirrorOS to work on all of their laptops, during the MVP and afterward. The MVP qualification boundary nevertheless remains one reference VM and one target laptop (NFR27); the Framework Laptop 13 Pro is the sole laptop in that boundary under [ADR 0005](0005-physical-target-change.md). [ADR 0006](0006-guided-live-installation-boundaries.md) distinguishes profile recognition, technical admission, and qualification, and permits machine-specific adjustments only after a verified profile match.

An exploratory, non-qualifying installation on the maintainer's ThinkPad T14s Gen 1 AMD exposed a hibernation failure: entry into ACPI S4 in systemd's default `platform` mode aborts with `Wakeup pending. Abort CPU freeze`. The same behaviour reproduces on Omarchy with another kernel. A local `HibernateMode=shutdown` workaround permits hibernation and same-boot resume. MirrorOS currently has no typed plan override or installation operation for that setting.

The question is how to recognize this laptop and deliver the adjustment only where it is needed, without making it a second qualified MVP laptop, weakening confirmation, changing the global hibernation baseline, or treating exploratory evidence as qualification.

## Constraints and decision criteria

- NFR27, the PRD, and the qualification and artifact-promotion boundaries remain unchanged. T14s findings do not block MVP completion or promotion to `target-laptop-eligible`.
- The Framework remains the sole qualified laptop target; this does not assert that its pending physical qualification has already occurred.
- Recognition must use captured, exact DMI identity and the existing identification algorithm and target definition format. No serials or UUIDs enter source control.
- Overrides remain typed, allowlisted, reviewable, and restricted to matched profiles. Recognition grants no destructive authorization and makes no compatibility or support promise.
- Hibernation remains default-enabled and disableable per installation under [ADR 0007](0007-zram-and-hibernation-policy.md). Disabled hibernation installs no hibernation artifact.
- Project-owned configuration uses native systemd drop-ins under `/usr/lib`; `/etc` remains reserved for administrator overrides. Asset content is bound to the reviewed plan digest.
- No new assistant stage, arbitrary target-file delivery, hardware-adjustment catalog, resident service, or runtime postcondition is introduced.
- ADRs 0005, 0006, and 0007 are related and remain unchanged; this decision supersedes none of them.

## Alternatives considered

1. **Make the T14s a second qualified laptop.** It would extend NFR27 and make evidence and failures on both laptops part of MVP qualification. Rejected; a post-MVP extension requires a future ADR.
2. **Leave the T14s unmatched and retain a local workaround.** Smallest product change, but it cannot deliver a reviewable machine-specific adjustment through the installer. Rejected.
3. **Recognized unqualified profile with a typed override (chosen).** Reuses exact identification and override precedence while keeping qualification independent. Further laptops can use the same category without a qualification redesign; only the T14s is added here.
4. **Apply `HibernateMode=shutdown` globally or make it user-editable.** It would give up firmware S4 wake sources on machines without evidence of this defect; editability would add assistant surface. Rejected.
5. **Deliver arbitrary per-target assets.** Flexible, but bypasses the typed, allowlisted override boundary. Rejected.
6. **Introduce a catalog of adjustment identifiers.** Adds an abstraction for a single use, contrary to NFR37. Rejected; reconsider only if typed keys accumulate and recurring value is demonstrated.
7. **Match a Lenovo MTM prefix or `product_version`.** Prefix matching would change the format and admit untested SKUs; `ThinkPad T14s Gen 1` is shared with the Intel variant. Rejected. Broader matching needs its own ADR.
8. **Keep the existing plan format with an optional key and implicit `platform`.** Reinterprets missing content instead of enforcing strict validation. Rejected; ephemeral plans must be regenerated.
9. **Show the change only in the full plan, or verify only with automated fixtures.** Neither provides sufficient visibility or real-hardware evidence for the installed behaviour change. Rejected.
10. **Perform a full T14s reinstallation now.** Risks the coexisting Omarchy installation before installer coexistence lands. Rejected for this change.

## Evidence

All evidence below is exploratory and **non-qualifying**. It neither qualifies the T14s nor substitutes for Framework physical qualification or the planned clean reference-VM regression.

- Local finding `TODO-582784b9` records an exploratory MirrorOS installation from commit `4376b2a`, `dirty: false`, using an ISO that was not boot-qualified. The captured DMI fields are `sys_vendor: LENOVO` and `product_name: 20UJ001RMX`; these identify the exact SKU, not a unique device. Evidence remains local under ignored `evidence/install/`.
- MirrorOS kernel `7.2.11-arch1-1` and Omarchy kernel `7.2.8-9-omarchy` reproduce the platform-mode abort on the same laptop, including on battery. The wakeup IRQ is the ACPI SCI, with EC GPE `0x03` and power-button/AC wakeup activity. This supports a platform/firmware diagnosis rather than a MirrorOS-specific regression; the precise firmware or kernel cause is not proven.
- BIOS `R1CET84W` 1.53 was the latest available version found in the recorded LVFS research. No newer BIOS remedy was available at that observation; this is not a permanent claim about upstream releases.
- `HibernateMode=shutdown` permits same-boot resume on both distributions. Recorded observations include loss of USB root-hub power and removal of `HibernateLocation`. On MirrorOS the local workaround was verified twice. These observations concern the local `/etc` workaround, not delivery of the proposed product asset.
- Finding 2 records `mt7921e` restore error `-110` and delayed Wi-Fi recovery. Finding 3 records fingerprint-session behaviour on Omarchy. Neither is mitigated by this decision; MirrorOS adds no `fprintd`.
- The accepted interview decisions DEC-001 through DEC-011 define the intended scope and mechanism. Subsequent maintainer approval adapts the plan format to 6 after ADR 0022 landed format 5, and permits execution directly on `main` after the other agent finished. This ADR records a decision, not product-drop-in runtime validation or a clean-ISO regression.

## Decision

### Recognized unqualified profile and exact identity

Introduce a **recognized unqualified profile** category: a defined profile that discovery can match to apply explicit target adjustments, but that is not a qualified NFR27 target. Recognition is not qualification, a support commitment, or an additional MVP or `target-laptop-eligible` gate. Profile status remains the existing `matched`; no new target-facts status is introduced.

Add `targets/thinkpad-t14s-gen1-amd/target.json` with `format_version: 1`, `target_id: thinkpad-t14s-gen1-amd`, `identity.status: defined`, `virtualization: none`, and exactly these DMI fields:

```json
{ "sys_vendor": "LENOVO", "product_name": "20UJ001RMX" }
```

Keep exact equality, the identification algorithm, and `contracts/target-facts.md` unchanged. Do not record `product_version`, `board_name`, serials, or UUIDs. A different product name does not match; an explicit `--target thinkpad-t14s-gen1-amd` assertion is accepted only if the observed identity matches. Future laptops require their own captured exact identities, not family matching.

### Typed policy and override

Add `hibernate_mode` to `install/plan/policy.json` with `value: platform`, `provenance: arch_guidance`, and `editable: false`. Its closed values are `platform` and `shutdown`. Keep resolution precedence `policy < detected < override < choice`, but reject this key in choices with `choices_not_editable`; no detected rule is added for it.

Extend the target plan-override allowlist to exactly `hostname` and `hibernate_mode`. Unknown keys fail with `override_unknown_key`; invalid mode values fail with `override_invalid_value`. Only a verified matched profile supplies its overrides. The T14s `overrides/plan.json` contains only `{"hibernate_mode": "shutdown"}`.

The resolved key retains `shutdown` with `source: override` even if hibernation is disabled: it describes the profile, not an applied change. The reference VM, Framework, and unmatched unqualified machines retain `platform` from policy and receive no sleep drop-in. The T14s itself remains unqualified despite receiving its matched-profile adjustment.

### Operation, ownership, and validation

Emit `configure_hibernate_mode` if and only if `hibernation` is `true` and the effective `hibernate_mode` is `shutdown`. Place it immediately after `create_swapfile`, preserving the relative order of every other operation. Its parameters are `destination`, `source_sha256`, and `hibernate_mode: shutdown`.

The project-owned asset is `install/plan/assets/usr/lib/systemd/sleep.conf.d/60-mirroros-hibernate-mode.conf`, delivered to `/usr/lib/systemd/sleep.conf.d/60-mirroros-hibernate-mode.conf` beneath the target root. It contains a comment naming this ADR, a comment directing administrators to `/etc/systemd/sleep.conf.d/`, a `[Sleep]` section, and `HibernateMode=shutdown`. Register and hash it through the configuration-assets mechanism; the plan digest covers its hash and operation parameters. The engine delivers it with the same copy, mode, and ownership semantics as `configure_zram`, without activating it on the live system.

Validation re-derives the expected operation from recorded resolved values and checks its asset parameters. Reject the operation with hibernation disabled using `hibernation_plan_mismatch`. Reject it with mode `platform`, or its absence with hibernation enabled and mode `shutdown`, using `hibernate_mode_plan_mismatch`. Diagnostics include an actionable `next_step`. No manual enabling of hibernation after installation is managed here.

### Installed-tree postconditions

Declare a mutually applicable pair next to the swap checks:

- `hibernate_mode_configuration`, when the operation is present: its destination exists beneath the target root, its SHA-256 equals `source_sha256`, and it contains `HibernateMode=shutdown`.
- `hibernate_mode_absent`, otherwise: no file exists at the product destination. A stray file fails the check, including on a T14s with hibernation disabled.

Details remain bounded and non-secret. These checks inspect the installed tree only; systemd's effective runtime mode is verified separately during the attended hardware check.

### Formats and review

Advance installation plans from format 5 to **6**, preserving the coexistence functionality of [ADR 0022](0022-installer-coexistence-and-uefi-boot-entry.md), and policy from 3 to **4**. The original interview proposed format 5 from a format-4 base; the maintainer approved format 6 after coexistence landed first. Choices remain **3**, target facts **2**, and target definitions **1**. Reject plans of formats 1–5 with `plan_format_unsupported` and regeneration guidance; never migrate or reinterpret them. Install-run and approval-record formats stay unchanged unless an actual embedded plan-version dependency requires adjustment, in which case document it with the implementation.

When the plan contains `configure_hibernate_mode`, extend the review hibernation label to `Enabled (swapfile N MiB, hibernate mode shutdown by target profile)`, adjusting wording only if width tests require it. Every other label remains byte-identical, including a disabled T14s plan. The full plan shows the key, source, provenance, and operation parameters. Record the label deviation in the confirmation contract's presentation difference inventory; the frozen prototype remains untouched. No assistant stage is added.

### Documentation and adoption boundary

Apply the two planned architecture amendments: name `targets/thinkpad-t14s-gen1-amd/` as a recognized unqualified profile under *Hardware and Target Boundaries*, and state at the MVP support boundary that a recognized profile is not qualification. The maintainer additionally approved a third, minimal amendment: update the installation-plan version statement to format 6 while retaining ADR 0022 attribution for coexistence and adding this ADR for the new format. Index this ADR in the existing ADR-index style.

Update the installation-plan, engine, postconditions, and confirmation contracts with the policy, operation, formats, mismatch codes, check pair, and presentation difference. Update `contracts/README.md` version listings if present. Add the target id to discovery help and the install procedure, with a short unqualified-profile and hibernate-mode note. Update the test procedure only if VM expectations change. Leave the illustrative "such as" wording in `resolve-layers.mjs` unchanged.

The target README records recognized unqualified status, non-qualifying DMI provenance, the exact-product-name rationale, known Wi-Fi and fingerprint findings, and this ADR. Its overrides README describes the two-key allowlist and the sole mode override. Update tests together with their governed change. At plan close, append ADR, plan, and verification links to `TODO-582784b9`, keeping Findings 2 and 3 open and not closing the todo.

The maintainer approved the Proposed draft before implementation and subsequently approved the format-6 adaptation and the minimal third architecture amendment. Acceptance and the governed documentation amendments are recorded during plan 02-24; this decision rewrites neither ADR 0005, 0006, nor 0007. Acceptance of the decision does not imply that the remaining ISO and attended hardware validation has passed.

## Consequences and trade-offs

- A matched T14s can receive a reviewable, digest-bound adjustment without expanding the qualified hardware set. Other machines retain their existing installed behaviour apart from the new resolved plan key and format.
- `shutdown` skips the failing firmware S4 entry path, but loses firmware S4 wake sources, such as lid-open or RTC-alarm wake, on the T14s only. This is accepted for this profile, not as a global policy.
- Exact SKU matching intentionally excludes untested AMD variants as well as Intel variants. Recognizing more machines requires captured identities and explicit review.
- The typed key adds schema, operation, engine, and verification surface; no general hardware-adjustment framework is justified by this single use.
- Installed-tree checks establish delivery, not effective runtime configuration or reliable resume. Administrator `/etc` overrides may alter effective behaviour.
- Old plans require regeneration. Source and operation binding remain mandatory; this adjustment grants no additional installation authority.
- Wi-Fi restoration and fingerprint-session findings remain open. Exploratory success is not a support promise or physical qualification.

## Replacement or reversal boundary

Revisit or replace this decision if firmware or kernel changes remove the need for `shutdown`, if its loss of wake sources becomes unacceptable, or if repeated resume fails with the product configuration. Review removal of the target override and the associated asset/operation rather than silently changing the global baseline or claiming automatic cleanup of already installed systems.

Broader DMI matching, editable mode selection, arbitrary target assets, a catalog of adjustments, or a widened qualification/support promise requires a new ADR. Reconsider the typed mechanism only when recurring needs justify the additional abstraction. Any change to NFR27 or multi-laptop qualification belongs to the post-MVP follow-up, not this implementation.

## Required validation

Decision review and numbering:

- The maintainer approved the draft against DEC-001 through DEC-011 before implementation, including non-qualifying evidence and unchanged qualification boundaries. Only this ADR was added by the drafting task.
- ADR 0022 landed for installer coexistence before integration. ADR number 0023 was free in tracked `main` at the documentation update; recheck for collisions before committing or merging.

After adoption, within plan 02-24:

- Synthetic discovery tests cover the exact T14s identity, a different product name, the Intel-shared product version alone, explicit target assertion success/contradiction, and unchanged QEMU recognition.
- Policy, choices, override, generation, digest, and validator tests cover T14s hibernation on/off, Framework with a defined fixture identity, reference VM, unmatched machines, invalid values/keys, legacy formats 1–5, and incoherent operation combinations.
- Engine tests establish delivery; postcondition tests cover correct content, hash mismatch, missing setting, expected absence, and a stray file. Review tests cover the extended label and unchanged other cases.
- All installation, hardware, and operations suites and repository static/secret checks pass. The protected ADRs, target-facts contract, existing target directories, PRD, and frozen prototype remain unchanged.
- A clean-source ISO, without a development overlay, completes the reference VM `default` installation with outcome `installed`, exit `0`, plan format 6, no mode operation, and all postconditions passing including `hibernate_mode_absent`.
- An attended non-destructive T14s check boots that ISO and runs read-only discovery and planning only: profile `matched`, mode `shutdown` from override, and the operation immediately after `create_swapfile`. No installation is started.
- On installed MirrorOS, an explicitly attended replacement of the local `/etc` workaround with the product `/usr/lib` drop-in (mode 0644) shows effective `HibernateMode=shutdown`; battery hibernation resumes in the same boot, without `Abort CPU freeze`, and removes `HibernateLocation`. Keep evidence ignored and local. These checks do not qualify the T14s.

Follow-ups from the interview:

- **TODO-001:** after the MVP, evaluate multi-laptop qualification and any NFR27 change through a future ADR.
- **TODO-002:** after installer coexistence (ADR 0022) lands, reinstall MirrorOS on the T14s through the guided installer while preserving Omarchy, then confirm hibernation without any local workaround. No destructive T14s installation belongs to this plan.

## References

- [Architecture](../architecture.md)
- [ADR 0005: Physical Target Change](0005-physical-target-change.md)
- [ADR 0006: Guided Live Installation Boundaries](0006-guided-live-installation-boundaries.md)
- [ADR 0007: Zram and Default-Enabled Hibernation Policy](0007-zram-and-hibernation-policy.md)
- [Target facts contract](../../contracts/target-facts.md)
- [Installation plan contract](../../contracts/installation-plan.md)
- [Installation engine contract](../../contracts/installation-engine.md)
- [Installation postconditions contract](../../contracts/installation-postconditions.md)
- [Installation confirmation contract](../../contracts/installation-confirmation.md)
- [T14s interview decision log](../technical-interviews/t14s-hibernate-mode_log.md) and [consolidated plan](../technical-interviews/t14s-hibernate-mode_plan.md)
- Execution plan `02-24-t14s-recognized-target-hibernate-mode.md` (local workflow tooling).
- Local finding `TODO-582784b9`, Findings 1–3, including the recorded BIOS research and two-distribution comparison; raw evidence is not committed.

## Superseded by

`None`
