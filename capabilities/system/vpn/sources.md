# VPN sources and ownership

`networkmanager-openconnect` comes from the official Arch `extra` repository. Its dependencies provide the
OpenConnect transport and NetworkManager service (`networkmanager-vpn-plugin-openconnect` on the explored T14s);
configure records resolved package versions rather than pinning observations. `openconnect` (authentication client)
and `jq` (username preference writer) from `extra` are declared explicitly for the owned commands below.
NetworkManager remains the single owner of connections, routes and DNS policy. The generic [network step](../network/sources.md) delivers
systemd-resolved/stub integration under [ADR 0024](../../../docs/adr/0024-networkmanager-resolved-dns-integration.md);
VPN DNS/domains are received dynamically. No standalone OpenConnect tunnel or vpnc-script is launched by this step.

The independently written step and `check` require the installed service registration and executable and ask
`nmcli --offline` to recognise the `openconnect` alias. Output is discarded: no profile is saved and no connection
or authentication occurs, in either context. This establishes plugin availability, not a successful corporate
connection. No VPN data is required by configure or included in its evidence.

The Story 4.4 gate approved 2026-11-03 retained this package after the Hyprland auth dialog failed. Exploration
validated a terminal `openconnect --authenticate` to NetworkManager handoff using ephemeral secret input with
not-saved flags. This does not authorise standalone tunnel setup. The secret-free procedure belongs to Task 5. Ignored provenance:
`evidence/hardware/exploration-20261103T200419Z/REPORT.md`. No server, certificate, credential or company profile
is delivered, logged or needed by this step. T14s results are exploratory; Framework validation remains pending.

## Owned commands

`vpn-connect` and `vpn-profile` are delivered to `/usr/share/mirroros/hardware/` (mode 0755) for the shell network
panel under [ADR 0025](../../../docs/adr/0025-shell-panels.md) (gate G8, plan 02-30). They are MirrorOS-owned
`GPL-3.0-only` code with no upstream source: an independent reimplementation of the approach validated by the
MirrorOS [OpenConnect helper prototype](../../../prototypes/vpn-openconnect-helper/README.md), which is neither copied
nor sourced. Decisions DEC-075 to DEC-094 are in the
[VPN panel interview log](../../../docs/technical-interviews/story-4-4-vpn-panel_log.md).

- `vpn-profile list` prints OpenConnect profiles with their state; `vpn-profile disconnect <uuid>` requests down and
  verifies the effective state instead of trusting the `nmcli` exit status (prototype finding).
- `vpn-connect <uuid>` runs only as the session user in a local terminal. The existing profile is the single source
  of settings: gateway with tunnel group, `protocol` (allowlist `anyconnect`; `anyconnect` when absent) and an
  optional `useragent` come from `vpn.data`, and the four secret flags must be 2. Password and one-time code stay at
  OpenConnect's prompts; a strict parser maps the authentication output to a runtime passwd-file for
  `nmcli connection up`. Only the username may be remembered, after an explicit `SAVE`, in
  `${XDG_STATE_HOME:-$HOME/.local/state}/mirroros/vpn/<uuid>.json`.
- Neither command creates or edits a profile, stores a secret, changes DNS or routes, or uses sudo or pkexec.
  configure delivers them but never runs them or OpenConnect.
