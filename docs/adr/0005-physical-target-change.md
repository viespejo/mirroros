# ADR 0005: Physical Target Change

## Identifier and title

- **Identifier:** `0005`
- **Title:** Physical Target Change

## Status

`Accepted`

## Date

`2026-10-07`

## Context and question

The architecture and the epics name the Slimbook Creative as the single physical target of the MVP (NFR27: one reference VM configuration and one target laptop). The maintainer has stated that the physical target is now the Framework Laptop 13 Pro with an AMD Ryzen AI 300 series processor and integrated AMD graphics only. The machine has no hybrid or discrete GPU.

The question is whether to replace the Slimbook Creative with the Framework Laptop 13 Pro as the MVP physical target, and which architectural passages that change affects.

## Constraints and decision criteria

- NFR27 keeps its meaning: one reference VM configuration and one target laptop.
- Target identity must come from captured evidence; no hardware identity is invented before capture.
- No real DMI values, serial numbers, or other machine identifiers enter the repository.
- This decision must not decide any hardware rule; hardware rules depend on the captured topology.
- Existing architecture content is amended only where it names the former target, and rules are never deleted to hide history.

## Alternatives considered

1. **Keep the Slimbook Creative as the target.** No documentation change. It does not match the machine the maintainer will use.
2. **Support both laptops in the MVP.** It would break the NFR27 bound of one target laptop and double the qualification effort.
3. **Replace the target with the Framework Laptop 13 Pro (chosen).** It keeps the one-target bound and aligns the documentation with the actual machine.

## Evidence

The evidence is the maintainer's statement of the target model and its graphics configuration. No hardware capture of the Framework Laptop 13 Pro exists yet, so its DMI identity, PCI, USB, firmware, storage, and graphics topology are pending capture (TODO-002 of Story 2.2).

## Decision

The MVP physical target is the Framework Laptop 13 Pro (AMD Ryzen AI 300 series, integrated AMD graphics only). The target definition directory becomes `targets/framework-13-pro-amd/` and replaces `targets/slimbook-creative/` in the architecture. The architecture and the epics stop naming the Slimbook Creative.

The `nvidia-discrete-graphics` and `hybrid-graphics` hardware rules, and the hybrid graphics cross-cutting concern, are marked as not applicable to the current target. They are not deleted.

This ADR decides no hardware rule.

## Consequences and trade-offs

- NFR27 now applies to the Framework Laptop 13 Pro.
- The target id is `framework-13-pro-amd`. Its identity stays `pending_capture`, so discovery against it exits `2` with a pending-capture reason until the DMI identity is recorded.
- The two graphics rules stay in the tree as not applicable. Story 2.6 decides whether to remove them, using the captured topology.
- Slimbook-specific knowledge gathered earlier no longer applies to the target and is not carried over.
- Risk: until the capture exists, hardware rules for the new target cannot be qualified on the physical machine.

## Replacement or reversal boundary

Replace or reverse this decision if the maintainer changes the physical target again, or if the captured topology of the Framework Laptop 13 Pro contradicts the integrated-graphics-only statement.

## Required validation

- Before adoption: the architecture and epics contain no reference to the Slimbook Creative, and the diff is limited to the passages that named it plus the not-applicable notes.
- After adoption: capture the Framework Laptop 13 Pro DMI identity and topology (TODO-002) and record them in the target definition before any physical qualification.

## References

- [Architecture](../architecture.md)
- [Epics](../epics.md)
- [ADR 0003: Storage and Recovery Baseline](0003-storage-and-recovery-baseline.md)

## Superseded by

`None`
