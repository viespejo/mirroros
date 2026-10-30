# Installation plan (`installation-plan.json`)

`format_version: 5`. Produced by `operations/install plan` from a valid [`target-facts.json`](target-facts.md)
(format 2), the installation policy, an optional override of a matched profile, and an optional choices file.
It identifies the observed machine, its profile classification, and the target disk, plus the ordered
declarative operations, every value with its provenance and source, the secret requirements by name, and the
hardware-derived selections, including the outcome of every hardware rule. It is bound to its inputs by a digest. Unknown fields are rejected by
`install/plan/validate-plan.mjs`.

A plan does not require a matched profile: an unqualified machine produces a plan bound to its observed
identity, with a warning (see [Warnings](#validation)).

The plan cannot express approval. Approval is an ephemeral, in-process confirmation bound to the digest (see
[`installation-confirmation.md`](installation-confirmation.md)); only a non-authorizing evidence record
is persisted, so a plan with an `approved` or `approval` field is invalid like any other unknown field.

Conventions: JSON fields use `snake_case`; fields that do not apply are omitted; sizes are integer bytes
except `swapfile_size` and the swap operation's `size_mib`, which are integer MiB; the document contains integers
only, never fractional numbers.

## Format versions

Each document keeps its own constant; no constant is shared between unrelated documents.

| Document | Constant | Value |
| --- | --- | --- |
| Installation plan (this contract) | `PLAN_FORMAT_VERSION` | `5` |
| Installation policy (`install/plan/policy.json`) | `PLAN_POLICY_FORMAT_VERSION` | `3` |
| Choices file (`--choices`) | `CHOICES_FORMAT_VERSION` | `3` |
| Target facts | `FACTS_FORMAT_VERSION` | `2`, see [`target-facts.md`](target-facts.md) |
| Plan override (`targets/<id>/overrides/plan.json`) | none: a flat object, unchanged | |

The confirmation records have their own constant, see [`installation-confirmation.md`](installation-confirmation.md).
Version `3` followed [ADR 0007](../docs/adr/0007-zram-and-hibernation-policy.md): conditional hibernation fields,
RAM-derived sizing, new operations, and a changed operation set must not reinterpret older documents. Version `4`
replaces the informational `detected_capabilities` with the rule outcomes of `hardware/rules/` and adds the
separate list of rule-selected packages, so a format `3` plan cannot be read as a format `4` plan. The policy,
choices-file, and facts constants were unchanged by that version: the hardware rules read facts and add no policy value.
Version `5` follows [ADR 0022](../docs/adr/0022-installer-coexistence-and-uefi-boot-entry.md): it adds
`target_mode`, replacement identities, partition-scoped operations and explicit UEFI registration. Policy and
choices formats remain `3`; `target_mode` defaults to `whole_disk`, and replacement always requires an explicit
full root PARTUUID. The format-2 facts extension supplies candidates; absent replacement evidence never implies one.

A plan of format `1`, `2`, `3`, or `4` is rejected with `plan_format_unsupported` and the instruction to regenerate it from
new target facts. Plans, policy snapshots, choices files, and evidence of earlier versions are never migrated or
reinterpreted; the generator reads facts of format `2` only, and the facts format is unchanged.

## Labels

Every value in `choices` carries three labels.

| Label | Values | Meaning |
| --- | --- | --- |
| `provenance` | `personal_preference`, `hardware_detection`, `arch_guidance`, `technical_necessity` | Why the value exists (FR12). |
| `source` | `policy`, `detected`, `override`, `choice` | The layer that set the final value. |
| `editable` | `true`, `false` | Whether a choices file may change it. |

Precedence: `policy` < `detected` < `override` (`targets/<id>/overrides/plan.json`, only for a matched
profile) < `choice` (`--choices`). Secrets are outside this chain: the plan only names them.

A value the user advances past without changing keeps the `provenance`, `source`, and `editable` of its
proposal. Only a changed value is recorded with source `choice` (and, because the user made it, provenance
`personal_preference`). A choices file therefore lists only values that differ from their proposal.

## Top-level fields

| Field | Description |
| --- | --- |
| `format_version` | Always `5`. |
| `target_mode` | `whole_disk` or `replace_installation`; must equal `choices.target_mode.value`. |
| `target` | `machine`, `profile`, `disk`, and `installation` only for replacement. |
| `choices` | Every resolved policy value, keyed by name. |
| `operations` | The ordered declarative operations. |
| `secret_requirements` | Ordered secret names, never values. |
| `hardware_selections` | `selections`, `rule_outcomes`, and `rule_packages`. |
| `warnings` | Entries with `code`, `message`, and `next_step`. May be empty. |
| `facts_binding` | Where the facts came from. |
| `policy_binding` | Which policy, matched-profile definition, and override were applied. |
| `digest` | `algorithm` (`sha256`) and `value` (hex). |

### `target`

`machine` is the observed safety identity projection, copied from the detected layer of the facts. It exists so
that approval is bound to the actual machine and never to a profile id:

| Field | Description |
| --- | --- |
| `architecture` | Always present (`x86_64` in a valid plan). |
| `memory_total_bytes` | Always present: the detected total memory in bytes, a positive safe integer. Planning requires it (see [Memory prerequisite](#memory-prerequisite)). |
| `virtualization` | The detected virtualization (`none` for physical hardware). Omitted when it was not observed. |
| `dmi` | The allowlisted `sys_vendor` and `product_name`, each omitted when it was not observed. Omitted when neither was observed. |

Whether a field is available is part of the projection: a field that was present and later is absent, or the
reverse, is a change.

`profile` is the facts' classification, copied without change: `status` is `matched` or `unqualified`, and
`profile_id` is present only for `matched`. It records recognition, not individual-machine qualification, and
it is not a substitute for `machine`.

`disk` copies the identity of the selected disk and its current layout:

| Field | Description |
| --- | --- |
| `path`, `by_id`, `wwn`, `serial`, `model`, `size_bytes` | Disk identity as in [`target-facts.md`](target-facts.md). Unavailable values are omitted; at least `by_id` or `path` is present. |
| `eligible` | Must be `true`. |
| `current_layout` | `partition_table` and `partitions` copied from the facts, including available geometry and partition type fields. In whole-disk mode all content is destroyed; in replacement only the selected ESP and root are formatted. |

For `replace_installation`, `target.installation` is the exact discovered candidate: `disk_path`,
`storage_option` (the existing installation's option), `esp`, and `root`. Each partition records `path`,
`size_bytes`, `fstype`, `uuid`, `partuuid`, `type_guid`, `partition_number`, `start_sector`, and any observed
`label`, `partition_label`, and `mountpoints`, exactly as in `current_layout`. Start sectors use 512-byte
units, as in target facts; optional `partition_table.sector_size_bytes` records logical sector size.
Both partitions must match unique unmounted layout identities, with the ADR's Linux root/ESP types and
filesystem binding. `target.installation.disk_path` equals `target.disk.path`.
With bound facts, the validator also requires exact membership in the disk's `replace_candidates` and an
unchanged `current_layout`; labels alone cannot authorize replacement. The selected new `storage_option`
may differ from the candidate's existing option, since both target filesystems are reformatted.

### `choices`

Each entry is `{ "value", "provenance", "source", "editable" }`. The keys are the policy keys of
`install/plan/policy.json` plus `target_disk` and, only for replacement, `replace_root_partuuid`:

| Key | Editable | Value |
| --- | --- | --- |
| `target_disk` | yes | The `by_id` of the selected disk, or its `path` when it has no `by_id`. |
| `target_mode` | yes | `whole_disk` (default) or `replace_installation`. |
| `replace_root_partuuid` | yes | Full root PARTUUID of the chosen candidate, required only in replacement. Never automatically selected; absent in whole-disk mode. |
| `storage_option` | yes | `ext4-systemd-boot`, `btrfs-rescue`, or `btrfs-limine` (the default). The entry also carries `tier`, `filesystem`, `bootloader`, and `resume_offset_method` from the tier table. |
| `hibernation` | yes | Boolean, initially `true`. Enables the hibernation swapfile and resume configuration; see [Hibernation and swapfile](#hibernation-and-swapfile). |
| `swapfile_size` | yes | Present only when `hibernation` is `true`. Integer MiB from 512 to the RAM-derived maximum; the maximum is also the default. |
| `lang` | yes | The system language: `en_US.UTF-8` (English, US) or `es_ES.UTF-8` (Spanish, Spain). |
| `regional_format` | yes | The regional formats: `follow_language` (the default, which tracks `lang`), `en_US.UTF-8`, or `es_ES.UTF-8`. |
| `locales` | no | Derived: the unique list of `lang` followed by the formats locale when it differs. Each is listed in `usr/share/i18n/SUPPORTED`. |
| `locale_categories` | no | Derived: `LANG` (equal to `lang`) and `LC_TIME`, `LC_NUMERIC`, `LC_MONETARY`, and `LC_MEASUREMENT` (each equal to the formats locale). `LC_ALL` is never set and other categories inherit `LANG`. |
| `console_keymap` | yes | The installed-system console keymap, independent of language and formats: a keymap present under `usr/share/kbd/keymaps`. |
| `timezone` | yes | A zone present under `usr/share/zoneinfo`. |
| `hostname` | yes | RFC 1123 hostname of at most 64 characters. |
| `user_name` | yes | A `useradd` name: `[a-z_][a-z0-9_-]*` with an optional trailing `$`, at most 32 characters, not `root`. |
| `root_account` | yes | `locked` or `password`. |
| `firmware_mode`, `partition_table`, `esp`, `root_minimum_bytes`, `kernel`, `initramfs`, `kernel_cmdline`, `bootloader_options`, `zram`, `memory_reclaim`, `packages`, `mirrorlist`, `hardware_clock`, `time_sync`, `network`, `user_groups`, `user_shell`, `sudoers`, `sysrq`, `pacman_options`, `fstrim` | no | Fixed by policy. |

The tier table of the policy reflects [ADR 0009](../docs/adr/0009-storage-option-promotion-and-esp-size.md):
`btrfs-limine` is `default` and is the default `storage_option`, while `ext4-systemd-boot` and `btrfs-rescue`
are `supported`. The ESP is 2 GiB for every option. `efibootmgr` is a base target package for all options,
not a Limine-only additional package, because registration and `mirroros-boot-first` apply to both bootloaders. The additional packages of `btrfs-limine` do not include
`base-devel` or `git`: its Limine snapshot tools are prebuilt in the artifact
([ADR 0008](../docs/adr/0008-installation-engine-execution-boundary.md)). Selecting an option whose tier is
`experimental` adds the warning `storage_option_experimental`; no option has that tier under the current policy.

### Hibernation and swapfile

Hibernation remains an essential capability that MirrorOS must support and qualify, enabled by default and
disableable per installation. The swapfile is hibernation-sized storage that also serves as lower-priority
fallback swap; it is not exclusively used for hibernation, and fallback use consumes free hibernation capacity.

When `hibernation` is `true`:

- `swapfile_size` is an integer MiB from `512` to `maximum`, where
  `maximum = ceil(memory_total_bytes / 1073741824) * 1024`. The default equals `maximum`, with provenance
  `hardware_detection` and source `detected`; an explicit size is a choice. The minimum is an input limit and no
  claim of sufficient hibernation capacity. Computation uses safe integers only.
- A size whose bytes (`swapfile_size * 1048576`) are less than `memory_total_bytes` is valid and adds the warning
  `swapfile_below_ram`. Equality does not warn. The default is above or equal to raw RAM and never warns.
- `create_swapfile` is present, the Btrfs options keep `@swap`, and the resume parameters are present.
- The layout must fit: in whole-disk mode the ESP, `root_minimum_bytes`, and `swapfile_size` must not exceed the disk
  (`plan_size_does_not_fit`). In replacement, the existing ESP must meet the policy ESP minimum and the existing
  root must fit `root_minimum_bytes` plus the swapfile (`replacement_target_invalid`); other partitions' space is never counted. The size is never silently reduced and hibernation is never silently disabled.

When `hibernation` is `false`, the plan has no `swapfile_size` choice, no `create_swapfile`, no `resume=` or
`resume_offset=` kernel parameters, no `resume_offset` entry in any `resolved_at_apply`, and, for both Btrfs
options, no `@swap` subvolume and no `@swap` mount. Root UUID resolution, the other subvolumes, Snapper policy,
bootloader selection, tiers, and the relative order of the other operations are unchanged. Zram is still
planned. A disabled plan never implies swapfile creation.

No custom hibernation image-size setting exists. The warning and the sizing screen state that success depends on
used memory and free swapfile space and never claim that the default guarantees a successful resume.

### Memory prerequisite

Planning requires `memory_total_bytes` in the facts' effective view, as a positive safe integer, even when
`hibernation` is `false`, because zram sizing also depends on memory. A missing, zero, negative, fractional, or
unsafe value fails generation with `memory_unavailable`, whose `next_step` asks for repeated discovery. No memory
value or swap size is assumed. The facts format is unchanged.

### Zram, zswap, and memory reclaim

These values are fixed by policy, not editable, and apply to every storage option. Nothing here changes the live
ISO.

| Policy key | Value |
| --- | --- |
| `zram` | The official Arch package `zram-generator`; destination `/usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf`; one `[zram0]` section with `zram-size = ram`, `compression-algorithm = zstd`, and `swap-priority = 100`. No resident-memory limit, recompression, writeback device, or algorithm fallback. |
| `memory_reclaim` | Destination `/usr/lib/sysctl.d/60-mirroros-memory.conf` with `vm.swappiness = 180`, `vm.page-cluster = 0`, `vm.watermark_scale_factor = 125`, and `vm.watermark_boost_factor = 0`. |
| `kernel_cmdline` | Always includes `zswap.enabled=0`. Includes `resume=UUID=<root>` and `resume_offset=<resume_offset>` only when `hibernation` is `true`. |
| `packages` | The installed package list explicitly includes `zram-generator`, with official-repository provenance. It is never added to the live package list. |

Zram logical capacity is not an immediate reservation of that much memory and does not guarantee doubled usable
memory. The settings are global rather than per device, are an initial baseline and not a claim of optimality, and
remain modifiable by the administrator through native overrides in `/etc`. No adaptive tuning, daemon, or
project-owned service exists. Installed activation, effective values, and pressure behavior are not asserted by a
plan; they are verified by later qualification.

### Configuration assets

The two drop-ins are owned under `install/plan/assets/`, mirroring their destinations:
`usr/lib/systemd/zram-generator.conf.d/60-mirroros.conf` and `usr/lib/sysctl.d/60-mirroros-memory.conf`. The
generator reads only these fixed allowlisted source paths, computes the SHA-256 of the raw bytes of each, and
refuses a missing or damaged asset (exit `6`). The settings declared in the policy and in the operation
parameters must agree with the source content; a mismatch is a contract failure. Source assets are embedded with
the installer code and are never installed into the live system's configuration locations.

### Localization

Language, regional formats, and keyboard are independent choices. With `regional_format` `follow_language` the
formats locale equals `lang`, so a later change of `lang` moves the formats with it; an explicit region stays
when `lang` changes. `locales` and `locale_categories` are always derived by the same resolver, with source
`policy`, provenance `technical_necessity`, and `editable` `false`; a document in which they contradict
`lang` and `regional_format` is invalid (`locale_derivation_mismatch`). Applications may use their own
preferences or ignore these settings.

### Disk selection

Discovery never selects a disk. With exactly one eligible disk, `target_disk` is preselected with
provenance `hardware_detection` and source `detected`. With several, the plan refuses to guess unless the
choices file names one (provenance `personal_preference`, source `choice`). A disk without `by_id` is
accepted by `path` with the warning `disk_without_by_id`; a disk with neither is rejected.

`whole_disk` remains the default even when replacement evidence exists. Replacement requires an explicit
`target_mode: "replace_installation"` and `replace_root_partuuid` naming the disk's sole unambiguous candidate.
Missing, ambiguous, mounted, incomplete, changed or undersized targets are rejected. The ESP must be at least
the policy ESP size (2 GiB), and root must meet the policy root minimum (15 GiB) plus any requested swapfile.
No partition is resized, moved or created in replacement. A root choice in whole-disk mode is a conflict.
The render and console summary identify the mode, both format targets and their full PARTUUIDs; replacement
review marks every other partition `PRESERVE` instead of displaying a whole-disk erasure warning.

### `operations`

Each operation is an object with:

| Field | Description |
| --- | --- |
| `id` | Stable identifier; equal to its `kind`, since each kind occurs at most once. |
| `kind` | A member of the vocabulary below. |
| `destructive` | `true` when the operation erases or rewrites existing disk content. |
| `parameters` | Values already resolved from policy and choices. |
| `description` | Human-readable sentence. |
| `resolved_at_apply` | Optional list of `{ "name", "method" }` for values that only exist during apply. They carry no value in the plan. |

The plan holds no command lines, so the digest does not depend on how the engine implements a step. An
engine must reject any `kind` it does not know. The engine's behavior per kind, including the constants it owns,
is defined in [`installation-engine.md`](installation-engine.md).

#### Kind vocabulary

| Kind | Destructive | Description |
| --- | --- | --- |
| `record_disk_partuuids` | no | Whole-disk only: capture and recheck the target disk's pre-wipe PARTUUID set. Parameters: `disk` (selected identifier), `partuuids` (observed layout PARTUUIDs, in layout order; absent PARTUUID fields are omitted from this list). The engine records these before wiping, never derives cleanup from the new partition table. |
| `remove_stale_uefi_entries` | no | Whole-disk only: remove only entries referencing the captured PARTUUID set, preserving unrelated entries. Parameters: `partuuids`, exactly the capture list; this mutates firmware, not disk content. |
| `wipe_partition_signatures` | yes | Replacement only: wipe signatures on the selected partition nodes, never the disk. Parameters: `esp` and `root`, exact copies of `target.installation` partition identities. |
| `format_partitions` | yes | Replacement only: format the selected partition nodes without rewriting the partition table. Parameters: `esp`, `root`, `esp_filesystem` (`vfat`) and `root_filesystem` (selected option). Resolves new `partition_uuids` by `blkid`; existing PARTUUIDs remain unchanged. |
| `register_uefi_boot_entry` | no | Both modes, last: find/create the selected loader's entry on the target ESP and move it first, preserving other entries' relative order. Parameters: `bootloader`, `label`, `loader_path`, `first` (`true`). Limine uses `Limine MirrorOS` and `\EFI\BOOT\BOOTX64.EFI`; systemd-boot uses `MirrorOS` and `\EFI\systemd\systemd-bootx64.efi`. The ESP is the selected replacement ESP or the newly created whole-disk ESP, never inferred from an unrelated entry. Duplicate matches fail closed, deleting none; the appropriate fallback remains deployed. |
| `wipe_disk_signatures` | yes | Whole-disk only: remove existing filesystem and partition-table signatures from the target disk. |
| `create_partition_table` | yes | Write an empty GPT. |
| `create_partitions` | yes | Create the ESP and the root partition on the remaining space. |
| `format_filesystems` | yes | Format the ESP as FAT32 and the root partition with the option's filesystem. Resolves `partition_uuids` (`blkid`). |
| `create_btrfs_subvolumes` | no | Create the flat subvolumes of the option on the new filesystem, without `@swap` when `hibernation` is `false`. |
| `mount_target` | no | Mount the root (with the subvolumes for Btrfs, and `@swap` only when `hibernation` is `true`) and the ESP under the target root. |
| `install_packages` | no | Install `packages` (including `zram-generator`), the network package, and the option's additional packages, then the `rule_packages` selected by the hardware rules. Parameters: `packages` (the personal, network, and option packages, in that order) and `rule_packages` (the package names of `hardware_selections.rule_packages`, in plan order, possibly empty). The engine installs both lists in one transaction and reads no policy or rule. |
| `generate_fstab` | no | Generate `/etc/fstab` by UUID. For Btrfs only subvolume paths are kept, never `subvolid=`. |
| `configure_zram` | no | Deliver the zram-generator drop-in. Parameters: `destination`, `source_sha256`, `zram_size` (`ram`), `compression_algorithm` (`zstd`), and `swap_priority` (`100`). |
| `configure_memory_reclaim` | no | Deliver the sysctl drop-in. Parameters: `destination`, `source_sha256`, and the four `vm.*` values. |
| `create_swapfile` | no | Only when `hibernation` is `true`: create `/swapfile` of `swapfile_size` MiB with swap priority `0` (`priority`) and list it in fstab. Resolves `resume_offset`. |
| `configure_locale_time_console` | no | Locales, `lang`, the regional category values, keymap, time zone, UTC hardware clock, and time sync. |
| `configure_hostname_network` | no | Hostname and NetworkManager without predefined connections. |
| `create_user` | no | Create `user_name` in `user_groups` with `user_shell`. Consumes `account_password`. |
| `configure_root_account` | no | Lock the root account, or give it the same password as the user. Consumes `account_password` only for `password`. |
| `configure_sudo_sysrq_pacman` | no | Sudoers drop-in, sysrq, and pacman options. |
| `install_bootloader` | no | Install and configure the option's bootloader and kernel command line, including `zswap.enabled=0`. Resolves `root_uuid`, and `resume_offset` only when `hibernation` is `true`. |
| `install_limine_snapshot_tools` | no | Install the pinned Limine snapshot tools prebuilt in the artifact, after verifying them against the embedded manifest. `btrfs-limine` only. |
| `configure_snapper` | no | Snapper root configuration for `@` only, with `snap-pac`. Btrfs only. |
| `enable_services` | no | Enable NetworkManager, the time sync service, `fstrim.timer`, and the option's services. |
| `create_baseline_snapshot` | no | Take the post-install baseline snapshot. Btrfs only. |
| `sync_limine_snapshot_entries` | no | Write the Limine snapshot entries. `btrfs-limine` only. |

#### Order per storage option

The sequence is fixed; the validator rejects a different set or a different order. Operation 10 exists only when
`hibernation` is `true`; omitting it does not change the relative order of the others.

`ext4-systemd-boot`:

1. `wipe_disk_signatures`
2. `create_partition_table`
3. `create_partitions`
4. `format_filesystems`
5. `mount_target`
6. `install_packages`
7. `configure_zram`
8. `configure_memory_reclaim`
9. `generate_fstab`
10. `create_swapfile` (only with hibernation)
11. `configure_locale_time_console`
12. `configure_hostname_network`
13. `create_user`
14. `configure_root_account`
15. `configure_sudo_sysrq_pacman`
16. `install_bootloader`
17. `enable_services`

`btrfs-rescue`: the same sequence with `create_btrfs_subvolumes` inserted after `format_filesystems`,
`configure_snapper` after `install_bootloader`, and `create_baseline_snapshot` after `enable_services`.

`btrfs-limine`: the `btrfs-rescue` sequence with `install_limine_snapshot_tools` inserted after
`install_bootloader` (before `configure_snapper`) and `sync_limine_snapshot_entries` appended after
`create_baseline_snapshot`.

For format `5` whole-disk mode, prepend `record_disk_partuuids` to the sequences above, insert
`remove_stale_uefi_entries` immediately after `create_partitions`, and append `register_uefi_boot_entry`
after all storage-option steps (including Limine snapshot synchronization).
For replacement, replace the four initial disk operations (`wipe_disk_signatures` through `format_filesystems`)
with `wipe_partition_signatures` then `format_partitions`. Omit capture and stale-entry cleanup entirely;
retain all subsequent option-specific steps and append `register_uefi_boot_entry` last. Thus replacement
cannot express partition-table creation or a disk-node wipe. Storage and registration parameters must agree
exactly with the declared targets and selected option; unknown extra parameters on these operations are rejected.

The resume offset method comes from the tier table: `filefrag` for ext4 and
`btrfs inspect-internal map-swapfile -r` for Btrfs, and applies only when hibernation is enabled. The Btrfs
subvolume, Snapper, baseline, and Limine steps derive from ADR 0003, amended for `@swap` and resume by
[ADR 0007](../docs/adr/0007-zram-and-hibernation-policy.md); the prototypes under `prototypes/storage/` are reference only and never
sourced.

### `secret_requirements`

Ordered list; each entry has exactly `name`, `purpose`, `required_by`, `channel`, and `provenance`.

| Name | Present | `required_by` | `provenance` |
| --- | --- | --- | --- |
| `account_password` | always | `["create_user"]`, plus `"configure_root_account"` only when `root_account` is `password` | `technical_necessity` |

There is one account-password requirement. With a locked root only the user operation consumes it; when root
password access is enabled root receives the same password as the user, and no separate root password is
requested. The shared password is not an independent recovery credential, and the interface says so.

`channel` is always `protected_prompt`. Values, hashes, and length hints never appear, and secret-named
keys are rejected everywhere else in the document. The plan names the requirement only; no value is
stored: the assistant collects it and hands it to the engine over a protected channel (see [`installation-confirmation.md`](installation-confirmation.md#password-hand-over)).

### `hardware_selections`

`selections` is a list of entries with `id`, `fact` (a dotted path of the facts' `effective` view),
`value`, `provenance` (`hardware_detection`), and `rule`. It holds `target_disk` (rule
`single_eligible_disk`, only when preselected) and `boot_mode` (rule `uefi_boot_mode_check`, a check
rather than a choice).

`rule_outcomes` replaces the format `3` `detected_capabilities`. It has exactly one entry per hardware rule, in
the fixed order `graphics`, `cpu-microcode`, `battery`, `virtualization`. Each entry has:

| Field | Description |
| --- | --- |
| `rule` | The rule id: `graphics`, `cpu-microcode`, `battery`, or `virtualization`. |
| `fact` | The dotted path of the facts' `effective` view the rule read (`hardware.graphics`, `hardware.cpu.vendor`, `hardware.battery_present`, `hardware.virtualization`). |
| `value` | The detected value as observed: the list of graphics vendors, the CPU vendor string, a boolean, or the virtualization string. `unknown` when the fact was not observed. |
| `outcome` | The rule's result, from the table below. |
| `explanation` | One sentence stating why the outcome follows from the value and what it changes in the plan. |

Outcomes per rule:

| Rule | Outcome | Condition | Plan effect |
| --- | --- | --- | --- |
| `graphics` | `kernel_driver_only` | Every detected device has vendor `amd`, `intel`, or `qemu_virtual`. | None. The kernel driver and `linux-firmware` already installed are enough; nothing additional is selected. No warning. |
| `graphics` | `nvidia_nouveau_fallback` | At least one device has vendor `nvidia` and none is unrecognized. | None. The in-kernel `nouveau` driver is used; it is neither blacklisted nor configured. Warning `graphics_nvidia_nouveau`. |
| `graphics` | `vendor_not_recognized` | Any device has vendor `unknown`, or no graphics device was observed. | None. Nothing is guessed. Warning `graphics_vendor_unknown`. |
| `cpu-microcode` | `amd_microcode` | The CPU vendor is `AuthenticAMD`. | Rule package `amd-ucode`. |
| `cpu-microcode` | `intel_microcode` | The CPU vendor is `GenuineIntel`. | Rule package `intel-ucode`. |
| `cpu-microcode` | `vendor_not_recognized` | Any other vendor, or none observed. | None. Nothing is guessed. Warning `cpu_vendor_unknown`. |
| `battery` | `battery_present`, `battery_absent`, or `not_observed` | The `battery_present` fact. | None. Informational only. No warning. |
| `virtualization` | `virtual_machine`, `physical_machine`, or `not_observed` | A virtualization value other than `none`, the value `none`, or no value. | None. Informational only. No warning. |

When the graphics rule sees several devices, the outcome is the most restrictive that applies: `vendor_not_recognized`
over `nvidia_nouveau_fallback` over `kernel_driver_only`. The `explanation` names the vendors. No rule blocks
installation, and no rule selects a driver, a Mesa or Vulkan package, a power-management tool, or a guest agent.

`rule_packages` is the list of packages the rules selected, separate from the personal `packages` of `choices`.
Each entry has `name`, `rule`, `provenance` (`hardware_detection`), `source` (`detected`), and `editable`
(`false`). A rule package cannot be edited, removed, or added by a choices file or an override, and it is shown in
review and in the rendered plan. With no matching rule it is an empty list. Every entry is justified by exactly
one rule outcome whose `Plan effect` names that package, and a rule outcome never lists a package that is absent
from `rule_packages`.

The rules are evaluated at plan generation by the generic evaluator of `hardware/rules/`, in the fixed order
above, from the facts only. Their warnings are appended to `warnings` after the policy-derived ones. A rule never
modifies `install/plan/policy.json`, a target override, or another rule's result; a target override never changes
a rule outcome. The origin of every plan entry is exposed by its labels: `source` `policy`, `detected`, `override`,
or `choice` for `choices`, and the `rule` field for rule outcomes and rule packages.

### Bindings

| Field | Description |
| --- | --- |
| `facts_binding.facts_sha256` | SHA-256 of the canonical `target-facts.json`. |
| `facts_binding.run_id`, `commit`, `dirty` | Copied from the facts `source`. The engine requires `commit` and `dirty` to equal its own embedded code identity ([`installation-engine.md`](installation-engine.md#pre-check-order)). |
| `policy_binding.policy_sha256` | SHA-256 of the canonical `install/plan/policy.json`. |
| `policy_binding.profile_definition_sha256` | SHA-256 of the canonical `targets/<id>/target.json` of the matched profile. Present exactly when `target.profile.status` is `matched`. |
| `policy_binding.override_sha256` | SHA-256 of the canonical applied `plan.json` override. Omitted when none applied; it can be present only for a matched profile. |

Every hash uses the existing canonical hashing implementation (`canonical-json.mjs` and `digest-plan.mjs`),
not a second one. The choices file is not hashed: its effect is already in `choices`.

## Choices file

`--choices <file>` is a flat JSON object kept wherever the user likes; it is not versioned under
`targets/`.

```json
{
  "format_version": 3,
  "hostname": "laptop",
  "storage_option": "btrfs-rescue"
}
```

Allowed keys: `target_disk`, `target_mode`, `replace_root_partuuid`, `storage_option`, `hibernation`, `swapfile_size`, `lang`, `regional_format`, `console_keymap`,
`timezone`, `hostname`, `user_name`, and `root_account`. Unknown keys, non-editable policy keys (including the
derived `locales` and `locale_categories`), invalid values, and secret-like keys (`password`, `*_password`)
are invalid input. A choices file of `format_version` `1` or `2` is invalid input, with regeneration guidance.
`hibernation` must be a JSON boolean. `hibernation: false` together with `swapfile_size` is contradictory and is
rejected (`choices_conflict`) rather than ignoring the size; `swapfile_size` is otherwise validated against the
RAM-derived range.

## Overrides

`targets/<id>/overrides/plan.json` is a flat JSON object. Only `hostname` is allowed in this format
version. Its value follows the same rules as the choices file and resolves with source `override`. It is read
only when the facts classify the machine as `matched`; an unqualified machine applies none.

## Choice helpers

The assistant never duplicates policy resolution. The plan component publishes two read-only helpers on its
Node CLI, reached through `install/plan/plan` as a first argument and used by process. Both reuse the resolver
and the value validators of final generation, write no file, create no intermediate plan, and take the same
facts as generation. Exit statuses are `0`, `2`, `5`, and `6` as below.

```text
install/plan/plan preview-choices --facts <file> [--choices <file>]
install/plan/plan validate-choice --facts <file> [--choices <file>] --key <key> --value <value>
```

`preview-choices` prints one JSON object on stdout with `format_version` `3` and:

| Field | Description |
| --- | --- |
| `choices` | Every editable key with its resolved `value`, `provenance`, `source`, and `editable`, as the plan would hold it for the given choices file. Defaults come from policy, detection, and a matched-profile override. |
| `options` | `target_mode` offers `whole_disk` and, only with a sole discovered candidate on the selected disk, `replace_installation`; `replace_root_partuuid` lists candidate objects with `value` (full root PARTUUID), `disk_path`, `root`, and `esp`. No replacement is offered with a pending disk. Other allowed values per key: the storage options with `tier`, `filesystem`, and `bootloader`; the eligible disks with `value`, `path`, `model`, and `size_bytes`; the languages and regional formats; `hibernation` (boolean); the `swapfile_size` range with `minimum`, `maximum`, `default`, `unit`, and `memory_total_bytes`, derived from the facts' RAM, and whether it is editable (only while `hibernation` is `true`); and the `root_account` values. Free-text keys (`hostname`, `user_name`, `timezone`, `console_keymap`) carry their validation rule rather than a list. |
| `derived` | The `locales` and `locale_categories` for the previewed `lang` and `regional_format`. |
| `warnings` | The warnings the plan would carry that do not depend on a combination failing. |

`validate-choice` checks one value against its own rules and the facts, not the complete combination. The `--value`
argument is a string: integers (`swapfile_size`) and booleans (`hibernation`, exactly `true` or `false`) are parsed by the same shared parser as the choices file, and a secret-like key is rejected before its value
is read. On success it prints `{ "valid": true, "key", "value", "derived" }`, with `derived` present for `lang`
and `regional_format`. Otherwise it prints `{ "valid": false, "reasons" }` with the generation reasons of the
plan contract (for example `choices_invalid_value`, `choices_not_editable`, or `choices_unknown_key`) and exits
`2`. Mode and candidate identity checks reuse selection; a replacement preview may leave the root choice pending,
but generation requires it explicitly. The complete combination, including layout fit, is validated when the plan is generated.

## Canonicalization and digest

The digest is SHA-256 in hex over the canonical form of the document without its `digest` field. The
canonical form sorts object keys by code point, uses no whitespace and UTF-8, and allows integers only;
`undefined`, fractional numbers, and non-JSON types are internal contract failures (exit `6`).

The signed content has no timestamp and no `run_id`, so identical facts, policy, override, and choices
always produce the same digest. A different digest always means different content.

## Run directory

Each `plan` run writes to `evidence/install/<run-id>/`, or to `--output`, with `0700` directories and
`0600` files:

| File | Content |
| --- | --- |
| `installation-plan.json` | The plan with its digest. |
| `installation-plan.txt` | Plain-text render of the persisted plan: no ANSI sequences, 80 columns except unavoidable long values, eight sections, `DESTRUCTIVE` markers. |
| `plan-run.json` | `run_id`, RFC 3339 `timestamp`, `inputs` (paths), `digest`, `exit_status`, `reasons`, and `warnings`. |

Each plan file is written to a temporary file in the same directory, flushed, re-read, revalidated
(including the digest), and renamed. An invalid plan is never written: only `plan-run.json` records the
reasons and exit `2`. An `--output` directory that already contains a plan is invalid input. Regeneration
never overwrites; an edited plan is a new run with its own digest.

## Validation

The validator is a pure function of the plan. It works on four levels: malformed, incomplete, unknown
fields, and contradictions. Given the facts document as an optional second argument it also checks the
disk identity and eligibility against the bound facts. Each reason and warning has `code`, `message`, and
`next_step`.

| Code | Condition |
| --- | --- |
| `plan_not_json`, `plan_invalid_type`, `plan_non_integer_number` | Malformed document. |
| `plan_format_unsupported` | `format_version` is not `5`. The `next_step` states that installation plans of earlier versions are not migrated and must be regenerated from new target facts with `operations/install plan`. |
| `plan_field_missing`, `plan_label_missing` | A required field, or a `provenance`, `source`, or `editable` label, is missing. |
| `plan_unknown_field` | A field outside this contract, including `approved` and `approval`. |
| `plan_secret_value_present` | A secret-named key outside `secret_requirements`, or an extra field in a secret entry. |
| `operations_storage_mismatch` | The operations do not match `storage_option` and `target_mode`. |
| `target_mode_mismatch` | Unknown/inconsistent mode, replacement fields in whole-disk mode, storage/UEFI parameters differing from the declared targets, or bootloader/filesystem metadata inconsistent with the selected option. |
| `replacement_target_invalid` | Missing, non-unique, incomplete, mounted, changed or undersized replacement identities, incorrect disk/root choice, or a replacement absent from the bound facts' candidates. |
| `operation_kind_unknown`, `operation_order_invalid` | Unknown kind, or disallowed order. |
| `operation_id_invalid`, `operation_destructive_mismatch` | An operation id differs from its kind, or its `destructive` flag differs from the kind table. |
| `destructive_without_target_disk` | A destructive operation exists without `target_disk`. |
| `root_account_secret_mismatch` | `root_account` and the root consumer of `account_password` are inconsistent. |
| `secret_consumer_mismatch` | The single `account_password` requirement is missing or duplicated, has no consumer, or an operation needs an undeclared secret. |
| `lang_not_in_locales` | `lang` is not one of `locales`. |
| `locale_derivation_mismatch` | `locales` or `locale_categories` contradict `lang` and `regional_format`, or `LC_ALL` is present. |
| `machine_identity_mismatch` | Given the facts document, `target.machine` (including `memory_total_bytes`) differs from the observed identity, including a difference in field availability. |
| `profile_binding_mismatch` | `target.profile` is inconsistent with its bindings: `matched` without `profile_definition_sha256` or `profile_id`, `unqualified` with a profile id, a profile hash, or an override hash, or, given the facts, a classification that differs from the facts. |
| `disk_identity_mismatch`, `disk_not_eligible` | The disk does not match the `target_disk` choice or the bound facts, or is not eligible. |
| `facts_binding_mismatch` | `facts_binding` contradicts `target`, or does not match the supplied facts document. |
| `hibernation_plan_mismatch` | The hibernation choice and the plan contradict each other: a `swapfile_size`, `create_swapfile`, `@swap` subvolume or mount, `resume` kernel parameter, or `resume_offset` resolution with hibernation disabled, or any of them missing or inconsistent with hibernation enabled, or a swapfile size outside the RAM-derived range. |
| `hardware_rules_mismatch` | `rule_outcomes` do not list the four rules in order, an outcome is not valid for its `value`, `rule_packages` is not exactly the set the outcomes name, a rule package lacks its labels or is `editable`, the `install_packages` `rule_packages` parameter differs from `hardware_selections.rule_packages`, or a rule warning is missing from or added to `warnings` against the outcomes. The validator re-derives these from the plan's own `value` fields with the shared rule module and reads no facts. |
| `configuration_asset_mismatch` | A configuration operation's destination, `source_sha256`, or declared settings differ from the policy or the allowlisted source asset, or the zram package or `zswap.enabled=0` is missing. |
| `plan_size_does_not_fit` | ESP, `root_minimum_bytes`, and `swapfile_size` (when present) exceed the disk size. |
| `digest_mismatch` | The digest does not match the content. |

Generation reasons, reported with the same shape and exit `2` unless noted:

| Code | Condition |
| --- | --- |
| `memory_unavailable` | The facts' effective view has no positive safe-integer `memory_total_bytes`. The `next_step` asks the user to repeat discovery. |
| `facts_invalid`, `facts_format_unknown` | The facts fail `validate-facts.mjs`, have `validation.status` `invalid`, or a `format_version` other than `2` (facts of format `1` are not accepted). |
| `choices_invalid_format`, `choices_unknown_key`, `choices_not_editable`, `choices_secret_key`, `choices_invalid_value` | The choices file is invalid, including one of `format_version` `1` or `2`, a non-boolean `hibernation`, or an out-of-range or non-integer `swapfile_size`. |
| `choices_conflict` | The choices contradict each other: `hibernation: false` with `swapfile_size`, or a replacement root choice in whole-disk mode. |
| `replacement_target_invalid` | Replacement selection or partition reuse constraints fail; repeat discovery and select a suitable candidate. |
| `override_invalid_format`, `override_unknown_key`, `override_invalid_value` | The target override is invalid. |
| `disk_selection_required` | Several disks are eligible; the reason lists the candidates. |
| `disk_unknown`, `disk_ineligible` | The named disk is unknown or ineligible; the reason lists the candidates. |
| `disk_unidentifiable` | The selected disk has neither `by_id` nor `path`. |
| `lang_not_in_locales`, `plan_size_does_not_fit` | The choices contradict each other or the disk. The validator codes are reused. |
| `output_exists` | `--output` already contains a plan. |

Warnings: `disk_without_by_id`, `storage_option_experimental`, `swapfile_below_ram`, `machine_unqualified`, and the
hardware-rule warnings `graphics_nvidia_nouveau`, `graphics_vendor_unknown`, and `cpu_vendor_unknown`.
`graphics_nvidia_nouveau` states in its `message` that an NVIDIA graphics device was detected, that MirrorOS does
not install its driver, and that the in-kernel `nouveau` driver will be used; its `next_step` states that the user
may install the NVIDIA driver after installation, without a MirrorOS guarantee, and that MirrorOS does not
blacklist `nouveau`. `graphics_vendor_unknown` states that MirrorOS does not recognize the graphics hardware (or
observed none) and installs nothing for it; its `next_step` states that the kernel's generic display support is
used and that drivers may be installed after installation. `cpu_vendor_unknown` states that the CPU vendor is not
`AuthenticAMD` or `GenuineIntel`, or was not detected, and that no microcode package is installed; its `next_step`
states that the user may install the microcode package of the vendor after installation. None of the three blocks
installation.
`swapfile_below_ram` is present exactly when hibernation is enabled and the size is below raw RAM; its `message`
states that hibernation may be unavailable under large memory workloads and depends on used memory and free
swapfile space, and its `next_step` states that the default size is not a guarantee either. `machine_unqualified` is present
exactly when `target.profile.status` is `unqualified`; its `message` states that the machine matches no known
profile and that installation is experimental, and its `next_step` states that no compatibility or support is
promised.

## Exit statuses

| Status | Meaning |
| --- | --- |
| `0` | A valid plan was written. |
| `2` | Invalid input or unmet precondition. No plan is written; `plan-run.json` records the reasons. |
| `5` | An external tool failed unexpectedly. |
| `6` | Damaged checkout or embedded code, a value that cannot be canonicalized, or a generated plan that failed its own validator. |
