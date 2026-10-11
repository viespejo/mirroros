# Zram and hibernation-only swapfile — Consolidated Interview Plan

## Accepted direction

Hibernation remains an essential MVP capability that MirrorOS must support and qualify, enabled by default but explicitly disableable by the user. When disabled, the installation plan omits the swapfile and resume configuration while retaining zram for everyday swap. This supersedes DEC-001's unconditional swapfile requirement. When enabled, the swapfile is dimensioned for hibernation and may also serve ordinary swap as a lower-priority fallback; exclusive hibernation-only use is not required. [DEC-001, DEC-002, DEC-007]

When hibernation is enabled, the maximum and default swapfile size are detected RAM rounded upward to a whole GiB. Users may explicitly choose smaller integer MiB sizes down to 512 MiB, with a warning when the chosen capacity is below raw detected RAM that hibernation may be unavailable under large memory workloads. The minimum is only an input limit, not a claim of sufficient hibernation capacity. This supersedes DEC-002's RAM-sized minimum and the earlier permission to exceed the default. If the chosen swapfile, root minimum, and ESP do not fit on the target disk, plan generation must fail with an explanation rather than automatically shrinking it or disabling hibernation. The RAM-based default and maximum are sizing policy, not proof of successful hibernation and resume. [DEC-002, DEC-008, DEC-009]

The policy change must be reconciled through a new ADR 0007 rather than rewriting accepted ADRs. The current architecture's combined ordinary-swap/hibernation policy remains normative until the new ADR is accepted. [DEC-001]

## Implementation context

The completed 02-07 summary reports a guided installer, v2 installation plans, and an explicit engine-not-available hand-over. No installation engine exists yet. This interview prepares the policy, contracts, assistant changes, declarative assets, and their verification before Story 2.5; installed-system execution remains excluded. [DEC-012]

## Deferred installed-system work

Story 2.5 and subsequent qualification must apply the reviewed assets, verify effective generator capacity and zstd support, check active zram and zswap state, and validate actual hibernation/resume and memory-pressure fallback. Runtime handling of insufficient free hibernation space is not implemented in 02-08. The tuning baseline remains subject to measurement and reversal if unacceptable. This is deferred work, not evidence of readiness or a reason to implement a partial engine now. [DEC-005, DEC-010, DEC-012, DEC-018, DEC-020, DEC-021, DEC-022, DEC-023, DEC-027]

## Memory prerequisite

Installation plan generation requires detected RAM even when hibernation is disabled, because zram sizing also depends on memory. Missing memory must block generation with an actionable diagnostic requesting discovery again; no assumed memory or fallback swap size is allowed. The planning boundary enforces this prerequisite while target facts remain v2. [DEC-003, DEC-015]

## Zram capacity

Zram logical capacity equals detected RAM and is fixed installation policy, with no installer editing control. This capacity is not an immediate physical-memory reservation or a guarantee of doubling available memory: actual consumption depends on stored data and compression, and poorly compressible data can cause memory pressure. [DEC-004]

Zram uses zstd compression as fixed policy, without an installer editing control. This choice favors compression over lower-CPU-cost alternatives such as lz4, without claiming an unmeasured performance benefit. Missing kernel support must be detected as a failure, not masked through silent algorithm substitution. [DEC-005]

## Zswap policy

The installed system's planned kernel command line explicitly includes zswap.enabled=0 as fixed policy, avoiding an additional compressed-cache layer in front of zram and dependence on kernel defaults. This decision does not change the live ISO's memory policy. Linux documents CONFIG_ZSWAP_DEFAULT_ON and the command-line override; ArchWiki reports official Arch kernels enabling zswap by default. The maintainer's running kernel also has CONFIG_ZSWAP_DEFAULT_ON=y, which is host evidence rather than qualification of an installed MirrorOS target. Disabling zswap is not a prerequisite for creating zram. [DEC-006]

## Swap priorities and fallback

Zram uses swap priority 100. When hibernation is enabled, the swapfile uses priority 0 and may also serve ordinary swap as a fallback under memory pressure. It is hibernation-sized storage with fallback swap use, not exclusively hibernation storage; priority does not guarantee it remains unused. When hibernation is disabled, no disk swapfile is planned. [DEC-002, DEC-007]

The maintainer's concern about reserving 64 GiB of disk on a 64 GiB machine led to allowing explicitly smaller swapfiles with a warning. Installed RAM does not determine the size of every hibernation image: the kernel attempts memory reclaim and normally compresses the image. Its documented default image-size target around two-fifths of available RAM is not a guarantee of sufficient swap capacity. No custom image-size limit has been approved. [DEC-008]

## Package and activation mechanism

The installed system uses the official Arch zram-generator package, explicitly declared among installation packages with provenance rather than inherited as a transitive dependency. Its native systemd integration avoids a project-owned replacement service. This decision does not add the package to the live ISO. Verification must check both package installation and an actually active zram device; configuration-file presence is insufficient. [DEC-010]

MirrorOS provides its installed-system configuration at /usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf, leaving /etc/ for explicit administrator overrides. Parameters fixed in the installer do not prevent later changes through native configuration mechanisms. The source is owned under install/plan/assets/; delivery is described by planned operations but not executed in 02-08. [DEC-011, DEC-012, DEC-024]

## Implementation scope

Plan 02-08 prepares this policy before the installation engine: ADR 0007 and normative-document reconciliation; installation policy and contracts; plan generation and validation; guided-installer hibernation choices, sizing, and warnings; declarative zram configuration; and tests of these changes. It must not introduce a partial installation engine. Applying the configuration to an installed disk, activating zram, and verifying real hibernation/resume belong to Story 2.5 and subsequent qualification. Declarative and planning checks in 02-08 must not be represented as installed-system readiness evidence. [DEC-012]

## Guided-installer presentation

Replace the existing swapfile-size stage immediately after storage layout with a hibernation stage at the same flow position. First offer Enabled or Disabled, initially defaulting to Enabled. Present swapfile sizing and its applicable warning only when enabled. Review content shows hibernation status and must not present a swapfile size as a pending creation when hibernation is disabled. This is an explicitly approved deviation from the frozen prototype, not authorization for unrelated presentation or workflow redesign. [DEC-013]

## Conditional plan choices

Introduce hibernation as an editable boolean defaulting to true. A disabled plan omits swapfile_size, swapfile creation, and resume parameters. The assistant removes the explicit size choice when hibernation is disabled; re-enabling it proposes the RAM-based default again rather than restoring a hidden stale size. Reject a choices file combining hibernation: false with swapfile_size as contradictory instead of silently discarding explicit input. [DEC-014]

## Versioning and compatibility

Installation plans, policy, and choices files advance to format version 3 because conditional fields and changed safety-relevant operations must not reinterpret older documents. Reject earlier versions with actionable regeneration guidance, without automatic migration. Target facts remain version 2: memory is already representable, and planning enforces its presence. Reading legacy workflow plans in .agents/plans/ remains unchanged; that compatibility is distinct from accepting old installation plans. [DEC-015]

## Planned operations

Every storage option includes configure_zram immediately after install_packages. This explicit operation describes zram-generator configuration, including the drop-in path, size, algorithm, and priority. create_swapfile is emitted only when hibernation is enabled and includes swap priority 0; omitting it preserves the relative order of all other operations. In 02-08 these operations are generated and validated, never executed. [DEC-016]

For both Btrfs options, disabling hibernation also omits the @swap subvolume and its mount. Enabling it retains @swap separately from snapshots and retains Btrfs-specific resume_offset calculation. Other subvolumes and Snapper policy remain unchanged; ADR 0007 must explicitly reconcile this conditional behavior with ADR 0003. [DEC-017]

## Verification boundary

Automated verification covers all three storage options, hibernation enabled and disabled, reduced sizing and warnings, missing RAM, size limits, rejected old formats, and confirmation/cancellation safety. An attended review on a clean ISO in the reference VM checks the new hibernation stage and review content without executing installation-disk operations. Builds and VM actions still require explicit sensitive-operation confirmation when executed. Neither this review nor unit/contract tests qualify installed zram activation or real hibernation cycles. Future physical qualification uses the Framework integrated-AMD target of ADR 0005; the handoff's hybrid AMD/NVIDIA reference does not expand support. [DEC-018]

## Memory reclaim tuning

The installed-system policy declares vm.swappiness=180 as an initial fixed setting, with native administrator overrides and no live-ISO change. This is a selected baseline, not a claim of workload-independent optimality; the engine applies declared policy instead of choosing tuning values. Swappiness is system-wide; its disk-fallback interaction remains subject to future pressure qualification, without dynamic adjustment. The additional settings are page-cluster=0, watermark_scale_factor=125, and watermark_boost_factor=0. [DEC-019, DEC-020, DEC-021, DEC-022, DEC-023]

Keep swappiness at 180 during disk fallback without dynamic adjustment or a project-owned daemon. Swap priorities do not change the global reclaim policy; disk fallback may increase latency, and ordinary swapfile usage reduces free hibernation capacity. Future installed-system pressure tests must reach the swapfile and assess responsiveness and hibernation availability. Revisit the policy if results are unacceptable. In 02-08 these risks and tests remain explicitly pending, not resolved or qualified. [DEC-020]

Set vm.page-cluster=0 as initial fixed installed-system policy, without an installer control but with native administrator overrides. Disabling swap readahead avoids fetching and decompressing potentially unused additional pages on zram. It may sacrifice disk-fallback readahead benefits and increase disk operations; the future pressure tests must cover this trade-off. No workload-independent optimality or live-ISO policy change is claimed. [DEC-021]

Set vm.watermark_scale_factor=125 as initial fixed installed-system policy, without an installer control but with native administrator overrides. This corresponds to watermark spacing of 1.25%, potentially promoting earlier kswapd reclaim and reducing direct reclaim, with a trade-off of more reclaim activity and retained free memory. It does not itself control the zram-to-disk transition. Its effects require future pressure testing; no optimality or live-ISO change is claimed. [DEC-022]

Set vm.watermark_boost_factor=0 as initial fixed installed-system policy, without an installer control but with native administrator overrides. This disables extra reclaim triggered by fragmentation, potentially disadvantaging high-order allocations. The trade-off belongs in future validation; adopting the tuning example is not evidence of optimality, and the live ISO is unchanged. [DEC-023]

## Declarative asset ownership

Installation policy owns declarative assets under install/plan/assets/ mirroring their destination paths: usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf and usr/lib/sysctl.d/60-mirroros-memory.conf. configure_memory_reclaim follows configure_zram immediately and describes delivery of the four accepted sysctl settings. These remain distinct native configuration mechanisms, with administrator overrides under /etc and no project-owned service. In 02-08 only sources and planned operations are prepared, not applied. [DEC-024]

The v3 plan's machine information includes memory_total_bytes. Final revalidation compares freshly detected RAM with this bound value; a changed or unavailable value invalidates authorization and requires plan regeneration and review, even when hibernation is disabled. Existing identity and disk safety checks remain in force. [DEC-025]

Each configuration operation includes its destination path and source asset SHA-256, covered by the plan digest. Final revalidation checks the current source assets and invalidates authorization if either native drop-in has changed. This binds the future engine's delivery to reviewed content rather than allowing asset changes behind an unchanged policy hash. [DEC-026]

The native generator drop-in contains one [zram0] section with zram-size = ram, compression-algorithm = zstd, and swap-priority = 100. The plan describes the formula and binds detected RAM. No resident-memory limit, recompression, or writeback device is added; the optional lower-priority swapfile is independent swap, not zram writeback. Native generator unit conversion and alignment must be respected when later verifying effective capacity. [DEC-027]

Below-RAM sizing produces a warning on the sizing screen, in review, and in the structured plan. It does not block an otherwise valid size or add a confirmation dialog; final confirmation authorizes the whole plan. Wording explains dependence on used memory and free swapfile space and never claims that the default guarantees correct resume. [DEC-028]

Confirmation evidence records install-run.json and approval-record.json also advance to their own format version 3, supporting machine memory_total_bytes and choices v3 coherently. Old records are not migrated. Their private handling and inability to authorize a future run remain unchanged; target facts stay version 2. [DEC-029]

## Normative approval gate

Execution first drafts ADR 0007 as Proposed with boundaries, risks, evidence, and exact normative amendments, and presents it with revised contracts and the approved UI deviation for maintainer review. Explicit approval is required before marking it Accepted, reconciling architecture and epics, or implementing policy/code changes. ADR 0003 retains its historical decision with only a partial-supersession forward link in the appropriate section. Declarative checks are not activation or hibernation evidence. [DEC-030]

## Plan organization

The maintainer rejected splitting the agreed scope. Keep one plan numbered 02-08, depending exclusively on 02-07-guided-live-installer-transition, with three milestones: normative approval, implementation with co-located tests, and assistant qualification. Grouping the work must preserve approval gates, test ordering, detailed design trade-offs, and the exclusion of the installation engine. No separate 02-09 is created for this scope. [DEC-031]
