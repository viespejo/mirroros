# Architecture Decision Records

## Relationship to the architecture

`docs/architecture.md` is the consolidated description of the current design. Architecture Decision Records (ADRs) preserve the reasoning, evidence, trade-offs, and history of individual decisions. The architecture and accepted ADRs are read together: the architecture describes the current shape, while ADRs explain why a decision was made and where its boundaries lie.

## Shared presentation extension

[ADR 0019: Shared Symbol and Live Splash](0019-shared-symbol-and-live-splash.md) narrowly extends
[ADR 0014](0014-native-login-and-boot-presentation.md) and [ADR 0018](0018-native-live-display-and-installer-presentation.md)
with the shared installer symbol, static greeter, reviewed splash animation, and live build integration.
Their unrelated decisions and historical evidence remain in force; real boot qualification remains separate.

[ADR 0021: Neutral Greeter and Themed Lock](0021-neutral-greeter-and-themed-lock.md) narrowly supersedes the
selected-account display of ADR 0014 and the preserved greeter layout of ADR 0019, keeps system surfaces neutral, and
lets the lock follow the selected theme.

## Installer coexistence extension

[ADR 0022: Installer Coexistence and UEFI Boot Entry](0022-installer-coexistence-and-uefi-boot-entry.md) is
Accepted and extends [ADR 0003](0003-storage-and-recovery-baseline.md) and
[ADR 0009](0009-storage-option-promotion-and-esp-size.md) with whole-disk and partition-scoped replacement
modes, explicit selected-loader UEFI registration and `mirroros-boot-first`. Narrow forward notes in those
records preserve their historical decisions; neither record is superseded by ADR 0022. Storage choices,
ESP policy and unrelated decisions remain in force.

## Numbering and filenames

Use four digits and a short descriptive title: `NNNN-short-title.md`. Allocate the next unused number when creating an ADR. Do not reuse a number, even if an ADR is later rejected or superseded.

The baseline template is `0000-template.md`; it is a template, not a decision record.

## Statuses

Use one of these statuses in each ADR:

- **Proposed:** under discussion and not yet authoritative.
- **Accepted:** the decision is authoritative and part of the current design.
- **Rejected:** the proposal was considered and explicitly not adopted.
- **Superseded:** a later ADR replaces the decision.

## When an ADR is required

Create an ADR for a critical technology or architecture selection, the outcome of a prototype that changes or constrains the design, or an exception to the architecture. Routine implementation choices that stay within accepted boundaries do not require a separate ADR.

A prototype is evidence, not permission to bypass the decision process. Record a prototype outcome when it creates a new constraint, validates a critical choice, or requires an architecture change.

## Supersession and history

Supersede an ADR with a forward link from the older record to the successor in its **Superseded by** section. Never delete an ADR to hide its history, and do not rewrite its decision to make the historical record appear current. The successor should identify the decision it replaces and explain the changed boundary.

## Non-retroactivity

Do not retroactively convert existing architecture content into ADRs. Create an ADR when a new decision, prototype outcome, or architecture exception requires one; preserve existing architecture documentation as the consolidated design unless a later decision changes it.
