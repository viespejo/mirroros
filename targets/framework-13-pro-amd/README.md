# framework-13-pro-amd

Target definition for the physical target: Framework Laptop 13 Pro with an AMD Ryzen AI 300 series
processor and integrated AMD graphics only. See
[ADR 0005](../../docs/adr/0005-physical-target-change.md).

- `target.json` declares `identity.status: pending_capture`. The DMI `sys_vendor` and `product_name` have
  not been captured yet, so `discover --target framework-13-pro-amd` exits `2` with a pending-capture
  reason. Record both values in `target.json` and set the status to `defined` after capturing them on the
  machine. Serial numbers and UUIDs are never recorded.
- `overrides/` holds explicit, reviewable target overrides. It is empty in Story 2.2.

Every target also has to satisfy the common boundary enforced by discovery: `x86_64`, 64-bit UEFI, and at
least one eligible non-removable disk that is not the live medium.

See [`contracts/target-facts.md`](../../contracts/target-facts.md) for the discovery format and validation
rules.
