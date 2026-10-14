# ADR 0010: Environment Configuration Mechanism and Scope

## Identifier and title

- **Identifier:** `0010`
- **Title:** Environment Configuration Mechanism and Scope

## Status

`Accepted`

## Date

`2026-10-14`

## Context and question

`docs/architecture.md` left two items gated before broad environment implementation: a shell versus Ansible
local-mode spike to select the convergence mechanism, and a minimal capability inventory relating each capability
to its implementation, package provenance, dependencies, and verification checks.

The Epic 3 technical interview concluded that configuration is not an independent user outcome. A base
configuration without the desktop has no standalone value, so `configure` applies the complete MVP environment
(system, desktop, and user tools) as one outcome on a newly installed system. The questions are:

1. Which mechanism applies the environment: bounded Bash scripts, Ansible local mode, or another abstraction?
2. Is the shell versus Ansible prototype still required?
3. Is a formal capability inventory still required, or does a lighter artifact serve the same purpose?

## Constraints and decision criteria

- NFR37: custom code, formats, services, and abstractions need a documented recurring need that simpler supported
  mechanisms cannot meet.
- NFR38: no proprietary configuration format without a documented, concrete gap in existing options.
- NFR46: binding choices of configuration mechanism and orchestration tool were to remain deferred until research
  and a minimal prototype provide evidence. This ADR records an explicit exception to the prototype requirement.
- Sustainability for a single maintainer: the mechanism must stay small enough to read, debug, and rerun by hand.
- Language hierarchy: Bash owns native Arch integration and bounded system operations.
- Native Arch and application formats remain authoritative.
- A full rerun after an interruption must be safe and must identify the failed step.
- Privilege boundaries and runtime-only secrets must be preserved.

## Alternatives considered

1. **Run the shell versus Ansible local-mode spike.** Produces comparative evidence, but costs a prototype tree and
   a decision step for a mechanism whose requirements are already narrow. The maintainer does not intend to adopt
   Ansible, so the result could not change the outcome.
2. **Adopt Ansible local mode.** Offers declarative idempotent modules and a mature ecosystem. It adds a large
   dependency to the installed system, a second configuration language, and an abstraction layer over native
   formats that one maintainer would have to keep current.
3. **Central manifest or universal MirrorOS schema.** Gives one place to describe the environment. It creates a
   proprietary format that duplicates native declarations and conflicts with NFR38.
4. **Formal capability inventory.** Gives machine-checkable links between capabilities, packages, dependencies,
   and checks. It is a second source of truth that must be kept synchronized with the native declarations and the
   verification catalog, and it only has a consumer if a convergence engine reads it.
5. **Bounded Bash scripts with native Arch and application formats (selected).** Uses pacman package lists,
   systemd units, and application-native files with their established semantics, applied by small scripts with
   explicit postconditions. It adds no dependency and no new format, at the cost of hand-written idempotency.

## Evidence

- Epic 3 technical interview log (`docs/technical-interviews/epic-3-environment-configuration_log.md`),
  DEC-005, DEC-011, and DEC-012, and the maintainer's stated intent not to use Ansible.
- The architecture already prescribes beginning with small, explicit scripts and documented commands.
- No prototype was run and no comparative measurement exists. This is a decision by scope reduction, not by
  experiment, and the replacement boundary below is the mitigation.

## Decision

MirrorOS applies the MVP environment with bounded Bash scripts that operate on native Arch and application
formats. Specifically:

- The shell versus Ansible local-mode prototype is not run. Ansible is not selected.
- There is no central manifest, no universal MirrorOS schema, no package version pinning, and no continuous
  synchronization of an installed system.
- The formal capability inventory is replaced by a human-readable MVP scope list, owned and frozen by Story 4.1,
  that names the software and capabilities of the environment and the frequent-action list.
- Package provenance and postcondition checks live in the native declarations, alongside the scripts that apply
  them, or in the reserved `inventory/` provenance records; Story 4.3 decides the form.
- Rerun safety is postcondition-based: a full rerun after interruption is safe and identifies the failed step.
- `configure` checks its own postconditions. Independent readiness verification stays in `verify` (Epic 5).

## Consequences and trade-offs

- No `prototypes/convergence/` tree and no `configuration-convergence` integration gate are created.
- Story 4.1 owns the MVP scope list; later stories consume it instead of a formal inventory schema.
- Idempotency is implemented and tested per script instead of being provided by a framework; each step carries
  the cost of an explicit postcondition check.
- Drift between declarations is limited by keeping a single native source per concern rather than by a
  cross-reference inventory.
- Risk: the decision is made without comparative evidence. This is accepted because the mechanism is small,
  reversible, and covered by the replacement boundary.
- Reserved `inventory/` and capability-schema paths in the architecture are not populated speculatively.

## Replacement or reversal boundary

Reconsider this decision through a new ADR if real scripts show recurring problems that a different mechanism
would address, for example repeated idempotency defects, duplicated logic across scripts that cannot be removed
by ordinary refactoring, or machine-specific variation that native formats cannot express. The new ADR must cite
the observed problems as evidence. Choosing Ansible, Stow, chezmoi, or a manifest for an unrelated story without
such an ADR is not permitted.

## Required validation

Before adoption:

- `docs/architecture.md` is amended so that it no longer requires the spike, an `ansible-local` prototype, or a
  formal capability inventory, and it references this ADR.

After adoption, through Story 4.2:

- A full rerun of `configure` on an already configured system leaves no duplicated or unintended state.
- A rerun after an interrupted run completes and identifies the step that failed.
- Postcondition evidence is produced by `configure` for the steps it applies.

## References

- [Architecture](../architecture.md)
- [Epic 3 technical interview plan](../technical-interviews/epic-3-environment-configuration_plan.md)
- [Epic 3 technical interview log](../technical-interviews/epic-3-environment-configuration_log.md)
- [PRD](../prd.md), NFR37, NFR38, NFR46
- [ADR 0002](0002-installation-engine-selection.md), the precedent for resolving an engine gate through an ADR

## Superseded by

`None`
