# thinkpad-t14s-gen1-amd

Recognized, unqualified profile for the maintainer's ThinkPad T14s Gen 1 AMD. It is not an NFR27 target,
adds no MVP or `target-laptop-eligible` gate, and makes no compatibility or support promise. The Framework
Laptop 13 Pro remains the sole laptop in the MVP qualification boundary. See
[ADR 0023](../../docs/adr/0023-recognized-unqualified-targets-and-target-hibernate-mode.md).

- `target.json` declares `identity.status: defined`, `virtualization: none`, and the exact DMI identity
  `sys_vendor: LENOVO`, `product_name: 20UJ001RMX`. These values were captured during the exploratory
  MirrorOS installation on 2026-10-27 (local finding `TODO-582784b9`). The evidence is non-qualifying;
  no serial numbers or UUIDs are recorded.
- Exact `product_name` matching deliberately excludes other SKUs. `product_version` is not used because
  `ThinkPad T14s Gen 1` is shared with the Intel variant. No family or MTM-prefix matching is performed.
- `overrides/` holds explicit, reviewable target overrides. The `hibernate_mode: shutdown`
  adjustment applies only to this matched profile and only delivers configuration when hibernation is
  enabled; see [the override notes](overrides/README.md).

Known exploratory findings in `TODO-582784b9`:

- Hibernation in the default `platform` mode aborts during firmware S4 entry. The local `shutdown`
  workaround permits resume; product delivery and attended verification are tracked by plan 02-24.
- `mt7921e` reports restore error `-110` with delayed Wi-Fi recovery. This finding remains open.
- Fingerprint-session behaviour was observed on Omarchy. This finding remains open; this profile adds
  no fingerprint mitigation or `fprintd`.

Every target also has to satisfy the common boundary enforced by discovery: `x86_64`, 64-bit UEFI, and at
least one eligible non-removable disk that is not the live medium. Recognition grants no installation
authorization and is not qualification.

See [`contracts/target-facts.md`](../../contracts/target-facts.md) for the discovery format and validation
rules.
