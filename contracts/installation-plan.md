# Installation plan (`installation-plan.json`)

`format_version: 1`. Produced by `operations/install plan` from a valid `target-facts.json`, the
installation policy, an optional target override, and an optional choices file. It identifies the target
disk, the ordered declarative operations, every value with its provenance and source, the secret
requirements by name, and the hardware-derived selections. It is bound to its inputs by a digest.
Unknown fields are rejected by `install/plan/validate-plan.mjs`.

The plan cannot express approval. Approval is a separate, digest-bound artifact of a later stage, so a
plan with an `approved` or `approval` field is invalid like any other unknown field.

Conventions: JSON fields use `snake_case`; fields that do not apply are omitted; sizes are integer bytes
except `swapfile_size`, which is integer MiB; the document contains integers only, never fractional
numbers.

## Labels

Every value in `choices` carries three labels.

| Label | Values | Meaning |
| --- | --- | --- |
| `provenance` | `personal_preference`, `hardware_detection`, `arch_guidance`, `technical_necessity` | Why the value exists (FR12). |
| `source` | `policy`, `detected`, `override`, `choice` | The layer that set the final value. |
| `editable` | `true`, `false` | Whether a choices file may change it. |

Precedence: `policy` < `detected` < `override` (`targets/<id>/overrides/plan.json`) < `choice`
(`--choices`). Secrets are outside this chain: the plan only names them.

## Top-level fields

| Field | Description |
| --- | --- |
| `format_version` | Always `1`. |
| `target` | `target_id` and `disk`. |
| `choices` | Every resolved policy value, keyed by name. |
| `operations` | The ordered declarative operations. |
| `secret_requirements` | Ordered secret names, never values. |
| `hardware_selections` | `selections` and `detected_capabilities`. |
| `warnings` | Entries with `code`, `message`, and `next_step`. May be empty. |
| `facts_binding` | Where the facts came from. |
| `policy_binding` | Which policy and override were applied. |
| `digest` | `algorithm` (`sha256`) and `value` (hex). |

### `target`

`target_id` is taken from the facts document. `disk` copies the identity of the selected disk and its
current layout:

| Field | Description |
| --- | --- |
| `path`, `by_id`, `wwn`, `serial`, `model`, `size_bytes` | Disk identity as in [`target-facts.md`](target-facts.md). Unavailable values are omitted; at least `by_id` or `path` is present. |
| `eligible` | Must be `true`. |
| `current_layout` | `partition_table` and `partitions` copied from the facts. It describes content that will be destroyed. |

### `choices`

Each entry is `{ "value", "provenance", "source", "editable" }`. The keys are the policy keys of
`install/plan/policy.json` plus `target_disk`:

| Key | Editable | Value |
| --- | --- | --- |
| `target_disk` | yes | The `by_id` of the selected disk, or its `path` when it has no `by_id`. |
| `storage_option` | yes | `ext4-systemd-boot`, `btrfs-rescue`, or `btrfs-limine`. The entry also carries `tier`, `filesystem`, `bootloader`, and `resume_offset_method` from the tier table. |
| `swapfile_size` | yes | Integer MiB from 512 to 65536. |
| `locales` | yes | Non-empty list of unique locales listed in `usr/share/i18n/SUPPORTED`. |
| `lang` | yes | One of `locales`. |
| `console_keymap` | yes | A keymap present under `usr/share/kbd/keymaps`. |
| `timezone` | yes | A zone present under `usr/share/zoneinfo`. |
| `hostname` | yes | RFC 1123 hostname of at most 64 characters. |
| `user_name` | yes | A `useradd` name: `[a-z_][a-z0-9_-]*` with an optional trailing `$`, at most 32 characters, not `root`. |
| `root_account` | yes | `locked` or `password`. |
| `firmware_mode`, `partition_table`, `esp`, `root_minimum_bytes`, `kernel`, `initramfs`, `kernel_cmdline`, `bootloader_options`, `zram`, `packages`, `mirrorlist`, `hardware_clock`, `time_sync`, `network`, `user_groups`, `user_shell`, `sudoers`, `sysrq`, `pacman_options`, `fstrim` | no | Fixed by policy. |

The tier table of the policy reflects [ADR 0003](../docs/adr/0003-storage-and-recovery-baseline.md):
`ext4-systemd-boot` is `default`, `btrfs-rescue` is `supported`, and `btrfs-limine` is `experimental`.
Selecting an experimental option adds the warning `storage_option_experimental`.

### Disk selection

Discovery never selects a disk. With exactly one eligible disk, `target_disk` is preselected with
provenance `hardware_detection` and source `detected`. With several, the plan refuses to guess unless the
choices file names one (provenance `personal_preference`, source `choice`). A disk without `by_id` is
accepted by `path` with the warning `disk_without_by_id`; a disk with neither is rejected.

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
engine must reject any `kind` it does not know.

#### Kind vocabulary

| Kind | Destructive | Description |
| --- | --- | --- |
| `wipe_disk_signatures` | yes | Remove existing filesystem and partition-table signatures from the target disk. |
| `create_partition_table` | yes | Write an empty GPT. |
| `create_partitions` | yes | Create the ESP and the root partition on the remaining space. |
| `format_filesystems` | yes | Format the ESP as FAT32 and the root partition with the option's filesystem. Resolves `partition_uuids` (`blkid`). |
| `create_btrfs_subvolumes` | no | Create the flat subvolumes of the option on the new filesystem. |
| `mount_target` | no | Mount the root (with the subvolumes for Btrfs) and the ESP under the target root. |
| `install_packages` | no | Install `packages`, the network package, and the option's additional packages. |
| `generate_fstab` | no | Generate `/etc/fstab` by UUID. For Btrfs only subvolume paths are kept, never `subvolid=`. |
| `create_swapfile` | no | Create `/swapfile` of `swapfile_size` MiB. Resolves `resume_offset`. |
| `configure_locale_time_console` | no | Locales, `lang`, keymap, time zone, UTC hardware clock, and time sync. |
| `configure_hostname_network` | no | Hostname and NetworkManager without predefined connections. |
| `create_user` | no | Create `user_name` in `user_groups` with `user_shell`. Consumes `user_password`. |
| `configure_root_account` | no | Lock the root account, or set its password. Consumes `root_password` for `password`. |
| `configure_sudo_sysrq_pacman` | no | Sudoers drop-in, sysrq, and pacman options. |
| `install_bootloader` | no | Install and configure the option's bootloader and kernel command line. Resolves `root_uuid` and `resume_offset`. |
| `install_limine_snapshot_tools` | no | Build and install the pinned Limine snapshot tools. `btrfs-limine` only. |
| `configure_snapper` | no | Snapper root configuration for `@` only, with `snap-pac`. Btrfs only. |
| `enable_services` | no | Enable NetworkManager, the time sync service, `fstrim.timer`, and the option's services. |
| `create_baseline_snapshot` | no | Take the post-install baseline snapshot. Btrfs only. |
| `sync_limine_snapshot_entries` | no | Write the Limine snapshot entries. `btrfs-limine` only. |

#### Order per storage option

The sequence is fixed; the validator rejects a different set or a different order.

`ext4-systemd-boot`:

1. `wipe_disk_signatures`
2. `create_partition_table`
3. `create_partitions`
4. `format_filesystems`
5. `mount_target`
6. `install_packages`
7. `generate_fstab`
8. `create_swapfile`
9. `configure_locale_time_console`
10. `configure_hostname_network`
11. `create_user`
12. `configure_root_account`
13. `configure_sudo_sysrq_pacman`
14. `install_bootloader`
15. `enable_services`

`btrfs-rescue`: the same sequence with `create_btrfs_subvolumes` inserted after `format_filesystems`,
`configure_snapper` after `install_bootloader`, and `create_baseline_snapshot` after `enable_services`.

`btrfs-limine`: the `btrfs-rescue` sequence with `install_limine_snapshot_tools` inserted after
`install_bootloader` (before `configure_snapper`) and `sync_limine_snapshot_entries` appended after
`create_baseline_snapshot`.

The resume offset method comes from the tier table: `filefrag` for ext4 and
`btrfs inspect-internal map-swapfile -r` for Btrfs. The Btrfs subvolume, Snapper, baseline, and Limine
steps derive from ADR 0003; the prototypes under `prototypes/storage/` are reference only and never
sourced.

### `secret_requirements`

Ordered list; each entry has exactly `name`, `purpose`, `required_by`, `channel`, and `provenance`.

| Name | Present | `required_by` | `provenance` |
| --- | --- | --- | --- |
| `user_password` | always | `["create_user"]` | `technical_necessity` |
| `root_password` | only when `root_account` is `password` | `["configure_root_account"]` | `personal_preference` |

`channel` is always `protected_prompt`. Values, hashes, and length hints never appear, and secret-named
keys are rejected everywhere else in the document.

### `hardware_selections`

`selections` is a list of entries with `id`, `fact` (a dotted path of the facts' `effective` view),
`value`, `provenance` (`hardware_detection`), and `rule`. It holds `target_disk` (rule
`single_eligible_disk`, only when preselected) and `boot_mode` (rule `uefi_boot_mode_check`, a check
rather than a choice).

`detected_capabilities` is informational: entries with `id`, `fact`, `value`, `rule` (`not_evaluated`),
and `next_story` (`"2.6"`) for `graphics_vendor`, `battery_present`, `virtualization`, and
`cpu_vendor`. None of them becomes a package or configuration in this stage.

### Bindings

| Field | Description |
| --- | --- |
| `facts_binding.facts_sha256` | SHA-256 of the canonical `target-facts.json`. |
| `facts_binding.run_id`, `target_id`, `commit`, `dirty` | Copied from the facts `source`. |
| `policy_binding.policy_sha256` | SHA-256 of the canonical `install/plan/policy.json`. |
| `policy_binding.override_sha256` | SHA-256 of the canonical applied `plan.json` override. Omitted when none applied. |

The choices file is not hashed: its effect is already in `choices`.

## Choices file

`--choices <file>` is a flat JSON object kept wherever the user likes; it is not versioned under
`targets/`.

```json
{
  "format_version": 1,
  "hostname": "laptop",
  "storage_option": "btrfs-rescue"
}
```

Allowed keys: `target_disk`, `storage_option`, `swapfile_size`, `locales`, `lang`, `console_keymap`,
`timezone`, `hostname`, `user_name`, and `root_account`. Unknown keys, non-editable policy keys, invalid
values, and secret-like keys (`password`, `*_password`) are invalid input.

## Overrides

`targets/<id>/overrides/plan.json` is a flat JSON object. Only `hostname` is allowed in this format
version. Its value follows the same rules as the choices file and resolves with source `override`.

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
| `plan_format_unsupported` | `format_version` is not `1`. |
| `plan_field_missing`, `plan_label_missing` | A required field, or a `provenance`, `source`, or `editable` label, is missing. |
| `plan_unknown_field` | A field outside this contract, including `approved` and `approval`. |
| `plan_secret_value_present` | A secret-named key outside `secret_requirements`, or an extra field in a secret entry. |
| `operations_storage_mismatch` | The operations do not match `storage_option`. |
| `operation_kind_unknown`, `operation_order_invalid` | Unknown kind, or disallowed order. |
| `operation_id_invalid`, `operation_destructive_mismatch` | An operation id differs from its kind, or its `destructive` flag differs from the kind table. |
| `destructive_without_target_disk` | A destructive operation exists without `target_disk`. |
| `root_account_secret_mismatch` | `root_account` and `root_password` are inconsistent. |
| `secret_consumer_mismatch` | A secret has no consumer, or an operation needs an undeclared secret. |
| `lang_not_in_locales` | `lang` is not one of `locales`. |
| `disk_identity_mismatch`, `disk_not_eligible` | The disk does not match the `target_disk` choice or the bound facts, or is not eligible. |
| `facts_binding_mismatch` | `facts_binding` contradicts `target`, or does not match the supplied facts document. |
| `plan_size_does_not_fit` | ESP, `root_minimum_bytes`, and `swapfile_size` exceed the disk size. |
| `digest_mismatch` | The digest does not match the content. |

Generation reasons, reported with the same shape and exit `2` unless noted:

| Code | Condition |
| --- | --- |
| `facts_invalid`, `facts_format_unknown` | The facts fail `validate-facts.mjs`, have `validation.status` `invalid`, or an unknown `format_version`. |
| `choices_invalid_format`, `choices_unknown_key`, `choices_not_editable`, `choices_secret_key`, `choices_invalid_value` | The choices file is invalid. |
| `override_invalid_format`, `override_unknown_key`, `override_invalid_value` | The target override is invalid. |
| `disk_selection_required` | Several disks are eligible; the reason lists the candidates. |
| `disk_unknown`, `disk_ineligible` | The named disk is unknown or ineligible; the reason lists the candidates. |
| `disk_unidentifiable` | The selected disk has neither `by_id` nor `path`. |
| `lang_not_in_locales`, `plan_size_does_not_fit` | The choices contradict each other or the disk. The validator codes are reused. |
| `output_exists` | `--output` already contains a plan. |

Warnings: `disk_without_by_id` and `storage_option_experimental`.

## Exit statuses

| Status | Meaning |
| --- | --- |
| `0` | A valid plan was written. |
| `2` | Invalid input or unmet precondition. No plan is written; `plan-run.json` records the reasons. |
| `5` | An external tool failed unexpectedly. |
| `6` | Damaged checkout or embedded code, a value that cannot be canonicalized, or a generated plan that failed its own validator. |
