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

## Recognized unqualified targets extension

[ADR 0023: Recognized Unqualified Targets and Target Hibernate Mode](0023-recognized-unqualified-targets-and-target-hibernate-mode.md)
is Accepted. It adds the exact-DMI `thinkpad-t14s-gen1-amd` recognized unqualified profile and a typed,
non-editable hibernate-mode override with conditional installed-tree delivery. The Framework remains the sole
qualified laptop target; recognition adds no qualification or support commitment. ADRs 0005, 0006 and 0007
remain related and unchanged; none is superseded.

## Installed DNS integration extension

[ADR 0024: NetworkManager and systemd-resolved DNS Integration](0024-networkmanager-resolved-dns-integration.md)
is Accepted. It selects the generic installed DNS backend/stub integration, preserving public DNS choices and
private dynamic VPN input. Configure owns bounded migration and both execution contexts; no accepted ADR is
superseded. The prototype and local tests do not establish updated-candidate or target-laptop readiness.

## Shell panels extension

[ADR 0025: Shell Panels](0025-shell-panels.md) is Accepted. It amends [ADR 0012](0012-owned-quickshell-desktop-shell.md)
with bar-anchored audio, network/Wi-Fi, Bluetooth, display and power panels and their credential, privilege, DNS
and service boundaries, as [ADR 0020](0020-wallpaper-selection.md) did for wallpaper. ADR 0012's remaining
exclusions and authentication rules stay in force; per-panel hardware validation belongs to the production plans.

[ADR 0026: MPRIS Player Names and Advanced Audio Tool](0026-mpris-player-names-and-advanced-audio-tool.md) is
Accepted. It narrowly supersedes ADR 0025's deferral of MPRIS labels with native player names in the audio mixer and
adds `pavucontrol` with an "Advanced…" panel button; no shell media service is added and the `playerctl` boundary
stays.

[ADR 0027: Display Panel Mirror Toggle](0027-display-panel-mirror-toggle.md) is Accepted. It narrowly supersedes
ADR 0025's display panel content with a runtime-only mirror toggle over the existing `display mirror` command, which
restores the external output's runtime layout when mirroring ends; no monitor arrangement editor or display
configuration write is added.

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
