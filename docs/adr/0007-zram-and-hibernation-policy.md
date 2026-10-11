# ADR 0007: Zram and Default-Enabled Hibernation Policy

## Identifier and title

- **Identifier:** `0007`
- **Title:** Zram and Default-Enabled Hibernation Policy

## Status

`Accepted`

## Date

`2026-10-10`

## Context and question

The architecture currently states one policy: a resizeable swapfile serves both ordinary swap and hibernation, and hibernation is an essential MVP capability. [ADR 0003](0003-storage-and-recovery-baseline.md) adds that every Btrfs option declares an `@swap` subvolume and that the installation plan carries the resume offset of that swapfile. The installation plan (version 2) always emits `create_swapfile` with a fixed 512 to 65536 MiB range and a 4096 MiB proposal, declares `zram: false`, and has no zswap policy.

The maintainer approved a different design in the [zram and hibernation policy decision log](../technical-interviews/zram-hibernation-policy_log.md) (DEC-001 to DEC-031) and its [consolidated plan](../technical-interviews/zram-hibernation-policy_plan.md). It collides with accepted normative text in four places:

1. **Ordinary swap.** Everyday swap moves to zram; the swapfile is no longer the primary ordinary swap.
2. **Hibernation is optional per installation.** It stays essential for MirrorOS to support and qualify, and is enabled by default, but one installation may disable it.
3. **Swapfile sizing.** The fixed range and 4096 MiB proposal become a RAM-derived range and default.
4. **ADR 0003 clauses.** `@swap` and the resume offset become conditional on hibernation.

The question is how to record this policy, and the contract changes it requires, without rewriting accepted decisions, without implementing an installation engine, and without claiming qualification that only installed-system tests can provide.

## Constraints and decision criteria

- Accepted ADRs are not rewritten; a forward link is the only change allowed to ADR 0003.
- No installation engine exists (Story 2.5). This decision prepares policy, contracts, planning, the guided assistant, and declarative assets. It does not apply, activate, or qualify anything on an installed system.
- The live ISO's memory policy does not change.
- Hibernation remains an essential capability that MirrorOS must support and qualify; disabling it is a per-installation user choice, not removal of the capability.
- The physical target remains the integrated-AMD Framework laptop of [ADR 0005](0005-physical-target-change.md). This decision does not widen hardware support or promote the Limine tier.
- Native mechanisms are preferred over project-owned services: official `zram-generator`, systemd, and `sysctl.d`, with `/etc` left to administrator overrides.
- Review and confirmation keep their safety binding: facts, hashes, and detected RAM that shaped a plan must be revalidated before approval stands.
- The guided assistant changes only where this decision says so; the frozen prototype remains the presentation reference.
- Tuning values are an initial baseline, not an asserted optimum.

## Alternatives considered

1. **Keep one swapfile for ordinary swap and hibernation (current architecture).** No change and no new package. It keeps the disk as the primary swap device and gives no compressed in-memory swap.
2. **zram plus a hibernation-only swapfile with an enforcement mechanism.** It reserves the file for hibernation. No mechanism was selected: an active low-priority swapfile can still receive ordinary swap, and enforcing exclusivity needs a runtime component that would be a partial engine.
3. **zram plus an optional swapfile that also provides lower-priority fallback swap (chosen).** Zram has priority 100 and is preferred; the swapfile has priority 0 and absorbs overflow. No custom enforcement and no daemon.
4. **zram only, hibernation removed from the MVP.** Smallest configuration, but it drops an essential capability that the architecture requires and the project has qualified in the reference VM.
5. **Unconditional swapfile with zram.** It preserves ADR 0003 and DEC-001 unchanged, but forces a RAM-sized disk reservation on users who do not hibernate.
6. **zswap instead of zram.** Rejected in the interview: zswap is a compressed cache in front of a disk swap device and is a different mechanism; the maintainer chose zram.

## Evidence

- Accepted interview decisions DEC-001 to DEC-031; later decisions supersede earlier ones where noted below.
- **Sizing history.** DEC-001 required an always-present swapfile. DEC-002 made hibernation default-enabled and disableable, with a RAM-rounded minimum. DEC-008 allowed smaller sizes with a warning, superseding that minimum. DEC-009 set the maximum and default to detected RAM rounded up to a whole GiB, with a 512 MiB input floor, superseding the permission to exceed the default. The current rule is DEC-009.
- **Mechanism references (not MirrorOS measurements):**
  - [ArchWiki: Zram](https://wiki.archlinux.org/title/Zram) and [zram-generator.conf(5)](https://man.archlinux.org/man/zram-generator.conf.5) for the generator drop-in format, the `ram` size expression, and the tuning example that includes swappiness 180.
  - [ArchWiki: Zswap](https://wiki.archlinux.org/title/Zswap) and the [kernel zswap documentation](https://docs.kernel.org/admin-guide/mm/zswap.html) for the `zswap.enabled=0` override.
  - [Kernel vm sysctl documentation](https://docs.kernel.org/admin-guide/sysctl/vm.html) for swappiness, page-cluster, and the watermark settings.
  - [Kernel swsusp documentation](https://docs.kernel.org/power/swsusp.html) for the hibernation image-size target.
- **Host observation (not target evidence).** The maintainer's running kernel has `CONFIG_ZSWAP_DEFAULT_ON=y`. This motivates an explicit override; it does not describe the installed MirrorOS kernel.
- **Omarchy** was read as a prior-art observation only. The configuration here is original MirrorOS material; no Omarchy code is incorporated. One reported Omarchy defect, configuration shipped without its required package, motivates declaring the package explicitly.
- No MirrorOS test of zram activation, hibernation with this policy, or memory pressure exists. This record is not performance or activation evidence.

## Decision

MirrorOS adopts the following installed-system policy. Items marked "plan" are expressed in installation plan version 3 and generated and validated but not executed until the engine exists.

### Hibernation

1. Hibernation is an editable boolean `hibernation`, default `true`. It remains an essential capability that MirrorOS must support and qualify.
2. When disabled, the plan has no `swapfile_size`, no `create_swapfile`, no resume kernel parameters, no `resume_offset` resolution, and, for both Btrfs options, no `@swap` subvolume or mount. Zram, root UUID resolution, the other subvolumes, Snapper policy, bootloader selection, and support tiers are unchanged, and the relative order of the remaining operations is unchanged.
3. A choices file combining `hibernation: false` with `swapfile_size` is rejected as contradictory. The guided assistant removes the explicit size when hibernation is disabled and proposes the RAM-derived default again when it is re-enabled.

### Swapfile sizing

4. Planning requires a positive detected `memory_total_bytes`, even with hibernation disabled. If it is missing, generation fails with an actionable diagnostic asking for repeated discovery. No memory or size is assumed.
5. When hibernation is enabled, `swapfile_size` is an integer MiB from 512 to `ceil(memory_total_bytes / 1073741824) * 1024`. That maximum is also the default. The minimum is an input limit, not a claim of sufficient hibernation capacity.
6. A size whose bytes are below the raw `memory_total_bytes` is valid and produces a persistent warning on the sizing screen, in the review, and in the structured plan. It adds no confirmation dialog. The wording explains that success depends on used memory and free swapfile space and never claims that the default guarantees a successful resume.
7. A layout whose ESP, root minimum, and swapfile exceed the disk is rejected. The swapfile is never silently shrunk and hibernation is never silently disabled.
8. No custom hibernation image-size setting is introduced. The kernel's image-size target and compression are not capacity guarantees.

### Swap roles and priorities

9. Zram has swap priority `100` and is the preferred everyday swap. When hibernation is enabled, the swapfile has priority `0` and also serves as lower-priority fallback swap. It is described as hibernation-sized storage with fallback swap use, not as exclusively used for hibernation. Fallback use consumes free hibernation capacity, so a RAM-sized default does not guarantee a successful resume.

### Zram

10. The installed package list explicitly includes the official Arch `zram-generator`, never as a transitive dependency and never in the live ISO package list.
11. The drop-in `/usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf` has one `[zram0]` section with `zram-size = ram`, `compression-algorithm = zstd`, and `swap-priority = 100`. No resident-memory limit, recompression, writeback device, or algorithm fallback is selected. Logical capacity is not an immediate reservation of that much RAM and does not guarantee doubled usable memory.
12. These zram parameters are fixed by policy and not editable in the installer. The optional swapfile is independent lower-priority swap, not a zram writeback device.

### Zswap

13. The installed kernel command line includes `zswap.enabled=0` for every storage option. The live ISO's memory policy is unchanged.

### Sysctl baseline

14. `/usr/lib/sysctl.d/60-mirroros-memory.conf` declares `vm.swappiness = 180`, `vm.page-cluster = 0`, `vm.watermark_scale_factor = 125`, and `vm.watermark_boost_factor = 0`. They are global rather than per device, fixed in the installer, and modifiable afterward through native administrator overrides. They are not proven optimal. No adaptive tuning, daemon, or project-owned service is added.

### Ownership, operations, and binding

15. The two drop-ins are owned under `install/plan/assets/`, mirroring their destination paths. `/etc` is reserved for administrator overrides.
16. The plan adds `configure_zram` immediately after `install_packages` and `configure_memory_reclaim` immediately after `configure_zram`. Each carries its destination path and the SHA-256 of its source asset, covered by the plan digest. `create_swapfile` carries priority `0` and exists only when hibernation is enabled.
17. The plan's `target.machine` gains `memory_total_bytes`. Final revalidation invalidates approval when detected RAM differs or is unavailable, or when either source asset's hash differs from the reviewed one, including with hibernation disabled. The future engine must not deliver different asset content under the same approved plan.
18. Installation plans, the installation policy, and choices files advance to format version `3`; `install-run.json` and `approval-record.json` advance to their own record version `3`. Target facts remain version `2`. Earlier installation inputs are rejected with regeneration guidance and are never migrated or reinterpreted. Reading legacy workflow plans in `.agents/plans/` is unchanged.

### Guided interface deviation

19. The former swapfile-size stage becomes a hibernation stage at the same position of the flow, with Enabled/Disabled initially on Enabled. Sizing is shown only when enabled. The review shows hibernation state, and a disabled review does not imply swapfile creation. This is the only approved presentation difference; it is recorded in the confirmation contract's difference inventory (D15), and the frozen prototype is unchanged.

### Scope exclusions

20. This decision prepares policy, contracts, plan generation and validation, the assistant, declarative assets, and tests. Applying them to an installed disk, activating zram, real hibernation and resume, memory-pressure tuning, and physical qualification remain future work (Story 2.5 and later).

### Exact normative amendments proposed

These apply only after this ADR is accepted, and change only the clauses named. No other accepted ADR is edited.

| Document | Clause today | Proposed amendment |
| --- | --- | --- |
| [ADR 0003](0003-storage-and-recovery-baseline.md) | Decision: `@swap` in the flat Btrfs subvolume list; Consequences: the plan carries "its resume parameters". | Add only a forward partial-supersession link, in the section named "Superseded by", identifying those swap, `@swap`, and resume clauses as amended by this ADR. The decision text is not rewritten. |
| [`docs/architecture.md`](../architecture.md), technical constraints | "Use a resizeable swapfile for both ordinary swap and hibernation." | "Use zram as the preferred everyday swap and an optional swapfile, enabled with hibernation, as hibernation storage and lower-priority fallback swap ([ADR 0007](0007-zram-and-hibernation-policy.md))." |
| `docs/architecture.md` | "Manage and verify the resume device and swapfile offset whenever the swapfile is created or resized." | Add "when hibernation is enabled". |
| `docs/architecture.md` (two summaries) | "a resizeable swapfile supporting mandatory hibernation" and "a resizeable swapfile, and hibernation form a compatible target-system baseline". | State that hibernation is an essential capability, enabled by default and disableable per installation, with zram for everyday swap, per this ADR. |
| [`docs/epics.md`](../epics.md), architecture summary and Story 2.5 | "a resizeable swapfile" and "the declared resizeable swapfile policy". | Refer to the declared zram and conditional hibernation swapfile policy of this ADR. Story 2.5's boundary and numbering do not change. |
| `docs/epics.md`, Story 2.5 postconditions | "swapfile, and resume configuration are checked". | "zram, memory settings, and, when enabled, swapfile and resume configuration are checked". |
| [`docs/prd.md`](../prd.md) | No clause states swap or hibernation policy. | No change. |
| [`docs/attribution.md`](../attribution.md) | No external configuration entry. | Add no incorporation entry unless the maintainer wants ArchWiki and kernel references listed there; they are mechanism references, not incorporated material. The configuration is original. |
| `docs/procedures/install.md`, `build.md`, `test.md` | Plan, choices, and records at version 2; "swapfile" screen name; no asset boundary. | Version 3 wording, "hibernation" stage name, installed-only asset note, and the new VM prompt step. |
| [`contracts/installation-plan.md`](../../contracts/installation-plan.md), [`contracts/installation-confirmation.md`](../../contracts/installation-confirmation.md) | Version 2. | Drafted at version 3 with this ADR (see References). |

The architecture's references to hybrid AMD/NVIDIA hibernation validation predate [ADR 0005](0005-physical-target-change.md). This ADR does not edit them; ADR 0005 governs the physical target.

## Consequences and trade-offs

- **Positive:** compressed in-memory swap by default; no disk reservation for users who disable hibernation; hibernation stays supported and qualifiable; native mechanisms only; and RAM and asset binding prevent a stale approval from authorizing different sizing or configuration.
- **Fallback consumes hibernation space.** Disk fallback uses the same file, so free capacity for hibernation shrinks under pressure. A RAM-sized default is a conservative starting point, not a guarantee.
- **Global tuning.** Swappiness 180 also applies during disk fallback. Page-cluster 0 can sacrifice disk readahead. A scale factor of 125 means 1.25% watermark spacing and can increase reclaim activity and retained free memory. Boost factor 0 disables fragmentation-triggered extra reclaim and may disadvantage some high-order allocations.
- **Reduced swapfile sizes** may make hibernation unavailable under large workloads. The warning is persistent but non-blocking.
- **Zram capacity is logical.** Poorly compressible data can still cause memory pressure.
- **More plan surface.** Plans carry conditional fields and two asset hashes; versioned rejection forces regeneration of old plans.
- **No runtime enforcement.** Declarative tests do not show that zram is active, that zstd is available in the kernel, that zswap is off, or that sysctl values take effect.
- **Fixed range is gone.** Machines above 64 GiB of RAM can now size the swapfile accordingly.
- **Bounded UI change.** One stage differs from the frozen prototype, with the deviation recorded.

## Replacement or reversal boundary

Revisit this decision if any of the following occurs:

- Installed-system pressure tests that reach the swapfile show unacceptable responsiveness or lost hibernation availability.
- Any sysctl value proves harmful for the target workload, or the kernel rejects zstd for zram.
- Repeated hibernation and resume fail on the Framework target with this layout.
- Fallback use of the swapfile proves incompatible with reliable resume and an exclusive-use mechanism becomes justified.
- The official `zram-generator` package or its configuration format changes incompatibly.
- Maintaining conditional plan surface proves more costly than the maintainer accepts.

## Required validation

Before adoption:

- The maintainer reviews this ADR, the version 3 contracts, and the proposed amendments above, and accepts them explicitly.

After adoption, within plan 02-08:

- Automated planning, validation, assistant, confirmation, embedding, and VM-driver tests pass for all three storage options with hibernation enabled and disabled.
- A clean ISO exercises the new stage and review in the reference VM with an attended, artifact-bound verdict, and the existing confirmation scenarios still pass.

Pending for Story 2.5 and later qualification, not claimed here:

- The `zram-generator` package is installed, a zram device is active, the selected algorithm is zstd, and zswap is disabled.
- The effective sysctl values equal the declared ones.
- Memory-pressure tests reach the disk fallback and assess responsiveness, hibernation availability, and the effect of each tuning value.
- Free hibernation space is checked, and repeated hibernation and resume are validated.
- The Framework integrated-AMD target of ADR 0005 is qualified physically.

## References

- [Architecture](../architecture.md)
- [ADR 0003](0003-storage-and-recovery-baseline.md)
- [ADR 0005](0005-physical-target-change.md)
- [ADR 0006](0006-guided-live-installation-boundaries.md)
- [Installation plan contract](../../contracts/installation-plan.md)
- [Installation confirmation contract](../../contracts/installation-confirmation.md)
- [Zram and hibernation policy decision log](../technical-interviews/zram-hibernation-policy_log.md) and [plan](../technical-interviews/zram-hibernation-policy_plan.md)
- [ArchWiki: Zram](https://wiki.archlinux.org/title/Zram)
- [ArchWiki: Zswap](https://wiki.archlinux.org/title/Zswap)
- [zram-generator.conf(5)](https://man.archlinux.org/man/zram-generator.conf.5)
- [Linux kernel vm sysctl documentation](https://docs.kernel.org/admin-guide/sysctl/vm.html)
- [Linux kernel zswap documentation](https://docs.kernel.org/admin-guide/mm/zswap.html)
- [Linux kernel software suspend documentation](https://docs.kernel.org/power/swsusp.html)

## Superseded by

`None`
