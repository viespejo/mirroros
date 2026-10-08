# Target facts (`target-facts.json`)

`format_version: 1`. Produced by `operations/install discover` from read-only inspection of a target. It
records what was detected, keeps the four precedence layers distinguishable, resolves them into an
`effective` view, and reports whether the facts are valid. Unknown fields are rejected by
`install/discovery/validate-facts.mjs`.

Conventions: JSON fields use `snake_case`; fields that do not apply are omitted; sizes are integer bytes.

Note: installation policy is resolved in the plan, not here; see [`installation-plan.md`](installation-plan.md).

## Sensitive data

The document, the retained raw collector output, and stdout never contain MAC addresses, SSIDs, Wi-Fi
credentials, `iwd` state, the DMI product, board, or chassis serial, the product UUID, or a battery
serial. Collectors drop these at collection time and normalization only copies allowlisted fields. Disk
identity (serial, WWN, model) is kept because Story 2.4 binds confirmation to it; the file lives only in
local, ignored, secret-scanned evidence with `0600` permissions.

## Top-level fields

| Field | Description |
| --- | --- |
| `format_version` | Always `1`. |
| `source` | `run_id`, embedded `commit`, `dirty`, and `target_id` (omitted when the id is missing or malformed). |
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
| `layout` | `partition_table` (`type`, `uuid`) and `partitions` (`path`, `size_bytes`, `fstype`, `label`, `uuid`, `partuuid`, `mountpoints`). Recorded as information only. |
| `eligible` | Whether the disk could be a candidate. |
| `ineligible_reasons` | Present only when `eligible` is false: `loop`, `rom`, `zram`, `unsupported_type`, `removable`, `read_only`, `live_medium`, `mounted`, `below_minimum_size`, or `size_unknown`. |

An existing layout alone never makes a disk ineligible.

### `hardware`

`architecture`, `cpu` (`vendor`, `model`, `cores`), `memory_total_bytes`, `graphics` (`vendor` as `amd`,
`intel`, `nvidia`, `qemu_virtual`, or `unknown`; `vendor_id`, `device_id`, `driver`, `boot_vga`),
`battery_present`, `virtualization`, and `wifi_reference`, which points to `network.wifi_present`. These
facts never block on their own; they take part only in the target identity check.

## Target identity

`targets/<id>/target.json` declares `identity.status` as `defined` or `pending_capture`, an optional
`virtualization`, and either `dmi` values (`sys_vendor`, `product_name`) for a defined identity or
`dmi_fields_pending` for a pending one. The detected virtualization (and, for a defined identity, the DMI
values) must match.

## Validation

`validation.status` is `valid` exactly when `reasons` is empty. Each reason and warning has `code`,
`message`, and `next_step`. Warnings do not affect the status.

| Code | Condition |
| --- | --- |
| `target_missing`, `target_unknown` | No target given, or no definition under `targets/`. |
| `target_identity_mismatch` | Detected virtualization or DMI values contradict the target identity. |
| `target_identity_pending_capture` | The target identity has not been captured yet. |
| `boot_mode_not_uefi`, `uefi_platform_32bit`, `efivars_unavailable` | The firmware is outside the supported boundary. |
| `secure_boot_enabled` | Secure Boot is enabled. |
| `unsupported_architecture` | The architecture is not `x86_64`. |
| `network_no_default_route`, `network_dns_failed`, `network_https_failed` | The network is not ready, by failing step. |
| `no_eligible_disk`, `disk_ineligible` | No eligible disk; one `disk_ineligible` reason per disk. |
| `fact_missing` | A required fact is missing from the collector output. |
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
| `storage` | `blockdevices` (the `lsblk -J -b` tree with lowercase column names), `by_id` (`name`, `target`), `live_medium_device`. |
| `hardware` | `architecture`, `cpu` (`vendor_id`, `model_name`, `cores`), `memory_total_kib`, `display_devices` (`vendor_id`, `device_id`, `driver`, `boot_vga`), `battery_present`, `virtualization`. |
