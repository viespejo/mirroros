# Network DNS sources and responsibility

Governed by accepted [ADR 0024](../../../docs/adr/0024-networkmanager-resolved-dns-integration.md).
The installer remains authoritative for base NetworkManager installation and enablement. This step declares
its existing NetworkManager/systemd prerequisites explicitly for independent configure convergence, not a second
connection manager or installer policy. Official Arch packages, with versions recorded per configure run:

| Package | Repository | Responsibility / upstream |
|---|---|---|
| systemd | core | systemd-resolved, busctl and native systemd configuration; https://systemd.io/ |
| networkmanager | extra | Connection/DNS-policy authority, nmcli and supported configuration/DNS reload; https://networkmanager.dev/ |
| jq | extra | Validate structured resolved D-Bus property responses without logging private values; https://jqlang.org/ |
| e2fsprogs | core | lsattr preflight rejects immutable/append-only regular resolver files; https://e2fsprogs.sourceforge.net/ |
| iw | core | Current Wi-Fi link (SSID, frequency, signal, bitrate) for the network panel commands; https://wireless.wiki.kernel.org/en/users/documentation/iw |

The live medium additionally needs its existing arch-install-scripts, util-linux (unshare/mount) and lsattr.
No package version pin, AUR source, public DNS provider, private profile, corporate value or credential is delivered.

## Owned state and mechanism

- `20-mirroros-dns.conf` is tracked under `/etc/NetworkManager/conf.d/`; it selects only the resolver backend and
  unmanaged rc-manager. `/etc/resolv.conf` points to the resolved stub. No profile is edited.
- `capabilities/lib/network.sh` owns context dispatch, conflict checks, a private migration snapshot and bounded
  activation/recovery. Running checks read effective NM D-Bus mode and resolved global scope, then perform a
  bounded public lookup; target checks inspect declared integration only.
- `capabilities/lib/target-exec` is invoked by cfg_exec for the exact absolute stub link. It runs unshare with
  private mount propagation, recursively binds the target to the namespace-only /mnt (the installer target lives
  under /run/mirroros/target), creates a namespace-only tmpfs /run with resolver input from fd 3, closes that fd,
  then invokes arch-chroot -r /mnt. arch-chroot binds /run non-recursively, so the whole /run is replaced. The
  command retains argv/stdin/status. No real host resolver file is created, replaced or used as a mount target.
- Root-private migration material is under `/var/lib/mirroros/configure/network-dns/`, never configure evidence.
  A converged rerun checks state without new backups or activation. An incomplete transaction cannot pass as
  converged; recovery rejects subsequent local edits and cross-context restoration.

Upstream API/behavior references (reviewed 2026-11-06):

- https://networkmanager.dev/docs/api/latest/NetworkManager.conf.html
- https://networkmanager.dev/docs/api/latest/gdbus-org.freedesktop.NetworkManager.DnsManager.html
- https://www.freedesktop.org/software/systemd/man/latest/org.freedesktop.resolve1.html
- https://www.freedesktop.org/software/systemd/man/latest/systemd-resolved.service.html
- https://gitlab.archlinux.org/archlinux/arch-install-scripts/-/blob/master/arch-chroot.in
- https://man.archlinux.org/man/mount.8.en

Manager DNS/Domain arrays include per-link entries; interface index 0 denotes global policy. Checks allow normal
and VPN link data, not only empty arrays. Raw property values and query diagnostics are not emitted to evidence.
Mutation diagnostics stay in private recovery storage; the public log records only phases and child statuses.

## Evidence and limits

The exploratory T14s prototype on 2026-11-06 selected dynamic VPN-pushed DNS/domains, not a manual private list.
Positive/private and public lookups, disconnect/reconnect cleanup and bounded positive/NXDOMAIN observations
support the decision; transport timeout isolation and reboot persistence remain untested. Ignored evidence and
its commit identities are described in ADR 0024 and the plan execution log. Candidate VM acceptance predates
this integration. Framework validation remains pending.

Omarchy 4.0.6 (MIT) informed the backend/stub pattern only; no literal script or third-party code fragment is
copied. In particular its provider-switching/global override logic is not delivered. The namespace adapter and
migration are MirrorOS-owned logic around upstream commands, not a modification of vendor arch-install-scripts.

## Network panel commands

Plan 02-28 delivers three commands for the shell network panel ([ADR 0025](../../../docs/adr/0025-shell-panels.md),
[ADR 0028](../../../docs/adr/0028-network-panel-internet-latency-probe.md)) to `/usr/share/mirroros/hardware/` (0755),
with the Omarchy MIT license copy `OMARCHY-LICENSE` at `/usr/share/mirroros/hardware/licenses/omarchy-network`. They
run as the session user, only at runtime and on panel action; configure never runs them and edits no profile. The
statement above about Omarchy 4.0.6 concerns the DNS backend and still holds.

| File | Status | Origin | MirrorOS divergences |
|---|---|---|---|
| `network-status` | Adapted | Omarchy `v4.5.0:bin/omarchy-network-status` | `command -v` instead of `omarchy-cmd-present`; `LC_ALL=C nmcli -e no -g` reads; `--verbose` adds the active Wi-Fi/Ethernet profile on the default-route interface (`uuid`, `connection`, `connection_type`); ping timeout 2 s (ADR 0028), single `INTERNET_PROBE=1.1.1.1` constant; sysfs root overridable for tests |
| `network-band` | Adapted | Omarchy `v4.5.0:bin/omarchy-network-band` | `get <device>` and `set <device> <uuid> <band>` instead of the first connected Wi-Fi device; stale device-UUID pair refused; `nmcli --wait 30` activation with the existing revert; `uuid` in `get` output; no output without `iw`; distinct exit codes |
| `network-dns` | Adapted | Omarchy `v4.5.0:bin/omarchy-dns` | `get <uuid>` and `set <uuid> <provider>` on one active Wi-Fi or Ethernet profile only, reapplying only its device; inactive or other-type UUIDs refused; no `[global-dns]`, `resolved.conf`, sudo/pkexec or reloads; DNS over TLS per connection with the v4.5.0 values; Custom names the profile and changes nothing on empty input; distinct exit codes |

The DNS presets (DHCP, Cloudflare, Google, Custom) keep the exact v4.5.0 server values and are applied only to the
profile the user confirms in the panel; DHCP remains the untouched default, so no public DNS provider is imposed
(ADR 0024). Exit codes are documented in each command's usage header.
