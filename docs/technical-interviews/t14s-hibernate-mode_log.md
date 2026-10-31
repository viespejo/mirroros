# ThinkPad T14s Gen 1 AMD recognized target and hibernate mode — decision log

Source finding: local todo `TODO-582784b9` (Finding 1: S4 entry aborts in `platform` mode).

## DEC-001
- **Question**: What status does the ThinkPad T14s Gen 1 AMD get in MirrorOS: a second qualified target laptop, a recognized but unqualified profile, or no target at all?
- **Context/Nuances**: NFR27 and ADR 0005 bound the MVP to one reference VM and one target laptop; ADR 0005 explicitly rejected supporting two laptops. ADR 0006 already separates profile recognition from qualification. Qualification means validation step 12 (physical qualification) and the `target-laptop-eligible` promotion state; a qualified second laptop would make its failures (platform-mode hibernation abort, `mt7921e` restore error) MVP blockers and require evidence from both laptops for every promotion. Day-to-day development effort is not duplicated by either option.
- **User Response**: B. Long term, MirrorOS is developed to work on all of the maintainer's laptops, for the MVP and beyond.
- **Decision**: The T14s Gen 1 AMD becomes a recognized, unqualified profile: a target with a `defined` DMI identity, classified `matched` by discovery so its target-specific adjustments apply. It does not count toward NFR27, does not block MVP completion or promotion to `target-laptop-eligible`, and the Framework Laptop 13 Pro remains the only qualified laptop (ADR 0005 unchanged). This introduces a new profile category and requires an ADR. Its failures are findings, not MVP blockers. The design of recognized profiles must scale to further laptops without redesign; this plan adds only the T14s.
- **Status**: Accepted

## TODO-001
- **Question**: Should NFR27 or the qualification boundary later extend to several laptops?
- **Context/Nuances**: Follows from the maintainer's long-term intent recorded in DEC-001.
- **User Response**: Accepted as a follow-up.
- **Decision**: After the MVP, evaluate in a future ADR. Out of scope for this plan.
- **Status**: Pending

## DEC-002
- **Question**: How does a target express that it needs `HibernateMode=shutdown`?
- **Context/Nuances**: No mechanism writes `sleep.conf` today. Plan overrides (`targets/<id>/overrides/plan.json`) allow only `hostname` and apply only to `matched` profiles. Hardware rules are capability-based and select packages and warnings only. Project drop-ins are delivered as hashed assets under `install/plan/assets/usr/lib/...` through explicit plan operations covered by the digest (ADR 0007 pattern). Alternatives: (A) typed override key; (B) arbitrary per-target asset files; (C) catalog of adjustment ids.
- **User Response**: A.
- **Decision**: Extend the `targets/<id>/overrides/plan.json` allowlist with a typed key `hibernate_mode` with closed values `platform` and `shutdown`. When the effective value is `shutdown`, the plan emits a new explicit operation (provisional name `configure_hibernate_mode`) that delivers a project-owned hashed asset from `install/plan/assets/usr/lib/systemd/sleep.conf.d/` to `/usr/lib/systemd/sleep.conf.d/`; `/etc` stays reserved for the administrator (ADR 0007). The value appears in review with `source: override`; the asset hash is covered by the plan digest; unqualified machines never receive it. B is rejected because it breaks allowlisted, reviewable overrides; C is rejected under NFR37 (single use today) and is reconsidered if typed keys accumulate.
- **Status**: Accepted

## DEC-003
- **Question**: How precisely is the T14s profile recognized?
- **Context/Nuances**: Discovery matches a profile only by exact equality of the declared DMI fields (`sys_vendor`, `product_name`) and `virtualization`. Captured values (local evidence of install run `20261027T190009Z-19f95db3-8e17-4d71-9ca5-3e9097cce128`): `sys_vendor` `LENOVO`, `product_name` `20UJ001RMX` (the Lenovo machine type model of the exact SKU), `product_version` `ThinkPad T14s Gen 1`, `board_name` `20UJ001RMX`, BIOS `R1CET84W(1.53 )`. `product_version` is shared with the Intel T14s Gen 1 (20T0/20T1), which does not show the firmware defect. AMD variants are 20UH/20UJ with many SKU suffixes.
- **User Response**: A, with target id `thinkpad-t14s-gen1-amd`.
- **Decision**: Create `targets/thinkpad-t14s-gen1-amd/target.json` with `identity.status: defined`, `virtualization: none`, and `dmi: { sys_vendor: "LENOVO", product_name: "20UJ001RMX" }`. Recognition stays exact equality; the target definition format (`format_version: 1`), the identification algorithm, and the discovery contract are unchanged. Family matching by MTM prefix is rejected (format change, untested SKUs) and would need its own ADR. `product_version` matching is rejected (also matches the Intel variant). Each future laptop gets its own target with its exact MTM. No serial or UUID is recorded.
- **Status**: Accepted

## DEC-004
- **Question**: How is `hibernate_mode` declared in the baseline installation policy, and can the user edit it?
- **Context/Nuances**: Plan overrides resolve over keys of `install/plan/policy.json` (precedence `policy < detected < override < choice`); each key has `value`, `provenance`, and `editable`, and the validator holds a schema per key. An editable key would need a new assistant stage (a deviation from the frozen prototype) and would let any machine give up firmware S4 wake sources.
- **User Response**: A.
- **Decision**: Add `hibernate_mode` to the installation policy with `value: "platform"`, `provenance: "arch_guidance"`, `editable: false`. The user cannot change it in the assistant or a choices file (rejected with the existing `choices_not_editable`); only a `matched` target override changes it. With `platform` (systemd's default) the plan emits no operation and no asset, so installed systems on the Framework, the reference VM, and unqualified machines stay as today apart from the new resolved key. With `shutdown` the plan emits `configure_hibernate_mode` and the review shows `source: override`. The assistant does not change. An editable key is rejected. Another machine that needs the adjustment gets its own target.
- **Status**: Accepted

## DEC-005
- **Question**: What happens when a recognized target overrides `hibernate_mode: shutdown` but the installation disables hibernation?
- **Context/Nuances**: ADR 0007 rule 2: with hibernation disabled, the plan carries no hibernation artifact (no swapfile, no resume parameters, no `@swap`). The drop-in would be harmless without a swapfile, but would install unused configuration.
- **User Response**: A.
- **Decision**: Emit `configure_hibernate_mode` and its drop-in only when `hibernation` is `true` and the effective `hibernate_mode` is `shutdown`. With hibernation disabled nothing is installed. The validator treats `configure_hibernate_mode` with `hibernation: false` as a contradiction, extending `hibernation_plan_mismatch`; the operation with `hibernate_mode: platform`, or its absence with `hibernation: true` and `shutdown`, is also rejected with a mismatch code whose exact name is fixed in the implementation plan. The resolved key still appears as `shutdown` with `source: override`, describing the profile, even when it has no effect. Enabling hibernation manually after installation stays outside the installer, like the swapfile and resume parameters.
- **Status**: Accepted

## DEC-006
- **Question**: Which format versions change?
- **Context/Nuances**: The plan gains a resolved key (`hibernate_mode`) and an operation kind (`configure_hibernate_mode`); the policy gains a key with its own schema. Precedent: Story 2.6 (`88e0413`) advanced the plan from 3 to 4 for a content change; earlier plans are rejected with `plan_format_unsupported` and regeneration guidance, never migrated.
- **User Response**: A.
- **Decision**: Installation plan advances from format 4 to 5 and installation policy from 3 to 4. Choices stay at 3 because the key is not editable. Target facts (2), target definition (1), `install-run.json`, and `approval-record.json` are unchanged, unless implementation finds a record that embeds the plan version, in which case it is adjusted and documented in the same change. An optional key with an implicit `platform` is rejected because it contradicts strict validation without reinterpretation. Plans are ephemeral, so the cost is nil.
- **Status**: Accepted

## DEC-007
- **Question**: What are the shape of the operation, its asset, and its postconditions?
- **Context/Nuances**: Existing postconditions `zram_configuration` and `memory_sysctl_configuration` check destination existence, SHA-256 against `source_sha256`, and planned values; `swapfile`/`swap_absent` are a pair applied by hibernation state. Postconditions inspect the installed tree; they do not boot it.
- **User Response**: A, including the operation name, position, and asset. The user asked to register the decision directly.
- **Decision**: Operation `configure_hibernate_mode`, placed immediately after `create_swapfile` (the relative order of the other operations is unchanged), with parameters `destination`, `source_sha256`, and `hibernate_mode` (`shutdown`); the engine delivers it like `configure_zram`. Asset `install/plan/assets/usr/lib/systemd/sleep.conf.d/60-mirroros-hibernate-mode.conf` with a header comment referencing the new ADR and the `/etc/systemd/sleep.conf.d/` administrator override, a `[Sleep]` section, and `HibernateMode=shutdown`. Postconditions as a pair: `hibernate_mode_configuration` when the operation is planned (destination exists, SHA-256 equals `source_sha256`, contains `HibernateMode=shutdown`) and `hibernate_mode_absent` otherwise (no file at the destination), which proves that machines without the adjustment never receive it. Checking systemd's effective runtime mode stays outside postconditions, as for zram and sysctl.
- **Status**: Accepted

## DEC-008
- **Question**: What is the ADR scope, and which normative documents are amended?
- **Context/Nuances**: ADR 0006 already says profiles remain for qualification, evidence, and machine-specific adjustments, but the architecture enumerates only the reference VM and the Framework as targets. ADR 0022 exists uncommitted in the main working directory (another agent), so this ADR takes number 0023. The mechanism exists only because of the profile.
- **User Response**: A.
- **Decision**: Create a single ADR 0023 (*Recognized Unqualified Targets and Target Hibernate Mode*), `Proposed` until the maintainer reviews it, then `Accepted`, covering DEC-001 to DEC-007. Narrow amendments to `docs/architecture.md`: list `targets/thinkpad-t14s-gen1-amd/` as a recognized unqualified profile under *Hardware and Target Boundaries*, and add to the MVP support boundary that a recognized profile is not qualification. Update the `docs/adr/README.md` index. ADRs 0005, 0006, and 0007 are not rewritten (nothing is superseded); ADR 0023 references them as related. Before merging, check that number 0023 does not collide with ADRs landed meanwhile. Two separate ADRs are rejected.
- **Status**: Accepted

## DEC-009
- **Question**: How is the change verified?
- **Context/Nuances**: The reference VM (DMI `QEMU`) can never match the T14s profile. The T14s now also hosts Omarchy in its free space; reinstalling MirrorOS without destroying it depends on installer coexistence (ADR 0022), which is not yet merged.
- **User Response**: A. The user asked to register the decision directly.
- **Decision**: (1) Automated tests with synthetic T14s DMI fixtures: discovery recognizes `thinkpad-t14s-gen1-amd` and stops recognizing it when `product_name` differs; plan generation resolves `hibernate_mode` by profile (`shutdown` with the override, `platform` otherwise) and emits the operation per DEC-005; the validator rejects incoherent combinations, format 4 plans, and `hibernate_mode` in choices; the engine delivers the asset; the postcondition pair behaves as specified. (2) A reference VM installation regression with plan format 5 in which `hibernate_mode_absent` passes and everything else is unchanged. (3) An attended, non-destructive check on the T14s: boot the new ISO and run read-only discovery and plan generation to confirm `matched` and the planned operation; then, on the installed MirrorOS, replace the local `/etc` workaround with the product drop-in under `/usr/lib` and confirm hibernation and resume in the same boot. (4) A full T14s reinstallation is a follow-up once installer coexistence has landed. A destructive reinstall in this plan and automated-only verification are rejected.
- **Status**: Accepted

## TODO-002
- **Question**: When is a full MirrorOS reinstallation on the T14s run?
- **Context/Nuances**: Follows from DEC-009; depends on ADR 0022 installer coexistence to preserve Omarchy.
- **User Response**: Accepted as a follow-up.
- **Decision**: After installer coexistence lands, reinstall MirrorOS on the T14s through the guided installer and confirm that the installed system hibernates in `shutdown` mode without any local workaround.
- **Status**: Pending

## DEC-010
- **Question**: Does the assistant's review summary show the hibernate mode?
- **Context/Nuances**: The full plan (`render-plan.mjs`, reachable through the assistant's pager) lists every resolved key generically with its provenance. The review summary (`review-content.mjs`) uses specific labels such as `Hibernation: Enabled (swapfile N MiB)`. Changing it is a presentation deviation from the frozen prototype.
- **User Response**: B.
- **Decision**: When the plan contains `configure_hibernate_mode`, the review summary's hibernation label is extended (for example `Enabled (swapfile N MiB, hibernate mode shutdown by target profile)`; exact English wording fixed in implementation); otherwise the label is unchanged. The deviation is recorded as a new entry in the confirmation contract's presentation difference inventory and covered by tests. The full plan keeps showing `hibernate_mode` with its provenance. The frozen prototype is unchanged. Showing it only in the full plan is rejected because an installed-system behaviour change should be visible on the screen being confirmed.
- **Status**: Accepted

## DEC-011
- **Question**: Which documentation and surfaces change together with the implementation?
- **Context/Nuances**: Target ids are enumerated in `install/discovery/discover` help text and `docs/procedures/install.md`; `resolve-layers.mjs` uses "such as" wording and needs no change. Repository rule: update attribution, tests, and documentation together with the change they govern.
- **User Response**: Correct. The user asked to register the decision directly.
- **Decision**: New: `targets/thinkpad-t14s-gen1-amd/{target.json, README.md, overrides/README.md, overrides/plan.json}` (README states recognized unqualified status, DMI provenance, known findings such as `mt7921e`, and links ADR 0023; `plan.json` holds only `{"hibernate_mode": "shutdown"}`); asset `install/plan/assets/usr/lib/systemd/sleep.conf.d/60-mirroros-hibernate-mode.conf`; ADR 0023. Contracts: `installation-plan.md` (override allowlist, policy key, operation, order, format 5, mismatch codes), `installation-engine.md` (operation), `installation-postconditions.md` (check pair, accepted plan format 5), `installation-confirmation.md` (new difference entry and review label), and `contracts/README.md` if it lists versions. Normative and procedures: `docs/architecture.md` (two amendments), `docs/adr/README.md` (index), `docs/procedures/install.md` (`--target` ids and T14s profile note), `docs/procedures/test.md` if scenarios change. Code lists: `install/discovery/discover` help text. Unchanged: `contracts/target-facts.md`, the frozen prototype, ADRs 0005/0006/0007. At plan close, append to local todo `TODO-582784b9` an update pointing to ADR 0023 and keeping Finding 2 (`mt7921e`) and Finding 3 (fingerprint) open.
- **Status**: Accepted
