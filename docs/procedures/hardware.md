# Hardware and connectivity procedure

Story 4.4 delivers the hardware core through configure. Provider choices were approved after supervised T14s
exploration on 2026-11-03. This is not a hardware qualification claim: the T14s is recognized and unqualified
under [ADR 0023](../adr/0023-recognized-unqualified-targets-and-target-hibernate-mode.md), and the Framework
Laptop 13 Pro remains the sole MVP laptop target, with physical validation pending.

## Ownership and activation

The explicit [step order](../../capabilities/configure-steps) places `system/audio`, `system/bluetooth`,
`system/power`, `system/network` and `system/vpn` before the Hyprland provider. See the [configure procedure](configure.md) for
prerequisites, both contexts, tracked-file conflicts, normalized outcomes and evidence. Running postconditions
check effective system state; target postconditions check installed files and enabled units without activation.
A successful configure is not proof of hardware usability.

- [Audio sources](../../capabilities/system/audio/sources.md): PipeWire, WirePlumber, pipewire-pulse,
  pipewire-alsa and playerctl; owned volume/media commands. User audio units are enabled under `default.target`,
  never started by configure. The approved user WirePlumber rule prefers A2DP on reconnect without removing
  microphone profile autoswitch. A user-owned drop-in is preserved.
- [Bluetooth sources](../../capabilities/system/bluetooth/sources.md): BlueZ and bluetoothctl. Configure enables
  bluetooth.service and starts it only if inactive. With no `/sys/class/bluetooth`, it instead reports unavailable
  and leaves the service enabled, matching BlueZ's hardware condition. A present subsystem requires active service.
- [Power sources](../../capabilities/system/power/sources.md): UPower, brightnessctl, power-profiles-daemon and
  libnotify. PPD is enabled and started only if inactive; profile switching uses D-Bus, not powerprofilesctl's
  optional Python dependency. The tracked logind drop-in owns only `HandlePowerKey=ignore`, with a reload only
  after the drop-in changes in the current step. Logind is never restarted. Existing hypridle/hyprlock continue
  to own lock-before-sleep. The user power watcher is enabled for `graphical-session.target`, never started by
  configure, and begins at the next graphical login.
- [Network sources](../../capabilities/system/network/sources.md): generic NetworkManager/systemd-resolved
  backend and stub integration under [ADR 0024](../adr/0024-networkmanager-resolved-dns-integration.md).
  Profiles and public DNS choices are preserved; VPN DNS/domains arrive dynamically. See migration below.
- [VPN sources](../../capabilities/system/vpn/sources.md): networkmanager-openconnect, including OpenConnect;
  configure checks plugin registration offline, without creating a profile or authenticating.
- [Hyprland provenance](../../capabilities/desktop/compositor/providers/hyprland/UPSTREAM.md): hardware bindings
  call only owned commands under `/usr/share/mirroros/hardware/`. The display helper is compositor-local and
  changes runtime rules only, never persistent monitor files.

Configure never starts, restarts or reloads the shell, hypridle or desktop. Review configure evidence before
re-login or reboot; do not restart a graphical session remotely without the maintainer's explicit authorization.
Panels, graphical VPN access, audio output/source switching and a possible shell media service belong to later
plan 02-26 with its ADR amending ADR 0012; this plan adds no QML or shell service.

## Validation matrix

Each row has three environment-result columns. `Pending` means not performed, not passed. Exploration validates
individual mechanisms, not the delivered candidate. Clean VM acceptance (plan 02-25 Task 6) and supervised T14s
acceptance (Task 7) are still pending. No capability below is claimed qualified.

Exploration date E1 is 2026-11-03: host base commit `03233ed55a190a78d129bd2f28ca9e49da979271`; installed ISO
commit reported as `ee07c83`, not independently reverified during exploration. E2 is the supervised seat-session
brightness check on 2026-11-04, same host base plus uncommitted Task 2/3 changes; no candidate configure was run.
These source identities must not be substituted for a future clean acceptance commit.

| Capability | Reference VM | T14s exploratory result (date and source above) | Framework Laptop 13 Pro |
|---|---|---|---|
| Audio output, mute and microphone | 2026-11-05, `a4313ad`: dummy output incorrectly reported as 100%. Authorized two-QML development delivery reports no audio output without a level; maintainer confirmed bar tooltip and audio/brightness OSD visually. Clean fixed-candidate acceptance pending | E1: wpctl volume cap/mute/mic mechanisms exercised; delivered bindings/OSD pending Task 7 | pending target-laptop validation |
| Bluetooth and A2DP/HFP | Pending Task 6; absent subsystem must not fail configure | E1: pairing/reconnection and profiles exercised; HFP reconnect defect corrected by temporary A2DP rule, then reverted; delivered rule pending Task 7 | pending target-laptop validation |
| Display brightness | Pending Task 6; report unavailable without backlight | E1: SSH write denied; E2: seat-session brightnessctl 65535 → 62258 → 65535 restored; bindings pending Task 7 | pending target-laptop validation |
| Media keys and MPRIS | Pending Task 6; no player must report unavailable | E1: no MPRIS player, no physical media keys; not exercised; pending Task 7 | pending target-laptop validation |
| Battery status | Pending Task 6; no battery must report unavailable | E1: UPower charge/source data and AC transition observed; delivered watcher pending Task 7 | pending target-laptop validation |
| Low-battery warning | Pending Task 6; no fabricated charge | E1: not exercised (battery near full); source tests do not prove notification delivery; pending Task 7 | pending target-laptop validation |
| Power key | Pending Task 6; inspect effective logind property | E1: baseline HandlePowerKey=poweroff confirmed by property, not key press; corrected delivered behavior pending Task 7 | pending target-laptop validation |
| Lid lock timing and clamshell | Pending Task 6; source checks only without lid/monitor | E1: lock screen only on resume; docked lid did not suspend; runtime display mechanisms exercised; delivered clamshell pending Task 7 | pending target-laptop validation |
| Display layout and scale | Pending Task 6; helper/source checks, not physical clamshell | E1: disable/restore/mirror mechanisms exercised; all delivered chords and scale pending Task 7 | pending target-laptop validation |
| Suspend and resume | Pending Task 6 | E1: one supervised lid s2idle cycle passed; full session-menu acceptance pending Task 7 | pending target-laptop validation |
| Hibernate and resume | Pending Task 6 | E1: one shutdown-mode same-boot resume; mt7921e restore -110 persists; session-menu acceptance pending Task 7 | pending target-laptop validation |
| Wi-Fi | Pending Task 6; do not infer Wi-Fi from wired networking | E1: on/off power-save latency compared; hibernate Wi-Fi recovery about 3 s with -110; delivered daily-use check pending Task 7 | pending target-laptop validation |
| Corporate VPN | Pending Task 6; plugin only, no corporate connection | E1: terminal authentication handoff connected, NM retained DNS; auth-dialog path failed; repeat acceptance pending Task 7 | pending target-laptop validation |
| Automatic power profiles | Pending Task 6; check exposed profiles/effective service | E1: platform_profile, three profiles, unprivileged D-Bus switch from active seat; automatic watcher acceptance pending Task 7 | pending target-laptop validation |
| Per-domain DNS integration | Updated-candidate clean target/boot/running acceptance pending; fixture tests do not validate real mount namespaces | 2026-11-06, clean `f075cf1` plus external prototype: dynamic VPN scope, public/private lookups, disconnect/reconnect and bounded positive/NXDOMAIN observations; product migration, reboot persistence and transport-timeout isolation pending | pending target-laptop validation |

Selected evidence is local and ignored: `evidence/hardware/exploration-20261103T200419Z/REPORT.md` and
`evidence/hardware/task-3/verification.md`. Task 2–4 source/contract test results are recorded in the local plan
execution log; mocked tests do not establish clean installation or physical acceptance. Future acceptance records
must identify date, clean candidate commit, execution context and limitations for every row.

## Keyboard and terminal action paths

Open a terminal with `SUPER+Return`. Wi-Fi and Bluetooth terminal paths are permanent recovery interfaces,
not temporary replacements for later panels. No impala, iwd, bluetui or wiremix is added.

| Action | Keyboard path | Owned terminal command |
|---|---|---|
| Volume ±5 / ±1 | Volume keys / ALT+volume keys | `volume raise`, `volume lower`, `volume +1`, `volume -1` |
| Output mute / microphone mute | XF86AudioMute / XF86AudioMicMute | `volume mute-toggle`, `volume mic-mute` |
| Brightness ±5% / ±1% | Brightness keys / ALT+brightness keys | `brightness +5%`, `brightness 5%-`, `brightness +1%`, `brightness 1%-` |
| Brightness max / min | SHIFT+brightness up / down | `brightness max`, `brightness min` |
| Media play-pause | XF86AudioPlay or XF86AudioPause | `media play-pause` |
| Media next / previous | XF86AudioNext / XF86AudioPrev; ALT+play / ALT+SHIFT+play | `media next`, `media previous` |
| Toggle internal display | SUPER+CTRL+Delete | `display laptop` |
| Toggle mirror | SUPER+CTRL+ALT+Delete | `display mirror` |
| Scale up / down | SUPER+/ / SUPER+ALT+/ | `display scale up`, `display scale down` |
| Session and power actions | XF86PowerOff or SUPER+Escape, then session-menu keyboard navigation | Existing session menu; confirmation remains required |

Commands in the table require the prefix `/usr/share/mirroros/hardware/`; they are not installed on PATH.
Hardware keys remain available while locked, with repetition on volume and incremental brightness. Volume never
exceeds 100%; OSD requests read measured volume/brightness or report unavailable. Mic mute uses a fixed message,
never a level. An OSD failure does not roll back a successful provider action and is reported separately.
Invalid arguments are rejected before provider effects; unavailable hardware/player is not a fabricated value.

`display laptop` toggles the internal panel only when another usable display exists; with the external display
remaining active this selects external-only or restores the laptop alongside it. `display mirror` toggles
mirroring. For laptop-only, disconnect the external display or use the existing personal native monitor layer;
these helpers do not introduce a persistent layout editor. Lid close with an external monitor disables only the
internal panel; lid open restores it explicitly. Without an external monitor, logind's suspend behavior remains.
Runtime layout/scale changes disappear on configuration reload or a new session and never rewrite `monitors.lua`
or `personal-monitors.lua`. Untrusted connector names are rejected before mutation.

Power-profile changes are occasional terminal actions, not reserved frequent-action bindings:

```bash
/usr/share/mirroros/hardware/power-profile set autodetect
/usr/share/mirroros/hardware/power-profile set ac balanced
/usr/share/mirroros/hardware/power-profile set battery power-saver
```

Explicit choices are remembered in `$XDG_STATE_HOME/mirroros/power-profiles/{ac,battery}` (default state root:
`~/.local/state`). Available profiles are validated; an unavailable remembered choice is reported rather than
silently rewritten. Defaults are performance on AC when available, otherwise balanced, and balanced on battery.
The watcher reapplies on power-source changes and sends one critical 30-second notification per discharging
battery episode at or below 10%, rearming after leaving that state. Do not discharge the laptop unsupervised to
prove this behavior. Keyboard-backlight keys are not bound: the T14s handles Fn+Space in firmware.

## Permanent connectivity fallback

Use `nmtui` interactively for Wi-Fi, or `nmcli --ask device wifi connect` with the selected network supplied in a
private interactive workflow. Enter credentials only at protected prompts; never supply a PSK as an argument.
Do not export SSID lists, device addresses or connection dumps to evidence. NetworkManager remains the owner;
no alternate Wi-Fi daemon is introduced.

For Bluetooth, use one private `bluetoothctl` session: `power on`, `agent on`, `default-agent`, `pairable on`,
then `scan on`. Select the device locally, stop scanning, and use `pair`, `trust` and `connect` with its locally
observed address. Confirm any device-side request, verify bonding and reconnect, then `pairable off` when done.
Do not copy device addresses, PINs, passkeys or pairing keys to logs or source. PIN/passkey UX beyond this
terminal path belongs to plan 02-26. Audio reconnect should select A2DP; microphone capture may switch to HFP.

## DNS integration and migration

[ADR 0024](../adr/0024-networkmanager-resolved-dns-integration.md) selects NetworkManager as the DNS-policy
authority and systemd-resolved as the per-link resolver, through `/run/systemd/resolve/stub-resolv.conf`.
No DNS provider is imposed: existing DHCP/RA and manual profile choices remain. VPN servers and domains are
received dynamically, not written into source or copied into a manual forwarding list.

Before a running migration, save work, ensure independent recovery access and explicitly approve a safe network
window. An active VPN/tunnel blocks a required transition; configure never disconnects it automatically.
An already-converged integration needs no migration, reload or new backup, even with an active VPN.

The mechanism accepts an absent target resolver or the exact live-medium regular-file copy; an arbitrary target
resolver requires private review. In running context, a legacy regular file's DNS servers and search domains must
match the current NetworkManager-provided values. Other options or an unrepresented manual policy require a
separately reviewed migration; do not remove them just to pass configure. Foreign links, conflicting backend/global
rules, an unavailable/masked resolver, unsafe parents, hardlinks or immutable/append-only files are rejected.
The exact retained prototype backend/stub may be adopted without rewriting profile DNS choices.

Recovery snapshots and operation diagnostics are root-private under `/var/lib/mirroros/configure/network-dns/`:
`current/` retains before/after files, service baseline, context and phase; prior attempts remain in private
`recovery.*` directories. Never copy these into evidence or Git. Normal failures attempt guarded restoration of
files, enablement and activity and report its outcome. A later run detects an interrupted applying transaction,
restores only recognised before/after states in the same context and stops for review before retrying. Subsequent
local edits, an incomplete snapshot or incomplete recovery require private inspection with rescue access;
do not delete phase markers or force restoration over edits. Retain recovery material until acceptance and a
separately approved cleanup. A Snapper snapshot/home backup remains independent protection.

Running postconditions inspect NM D-Bus mode, enabled/active resolved and absence of global index-0 DNS/domain
entries, then make a 15-second public `example.com` lookup. Operation limits are 30 seconds; missing connectivity
is not a passed lookup or a ready step. Target postconditions inspect declarations only. For subsequent target
commands, a private mount namespace supplies transient live-medium resolver input under a namespace-only `/run`
and uses `arch-chroot -r`; no host resolver file or mount is changed. Targets under `/run` are rejected, and live
unshare/mount/lsattr support is required. Real first boot and namespace behavior remain candidate-VM validation,
not a conclusion from doubles.

Privately verify VPN suffix scope, no unexpected root routing/default DNS route and unrelated public lookups on
the normal link. Search suffixes also route DNS; no conversion to a hard-coded route-only list is required.
A VPN pushing broader/missing/conflicting scope needs private review, not automatic profile rewriting.
There is no disconnected-name blocker: private names can reach the normal resolver while disconnected.
Application DoH/bypass is outside enforcement. Bounded positive/NXDOMAIN evidence is not transport-timeout or
universal no-leak evidence; timeout isolation and reboot persistence remain pending.

## Private corporate VPN procedure

The approved provider remains the NetworkManager OpenConnect plugin. Exploration found that username,
password and OTP authentication worked through terminal OpenConnect, but `nmcli --ask connection up` alone
failed without a working graphical secret agent. Do not describe the auth dialog as validated under Hyprland.
An owned connect wrapper and graphical access are deferred to plan 02-26.

Perform this workflow locally in an unrecorded terminal, as the graphical user, never through configure or a
captured SSH session. Disable shell tracing and terminal recording. Do not paste real values into command
history, agent chat or evidence. All editor steps below require a private editor with swap, backups, recovery
files and persistent history disabled; if that cannot be guaranteed, stop rather than writing private data to disk.

1. Create a private local VPN profile through interactive `nmcli connection edit type vpn vpn-type openconnect`.
   In the editor, choose a local connection name and the private gateway including its tunnel-group path.
   Set the plugin service to `org.freedesktop.NetworkManager.openconnect` and `vpn.data` entries
   `cookie-flags=2`, `gwcert-flags=2`, `gateway-flags=2`, `resolve-flags=2` (not saved). Preserve the site's
   reviewed route policy; never put credentials in profile properties. Save the profile privately on the machine,
   not in the repository. Use normal certificate verification; do not bypass trust errors.
2. In a fresh Bash subshell with `umask 077`, require `$XDG_RUNTIME_DIR` to be the current user's private runtime
   directory on tmpfs. Create a unique directory there with `mktemp -d`. Register EXIT/HUP/INT/TERM cleanup of
   that exact directory. Keep all subsequent temporary files there, mode 0600; do not use `/tmp` or the checkout.
3. Privately create an OpenConnect config file with a `server` entry containing the gateway/group. Run
   `openconnect --protocol=anyconnect --authenticate --config <private-config-path>`, redirecting stdout to a
   protected runtime file. Credentials and OTP are entered at its terminal prompts, never argv or environment.
   This is authentication only: no root, tunnel or vpnc-script. Do not enable verbose output or retain diagnostics.
4. Read the authentication result only in the private editor. Treat it as data, **never source it or use eval**.
   Populate a separate protected passwd-file with `vpn.secrets.cookie` from `COOKIE`, `vpn.secrets.gwcert` from
   `FINGERPRINT`, `vpn.secrets.gateway` from `HOST`, and `vpn.secrets.resolve` from `RESOLVE`, in nmcli's
   `key:value` line format. Remove the shell-assignment quoting, reject embedded newlines and stop if required
   fields are missing. Do not guess a mapping when upstream output differs; revalidate the handoff privately.
5. Activate the local profile with `nmcli connection up <local-profile-name> passwd-file <private-passwd-path>`.
   Only non-secret local names and file paths appear in argv. Immediately remove the auth config, auth result
   and passwd-file and leave the subshell to clean up. Cleanup must also occur after failed authentication,
   cancellation or activation failure; disconnect an unintended partial connection. Never store a cookie in
   `vpn.secrets`, use `--show-secrets`, or export a profile. A host crash cannot be handled by a trap; runtime
   tmpfs is cleared on reboot.
6. Privately verify tunnel reachability, expected split routes and DNS ownership, recording only pass/fail and
   sanitized reasons. NetworkManager must remain the single route/DNS-policy owner, with resolved executing
   its per-link policy. Check the scope and limitations above; successful resource access alone does not prove
   DNS routing. Do not run standalone OpenConnect
   as a tunnel or introduce another DNS writer. Disconnect through NetworkManager when finished.

The gateway, certificate/fingerprint, authentication result, resolved addresses and credentials are all private.
Do not retain any of them as evidence, even when a value is not itself a password. Exploration established the
handoff once; future real connection acceptance remains supervised and must recheck that no secrets were saved.

## Evidence-driven tuning decisions

The exploration gate approved only the A2DP reconnect preference, with Omarchy 4.0.6 (MIT) provenance and notice
in the audio step. Profile-memory behavior and hardware chords also cite Omarchy 4.0.6 in their governing sources.
No upstream copy belongs under vendor/archiso-releng.

- `wifi.powersave`: disabling it reduced exploratory idle RTT from about 21 to 5 ms, but did not remove the
  mt7921e hibernate restore error. TODO-005 was explicitly deferred: evidence only, no global NetworkManager
  setting, policy/profile change or delivery route adopted. Global policy awaits Framework battery evidence;
  a new T14s-specific delivery mechanism needs separate governance outside this plan.
- No ASUS keyboard-backlight hook: irrelevant hardware and no delivered keyboard-backlight keysym.
- No global USB autosuspend change and no targeted btusb setting: no supporting peripheral symptom was observed.
- Lock timing passed exploration, so no `InhibitDelayMaxSec` or immediate lid-close lock was added. Any later
  failure requires maintainer review before crossing the plan's lock boundary.

## Supervised delivery, diagnostics and rollback

Before touching an installed T14s, obtain approval for consequential operations, take a Snapper root snapshot
on a Snapper-managed installation, and back up the user configuration/state that will be touched separately.
A root snapshot does not replace a home backup. Keep both private and record only non-sensitive identifiers.
Do not assume exploration snapshot numbers exist on another machine.

Transfer a checksummed Git bundle of a clean candidate over SSH, verify it, and extract it into the candidate
checkout. Record its commit. Run `sudo operations/configure` there, not `/usr/local/bin/mirroros-configure`,
which is pinned to the installed ISO's code snapshot. No agent is installed on the T14s or reference VM.
After the maintainer-approved re-login/reboot, perform the physical checks and a second no-change configure run.
Clean VM installation must independently exercise installer target context and installed running context.

Useful local diagnostics (inspect privately; do not export raw device/profile/journal dumps):

- Configure's named failed step, outcome and `/var/log/mirroros/configure/<run-id>/configure-run.tsv` and log.
  A later step marked `not_run` is not ready. Tracked-file conflicts require preserving the edited file before
  deliberately restoring the owned destination and rerunning.
- `systemctl status bluetooth.service power-profiles-daemon.service`; user status for pipewire, pipewire-pulse,
  wireplumber and mirroros-power-watch; `wpctl status` for audio. User services require a user session.
- `busctl --system get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey`
  must report `ignore` after running configure; inspect administrator overrides if it does not. Never restart logind.
- UPower battery properties, `/sys/class/backlight`, and PPD's `Profiles`/`ActiveProfile` properties; test writes
  from the active graphical seat, not a plain SSH session. The exploration SSH brightness/polkit denial was not
  evidence of a failed seat-session provider.
- Hyprland binding registry/help and local monitor state; pass only `XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY` and
  `HYPRLAND_INSTANCE_SIGNATURE` from the actual session for authorized graphical commands. Do not dump the
  session environment. Do not issue a compositor reload as an incidental diagnostic.
- After a supervised suspend/hibernate, reconnect and privately inspect the boot journal for lock-before-sleep,
  same-boot resume and mt7921e errors. Reconnection alone does not establish resume correctness or a safe lock.
- VPN plugin registration and offline recognition can be checked without a corporate profile; actual
  authentication, DNS and route acceptance must not enter configure logs.

If rollback is needed, stop applying changes and preserve sanitized failure evidence. From independent rescue
media or a known-good boot/snapshot entry, inspect the pre-change Snapper snapshot and follow the installation's
native Btrfs/Limine recovery procedure; select the verified pre-change root only after explicit confirmation.
For non-Snapper storage, use the external backup/rescue path instead of assuming snapshot rollback is available.
Restore the separately backed-up user files as that user after reviewing exactly what will be overwritten.
Review package/file/unit state and reboot or re-login under supervision; never restart logind to recover a session.
Do not delete paired devices, private VPN profiles or personal configuration as an automatic recovery action.

Raw evidence remains in ignored `evidence/`, including VM results under `evidence/reference-vm/`. Retain only
allowlisted summaries with date, commit and result. Redact SSIDs, MACs, VPN servers, certificates, credentials,
serials and internal addresses before collection; scan selected evidence with Gitleaks on the host. Do not commit
generated output. T14s-specific findings belong in its [target notes](../../targets/thinkpad-t14s-gen1-amd/README.md)
and local TODO-582784b9 without resolving the open Wi-Fi/fingerprint findings or changing the todo's existing
closed status. Final matrix updates belong to plan 02-25 Task 8 after the two acceptance checkpoints.
