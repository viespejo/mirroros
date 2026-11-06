# ADR 0024: NetworkManager and systemd-resolved DNS Integration

## Identifier and title

- **Identifier:** `0024`
- **Title:** NetworkManager and systemd-resolved DNS Integration

## Status

`Accepted`

The maintainer accepted this architectural decision on 2026-11-06. Implementation remains subject to a separate
scoped review; consequential migration and network operations require their own approval.

## Date

`2026-11-06`

## Context and question

Story 4.4 delivers the NetworkManager OpenConnect plugin without a corporate profile or stored credentials.
The T14s acceptance run established corporate connectivity, but the original flat `/etc/resolv.conf` placed VPN
resolvers before the normal connection's resolvers. That arrangement cannot express per-domain DNS routing and
does not meet the maintainer's requirement to keep unrelated public lookups on the normal connection.

An explicitly authorized external prototype combined NetworkManager with systemd-resolved and its local stub.
The VPN supplied usable DNS servers and a search domain dynamically; no manual corporate DNS list was needed.
The prototype is retained on the exploratory T14s, but is not reproduced by candidate `e3c3228`. A successful
configure rerun of that candidate would not prove delivery of the resolver integration.

The question is how to deliver generic, reproducible DNS integration without embedding corporate information,
imposing a public DNS provider, or turning a successful experiment into an undocumented prerequisite.

The maintainer explicitly expanded plan 02-25 on 2026-11-06 to permit this ADR and subsequent reviewed
implementation, tests, documentation and revalidation. This narrowly overrides that plan's prohibition on new
ADRs; unrelated accepted decisions and shell boundaries remain unchanged.

## Constraints and decision criteria

- Follow the architecture and ADR 0010: bounded Bash, native formats, explicit ownership and postconditions.
- NetworkManager remains the sole connection/DNS-policy authority. systemd-resolved executes its per-link
  resolver policy; no second network manager, custom daemon or resolver orchestration service is introduced.
- Separate generic network integration from the optional act of authenticating or connecting a VPN.
- Preserve existing public DNS choices, automatic DNS settings, connection profiles and routing policy.
- Corporate servers, domains, gateways, certificates, identifiers and credentials stay outside source and evidence.
- Support both mounted-target and running contexts, safe interruption/retry, and a no-change converged rerun.
- Never restart NetworkManager, the shell, hypridle or the desktop from configure.
- T14s observations are exploratory, not qualification. Framework validation remains pending.

## Alternatives considered

1. **Keep a flat resolv.conf with corporate servers first.** Smallest delivery, but lacks per-domain routing and
   sends unrelated queries to corporate DNS. Rejected for the stated requirement.
2. **NetworkManager with systemd-resolved and the local stub (proposed).** Uses installed upstream mechanisms,
   supports per-link DNS/domain policy and has direct prototype evidence. Requires explicit migration, service
   lifecycle integration and verification of effective state.
3. **NetworkManager with dnsmasq.** Can express conditional forwarding, but adds another package/backend and
   lacks this plan's equivalent prototype evidence. Not selected.
4. **Standalone OpenConnect with resolver scripts or static private forwarding rules.** Duplicates connection
   and DNS ownership, requires private values in another configuration surface, and weakens cleanup semantics.
   Not selected.
5. **Copy the entire Omarchy DNS-switching implementation.** Provides provider selection but adds policy and
   global overrides beyond the requirement. Use the upstream backend/stub pattern, not the provider-changing
   scripts or global wildcard configuration.

## Evidence

The supervised 2026-11-06 prototype used NetworkManager 1.58.1-2 and systemd 262.1-1 on a recognized, unqualified
T14s. The checked-out product baseline during the DNS experiment was clean `f075cf1`; prototype state was external.
Sanitized records remain under ignored `evidence/hardware/acceptance-20261105T223002Z/`:

- `dns-phase1-result.md`: backend/stub delivery, public resolution, failed first attempt and rollback limitations.
  A separately authorized resolved reload and NetworkManager DNS republish removed observed residual global DNS.
- `dns-phase2-dynamic-result.md`: VPN-pushed DNS/domain scope, positive private answers through the tunnel,
  public A/AAAA answers through the normal link, and observed DNS/domain removal after disconnect and restoration
  after reconnect. Some pending lists in this intermediate report were superseded by later execution records.
- Plan execution log entries at 15:45:57Z and 15:49:42Z: bounded positive and NXDOMAIN packet observations used
  only the tunnel, with no normal-link packets and zero reported drops in the observed windows.
- `closure-inventory-20261106.md`: retained prototype, recovery material, package/tool disposition and remaining
  acceptance gaps. The later 17:52:53Z execution record authorizes this governance expansion.

The tunnel had a search domain, no root-routing domain and DefaultRoute=false; the normal DNS-bearing link was
DefaultRoute=true. Search domains participate in resolved routing as well as short-name expansion. Manual
corporate DNS/domain edits were not needed. Public-provider changes in phase 1 were an explicitly approved local
experiment, not a proposed product default.

Corporate DNS transport unavailability/timeout was not injected. NXDOMAIN is a negative DNS response, not a
transport-failure test. No universal no-leak, application DoH, IPv6 resource-connectivity, reboot persistence or
qualified-laptop claim follows from these observations. A reported VPN disconnection remains unclassified,
possibly manual according to the maintainer; neither spontaneous failure nor manual cause is established.

## Decision

Propose NetworkManager plus systemd-resolved with the local stub as the installed system's generic DNS path.
No accepted ADR is superseded.

### Ownership and native configuration

- Add a `system/network` configure step before `system/vpn` and the desktop consumers. It owns resolver integration,
  not Wi-Fi credentials, VPN authentication, profile creation or the installer's existing NetworkManager setup.
- Preserve installer ownership of base NetworkManager installation/enablement. The new step declares its
  resolver package prerequisites and provenance, using official Arch packages without version pins; verify the
  installed systemd package supplies the resolver service and required interfaces.
- Deliver `/etc/NetworkManager/conf.d/20-mirroros-dns.conf` with only `[main]`,
  `dns=systemd-resolved` and `rc-manager=unmanaged`.
- Own `/etc/resolv.conf` as a symlink to `/run/systemd/resolve/stub-resolv.conf`. The runtime destination need not
  exist inside an offline target root; the symlink must not resolve through the host during target validation.
- Enable `systemd-resolved.service`. Do not enable systemd-networkd or install another DNS-policy manager.
- Do not write global DNS servers, a wildcard/root domain, a public-provider selection or a corporate profile.
  Keep normal connection DNS policy in NetworkManager profiles, including DHCP/RA defaults and existing manual
  choices. A provider selector and graphical VPN integration remain outside this decision.
- Keep `system/vpn` responsible for the OpenConnect plugin and its registration check. Record actual file,
  package and service ownership in `system/network/sources.md` during implementation.

### Dynamic VPN policy and privacy boundary

Use DNS servers and domains received by NetworkManager from the VPN. Do not infer organizational suffixes,
commit private forwarding rules, or overwrite existing profile DNS priorities, routes, permissions or autoconnect.
For the intended split-DNS session, verify that the private suffix is scoped to the tunnel, that the tunnel is
not the default DNS route, and that unrelated names use the normal link. A VPN advertising root routing, missing
suffixes or conflicting scopes requires private inspection and a separately reviewed policy, not silent rewriting.

This is per-domain routing, not a universal DNS privacy firewall. While disconnected, no private-domain blocker
is added: those names may reach the normal resolver. Applications bypassing the system resolver, including DoH,
are outside this integration's enforcement. These limits must be documented before claiming readiness.

### Safe migration and reproducible application

Implementation must provide a bounded migration, not copy the acceptance scripts into production:

1. Discover the resolver file type, ownership, service state and effective NetworkManager/resolved configuration
   before mutation. Recognize the already-converged prototype explicitly. Masks, immutable files, custom links,
   competing resolver managers, conflicting overrides or ambiguous manual-only DNS state must stop with an
   actionable precondition failure rather than be overwritten.
2. Preserve regular-file resolver content and relevant service/configuration state in a root-private backup
   outside retained public evidence. Log only allowlisted phases and outcomes. A regular resolv.conf is not
   sufficient authority to rewrite all connection profiles: if its manual DNS policy is not represented in the
   profiles, require a separately reviewed private migration preserving that choice before replacing the file.
3. Stage and validate the owned drop-in and symlink, publish with bounded failure handling, and enable the service.
   Mounted-target application writes only target declarations and enablement links; it performs no live service,
   host DNS, D-Bus, connection or network operations. First boot must establish service ordering and DNS readiness
   without a manual repair command.
4. In the running context, start resolved only if inactive. Apply changed backend/stub state with supported,
   bounded NetworkManager configuration reload/DNS republish and any necessary resolved refresh, never a
   NetworkManager restart. The prototype's residual-global-state issue must be covered explicitly. Gate migration
   away from an active VPN on a separately confirmed safe window; do not disconnect a VPN automatically.
5. Express runtime activation through reviewed mechanism helpers, not direct systemctl/nmcli mutations in apply.
   Existing start/reload helpers do not by themselves specify NetworkManager reload/DNS republish semantics;
   review the exact additional helper contract, ordering and test doubles before implementation.
6. On failure, identify the phase and restore prior files, links and service enablement/activity where safe.
   Verify the restored state after probes: NSS can activate resolved, so a rollback marker alone is insufficient.
   Report incomplete recovery and stop; no automatic retry or false readiness. Preserve private recovery material
   until the migration and subsequent validation are accepted.
7. A converged rerun verifies state without rewriting files, creating another backup, reloading services or
   republishing DNS merely because configure ran. Interrupted application must be recoverable without treating
   an incomplete transition as an already-converged baseline.

Running postconditions inspect effective backend, stub link, enabled/active resolver, absence of unintended
MirrorOS global DNS overrides and successful public resolution when connectivity is available. Offline or
externally unavailable DNS must be identified honestly, never converted into a successful lookup result.
Target postconditions inspect declared files, link and enablement only. Neither context requires an active VPN,
corporate profile or private DNS lookup for generic configuration success.

## Consequences and trade-offs

- Normal and VPN DNS can coexist without making corporate DNS the default for unrelated lookups.
- The DNS backend becomes a declared system capability rather than a persistent external experiment.
- Migration and rollback add bounded complexity, but no custom resolver service or configuration schema.
- DNS changes can interrupt name resolution, including SSH-dependent work; consequential runtime application
  needs a reviewed recovery path and explicit authorization during this plan.
- Existing manual DNS choices are preserved, at the cost of stopping on ambiguous legacy configurations instead
  of guessing. Clean installs retain automatic network-supplied DNS unless the user chooses otherwise.
- A later public-DNS provider selector (for example one modelled on Omarchy 4.0.6 `omarchy-dns`) remains
  compatible only if it writes per-connection `ipv4.dns`/`ipv6.dns` and `ignore-auto-dns` properties, including
  for profiles created afterwards. NetworkManager `[global-dns*]` sections or resolved `DNS=`/`Domains=`
  assignments are rejected by configure as conflicting policy; adopting that global layer requires amending this
  decision.
- Upstream defaults, resolver routing and service activation remain version-sensitive. Tests and real postconditions
  must detect changes; prototype observations are not package pins or permanent guarantees.

## Replacement or reversal boundary

Reconsider this selection if supported upstream behavior cannot maintain the required per-domain routing,
reproducible first boot, safe migration or DNS cleanup, or if bounded transport-failure testing demonstrates
unacceptable fallback. A competing resolver backend or stronger disconnected-name enforcement requires a new
reviewed decision rather than hidden policy inside an action command.

Rollback removes only owned integration and restores the recorded pre-migration resolver/service state through
an explicitly authorized recovery operation. Do not uninstall systemd or destroy user profiles/preferences.

## Required validation

Before decision acceptance:

- Review this proposal against architecture ownership/privilege rules and the sanitized prototype evidence.
- Confirm preserved public DNS policy, dynamic VPN input, disconnected-name limits and migration rejection cases.
- Agree on the untested transport-failure disposition; no no-leak guarantee may be inferred while it remains open.

After acceptance, before product readiness:

- Add mechanism/step tests for both contexts, missing/conflicting state, already-converged prototype adoption,
  manual-policy preservation, interrupted migration, failure propagation, verified rollback and zero-change rerun.
- Prove target operations do not touch host DNS or activate services, including a dangling target stub link.
- Validate first boot from a clean candidate ISO, effective running state and a no-change rerun in the VM.
- Validate the updated T14s candidate, public and private DNS scope, connected/disconnected/reconnected behavior,
  negative responses and a separately authorized bounded transport-failure test or an explicit remaining limitation.
- Recheck post-refresh global scope and reboot persistence without manual repair. Never require corporate values
  in generic VM tests; use synthetic fixtures and separately supervised private acceptance.
- Update configure documentation, capability ordering, provenance, MVP scope and hardware validation matrix
  together with implementation. Scan changed source and selected sanitized evidence for secrets.
- Keep T14s exploratory and Framework pending target-laptop validation; old candidate VM results do not validate
  the new integration. No implementation or runtime validation is claimed by creating this Proposed ADR.

## References

- [Architecture](../architecture.md)
- [ADR policy](README.md)
- [ADR 0010](0010-environment-configuration-mechanism-and-scope.md)
- [Configure procedure](../procedures/configure.md)
- [Hardware procedure](../procedures/hardware.md)
- [MVP scope](../mvp-scope.md)
- [OpenConnect step](../../capabilities/system/vpn/apply)
- [NetworkManager.conf upstream manual](https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html)
- [systemd-resolved upstream manual](https://www.freedesktop.org/software/systemd/man/latest/systemd-resolved.service.html)
- Omarchy 4.0.6 (MIT), DNS/backend and stub integration reference only; no literal source fragments copied here.
- Local plan execution log: `.agents/plans/02-25-story-4-4-hardware-connectivity-core.execution.jsonl`, task-7.
  Ignored evidence paths above are local planning context, not required distributable documentation.

## Superseded by

`None`
