# Story 4.4 Hardware and Connectivity Planning — Consolidated Plan

## Validation environments

Story 4.4 uses three environments with distinct roles. The ThinkPad T14s, reached over SSH and running MirrorOS from the latest built ISO, is where hardware providers are explored and where audio, Bluetooth, brightness, media keys, battery, lid, suspend/hibernate and Wi-Fi are exercised in daily use; user configuration touched there is backed up first. Because ADR 0023 keeps the T14s a recognized unqualified profile, its results are exploratory, non-qualifying evidence, and every hardware capability remains "pending target-laptop validation" for the Framework Laptop 13 Pro, the sole qualified laptop. The open `mt7921e` Wi-Fi resume finding in `TODO-582784b9` remains a known T14s limitation. [DEC-001]

A clean reference VM provides the reproducible acceptance demanded by the Epic 4 common contract: clean installation plus `configure` without manual steps, a rerun without unnecessary mutation, and both execution contexts. Since the VM lacks most of the hardware, slice postconditions must report absent hardware as unavailable rather than failing or claiming the capability works. [DEC-001]

The laboratory guest (`~/qemu/mirroros-lab`) is optional and reserved for iterating the bar panels without risking the T14s session; otherwise it is not used. [DEC-001]

## Test orchestration

The host agent drives every test over SSH on the T14s and the reference VM, and no agent is installed inside them, so the maintainer's credentials and personal data on the T14s stay outside any agent's direct reach. Tests that need a physical action follow a supervised script: the agent asks for the action (closing the lid, pressing a media key, pairing a device, listening, unplugging the charger), the maintainer performs it, and the agent verifies and collects evidence. Because suspend and hibernate interrupt the SSH session, the agent reconnects afterwards and reads the boot journal. Graphical-session checks run over SSH by inheriting the session environment (`XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY`, `HYPRLAND_INSTANCE_SIGNATURE`). [DEC-002]

If bar-panel iteration is needed in the laboratory and proves slow from the host, a guest agent may be used there under the Story 4.3 protocol: a recoverable snapshot first, a checksummed Git bundle handoff, and host review before integration. [DEC-002]

## Plan split

Story 4.4 is delivered in two plans. Plan 02-25 covers the hardware core: it selects the audio, Bluetooth and brightness/battery/lid/suspend providers, applies them through `configure` with postconditions, binds the volume, brightness and media keys, provides Wi-Fi and Bluetooth through the terminal fallback path [DEC-006], and validates in the reference VM and through supervised T14s use. Because the story accepts connection "through the shell or a terminal interface", this plan alone satisfies Story 4.4. [DEC-003]

Plan 02-25 starts with a T14s exploration phase that ends in a maintainer approval gate: providers are proposed, approved, and only then implemented. No separate prototype plan is needed, as in Story 4.3, because the candidates are standard and the risk lies in hardware behaviour rather than design. [DEC-003]

The Omarchy-style bar panels deferred by Story 4.3 DEC-016 (audio, network, Bluetooth, display, power) move to a later plan 02-26, which carries the ADR amending ADR 0012 and depends on 02-25. They are an enhancement with their own governance and do not block the hardware core. [DEC-003]

## Candidate providers

The T14s exploration starts from a baseline consistent with the integration the Story 4.3 shell already consumes, and deviates only when the T14s demonstrates a real problem. Audio uses PipeWire with WirePlumber, `pipewire-pulse` and `pipewire-alsa`, with volume driven through `wpctl`. Bluetooth uses BlueZ (`bluez`, `bluez-utils`) with `bluetooth.service`. Battery status comes from UPower, brightness from `brightnessctl` writing through logind, and media control from `playerctl` over MPRIS. Lid and suspend keep the `systemd-logind` defaults, with a drop-in added only if the T14s requires one. Networking stays on NetworkManager, fixed by the installation policy. [DEC-004]

Media keys in plan 02-25 call `playerctl` with Quattro's keys and modifiers. This deliberately deviates from Quattro, which retired `playerctl` for a shell media service, because adding a shell service exceeds the ADR 0012 boundary; plan 02-26 decides under its ADR whether to adopt that service, move the keys to it, and keep `playerctl` as a CLI fallback. [DEC-008, TODO-003]

Power profiles are provided by `power-profiles-daemon`, the provider the maintainer has run successfully under Omarchy on the T14s. Because they add a capability, they enter `docs/mvp-scope.md` as a scope change in a commit citing Story 4.4's "power behavior"; the other providers are reviewed updates that close the open rows. TLP is excluded so that power policy has a single owner. Exploration records which mechanism `power-profiles-daemon` uses on the T14s (`platform_profile` and/or `amd-pstate`), since the Omarchy experience is not proof under MirrorOS, and all results remain non-qualifying evidence. [DEC-004, DEC-001]

Profile switching is not a frequent action: it is occasional, and a binding would consume space in the Omarchy-first key table. Plan 02-25 offers it from a terminal through the owned `power-profile` command, which replaced `powerprofilesctl` as the terminal path (still available for diagnostics) [DEC-014], with a postcondition that the daemon is active and exposes profiles; graphical access arrives with the plan 02-26 power panel, with no interim shell menu entry. Daily use may still promote it to a frequent action through a reviewed update before Story 4.8 completes. [DEC-005, TODO-001]

## Corporate VPN

The maintainer's daily Cisco AnyConnect VPN, reached through OpenConnect, enters plan 02-25 as a `docs/mvp-scope.md` scope change citing Story 4.4 and daily use. It is provided by `networkmanager-openconnect` with `openconnect` from `extra`, so NetworkManager remains the single owner of routes and DNS, users activate the VPN without `sudo`, and the WebKit-based `nm-openconnect-auth-dialog` can complete Cisco SAML/SSO; its `gtk3` and `webkit2gtk-4.1` dependencies are accepted because `configure`, not the ISO, installs them. Standalone `openconnect` is rejected because its `vpnc-script` would change DNS behind NetworkManager. [DEC-007]

The postcondition checks only that the plugin is installed and recognised by NetworkManager. Corporate profiles, servers, certificates and credentials never reach the repository or evidence; the profile is created at runtime through a documented procedure. A supervised real connection on the T14s validates the VPN as non-qualifying evidence, while the reference VM checks the plugin alone. Exploration must confirm the company's authentication method and that the auth dialog completes it under Hyprland; a failure reopens the provider choice. Graphical VPN access, which the Quattro panels do not offer, is left to plan 02-26. [DEC-007, DEC-001, TODO-004]

## Hardware key bindings

Plan 02-25 binds the hardware keys through the existing `MirrorOSKeys.bind` registry, reusing the chords and options of Quattro's `media.lua` (`locked = true`, and `repeating` where Quattro repeats). Volume moves by 5 or, with ALT, by 1 and mutes through `wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ …`, capped at 100%; the microphone mutes; brightness moves by 5% or 1% and jumps to maximum or minimum with SHIFT through `brightnessctl`; and media next, previous and play-pause go through `playerctl`. After each volume or brightness change, the binding calls `osd showSource …`, so the OSD displays the measured value rather than a fabricated one. Mic mute is reported through `osd show` with a fixed message and no level, so no new OSD source is added. [DEC-009, DEC-008]

Keyboard-backlight keys are bound only if T14s exploration shows `XF86KbdBrightness*` reaching Hyprland, since ThinkPads often handle the backlight in firmware. Audio output and source switching move to plan 02-26 with the audio panel, and touchpad toggle and eject fall outside the hardware slice; their chords are recorded as reserved in `UPSTREAM.md`. [DEC-009]

## Lid and power-key policy

Story 4.3 binds `XF86PowerOff` to the system menu, but with no logind drop-in the default `HandlePowerKey=poweroff` probably powers the machine off as well. Plan 02-25 therefore delivers a MirrorOS-owned logind drop-in with `HandlePowerKey=ignore`, as Quattro does, after recording the current T14s behaviour as defect evidence; the firmware long-press hard off is unaffected. In the running context a postcondition reads the effective value from logind through `busctl`; in the target context it checks the delivered drop-in. [DEC-010, DEC-012]

Closing the lid without an external monitor keeps logind's default suspend, and locking continues through `hypridle`'s `before_sleep_cmd`. T14s exploration measures whether the session is locked before suspend, so that no content is visible on resume. Quattro's raised `InhibitDelayMaxSec` and immediate lid-close lock are added only if that measurement fails, never pre-emptively. Logind drop-ins take effect through `systemctl reload systemd-logind`, because a restart would end the session; in the installer context the file is only written. [DEC-010]

## Display layout and clamshell

The frequent action "Switch the monitor layout between external, mirrored, and laptop only" had no owner, and Story 4.3 had already assigned monitor scaling to Story 4.4. Plan 02-25 takes both, because clamshell behaviour is part of the story's lid criterion. Bindings reuse Quattro's chords: SUPER+CTRL+Delete toggles the laptop display, SUPER+CTRL+ALT+Delete toggles mirroring, and SUPER+/ and SUPER+ALT+/ change scaling. The ownership is recorded in `docs/mvp-scope.md` as a reviewed update. [DEC-011]

The logic lives in owned Bash helpers over `hyprctl` that validate connector names, as Quattro does. Changes are runtime-only: they never rewrite `monitors.lua` or `personal-monitors.lua` and disappear on reload or reboot, so they do not compete with Story 4.3's managed monitor configuration. Clamshell is automatic: closing the lid with an external monitor connected disables the internal display and opening it re-enables it, while without an external monitor the lid suspends as in DEC-010. Quattro's monitor panel moves to plan 02-26. Validation uses the maintainer's external monitor on the T14s; the reference VM covers sources and tests only. [DEC-011, DEC-010]

## Source organisation

Each `docs/mvp-scope.md` row becomes one configure step under `capabilities/system/`, with its own `apply`, `packages` and `sources.md`. `system/audio` holds PipeWire, WirePlumber, `pipewire-pulse`, `pipewire-alsa` and `playerctl`; `system/bluetooth` holds `bluez` and `bluez-utils` and enables and starts the service; `system/power` holds UPower, `power-profiles-daemon`, `brightnessctl` and the logind drop-in; and `system/vpn` holds `networkmanager-openconnect`. These four steps run before `desktop/compositor/providers/hyprland` in `CFG_STEPS`, so the bindings find their commands installed. [DEC-013]

To satisfy the story's provider-replacement criterion, bindings never call provider tools directly. Owned action commands with a command/sub-action shape, as with Quattro's `omarchy-*`, encapsulate the tool and the OSD call: `/usr/share/mirroros/hardware/volume`, `brightness` and `media`, delivered by their system steps, and `display` (laptop, mirror, scale, clamshell), which is Hyprland-specific and lives under `desktop/compositor/providers/hyprland/`. A new `hardware-bindings.lua`, loaded like `shell-bindings.lua` and covered by the existing duplicate id/chord test, calls only these commands, so replacing a provider touches only its step and command. The commands take argv arguments and validate connector names and values. They adapt Quattro's pattern rather than copying it, and any literal Quattro fragment reused records Omarchy 4.0.6 (MIT) provenance in the governing `UPSTREAM.md`. [DEC-013]

## Automatic power profiles

Plan 02-25 reproduces the Quattro behaviour the maintainer validated on the T14s: one profile remembered for AC and one for battery, applied at login and whenever the machine is plugged in or unplugged. An owned `/usr/share/mirroros/hardware/power-profile set [autodetect|ac|battery] [profile]` follows `omarchy-powerprofiles-set` semantics, storing the choice under `$XDG_STATE_HOME/mirroros/power-profiles/{ac,battery}`, validating availability, and defaulting to `performance` on AC (`balanced` when unavailable) and `balanced` on battery. A user unit applies `autodetect` at login and listens to UPower `OnBattery`; it is enabled, not started, and takes effect at the next login. Quattro triggers the same switch from its shell battery service, which ADR 0012 rules out before plan 02-26, so only the trigger differs; plan 02-26 keeps it outside the shell by default [DEC-015]. Exploration records which profiles the T14s exposes. [DEC-014, DEC-012]

## Hardware tunings

None of Quattro's hardware tunings is adopted pre-emptively. The T14s exploration carries a checklist of the four — NetworkManager `wifi.powersave = 2`, WirePlumber A2DP auto-connect, the keyboard-backlight hibernate hook and global `usbcore autosuspend=-1` — and adopts only what evidence justifies, with Omarchy 4.0.6 (MIT) provenance. Wi-Fi power save is tested on and off for latency and resume, given the open `mt7921e` finding; because networking is installation-delivered, its route (scope change or T14s target-profile adjustment) is decided with that evidence. A2DP auto-connect becomes a user drop-in in `system/audio` only if devices are seen falling back to HFP. The keyboard-backlight hook is ASUS-specific and rejected. [DEC-016, TODO-005]

USB autosuspend is never disabled globally: on the T14s the internal Bluetooth, webcam and fingerprint reader sit on USB, so a global switch would cost idle battery to fix problems that may never appear. If Bluetooth or a peripheral misbehaves, a targeted setting is used instead, either `btusb enable_autosuspend=0` or a per-device udev `power/control=on` rule, recorded with its evidence. [DEC-016]

## T14s delivery and acceptance

During iteration the host agent carries each candidate commit to the T14s as a checksummed Git bundle over SSH, verifies it, extracts it into a working checkout such as `~/code/mirroros-candidate`, and runs `sudo operations/configure` in the running context. The installer's `mirroros-configure` copy is pinned to the ISO commit and is not used. Nothing is published or synchronized automatically, and every run keeps sanitized evidence with the tested commit recorded. Before the first run the touched user configuration is backed up and a Snapper snapshot provides a full rollback point. [DEC-017, DEC-001, DEC-002]

T14s acceptance closes on the installed system: configure, then a reboot or re-login, then a mutation-free second run. No reinstallation from a new ISO is required, because clean reconstruction belongs to the reference VM and the T14s remains non-qualifying; an optional reinstall stays the maintainer's choice. [DEC-017]

## Validation status and evidence

A new `docs/procedures/hardware.md` is the single place where the story's "pending target-laptop validation" criterion is recorded. Its per-capability matrix covers audio, Bluetooth, brightness, media keys, battery and its warning, lid and clamshell, suspend, hibernate, Wi-Fi, VPN and power profiles, with three columns whose meanings differ deliberately: the reference VM shows installation and honest unavailability, the T14s shows real but non-qualifying results with date and commit, and the Framework Laptop 13 Pro, the sole qualified laptop, stays "pending target-laptop validation" until it is available. Nothing is claimed as qualified. The same procedure documents the terminal fallback, the secret-free VPN profile procedure, Snapper rollback and diagnostics. [DEC-018, DEC-006, DEC-007, DEC-017]

Each fact has one home. Raw evidence stays in ignored `evidence/hardware/…`, and only a selected summary with SSIDs, MAC addresses, VPN servers and serials redacted enters the procedure. Provenance lives in each step's `sources.md` and the Hyprland provider `UPSTREAM.md`. `docs/mvp-scope.md` names the selected providers and links to the procedure without duplicating validation status. T14s-specific findings, such as the `mt7921e` resume error and any `wifi.powersave` result, are appended to `TODO-582784b9` and the T14s target README without closing them. [DEC-018]
