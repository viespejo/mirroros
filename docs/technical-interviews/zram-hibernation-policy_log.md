# Zram and hibernation-only swapfile — Decision Log

## DEC-001
- **Question**: Does hibernation remain an essential MVP capability or become optional?
- **Context/Nuances**: The current architecture requires hibernation and a swapfile serving both ordinary swap and hibernation. Plan 02-07 is complete, but no installation engine exists. Separating everyday swap from hibernation does not by itself prevent an active low-priority swapfile from serving ordinary swap. The enforcement mechanism remains unresolved. Existing accepted ADRs must not be rewritten; the policy change requires a new ADR 0007.
- **User Response**: "nota: activa la persistencia. yes, registra directamente la decisión"
- **Decision**: Keep hibernation essential for the MVP and always plan a swapfile intended for hibernation, with zram for everyday swap. Adopt the separation of roles rather than Omarchy's opt-in hibernation requirement. Swapfile sizing and the mechanism enforcing the separation of roles remain pending.
- **Status**: Accepted

## DEC-002
- **Question**: Should users be able to disable hibernation despite its default-enabled and essential MVP status, and how should its swapfile be sized?
- **Context/Nuances**: Essential MVP support and qualification do not require enabling the capability on every installation. This decision supersedes DEC-001's requirement to always plan a swapfile; DEC-001 remains preserved as history. Capacity alone does not guarantee successful hibernation and resume.
- **User Response**: The maintainer proposed allowing users to disable default-enabled hibernation, then explicitly confirmed the proposed registration: "yes, registra directamente la decisión".
- **Decision**: Hibernation remains an essential capability MirrorOS must support and verify, enabled by default but explicitly disableable by the user. Disabling it omits the swapfile and resume configuration while retaining zram. When enabled, the swapfile minimum is detected RAM rounded upward to a whole GiB; users may increase but not decrease it below that minimum. If the swapfile, root minimum, and ESP do not fit, block plan generation with an explanation rather than silently disabling hibernation. UI presentation and the mechanism reserving the swapfile for hibernation remain unresolved.
- **Status**: Accepted

## DEC-003
- **Question**: Should detected RAM be required for plan generation, including when hibernation is disabled?
- **Context/Nuances**: Memory is currently optional in discovery facts. Both RAM-based swapfile sizing and the forthcoming zram sizing policy depend on detected memory; no fallback size has been approved.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Require detected RAM to generate an installation plan, even with hibernation disabled. If unavailable, block generation with an actionable diagnostic asking the user to repeat discovery. Do not substitute an assumed memory or swap size.
- **Status**: Accepted

## DEC-004
- **Question**: What logical size should zram use, and should users edit it in the installer?
- **Context/Nuances**: The handoff reports Omarchy using a logical zram size equal to RAM. Logical capacity is not an immediate reservation of that amount of physical memory. Actual consumption depends on stored data and compression; poorly compressible data can create memory pressure. This does not guarantee doubling available memory.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Set zram logical capacity equal to detected RAM as fixed installation policy, not editable through the installer. Exact conversion and configuration representation remain implementation details to specify.
- **Status**: Accepted

## DEC-005
- **Question**: Should zram use zstd as its fixed compression algorithm?
- **Context/Nuances**: The handoff reports Omarchy using zstd. The recommendation favors compression over alternatives oriented toward lower CPU cost, such as lz4; no unmeasured performance improvement is claimed. Kernel support must be checked rather than assumed.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Use zstd for zram compression as fixed policy, not editable through the installer. Detect failure if the kernel does not provide zstd; do not silently substitute another algorithm.
- **Status**: Accepted

## DEC-006
- **Question**: Is explicitly disabling zswap necessary, and should this policy affect the installed system or the live ISO?
- **Context/Nuances**: The maintainer questioned when zswap would be enabled by default. Linux documents CONFIG_ZSWAP_DEFAULT_ON as controlling the boot default and zswap.enabled=0 as an override (https://docs.kernel.org/admin-guide/mm/zswap.html). ArchWiki reports official Arch kernels enabling zswap by default (https://wiki.archlinux.org/title/Zswap). Read-only inspection of the maintainer's running kernel found CONFIG_ZSWAP_DEFAULT_ON=y; this is host evidence, not installed-target qualification. MirrorOS currently declares the linux package and no zswap override in install/plan/policy.json. Disabling zswap is not required to create zram; it avoids an additional compressed-cache layer in front of it and makes policy independent of kernel defaults.
- **User Response**: After the explanation and evidence, "yes, registra directamente la decisión".
- **Decision**: Explicitly disable zswap with zswap.enabled=0 in the installed system's planned kernel command line as fixed policy. Do not change the live ISO's memory policy through this decision.
- **Status**: Accepted

## DEC-007
- **Question**: May the hibernation-sized swapfile serve as fallback ordinary swap when zram is under pressure, using priorities 100 and 0?
- **Context/Nuances**: Priority prefers zram but does not reserve the swapfile exclusively for hibernation or guarantee it stays unused. Under DEC-002, the swapfile exists only when hibernation is enabled. The maintainer explicitly raised this condition and questioned the RAM-sized minimum for a 64 GiB machine; that sizing concern remains open and does not yet supersede DEC-002.
- **User Response**: "yes, registra directamente la decisión", followed by a question confirming the hibernation-enabled condition and concern about allocating a 64 GiB swapfile.
- **Decision**: Use zram swap priority 100. Only when hibernation is enabled, plan a swapfile with priority 0 that may also serve as fallback ordinary swap under memory pressure. Describe it as hibernation-sized storage with fallback swap use, not as exclusively used for hibernation. With hibernation disabled, no disk swapfile is planned.
- **Status**: Accepted

## DEC-008
- **Question**: Should users be allowed to choose a hibernation swapfile smaller than detected RAM, with a warning?
- **Context/Nuances**: The maintainer questioned reserving 64 GiB of disk on a machine with 64 GiB of RAM. RAM capacity is not the size of every hibernation image: the kernel attempts to reclaim memory and normally compresses the image. Linux documentation describes a default image-size target around two-fifths of available RAM (https://docs.kernel.org/power/swsusp.html), but this is not a guarantee of sufficient swap capacity. A RAM-sized file remains a conservative default, not proof of successful hibernation. This decision supersedes DEC-002's prohibition on reducing size below RAM, not its default-enabled hibernation or disk-fit rules.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Retain detected RAM rounded upward to a whole GiB as the default swapfile size when hibernation is enabled. Permit users to explicitly choose smaller sizes with a warning that hibernation may be unavailable under large memory workloads. Exact allowed minimum and maximum, warning presentation, and runtime handling of insufficient space remain unresolved.
- **Status**: Accepted

## DEC-009
- **Question**: Should the swapfile size maximum be RAM-based rather than disk-based, and what range should be allowed?
- **Context/Nuances**: The current range is 512–65536 MiB. The maintainer rejected a disk-capacity-based maximum in favor of RAM. The approved maximum is detected RAM rounded upward to a whole GiB, so it may be slightly greater than the raw detected RAM value. The minimum is an input limit, not a claim that 512 MiB suffices for hibernation. This supersedes the earlier permission to increase the swapfile beyond its RAM-based default.
- **User Response**: The maintainer proposed RAM as the maximum and then confirmed the complete registration: "yes, registra directamente la decisión".
- **Decision**: When hibernation is enabled, allow integer MiB sizes from 512 MiB up to detected RAM rounded upward to a whole GiB. Use that maximum as the default. Warn when the chosen size is below raw detected RAM. Reject a chosen size that does not fit alongside the ESP and root minimum, without automatically shrinking it or disabling hibernation. The RAM-based maximum is a sizing policy, not a guarantee of successful hibernation.
- **Status**: Accepted

## DEC-010
- **Question**: Should the installed system use the official zram-generator package to configure zram?
- **Context/Nuances**: Native systemd integration avoids a project-owned replacement service. The handoff reports an Omarchy defect where configuration shipped without the required package; configuration presence alone is not activation evidence. Package provenance must be explicit rather than relying on transitive dependencies.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Use the official Arch zram-generator package, explicitly declared among installed-system packages. Do not add it to the live ISO under this decision. Future verification must check both package installation and an actually active zram device, not merely configuration-file presence.
- **Status**: Accepted

## DEC-011
- **Question**: Where should MirrorOS provide its zram-generator configuration, and how should administrator overrides be separated?
- **Context/Nuances**: The handoff identifies /usr/lib/systemd/zram-generator.conf.d/ as the vendor configuration location and /etc/ as administrator-owned. Fixed installer choices do not prohibit later explicit administrator changes through native configuration mechanisms.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Provide MirrorOS's installed-system zram configuration at /usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf. Reserve /etc/ for administrator overrides and preserve the ability to change parameters after installation through native mechanisms. The repository source location and delivery boundary remain to be specified.
- **Status**: Accepted

## DEC-012
- **Question**: Should plan 02-08 prepare the swap policy before the installation engine rather than implement installed-system execution?
- **Context/Nuances**: Plan 02-07 is complete but install/engine/apply does not exist. Implementing target-disk delivery or activation now would prematurely introduce a partial engine. Declarative and planning tests do not establish installed-system activation or real hibernation readiness.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Limit 02-08 to ADR 0007 and normative-document reconciliation; policy, contracts, plan generation and validation; guided-installer hibernation choices, sizing and warnings; declarative zram configuration; and tests of these changes. Leave application to the installed disk, actual zram activation, and real hibernation/resume verification to Story 2.5 and subsequent qualification. Do not claim those capabilities verified in 02-08.
- **Status**: Accepted

## DEC-013
- **Question**: Should the existing swapfile-size screen become one hibernation stage in the same position of the guided flow?
- **Context/Nuances**: The current configuration flow presents swapfile sizing immediately after storage layout. The frozen prototype and confirmation contract require explicit approval of presentation or workflow deviations. This is a narrow approved deviation, not permission for a general redesign.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Replace the existing swapfile-size stage with a hibernation stage at the same point in the flow. First offer Enabled or Disabled, defaulting to Enabled for the initial choice. Only when enabled, present swapfile sizing and its applicable warning. The review shows hibernation status and does not present a swapfile size as something to be created when disabled. Document this as an explicitly approved prototype deviation.
- **Status**: Accepted

## DEC-014
- **Question**: How should hibernation and conditional swapfile sizing be represented, including toggle behavior and contradictory choices?
- **Context/Nuances**: Generated plans should describe only proposed configuration. Keeping a stale swapfile size when hibernation is disabled could misleadingly imply file creation or allow silently ignored explicit inputs. The existing edit loop accumulates explicit choices and therefore needs conditional cleanup.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Introduce editable boolean hibernation, default true. With false, omit swapfile_size, swapfile creation, and resume parameters from the generated plan. The assistant removes the explicit size choice when disabling hibernation and proposes the RAM-based default again when re-enabling it. Reject choices files combining hibernation: false with swapfile_size as contradictory rather than silently ignoring the size.
- **Status**: Accepted

## DEC-015
- **Question**: Should installation plans, policy, and choices advance to version 3 while target facts remain version 2?
- **Context/Nuances**: Conditional fields and changed safety-relevant operations must not silently reinterpret old plans. The current installation contract already rejects earlier versions with regeneration guidance. Memory is already representable in facts v2; requiring it at the planning boundary does not require a facts schema change. Compatibility for legacy workflow plans in .agents/plans/ is separate from installation-plan execution safety.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Advance installation plans, installation policy, and choices files to format version 3. Reject earlier versions with actionable regeneration guidance, without automatic migration or reinterpretation. Keep target facts at format version 2 and enforce the RAM prerequisite during planning. Leave reading of legacy workflow plans in .agents/plans/ unchanged.
- **Status**: Accepted

## DEC-016
- **Question**: Should the installation plan expose configure_zram explicitly and make create_swapfile conditional?
- **Context/Nuances**: The existing contract fixes operation vocabulary and ordering per storage option. Explicit operations keep the future engine's responsibilities reviewable. Plan generation and validation are not execution evidence.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Add configure_zram immediately after install_packages for every storage option. It describes zram-generator configuration, including the drop-in path, size, algorithm, and priority. Emit create_swapfile only when hibernation is enabled and include swap priority 0. When disabled, omit that operation without changing the relative order of the others. Plan 02-08 generates and validates these operations but does not execute them.
- **Status**: Accepted

## DEC-017
- **Question**: Should Btrfs installations omit the @swap subvolume when hibernation is disabled?
- **Context/Nuances**: Both existing Btrfs options always declare @swap. With no planned swapfile, keeping its subvolume and mount would not serve this installation's policy. This condition must be reconciled through ADR 0007 rather than silently changing the ADR 0003 baseline.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: For both Btrfs storage options, omit @swap and its mount when hibernation is disabled. When enabled, retain @swap separately from snapshots and retain Btrfs-specific resume_offset calculation. Leave other subvolumes and Snapper policy unchanged.
- **Status**: Accepted

## DEC-018
- **Question**: Should 02-08 conclude with automated tests and attended assistant review on a clean ISO in the reference VM?
- **Context/Nuances**: Coverage includes all three storage options, enabled/disabled hibernation, reduced sizing and warning, missing RAM, size limits, old versions, and confirmation/cancellation safety. Review is non-destructive with respect to the installation disk. The handoff's hybrid AMD/NVIDIA qualification reference is stale: accepted ADR 0005 fixes the Framework target with integrated AMD graphics only. Physical qualification is not performed in this plan. The maintainer asked why graphics are relevant and where swappiness should be decided; swappiness remains unresolved.
- **User Response**: "yes, registra directamente la decisión", followed by questions about graphics relevance and swappiness ownership.
- **Decision**: Verify 02-08 through automated tests and attended review of the new hibernation stage and review content on a clean ISO in the reference VM, without executing installation-disk operations. Leave installed zram activation and actual hibernation cycles pending. Future physical qualification follows the Framework integrated-AMD target under ADR 0005, not a newly expanded NVIDIA support scope. Builds and VM actions still require their own explicit sensitive-operation confirmation at execution time.
- **Status**: Accepted

## DEC-019
- **Question**: Should the installed-system policy use vm.swappiness=180 rather than the proposed 100?
- **Context/Nuances**: The maintainer selected 180. Linux documentation describes swappiness as the relative cost of swap versus filesystem paging, with a workload-dependent optimum (https://docs.kernel.org/admin-guide/sysctl/vm.html#swappiness). ArchWiki's zram tuning example includes 180 plus watermark and page-cluster settings (https://wiki.archlinux.org/title/Zram#Optimizing_swap_on_zram); the other settings are not approved by this decision. Swappiness is system-wide rather than per swap device. The maintainer explicitly raised whether disk fallback requires different handling; that remains unresolved.
- **User Response**: Initially requested 180, then confirmed registration: "yes, registra directamente la decisión", and asked about falling back to the swapfile.
- **Decision**: Declare vm.swappiness=180 as initial fixed installed-system policy, modifiable afterward by the administrator. Do not change the live ISO and do not claim this value is optimal. The installation engine applies declared policy rather than selecting tuning values. Handling and qualification of the interaction with disk fallback remain open; no dynamic adjustment is approved.
- **Status**: Accepted

## DEC-020
- **Question**: Should swappiness remain 180 during disk fallback without dynamic tuning, subject to future pressure testing?
- **Context/Nuances**: Swappiness is global and swap priorities do not change reclaim's swap-versus-file-cache policy. When zram cannot accept more pages, disk fallback may retain the high swap preference and increase latency. Ordinary swapfile usage also reduces available hibernation capacity. No daemon or adaptive controller has been selected.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Keep vm.swappiness=180 without dynamic adjustment or a project-owned daemon. Require future installed-system memory-pressure tests that reach the swapfile and assess responsiveness and hibernation availability. Revisit policy if results are unacceptable. In 02-08 document these risks and pending tests, without representing them as resolved or qualified.
- **Status**: Accepted

## DEC-021
- **Question**: Should the installed-system policy set vm.page-cluster=0?
- **Context/Nuances**: Zero disables swap readahead, fetching only the needed page rather than potentially decompressing unused additional pages on zram. This setting is global: disk fallback may lose readahead benefits and require more disk operations. Kernel documentation describes the latency-versus-additional-fault trade-off (https://docs.kernel.org/admin-guide/sysctl/vm.html); ArchWiki includes zero in its zram tuning example. No optimality is established for MirrorOS workloads.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Set vm.page-cluster=0 as initial fixed installed-system policy, not editable through the installer but modifiable afterward by the administrator. Include its disk-fallback trade-off in the future memory-pressure tests already required. Do not claim it is optimal or change the live ISO's policy.
- **Status**: Accepted

## DEC-022
- **Question**: Should the installed-system policy set vm.watermark_scale_factor=125?
- **Context/Nuances**: The value uses units of 1/10000 and corresponds to watermark spacing of 1.25%, not 125%. Wider spacing can encourage kswapd to reclaim earlier and reduce direct reclaim, at the cost of more reclaim activity and retained free memory. It is global and does not itself select the transition from zram to disk swap. The maintainer asked whether 64 GiB RAM makes swapfile fallback nearly impossible; no such workload-independent claim is accepted.
- **User Response**: "yes, registra directamente la decisión", followed by a question about disk-fallback likelihood with 64 GiB RAM.
- **Decision**: Set vm.watermark_scale_factor=125 as initial fixed installed-system policy, without an installer control but with native administrator overrides. Cover its effects in future pressure testing, without claiming optimality or changing the live ISO.
- **Status**: Accepted

## DEC-023
- **Question**: Should the installed-system policy set vm.watermark_boost_factor=0?
- **Context/Nuances**: Zero disables additional reclaim triggered by fragmentation. It completes the discussed ArchWiki zram tuning example but can disadvantage certain high-order allocations. This is a chosen initial policy, not workload-independent optimality; future pressure testing must include the trade-off.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Set vm.watermark_boost_factor=0 as initial fixed installed-system policy, without an installer control but with native administrator overrides. Record the high-order-allocation trade-off for future validation. Do not claim optimality or change the live ISO.
- **Status**: Accepted

## DEC-024
- **Question**: How should declarative zram and sysctl assets be owned and represented in planned operations?
- **Context/Nuances**: zram-generator configuration and sysctl configuration have distinct native mechanisms. Distribution-owned files belong under /usr/lib, with /etc reserved for administrator overrides. The policy preparation scope does not apply these assets to an installed system.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Store declarative assets under install/plan/assets/ mirroring their destination paths: usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf and usr/lib/sysctl.d/60-mirroros-memory.conf. Add configure_memory_reclaim immediately after configure_zram to describe delivery of the four accepted memory settings through the sysctl drop-in. Preserve native administrator overrides and introduce no project-owned service. In 02-08 prepare files and planned operations only.
- **Status**: Accepted

## DEC-025
- **Question**: Should detected RAM be bound into the installation plan and checked during final revalidation?
- **Context/Nuances**: Existing compare-safety checks machine identity, firmware, disk, profile, and policy but not RAM. RAM-derived sizing must not remain authorized when the freshly observed memory differs or disappears. This applies even without hibernation because zram also depends on RAM.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Include memory_total_bytes in the machine information of installation plan v3. During final revalidation, invalidate authorization if RAM differs or is unavailable and require regeneration and review, including when hibernation is disabled.
- **Status**: Accepted

## DEC-026
- **Question**: Should declarative configuration assets be content-bound into the approved plan and revalidated?
- **Context/Nuances**: A policy hash alone must not allow a changed configuration asset to be delivered under apparently unchanged authorization. Both native drop-ins are inputs to future installed-system delivery. The binding is not execution evidence.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Each configuration operation includes its destination path and the SHA-256 of its source asset, covered by the installation plan digest. Final revalidation compares the current assets and invalidates authorization if either drop-in has changed since review. The future engine must not deliver different asset content under the same approved plan.
- **Status**: Accepted

## DEC-027
- **Question**: Should the native zram configuration use a minimal single-device ram expression without additional mechanisms?
- **Context/Nuances**: zram-generator supports a native ram expression based on MemTotal (https://man.archlinux.org/man/zram-generator.conf.5). Resident limits, recompression, and writeback are distinct mechanisms not needed for the accepted policy. An ordinary lower-priority swapfile is not a zram writeback device.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Use one [zram0] section with zram-size = ram, compression-algorithm = zstd, and swap-priority = 100. The plan describes the formula and binds detected RAM. Add no resident-memory limit, recompression, or writeback device. Keep the optional swapfile independent as lower-priority swap.
- **Status**: Accepted

## DEC-028
- **Question**: Should below-RAM sizing be a persistent warning without an additional confirmation dialog?
- **Context/Nuances**: DEC-008 permits smaller sizes with a warning. Hibernation capacity depends on workload and free swapfile space; even the default does not prove successful resume. Final confirmation already authorizes the complete reviewed plan.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Display the below-RAM warning on the sizing screen and in review, and include it among structured plan warnings. Do not reject an otherwise valid size or add another confirmation dialog. Explain dependence on used memory and free swapfile space, and avoid claiming that the default guarantees correct resume.
- **Status**: Accepted

## DEC-029
- **Question**: Should installation and approval evidence records also advance to version 3 to reflect RAM binding and choices v3?
- **Context/Nuances**: Confirmation records have their own format constant and strict machine-field validation. A new machine field and embedded choices v3 should be represented coherently without reinterpreting old evidence. Evidence is private and cannot authorize a future execution.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: Advance install-run.json and approval-record.json to record format version 3, supporting machine memory_total_bytes and choices v3. Preserve privacy and their non-authorizing status for future runs. Do not migrate old records or change target facts v2.
- **Status**: Accepted

## DEC-030
- **Question**: Should implementation be blocked on explicit approval of a proposed ADR 0007 and its associated contracts and UI deviation?
- **Context/Nuances**: Interview decisions define the intended design but do not silently ratify a normative ADR. Accepted historical ADR decisions must not be rewritten. Declarative tests are not activation or hibernation evidence.
- **User Response**: "yes, registra directamente la decisión"
- **Decision**: During 02-08 execution, first draft ADR 0007 as Proposed with scope, risks, evidence, and exact normative amendments. Present it with revised contracts and the UI deviation for maintainer review. Only after explicit approval mark it Accepted, reconcile architecture and epics, and implement policy/code changes. Preserve ADR 0003's historical decision, adding only a partial-supersession forward link in its corresponding section. Do not represent declarative checks as activation or hibernation evidence.
- **Status**: Accepted

## DEC-031
- **Question**: Should the agreed scope be split between a normative/declarative plan and an implementation/qualification plan?
- **Context/Nuances**: During draft preparation, the references recommended short executable plans. The assistant proposed splitting into 02-08 and 02-09. The maintainer rejected that organization; the previously accepted complete scope remains unchanged. Approval gates and verification boundaries must not be lost by grouping work into fewer milestones.
- **User Response**: "prefiero un solo plan"
- **Decision**: Keep the full agreed scope in a single 02-08 plan, depending exclusively on 02-07-guided-live-installer-transition. Do not create a separate 02-09 for this work. Organize the draft into three milestones while preserving explicit normative approval and attended qualification gates, co-located implementation tests, and the exclusion of the installation engine.
- **Status**: Accepted
