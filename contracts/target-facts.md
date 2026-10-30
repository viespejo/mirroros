# Target facts (`target-facts.json`)

`format_version: 2`. Produced by `operations/install discover` from read-only inspection of the machine. It
records what was detected, classifies the machine as matching a known profile or as unqualified, keeps the
four precedence layers distinguishable, resolves them into an `effective` view, and reports whether the
facts are valid. Unknown fields are rejected by `install/discovery/validate-facts.mjs`, and a document with
any other `format_version` is rejected.

Machine facts are independent of profile identity: the observed layers are the authority for what the machine
is, and the optional profile only records which defined identity, if any, those facts verifiably match.

Conventions: JSON fields use `snake_case`; fields that do not apply are omitted; sizes are integer bytes.

Note: installation policy is resolved in the plan, not here; see [`installation-plan.md`](installation-plan.md).

## Format versions

The documents around discovery version independently, and the validator uses one constant for each.

| Document | Constant | Value |
| --- | --- | --- |
| Target facts (this contract) | `FACTS_FORMAT_VERSION` | `2` (version `1` was bound to a `target_id` and is not accepted) |
| Target definition (`targets/<id>/target.json`) | `TARGET_DEFINITION_FORMAT_VERSION` | `1`, unchanged |
| Discovery policy (`install/discovery/policy.json`) | `DISCOVERY_POLICY_FORMAT_VERSION` | `1`, unchanged |

ADR 0022 adds optional partition geometry and replacement fields to format `2`; this is an additive
extension, not a new format. New discovery runs always emit `replace_candidates` and `replace_rejections`
for each disk. Consumers must treat absent replacement fields in earlier format-2 facts as no replacement
evidence, never infer a candidate from labels alone.

The facts of an earlier run are never transformed. Consumers reject a facts document of another version and
ask for a new discovery.

## Sensitive data

The document, the retained raw collector output, and stdout never contain MAC addresses, SSIDs, Wi-Fi
credentials, `iwd` state, the DMI product, board, or chassis serial, the product UUID, or a battery
serial. Collectors drop these at collection time and normalization only copies allowlisted fields. Disk
identity (serial, WWN, model) is kept because Story 2.4 binds confirmation to it; the file lives only in
local, ignored, secret-scanned evidence with `0600` permissions.

## Top-level fields

| Field | Description |
| --- | --- |
| `format_version` | Always `2`. |
| `source` | `run_id`, embedded `commit`, `dirty`, and `requested_profile_id`, present only when `--target` asserted a profile (omitted when the id is missing or malformed). |
| `profile` | The profile classification: `status` and, only for a verified match, `profile_id`. |
| `layers` | The four precedence layers, kept separate. |
| `effective` | The resolved view, keyed by dotted path. |
| `validation` | `status`, `reasons`, and `warnings`. |

## Layers

Precedence: `portable_baseline` < `detected` < `target_override` < `runtime_private`.

| Layer | Content |
| --- | --- |
| `layers.portable_baseline.policy` | The discovery policy of `install/discovery/policy.json`: each key has `value` and `provenance` (`personal_preference`, `hardware_detection`, `arch_guidance`, or `technical_necessity`). |
| `layers.detected` | `firmware`, `network`, `storage`, and `hardware` facts. Detected facts are never overridable. |
| `layers.target_override.policy` | Accepted values from `targets/<id>/overrides/discovery.json`. Only allowlisted policy keys are accepted. |
| `layers.runtime_private.required_inputs` | Names of required private inputs. Never values. Empty in Story 2.2. |

### Overrides

A target override is read only after a verified, unambiguous profile match (see
[Profile identification](#profile-identification)). An unqualified machine, a pending identity, or an
ambiguous match applies no override and records an empty `layers.target_override.policy`.

`targets/<id>/overrides/discovery.json` is a flat JSON object of policy keys. The allowlist is the key set
of the baseline policy: `minimum_disk_bytes` (positive integer), `https_probe_url` (an `https://` URL),
and `https_probe_timeout_seconds` (integer from 1 to 300). A key that names a detected fact (`firmware`,
`network`, `storage`, `hardware`, or a dotted path below them) or a key outside the allowlist is invalid
input.

## Effective view

`effective` maps a dotted path to an entry with `source` (`baseline`, `detected`, `override`, or
`runtime`) and, except for runtime entries, a `value`. Policy keys use the prefix `policy.`, detected facts
use their section path (for example `firmware.boot_mode`; arrays are kept whole, for example
`storage.disks`), and runtime inputs use `runtime.<name>`. A baseline-sourced entry also carries its
`provenance`. A runtime entry carries `private: true` and never a value. The highest-precedence layer that
defines a path wins.

## Detected facts

### `firmware`

`boot_mode` (`uefi` or another value recorded only for rejection), `platform_bits` (`32` or `64`),
`efivars_available`, `secure_boot` (`enabled`, `disabled`, or `unknown`), and `dmi` with the non-sensitive
fields `sys_vendor`, `product_name`, `product_version`, `board_name`, `bios_vendor`, `bios_version`, and
`bios_date`.

### `network`

`ready` is true only when a default route exists, DNS resolves, and the HTTPS probe succeeds. When it is
false, `failing_step` is the first failing step (`default_route`, `dns`, or `https`). Other fields:
`default_route`, `dns_resolved`, `https_reachable`, `wifi_present`, and `interfaces` (`name`, `kind` as
`wired`, `wireless`, or `other`, `state`, `has_global_ipv4`, `has_global_ipv6`).

### `storage`

`live_medium_device` and `disks`. Every top-level block device is listed, and discovery never selects one.
Each disk has:

| Field | Description |
| --- | --- |
| `identity` | `path`, `by_id` (preferring `nvme-eui.*`, then `wwn-*`), `wwn`, `serial`, `model`, and `size_bytes`. Unavailable values are omitted. |
| `type`, `transport`, `removable`, `read_only` | Device attributes. |
| `layout` | `partition_table` (`type`, `uuid`, optional `sector_size_bytes`) and `partitions` (`path`, `size_bytes`, `fstype`, `label`, `uuid`, `partuuid`, `mountpoints`, optional `type_guid`, `partition_number`, `start_sector`, `partition_label`). `type_guid` is lowercase; `start_sector` uses lsblk's 512-byte units, independent of logical sector size. |
| `replace_candidates` | Optional array of unambiguously identified MirrorOS installations; each has `disk_path`, `storage_option`, `root` and `esp` (copies of their layout partition records). New runs emit an empty array when none qualifies. |
| `replace_rejections` | Optional array of `{ root_path, reason }` for partitions labelled `mirroros` that cannot be identified safely. It does not make a whole-disk-eligible disk invalid. |
| `eligible` | Whether the disk could be a candidate. |
| `ineligible_reasons` | Present only when `eligible` is false: `loop`, `rom`, `zram`, `unsupported_type`, `removable`, `read_only`, `live_medium`, `mounted`, `below_minimum_size`, or `size_unknown`. |

An existing layout alone never makes a disk ineligible.

#### Replacement identification

[ADR 0022 (a)](../docs/adr/0022-installer-coexistence-and-uefi-boot-entry.md) governs the binding:

- Require an eligible GPT disk and exactly one partition labelled `mirroros`, of Linux filesystem type
  GUID `0fc63daf-8483-4772-8e79-3d69d8477de4`, formatted as ext4 or Btrfs.
- Require root and ESP paths, positive sizes, partition numbers, start offsets, filesystem UUIDs and
  GPT PARTUUIDs. Filesystem UUIDs and PARTUUIDs must be unique on the disk.
- Read `/etc/fstab` from the unmounted root through `ro,noload` for ext4 or `ro,nologreplay,subvol=@`
  for Btrfs (falling back to `ro,nologreplay,subvolid=5` if `@` cannot be mounted). No journal or tree-log
  replay is allowed. Never elevate or inspect a mounted disk. Unmount every successful inspection mount;
  an unmount failure terminates discovery as an external-command failure.
- Require exactly one `/` fstab entry bound by `UUID=` to that root and exactly one `/boot` entry bound
  by `UUID=` to a vfat ESP on the same disk, with type GUID
  `c12a7328-f81f-11d2-ba4b-00a0c93ec93b`. Mount that ESP read-only. Symlinked binding files or their
  containing directories are not accepted.
- Require exactly one bootloader configuration: `limine.conf` for Btrfs/Limine, or
  `loader/entries/mirroros.conf` for systemd-boot. Its native `cmdline:` or `options` records must contain
  `root=UUID=<root UUID>` and no conflicting `root=` token. Comments and titles are not evidence.
- Record `btrfs-limine`, `btrfs-rescue` or `ext4-systemd-boot` according to the observed filesystem and
  loader. Never select a disk or choose a candidate on the user's behalf. Identification is not an
  authorization to format: plan generation and engine prechecks enforce current reuse-size policy.

Rejection reasons are `ambiguous_roots`, `unsupported_root`, `disk_ineligible`, `incomplete_identity`,
`missing_esp_binding`, `inspection_unavailable`, `ambiguous_identity`, `ambiguous_boot_configuration`,
`boot_root_mismatch`, and `ambiguous_esp_binding`. An ordinary disk without a `mirroros` root has empty
candidate and rejection arrays. Missing or unreadable inspection evidence never produces a candidate.
The geometry is observed information, not a full partition-table preservation proof; the replacement
engine records and compares `sfdisk --dump` separately.

### `hardware`

`architecture`, `cpu` (`vendor`, `model`, `cores`), `memory_total_bytes`, `graphics` (`vendor` as `amd`,
`intel`, `nvidia`, `qemu_virtual`, or `unknown`; `vendor_id`, `device_id`, `driver`, `boot_vga`),
`battery_present`, `virtualization`, and `wifi_reference`, which points to `network.wifi_present`. These
facts never block on their own; `architecture`, `virtualization`, and the DMI `sys_vendor` and
`product_name` also form the machine safety identity projected into the plan (see
[`installation-plan.md`](installation-plan.md#target)), and they take part in profile identification.

## Profile identification

`targets/<id>/target.json` declares `identity.status` as `defined` or `pending_capture`, an optional
`virtualization`, and either `dmi` values (`sys_vendor`, `product_name`) for a defined identity or
`dmi_fields_pending` for a pending one. The definition format is unchanged.

Discovery without `--target` identifies a profile automatically. A profile matches only when its identity is
`defined` and every field it declares (`virtualization` when present, and each `dmi` value) was observed and
equals the observed value. A declared field that could not be observed never matches. A `pending_capture`
identity is never inferred and never enables profile-specific adjustments.

| Result | `profile` | Validation |
| --- | --- | --- |
| Exactly one defined profile matches | `{ "status": "matched", "profile_id": "<id>" }` | Unchanged; the profile's overrides apply. |
| No defined profile matches | `{ "status": "unqualified" }` | Unchanged; no generic profile is invented and no override applies. |
| Two or more defined profiles match | `{ "status": "unqualified" }` | `profile_ambiguous`; none is selected arbitrarily and no override applies. |

`profile` records recognition only. It is not evidence that the individual machine was qualified, and
qualification claims live only in qualification evidence, never in the facts.

With `--target <id>` the identity is an assertion, not a classification. The facts are valid only if that
profile's identity is defined and matches; a contradiction, a pending identity, or an unobserved declared
field is rejected with a specific reason (see Validation) and the facts record the requested id in
`source.requested_profile_id`. A rejected assertion records `profile.status` `unqualified`. Discovery stays
read-only in both modes.

## Validation

`validation.status` is `valid` exactly when `reasons` is empty. Each reason and warning has `code`,
`message`, and `next_step`. Warnings do not affect the status.

| Code | Condition |
| --- | --- |
| `target_unknown` | `--target` names no definition under `targets/`. |
| `target_identity_mismatch` | `--target` only: the detected virtualization or DMI values contradict the asserted profile identity. |
| `target_identity_pending_capture` | `--target` only: the asserted profile identity has not been captured yet. |
| `target_identity_unobserved` | `--target` only: a field declared by the asserted identity could not be observed. |
| `profile_ambiguous` | Automatic identification only: more than one defined profile matches. |
| `boot_mode_not_uefi`, `uefi_platform_32bit`, `efivars_unavailable` | The firmware is outside the supported boundary. |
| `secure_boot_enabled` | Secure Boot is enabled. |
| `unsupported_architecture` | The architecture is not `x86_64`. |
| `network_no_default_route`, `network_dns_failed`, `network_https_failed` | The network is not ready, by failing step. |
| `no_eligible_disk`, `disk_ineligible` | No eligible disk; one `disk_ineligible` reason per disk. |
| `fact_missing` | A required fact is missing from the collector output. A missing identity field alone is not `fact_missing`: it only prevents a match. |
| `override_unknown_key`, `override_detected_fact`, `override_invalid_value`, `override_invalid_format` | The target override is invalid. |

Warning: `secure_boot_unknown` (the state could not be determined; exit `0`).

## Exit statuses

| Status | Meaning |
| --- | --- |
| `0` | Valid facts, possibly with warnings. |
| `2` | Invalid input or unmet precondition. `target-facts.json` is still written with `validation.status` `invalid`. |
| `5` | An external command failed unexpectedly. Only raw evidence and a structured error are written. |
| `6` | Damaged checkout or embedded code, or the produced document failed its own validator. Only raw evidence and a structured error are written. |

## Collector output

Each collector prints one JSON object on stdout. Normalization reads only the fields below and ignores
the rest.

| Collector | Fields |
| --- | --- |
| `firmware` | `boot_mode`, `fw_platform_size`, `efivars_available`, `secure_boot`, `dmi` (the seven DMI fields). |
| `network` | `interfaces` (`name`, `kind`, `state`, `has_global_ipv4`, `has_global_ipv6`), `default_route`, `dns` (`host`, `resolved`), `https` (`url`, `ok`, `timeout_seconds`). |
| `storage` | `blockdevices` (the `lsblk -J -b` tree with lowercase column names, including `parttype`, `partn`, `start`, `partlabel`, `log-sec`), `by_id` (`name`, `target`), `live_medium_device`, `installation_inspections`. |
| `hardware` | `architecture`, `cpu` (`vendor_id`, `model_name`, `cores`), `memory_total_kib`, `display_devices` (`vendor_id`, `device_id`, `driver`, `boot_vga`), `battery_present`, `virtualization`. |

Each storage `installation_inspections` record contains `root_path`, `esp_path`, `status` (`inspected` or
`unreadable`), and booleans `fstab_matches`, `limine_present`, `systemd_boot_present`, `limine_matches`,
`systemd_boot_matches`. Only these allowlisted binding results are retained: no fstab contents, full boot
configuration or unrelated kernel options are copied to raw evidence or normalized facts. Failure to mount
an installation is a recorded rejection, not a successful inspection or a whole-disk discovery failure.
