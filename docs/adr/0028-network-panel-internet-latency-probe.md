# ADR 0028: Network Panel Internet Latency Probe

## Identifier and title

- **Identifier:** `0028`
- **Title:** Network Panel Internet Latency Probe

## Status

`Accepted`

The maintainer accepted this architectural decision on 2026-11-08 at the plan 02-28 acceptance checkpoint, after the
plan 02-28 technical interview (DEC-055 to DEC-057). Implementation and validation remain with plan 02-28.

## Date

`2026-11-08`

## Context and question

[ADR 0025](0025-shell-panels.md) admits a bar-anchored network panel adapted from Omarchy 4.5. Its Decision states
"**Diagnostics:** no continuous probing of a fixed third-party host; panels use the gateway and NetworkManager's
connectivity check". The motivation was third-party traffic, metered and ICMP-filtering networks, and the noise seen on
the T14s with the prototype (latency variation, no real loss).

The Omarchy `v4.5.0` network panel runs `omarchy-network-status --verbose` every 1.5 s while it is open. That command
pings the gateway and `1.1.1.1` with one packet and a 1 s timeout, and the panel shows only the `1.1.1.1` samples as
"Ping" and "Packet loss" over a 24-sample window, turning loss red on any lost sample. On the T14s, Wi-Fi latency
spikes above 1 s counted as lost samples, which together with the strict threshold explains the noisy indicator.

During the plan 02-28 technical interview the maintainer stated that internet latency is the value worth seeing in the
panel. The panel header already reports reachability from NetworkManager's connectivity state ("Limited access",
"Sign in required"), so a connectivity row would be redundant, and a gateway-only ping diagnoses the local hop but
does not measure internet quality. [`docs/adr/README.md`](README.md) forbids rewriting an accepted decision.

The question is: may the network panel probe a fixed internet host, and within which boundary?

## Constraints and decision criteria

- ADR 0025's remaining decisions stay in force, including no resident shell daemon and no background service.
- No probe traffic while the panel is closed.
- No DNS resolution per sample, and no additional configuration surface for the destination.
- Stay close to the Omarchy `v4.5.0` behaviour to keep the adaptation reviewable.
- The loss indicator must not report false alarms on ordinary Wi-Fi latency variation.

## Alternatives considered

1. **Internet ping to `1.1.1.1` only while the panel is open, with a relaxed loss indicator (selected).** Keeps the
   4.5 rows and destination; anycast and no DNS resolution; adds Cloudflare as a third party while the panel is open.
2. **Gateway-only ping.** Within ADR 0025, diagnoses the local Wi-Fi hop, but does not measure internet latency.
3. **Remove the "Ping" and "Packet loss" rows.** Within ADR 0025, but drops the value the maintainer asked for.
4. **On-demand measurement.** No continuous traffic, but needs an extra control and gives no running view.
5. **Quad9 (`9.9.9.9`).** Anycast and privacy-oriented, but diverges from upstream without clear gain.
6. **Arch connectivity host (`ping.archlinux.org`).** No new third party, but needs DNS per sample, is a single server
   whose latency measures distance rather than internet quality, and may not answer ICMP.

## Evidence

- The [shell panels prototype procedure](../procedures/shell-panels-prototype.md) records the noisy packet-loss
  indicator observed on the T14s with the 4.5 threshold and timeout.
- The Omarchy `v4.5.0` sources `bin/omarchy-network-status` and `shell/plugins/panels/network/{Panel.qml,Model.js}`,
  read from the pinned upstream reference, define the 1.5 s cadence, the 1 s timeout and the 24-sample window.
- The [Story 4.4 network panel technical interview log](../technical-interviews/story-4-4-network-panel_log.md)
  records DEC-055 to DEC-057.

No laboratory or hardware evidence exists yet for the relaxed indicator; validation belongs to plan 02-28.

## Decision

- **Probe:** while the network panel is open, and only then, the owned `network-status` command pings the default
  gateway and the single constant internet host `1.1.1.1`, declared once in the command. Each poll sends one packet
  per host with a 2 s timeout. The panel polls every 1.5 s; a poll still running when the next tick fires makes that
  tick skip, so probes never overlap. No probe runs while the panel is closed.
- **Display:** "Ping" and "Packet loss" describe the `1.1.1.1` samples, as in 4.5. Loss is computed over a 24-sample
  window (about 36 s) and turns red only with at least 10 samples and loss of 10 % or more; below that the percentage
  shows in the normal colour. With Portal, Limited or None connectivity both rows show "--".

This ADR supersedes only ADR 0025's "Diagnostics" item for the network panel. Every other part of ADR 0025 remains in
force, and other panels keep the gateway and NetworkManager connectivity check.

## Consequences and trade-offs

- Opening the network panel sends ICMP traffic to Cloudflare at about one packet every 1.5 s for as long as it stays
  open, including on metered networks.
- On networks that filter ICMP the internet rows show high or total loss that does not reflect real connectivity; the
  header's NetworkManager connectivity state remains the authoritative reachability signal.
- The destination is fixed in code; changing it requires a source change, not configuration.
- Latency spikes between 1 s and 2 s count as high latency rather than loss, reducing false alarms on Wi-Fi.

## Replacement or reversal boundary

Reconsider through a new ADR if the probe must run while the panel is closed, if the destination must become
configurable, or if the indicator proves misleading on supported networks.

## Required validation

In plan 02-28, after acceptance:

- Command tests for the gateway and internet ping arguments (one packet, 2 s timeout, constant host) and for no ping
  fields without a gateway or route.
- Model tests for the loss threshold (fewer than 10 samples never red; 10 % or more with at least 10 samples red) and
  for "--" under Portal, Limited and None connectivity.
- Laboratory guest: ping and loss shown while the panel is open, and no ping process after it closes.
- T14s: several minutes of Wi-Fi use without false red loss.

## References

- [ADR 0025: Shell Panels](0025-shell-panels.md)
- [ADR 0012: Owned Quickshell Desktop Shell](0012-owned-quickshell-desktop-shell.md)
- [Shell panels prototype procedure](../procedures/shell-panels-prototype.md)
- [Story 4.4 network panel technical interview log](../technical-interviews/story-4-4-network-panel_log.md)

## Superseded by

`None`
