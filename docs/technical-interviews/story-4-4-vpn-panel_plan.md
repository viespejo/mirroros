# Story 4.4 VPN panel — consolidated plan

Current design state for plan 02-30. Traceability tags point to
[story-4-4-vpn-panel_log.md](story-4-4-vpn-panel_log.md).

## Settled inputs

ADR 0025 (gate item G8) fixes the boundary for graphical VPN access: an owned Bash wrapper in
`capabilities/system/vpn`, reimplemented from the OpenConnect helper prototype rather than promoted, runs only in the
local graphical session, verifies the effective state after disconnecting and keeps preferences under
`$XDG_STATE_HOME/mirroros/`. The network panel lists NetworkManager VPN profiles and opens the wrapper in `foot`; no
VPN credential passes through QML. NetworkManager stays the single owner of connections, routes and DNS, and VPN DNS
is received dynamically (ADR 0024). Plan 02-28 deliberately shipped the network panel without a VPN section so that
the listing and the wrapper arrive together. Upstream Omarchy v4.5.0 has no VPN section in its network panel.

## Scope

Plan 02-30 is one plan. It delivers owned VPN commands in `capabilities/system/vpn` — an interactive connect run in a
terminal and non-interactive disconnect and status — together with a VPN section in the network panel, their tests,
a laboratory checkpoint, a supervised non-qualifying T14s checkpoint against the real corporate VPN, and the
documentation and provenance updates, including marking the prototype as superseded. Splitting the wrapper from the
listing was rejected because either half alone has no valid user action, the same reasoning that kept the VPN section
out of plan 02-28. No new ADR is needed while the work stays inside ADR 0025. Credential-bearing non-OpenConnect
profiles, Tailscale (TODO-023), a dedicated VPN bar indicator and Framework Laptop 13 Pro validation are out of scope
[DEC-075]; the bar indicator was later
declined for this plan [DEC-090].

## Listed profiles

The VPN section lists only NetworkManager profiles of type `vpn` whose service type is
`org.freedesktop.NetworkManager.openconnect`, the single provider MirrorOS installs and the only path validated
end to end. Connecting such a profile opens the owned wrapper in Foot and disconnecting it calls the owned
non-interactive command. WireGuard and other VPN plugin profiles are not listed: activating them from the panel would
rely on a graphical secret agent that does not work under Hyprland, so they stay reachable through "Advanced…"
(`nmtui`). Listing them, read-only or with direct activation, is left as a later extension [DEC-076].

## Command interface

Two owned commands are delivered to `/usr/share/mirroros/hardware/`, keeping the credential path separate from the
path the panel calls. `vpn-connect <uuid>` is interactive only: it refuses to run without a terminal, over SSH or as
root, authenticates with `openconnect --authenticate` and hands the result to NetworkManager through
`nmcli connection up ... passwd-file`. The panel never runs it directly; it opens it in Foot with
`uwsm app -- foot -e /usr/share/mirroros/hardware/vpn-connect <uuid>`. `vpn-profile` is non-interactive: `list`
prints the OpenConnect profiles with UUID, name and state in a fixed parseable format, and `disconnect <uuid>` asks
NetworkManager to bring the profile down and then checks the effective state within a bounded wait, because the
prototype showed `nmcli connection down` returning success while polkit denied the request. A profile that stays
active yields its own exit code. The UUID on argv follows the `network-dns` precedent; no other private value is
passed as an argument [DEC-077].

## Connection settings source

The NetworkManager profile is the single source of connection configuration. `vpn-connect` reads `vpn.data` and
consumes only three keys through a strict parser: the required `gateway` (including the tunnel-group path the
hardware procedure already stores there), `protocol`, accepted only when it is on an allowlist that today holds just
the validated `anyconnect`, and an optional `useragent`, which is written into the private OpenConnect config file on
tmpfs rather than passed on argv. A missing gateway or an unsupported protocol stops the command with a message that
points to the hardware procedure. Unlike the prototype, the gateway is neither typed nor kept in preferences, so it
cannot drift from the profile. The 02-25 exploration showed that neither a custom User-Agent nor a lowered GnuTLS
priority string was needed for the corporate server; the User-Agent stays possible through the profile if a server
ever requires it, while `--gnutls-priority` is deliberately unsupported because weakening TLS is a security decision
that must not hide inside a wrapper [DEC-078]. A profile without a `protocol` key behaves as the plugin does and is
treated as `anyconnect`, passed explicitly; only a present value outside the allowlist is refused, and the procedure
recommends but does not require setting it [DEC-092].

## Preferences

The username is the only remembered value. It lives in `${XDG_STATE_HOME:-$HOME/.local/state}/mirroros/vpn/<uuid>.json`
with the schema `{"schema_version": 1, "username": ...}`, inside an owned 0700 directory as an owned, single-link
0600 regular file; symlinks are refused and values reach `jq` on stdin, as in the prototype. A saved username is
reused with a notice. Otherwise the user types it and may keep it by answering `SAVE`, while Enter uses it once;
existing files are never overwritten. When a username is saved, the prompt also accepts `FORGET`, which deletes the
file and asks again, and removing the file by hand is documented as an equivalent reset. The prototype's
`~/.mirroros-vpn-acceptance/` directory is not migrated or read; the procedure tells the user to delete it, since it
also holds a gateway that is now taken from the profile. Passwords and OTPs stay at OpenConnect's own prompts and
are never stored, and authentication cookies are never reused [DEC-079].

## Connect flow

`vpn-connect` keeps the prototype's preconditions: it refuses root, SSH and anything but a terminal on all three
standard streams, requires the user's own 0700 tmpfs runtime directory at `/run/user/$EUID`, checks its tools and the
UUID format, and accepts only an existing OpenConnect profile that already marks the cookie, certificate, gateway and
resolve secrets as not saved. A profile missing those flags is refused without being modified, with a pointer to the
procedure, and an active or activating profile is refused too. Unlike the prototype, there is no typed `CONNECT`: the
click in the panel is the intent, the terminal names the profile, and Ctrl+C at any prompt cancels with full cleanup.
As with Custom DNS, the panel launches it through a small wrapper that prints `Connected`, `Cancelled` or `Failed`
and waits for a key, so errors stay visible; the panel itself trusts only the state re-read from `vpn-profile list`.
Exit codes are distinct — 2 usage, 3 environment, 4 invalid profile, 5 already active, 6 cancelled, 7 authentication
failed, 8 unsupported authentication output, 9 activation failed — and a trap removes the runtime files on every
exit, bringing a half-activated profile down and verifying the result with the same check as `vpn-profile disconnect`.
Verbose OpenConnect output, cookies in `vpn.secrets` and `--show-secrets` are never used [DEC-080].

## Profile listing and disconnect

`vpn-profile list` prints one tab-separated line per OpenConnect profile — UUID, state (`inactive`, `activating`,
`active` or `deactivating`) and name, in that order — so a name containing colons cannot break the format; names
with control characters keep their row, each control character shown as `?`, since actions go by UUID [DEC-093]. Active profiles come first, then alphabetical order, and an empty
list is a normal exit 0. `vpn-profile disconnect <uuid>` accepts only an OpenConnect profile, does nothing and
succeeds when it is already inactive, and otherwise asks NetworkManager to bring it down without trusting the exit
status: it polls the effective state for up to 5 s (a test-only `MIRROROS_VPN_DOWN_WAIT_SECONDS` override follows
the `bluetooth-power` precedent) and returns 5 when the profile is still active, which is the polkit-denial case seen
in the prototype. Other shared codes are 2 for usage, 3 for an unknown or non-OpenConnect UUID and 4 when
NetworkManager is unavailable. Only the profile name leaves the command, because the panel shows it; nothing from
`vpn.data` or `vpn.secrets` is printed [DEC-081].

## Open constraints

Adding the VPN section must not make the network panel overflow its height. The Bluetooth panel hit exactly this on
the T14s in plan 02-29 and was fixed with a list cap, while a robust shared layout remains TODO-644fa670. The panel
design accounts for it through the section cap and both checkpoints check it [RISK-001, DEC-082].

## Panel placement and height

The VPN section sits between the DNS controls and the Wi-Fi list, under its own `VPN` header and separator, so it is
visible without scrolling and does not compete with the Wi-Fi list, which is the part that grows. It appears only when
at least one OpenConnect profile exists, so users without a VPN pay no space, and it hides together with the rest of
the panel when NetworkManager is unavailable. Its rows live in a separate `ListView` capped at about
`Style.space(96)`, two to three rows, scrolling beyond that, while the Wi-Fi list keeps its 240 cap. Both checkpoints
check the card height on the T14s at its real scale; an overflow would be fixed by lowering the caps, leaving a
layout redesign to TODO-644fa670. Placing the section below the Wi-Fi list, closer to the upstream stacking, was
rejected as more likely to fall off screen [DEC-082, RISK-001].

## Rows, states and actions

Each VPN row shows an icon, the profile name and, unless the profile is inactive, its state as `Connected`,
`Connecting…` or `Disconnecting…`. An inactive profile offers Connect, which launches `vpn-connect` in Foot through
the Connected/Cancelled/Failed wrapper and closes the panel, as Custom DNS and "Advanced…" already do. An active
profile offers Disconnect, which runs `vpn-profile disconnect` from the panel and leaves it open so the result is
visible. Profiles that are activating or deactivating offer nothing; a connection in progress is cancelled with
Ctrl+C in its own terminal. Only one VPN may be up at a time: while a profile is active or activating, Connect is
dimmed and inert on the other rows, because only a single tunnel has been validated and two would mix routes and DNS.
Disconnect follows the 02-29 single-action pattern — the acting row reads `Disconnecting…`, the others are dimmed
and inert, and repeats are ignored — and its failures appear only on that row: `Still connected: disconnect not
authorized` for exit 5, `NetworkManager unavailable` for exit 4 and `Disconnect failed` otherwise, cleared when a
refresh reads the profile inactive or the panel closes. The row body itself is not clickable, so a stray click
cannot open a credential terminal [DEC-083].

## State refresh

Quickshell 0.3.2's networking module knows only Wi-Fi and wired devices, so the VPN state comes from
`vpn-profile list`. The panel reads it on open and immediately after each Disconnect, then every 2 s while it stays
open, skipping a tick when the previous read has not finished and running nothing once closed; the cost is local
D-Bus traffic through `nmcli`, not network traffic. A failed read hides the section instead of leaving stale rows. A
native API would only have made reading reactive: connecting would still go through the Foot wrapper, because the
cookie handoff cannot pass through QML, and disconnecting would still verify the effective state. An event-driven
`nmcli monitor` process was rejected as more machinery than one to three profiles justify, and a code comment marks
the polling for review if Quickshell ever exposes VPN connections [DEC-084].

## Delivery

The existing `system/vpn` configure step delivers both commands to `/usr/share/mirroros/hardware/` with mode 0755,
using the same tracked-file pattern as `system/network`, and keeps its plugin registration check; no step is added,
so `CFG_STEPS` stays 19. Its package list gains `openconnect` and `jq`, which the commands call directly and should
not inherit from a transitive dependency or another capability; Foot stays with `desktop/terminal`, because only the
panel needs it. The commands are MirrorOS-owned `GPL-3.0-only` code with MirrorOS headers and no Omarchy license
copy. `check` is unchanged: configure still creates no profile and never authenticates or connects. A delivery
contract test asserts paths, modes, packages and that configure never runs the commands [DEC-085]; it extends the
existing `hardware.contract.bats` [DEC-086].

## Tests

Delivery assertions extend `hardware.contract.bats`, which already covers `system/vpn` and was extended the same way
for Bluetooth. The commands get their own Bats suite, `hardware-vpn-commands.bats`, driven by namespaced doubles
that record argv and exist under their real names only inside that suite. It refuses root, SSH and missing terminals,
and exercises the interactive happy path under a pty created with `script -qec`. Every profile refusal leaves the
profile untouched, a `useragent` reaches only the private config, and no recorded argv ever carries the username,
gateway, cookie or fingerprint. The strict parser is tested for its mapping and every rejection without `eval`, and
cleanup is checked after success, failed authentication, Ctrl+C and failed activation, including the verified
`down` of a half-activated profile. The suite also covers the preferences file rules with `SAVE` and `FORGET`, each
exit code, the `list` format with awkward names, and a `disconnect` that sees `nmcli` succeed while the profile stays
up. ShellCheck runs on both commands. On the panel side, the new pure helpers in `panels/network/Model.js` get Node
tests, and static guards pin the exact Foot launch argv, forbid running `vpn-connect` any other way, forbid
credential fields, `nmcli connection up` and `omarchy-*` calls in the VPN section, and keep polling tied to the open
panel; `check-panels.sh` and the reviewed qmllint baseline close the loop in the laboratory. The prototype's own
tests are left alone here [DEC-086].

## Prototype and provenance

The prototype stays in `prototypes/vpn-openconnect-helper/` with its scripts and synthetic tests untouched, as the
evidence behind the command design, and its tests stay outside the product suites. Following the prototypes
register convention, Track 5 is marked as executed in plan 02-25 and superseded by the owned `capabilities/system/vpn`
commands of plan 02-30, and the Layout note that the wrapper still belongs to 02-30 is dropped. The prototype README
gains an updated status and a short "Superseded by" section listing the deliberate differences — gateway from the
profile, a new preferences location holding only the username, no typed `CONNECT`, `FORGET`, a verified `down` and
distinct exit codes — while its "Findings for plan 02-30" remain as history. `system/vpn/sources.md` records the
commands as an owned reimplementation, links the prototype and this log, and replaces its "deferred to 02-30"
sentence [DEC-087].

## Documentation

The hardware procedure keeps step 1 of the private corporate VPN workflow — creating the profile locally with the
not-saved secret flags — and states that gateway, tunnel group, protocol and an optional User-Agent belong in that
profile. The old manual handoff (steps 2–5) gives way to a "Connect and disconnect" section covering the panel and
the two commands, their exit codes, the username preference with `SAVE`, `FORGET` or manual deletion, and removal of
the prototype's `~/.mirroros-vpn-acceptance/`. The manual handoff survives in condensed form as a "Manual fallback"
for profiles the command refuses, because ADR 0025 keeps the terminal paths as the permanent fallback. The procedure's
"deferred to 02-30" sentences are updated, the "Corporate VPN" matrix row records the new results, and a "Network
panel: VPN section" row is added. The desktop-shell procedure needs no IPC or binding change, since the section lives
in the existing `network` panel, and gains at most a mention. `docs/mvp-scope.md` row 45 is synced with the commands
and panel access as alignment with ADR 0025, not as a scope change. The shell `UPSTREAM.md` marks the VPN section of
`Network.qml` and `Model.js` as MirrorOS-owned. `docs/attribution.md` and `docs/architecture.md:486` are untouched,
and this log collects dated execution findings [DEC-088].

## Checkpoints

Both checkpoints run a checksummed bundle in a fresh clone. The laboratory uses only fictitious OpenConnect profiles
pointing at `vpn.example.invalid`. That covers everything except a real tunnel: delivery and an unchanged rerun, the
panel with no profiles, one profile and four within the height cap, Connect opening Foot and closing the panel, a
misconfigured profile refused without changes, and a genuine authentication failure against the nonexistent host that
ends in `Failed` with nothing left behind. It also covers Ctrl+C ending in `Cancelled`, the `SAVE`/`FORGET` file
rules, a stopped NetworkManager, the session suites and the reviewed qmllint baseline. Connecting the real corporate
profile in the guest would have caught happy-path defects earlier, but it would leave corporate data in a disposable,
snapshotted and agent-operated VM, may clash with corporate policy and costs an OTP per run, so the real connection
is left to the T14s.

There, in a supervised, non-qualifying session with sanitized evidence, the maintainer removes the prototype's
preferences, connects from the panel and saves the username, and privately checks resource access, split DNS and
routes. Disconnecting from the panel must need no sudo or polkit prompt. A second connection reuses the username. An
SSH disconnect must report the profile still active, reproducing the polkit denial. A wrong password and a Ctrl+C at
the OTP prompt must leave nothing behind, and `FORGET` must reset the username. The panel height is checked at real
scale, and one-VPN gating optionally with a temporary fictitious profile. Gitleaks and a journal check close the
session. The Framework Laptop 13 Pro, other protocols and cookie reuse stay out of scope [DEC-089, RISK-001].

## No bar indicator

The bar does not show the VPN state. Without a Quickshell VPN API, an indicator would need either continuous
polling or a permanently running `nmcli monitor` while the panel is closed, contradicting the open-only refresh
and edging towards the resident processes ADR 0025 excludes. The state is therefore visible only with the panel
open. An indicator remains a follow-up for when Quickshell exposes VPN connections, or for an explicit decision to
accept continuous polling [DEC-090].

## Commits

The work lands at the end as three local commits — commands with delivery and their tests, then the panel model,
VPN section, guards, lint baseline and shell provenance, then documentation including these interview artifacts —
and nothing is pushed. Temporary candidate refs under `refs/mirroros-candidates/02-30-*` stay local until the
maintainer reviews them [DEC-091].

## Keyboard

The VPN section joins the panel's section focus model as `vpn`, between the DNS controls and the Wi-Fi list, matching
its position on screen: moving down walks the VPN rows and then continues into the Wi-Fi list, and moving up
reverses the path. Enter presses the row's only button and does nothing on rows without an available action, so
there is no horizontal movement inside the section. Opening the panel still focuses the portal, the Wi-Fi list or
the DNS controls as before, which keeps a stray Enter from opening a credential terminal. When the section vanishes
while focused, focus falls back to DNS as it already does for the band controls, and the focused row reuses the
panel's cursor style [DEC-094].

## Execution notes (2026-11-10)

This section supplements the narrative above; the execution findings in the
[interview log](story-4-4-vpn-panel_log.md#execution-findings--2026-11-10-plan-02-30) hold the details.
Both checkpoints were approved, and the T14s record is non-qualifying. The corporate VPN connected from the network
panel and disconnected from it with a verified state. Two outcomes differ from the expectations above. With a long
Wi-Fi list the card overflowed the T14s screen, so while the VPN section is shown the Wi-Fi list cap now yields the
section's height instead of staying at 240 (RISK-001 closed; TODO-644fa670 tracks a robust layout). The corporate
server asks for the password again after a wrong one, so the Failed path was confirmed only in the laboratory.
