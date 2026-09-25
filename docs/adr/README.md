# Architecture Decision Records

## Relationship to the architecture

`docs/architecture.md` is the consolidated description of the current design. Architecture Decision Records (ADRs) preserve the reasoning, evidence, trade-offs, and history of individual decisions. The architecture and accepted ADRs are read together: the architecture describes the current shape, while ADRs explain why a decision was made and where its boundaries lie.

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
