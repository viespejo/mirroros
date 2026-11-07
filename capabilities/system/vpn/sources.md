# VPN sources and ownership

`networkmanager-openconnect` comes from the official Arch `extra` repository. Its dependencies provide the
OpenConnect transport and NetworkManager service (`networkmanager-vpn-plugin-openconnect` on the explored T14s);
configure records resolved package versions rather than pinning observations. NetworkManager remains the single
owner of connections, routes and DNS policy. The generic [network step](../network/sources.md) delivers
systemd-resolved/stub integration under [ADR 0024](../../../docs/adr/0024-networkmanager-resolved-dns-integration.md);
VPN DNS/domains are received dynamically. No standalone OpenConnect tunnel or vpnc-script is launched by this step.

The independently written step and `check` require the installed service registration and executable and ask
`nmcli --offline` to recognise the `openconnect` alias. Output is discarded: no profile is saved and no connection
or authentication occurs, in either context. This establishes plugin availability, not a successful corporate
connection. No VPN data is required by configure or included in its evidence.

The Story 4.4 gate approved 2026-11-03 retained this package after the Hyprland auth dialog failed. Exploration
validated a terminal `openconnect --authenticate` to NetworkManager handoff using ephemeral secret input with
not-saved flags. This does not authorise standalone tunnel setup. The secret-free procedure belongs to Task 5;
an owned connect command and graphical UI are deferred to 02-30. Ignored provenance:
`evidence/hardware/exploration-20261103T200419Z/REPORT.md`. No server, certificate, credential or company profile
is delivered, logged or needed by this step. T14s results are exploratory; Framework validation remains pending.
