# OpenConnect VPN helper prototype

## Status

Executed during plan 02-25 Task 7 (Story 4.4 T14s supervised acceptance) as acceptance-only tooling. Superseded by
the owned `capabilities/system/vpn` commands (plan 02-30); kept unchanged as the evidence behind that design. It is
not a MirrorOS product command: configure does not deliver it, and production code never sources it.

## Superseded by

`vpn-connect` and `vpn-profile` in [`capabilities/system/vpn`](../../capabilities/system/vpn/sources.md), an
independent reimplementation reviewed in the
[VPN panel interview log](../../docs/technical-interviews/story-4-4-vpn-panel_log.md) (DEC-075..DEC-094) and launched
from the shell network panel. Deliberate differences:

- The gateway, protocol and optional user agent come from the profile's `vpn.data`; nothing about the server is
  prompted or remembered.
- Preferences live in `${XDG_STATE_HOME:-$HOME/.local/state}/mirroros/vpn/<uuid>.json` and hold only the username;
  `~/.mirroros-vpn-acceptance/` is never read and should be deleted.
- The profile UUID is an argument; there is no typed `CONNECT` confirmation.
- `FORGET` deletes a saved username and asks again.
- Disconnect verifies the effective state after `down` (`vpn-profile disconnect`), and connect cleanup uses the same
  check after a partial activation.
- Distinct exit codes for usage, environment, profile, already active, cancelled, authentication, unsupported output
  and activation failures.

## Question

Can a corporate Cisco AnyConnect-compatible VPN be authenticated and activated from a local terminal while
NetworkManager stays the single owner of the connection, routes and DNS, no credential is persisted, and the
gateway and username can optionally be remembered per profile?

## Scenario

- ThinkPad T14s Gen 1 AMD running MirrorOS candidate `f075cf1` with `networkmanager-openconnect`
  (product step `system/vpn`) and the external NetworkManager/systemd-resolved DNS prototype that ADR 0024
  later turned into the `system/network` step.
- An existing, inactive NetworkManager OpenConnect profile created privately by the maintainer, with
  `cookie-flags`, `gwcert-flags`, `gateway-flags` and `resolve-flags` set to `2` (not saved).
- Run as the graphical user in a local, unrecorded terminal; never via `sudo`, SSH or a pipe.

## Design

1. `vpn-acceptance.sh` refuses arguments, root, SSH and non-TTY execution, and requires a private tmpfs
   `XDG_RUNTIME_DIR`.
2. It resolves the selected profile, requires the OpenConnect plugin service type, refuses an already active
   profile and checks the four not-saved secret flags without changing the profile.
3. Gateway and username are read with visible input or reused from
   `~/.mirroros-vpn-acceptance/<profile-uuid>.json` (`vpn-preferences.sh`): owned directory mode 0700, owned
   single-link file mode 0600, schema `{schema_version: 1, gateway, username}` only. Saving needs an explicit
   `SAVE`; existing files are never overwritten. Values reach `jq` through stdin, never arguments.
4. After an explicit `CONNECT`, `openconnect --protocol=anyconnect --authenticate` runs with a private config
   file (`server`, `user`) in the runtime directory. Password and OTP stay at OpenConnect's own prompts.
5. A strict parser accepts only single-quoted `COOKIE`, `HOST`, `FINGERPRINT`, `RESOLVE` and `CONNECT_URL`
   assignments (no `eval`/`source`), rejecting unknown, duplicate, empty or control-character fields, and writes
   a NetworkManager `passwd-file`.
6. `nmcli connection up uuid <uuid> passwd-file <file>` activates the profile. The EXIT trap removes the
   temporary files and deactivates a partially activated connection.

No NetworkManager profile, DNS, route, autoconnect or permission setting is modified by the helper. Cookies,
authentication results, certificate fingerprints and passwd files never leave the runtime tmpfs; cookie reuse is
not implemented.

## Verification

- `node --test vpn-acceptance.test.mjs vpn-preferences.test.mjs`: 21 synthetic tests (parser mapping and
  rejection cases, no command substitution, EXIT cleanup, SSH/non-interactive refusal, preference schema,
  ownership, modes, symlinks, hard links, traversal and no-overwrite). No real network or credential is used.
- `bash -n` and ShellCheck pass on both scripts.
- Real use on the T14s (2026-11-06): the maintainer authenticated locally and NetworkManager activated the VPN;
  corporate resources were reachable. Independent sanitized checks confirmed one active VPN, private preferences
  with the exact schema and modes, and per-domain DNS scoping under the external DNS prototype (the product
  `system/network` step was not yet deployed). A second local run reused
  the saved gateway and username, as observed by the maintainer.
- Not verified: whether a server-specific authentication form still asks for the username; cookie reuse;
  non-AnyConnect protocols; behaviour without the not-saved secret flags.

## Findings for plan 02-30

- Disconnecting over SSH failed: `nmcli connection down` returned 0 while NetworkManager audited an
  authorization denial (`org.freedesktop.NetworkManager.network-control` is `auth` for SSH sessions) and the VPN
  stayed active. `nmcli --ask` in an SSH PTY did not complete the authorization either. A wrapper must verify the
  effective state after `down` instead of trusting the exit status, and run in the local graphical session.
- The VPN pushes its DNS servers and search domain dynamically; manual DNS or route-only domains on the profile
  were not needed. Keep profile DNS untouched (ADR 0024).
- Corporate resources reached through IP literals or `/etc/hosts` validate reachability, not VPN DNS routing.
- Preferences live under the acceptance-specific `~/.mirroros-vpn-acceptance/`. A product wrapper should choose
  its own reviewed location (for example under `$XDG_STATE_HOME/mirroros/`) and a migration or reset path.
- The product provides only the plugin and the documented private profile procedure
  ([hardware procedure](../../docs/procedures/hardware.md#private-corporate-vpn-procedure)); profile creation, graphical access and a bar panel
  remain later scope; graphical access through the network panel and an owned wrapper is plan 02-30
  ([ADR 0025](../../docs/adr/0025-shell-panels.md)).

## Handoff boundaries

Never commit corporate gateways, usernames, profile names or UUIDs, DNS servers, domains, certificates or
authentication output. Tests use synthetic `.invalid` values only. Raw acceptance evidence stays in ignored
`evidence/hardware/`.

## Provenance

Written for MirrorOS during plan 02-25. Behaviour follows the
[OpenConnect manual](https://www.infradead.org/openconnect/manual.html) (`--authenticate`, `--config`, `server`,
`user`) and NetworkManager `nmcli connection up ... passwd-file`. No upstream script is copied.
