# reference-vm

Target definition for the MirrorOS reference virtual machine (QEMU/KVM, UEFI).

- `target.json` declares the identity constraints that discovery checks against detected facts: `kvm`
  virtualization and the DMI `sys_vendor` `QEMU`.
- `overrides/` holds explicit, reviewable target overrides. It is empty in Story 2.2.

Every target also has to satisfy the common boundary enforced by discovery: `x86_64`, 64-bit UEFI, and at
least one eligible non-removable disk that is not the live medium.

See [`contracts/target-facts.md`](../../contracts/target-facts.md) for the discovery format and validation
rules.
