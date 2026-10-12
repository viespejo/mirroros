# ADR 0008: Installation Engine Execution Boundary

## Identifier and title

- **Identifier:** `0008`
- **Title:** Installation Engine Execution Boundary

## Status

`Accepted`

## Date

`2026-10-12`

## Context and question

[ADR 0006](0006-guided-live-installation-boundaries.md) accepted a root live session and an automatic start of the
guided assistant on tty1. Part of that acceptance rested on a stated premise: the delivery "performs no
installation-disk operation, collects no password, and creates no installation engine", and the record's
reversal boundary reads "Supersede this ADR before the installation engine story changes the hand-over boundary
described in the installation confirmation contract."

Story 2.5 (plan 02-09) connects the native installation engine selected by
[ADR 0002](0002-installation-engine-selection.md), behind `install/engine/apply`, to the guided assistant. The
premise no longer holds: the first disk-writing operation becomes reachable from a root session that starts
automatically. The questions are:

1. Do live-root and automatic startup remain acceptable once the engine is reachable, and on what argument?
2. Which hand-over boundary replaces the one ADR 0006 described?
3. How does the pinned build of the Limine snapshot tools relate to the architecture's rule that AUR packages
   are installed through `yay` after review and an unprivileged build?

The other engine rules (inputs, digest verification, password transport, exits, failure, cleanup, retry,
records) stay within accepted boundaries and are defined as contract material in
[`contracts/installation-engine.md`](../../contracts/installation-engine.md) and
[`contracts/installation-confirmation.md`](../../contracts/installation-confirmation.md), not here.

## Constraints and decision criteria

- Root privilege, automatic startup, and reachability of the engine must never by themselves authorize an
  installation-disk operation.
- Authorization is the bound, two-step confirmation of the concrete disk and plan, protected password entry, and
  final revalidation. Each element must be demonstrated by tests, not asserted.
- The confirmation stays ephemeral and single-use; no persisted file authorizes anything.
- The engine is a non-interactive child of the assistant (ADR 0004: Gum presents only and the plan, its digest,
  and `install/engine/apply` do not depend on it).
- The architecture's destructive retry policy stays: no automatic retry of destructive operations.
- Accepted ADR files are not rewritten. Supersession is recorded forward and limited to the clauses named below.
- A root user on the live system can run any command, including the engine; a digest argument cannot be an
  authorization mechanism, and the record must say so plainly.

## Alternatives considered

1. **Keep ADR 0006 unchanged and treat the engine as an implementation detail.** Rejected: ADR 0006 explicitly
   requires supersession before the hand-over boundary changes, and its safety argument depended on no engine
   being reachable.
2. **Run the engine through an unprivileged live account with narrow elevation.** It matches the architecture's
   privilege rule literally. Rejected again for the reasons recorded in ADR 0006: it adds an account and
   per-phase elevation that the reference experience lacks, and the engine needs root for every operation it
   performs, so elevation would be a formality.
3. **Persist a signed approval record that the engine requires.** It would let the engine distinguish a human
   approval from a direct call. Rejected: it creates a persisted authorization, contradicting the ephemeral,
   single-use confirmation, and a root session could still forge or replay it.
4. **Let the engine prompt for confirmation and the password itself.** Rejected: the engine would own a console,
   duplicating the assistant's interaction model and contradicting ADR 0004 and the single-UI-owner design.
5. **Build the Limine tools on the installed system with a temporary build user and sudoers entry.** Rejected:
   it grants privilege to a build user on the target and compiles a networked Gradle and GraalVM build during
   installation.
6. **Narrow supersession with an explicit path argument and a build-time prebuild (chosen).**

## Evidence

- ADR 0006 and the Story 2.4 transition record define the live-root session, the automatic tty1 startup, the
  terminal gate, and the bound confirmation that this decision reuses.
- Plan 02-07 delivered those mechanisms with tests; its hand-over point (`approved` with `engine_not_available`)
  is the single place this decision replaces.
- The Story 2.5 interview (DEC-002, DEC-004, DEC-013, DEC-014, DEC-017, DEC-019, DEC-020, DEC-021) records the
  design reviewed with the maintainer; see the [interview plan](../technical-interviews/story-2-5-base-system-install_plan.md)
  and [log](../technical-interviews/story-2-5-base-system-install_log.md).
- The Omarchy 4.0.4 ISO observations recorded in DEC-008 show an equivalent live-root, automatic-start installer
  model; they are patterns only and no code is copied.
- No physical-hardware evidence exists, and none is claimed.

## Decision

### Hand-over boundary

This ADR supersedes only the hand-over boundary of ADR 0006: the premise that no engine is reachable, and the
reversal-boundary clause that required this supersession. Everything else in ADR 0006 remains in force,
including the live-root session, experimental admission, the colored-console scope, and the automatic welcome.

The installation engine is reachable only through one path:

1. The terminal gate and Gum check of the assistant.
2. The installer lock, taken before any cleanup, discovery, or run directory and held through the engine.
3. Review of a validated plan and the bound two-step confirmation of the concrete disk and plan reference.
4. Protected entry of the single `account_password`, with repetition.
5. Final revalidation of machine, profile, disk, layout, eligibility, policy, configuration assets, and plan
   digest over fresh discovery.
6. A single invocation of `install/engine/apply` by the assistant.
7. The engine's own pre-check: lock held, code identity equal to the plan's, plan validation and digest, ready
   keyring, a read-once password, and a last read-only comparison of the disk with the plan immediately before
   the first destructive operation.

`mirroros-install --plan` enters the same path at review. There is no public `apply` subcommand, no
non-interactive mode, and no flag that bypasses confirmation, password entry, or the terminal gate.
`install/engine/apply` is an internal boundary.

Each step is covered by tests that show the engine is not started, and the disk is untouched, when the step is
not satisfied. Starting the assistant, including automatic startup, and being root grant no authorization.

### Why live-root and automatic startup remain acceptable

ADR 0006 accepted these because nothing reachable could write to a disk. That argument is replaced by the
following one:

- The automatic start only opens the welcome. Every route from it to a disk write crosses the confirmation, the
  password entry, and the final revalidation above, and none is skipped by any flag or environment variable.
- The engine adds no capability to a root session that it did not already have: root on the live system can
  already run `wipefs` or `dd` against any disk, with or without MirrorOS. The engine's guards protect against
  mistakes and stale approval, not against a deliberate root user.
- A direct engine call by root is therefore an accepted residual risk. The engine still refuses to run without
  the inherited installer lock, with a plan that fails validation or its digest, with a plan from a different
  code identity, or when the disk differs from the plan. These checks make accidental or stale execution fail
  early; they are integrity bindings, not authorization.
- Other consoles stay available and `mirroros-install` can be restarted manually, so the installer lock is
  required to keep a second run from disturbing an active one.

### Pinned build of the Limine snapshot tools

A narrow clarification, not a privilege exception. The architecture allows AUR packages "through `yay` only after
explicit `PKGBUILD` review and unprivileged build". Two paths now exist:

- **Artifact build:** the two Limine snapshot tools needed by `btrfs-limine` are built during the artifact build,
  before the image is assembled, with pinned `makepkg` from a reviewed recipe (AUR commit and upstream commit
  both verified), as a non-root user, without `--syncdeps` and without a sudoers grant. Build dependencies are
  installed by root from official repositories before the unprivileged build. The packages and a manifest of
  names, versions, hashes, and pins are embedded in the artifact and never committed.
- **Installed system:** `yay` with review and unprivileged build remains the AUR path of Epic 3 and Story 3.2.
  No AUR build happens during installation.

At installation the engine installs the prebuilt packages locally only after verifying their SHA-256 against the
embedded manifest. Package signature verification is never disabled; runtime dependencies come signed from the
official repositories.

## Consequences and trade-offs

- The live installer reaches a destructive engine from a root session that starts automatically. The mitigation
  is the single tested path above; the accepted cost is the residual risk that a root user can bypass the
  assistant, which was already possible with native tools.
- The confirmation contract can no longer claim that no installation-disk operation is reachable; it describes
  the real hand-over sequence instead.
- The artifact build gains a networked, longer stage with a pinned recipe, and old artifacts may drift in
  library versions between build day and install day.
- The installed Limine tools are foreign packages: their later updates through `yay` would build unpinned AUR
  head until Story 3.2 pins them.
- `engine_not_available` disappears as an outcome, and `approved` stops being terminal (contract change, not an
  ADR matter).

## Replacement or reversal boundary

Revisit this decision if any of the following occurs:

- A test or defect shows a path to a disk write that skips confirmation, password entry, or final revalidation.
- A non-interactive, remote, or public apply surface is requested.
- The live session stops running as root, or a live account is introduced.
- An installer phase needs elevation that root does not already hold.
- The artifact build can no longer pin or verify the Limine tool sources, or they require a repository this
  project excludes.
- A later ADR changes the engine selected by ADR 0002.

## Required validation

- Before adoption: the maintainer reviews this ADR, the engine contract, and confirmation contract version 4.
- After adoption: Bats and Node tests prove that no engine start occurs without the bound confirmation, the
  password entry, and a passing final revalidation, that no public or non-interactive apply path exists, that
  a second concurrent run cannot disturb an active one, and that the password never appears in process
  arguments, environments, logs, records, or evidence.
- Counted qualification on a clean artifact exercises the path end to end in the reference VM. No
  physical-hardware qualification is claimed.

## References

- [Architecture](../architecture.md)
- [ADR 0002](0002-installation-engine-selection.md)
- [ADR 0004](0004-interactive-presentation-with-gum.md)
- [ADR 0006](0006-guided-live-installation-boundaries.md)
- [Installation engine contract](../../contracts/installation-engine.md)
- [Installation confirmation contract](../../contracts/installation-confirmation.md)
- [Installation plan contract](../../contracts/installation-plan.md)
- [Story 2.5 interview plan](../technical-interviews/story-2-5-base-system-install_plan.md) and [log](../technical-interviews/story-2-5-base-system-install_log.md)

## Superseded by

`None`
