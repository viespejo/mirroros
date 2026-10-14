# MVP Environment Scope

This document freezes the scope of the MirrorOS MVP daily environment: the capabilities the ready environment
provides, the providers already decided, the story that owns each open provider choice, and the baseline list of
frequent actions. It is owned by Story 4.1 and replaces a formal capability inventory, as decided by
[ADR 0010](adr/0010-environment-configuration-mechanism-and-scope.md). It defines no schema, identifier grammar, or
dependency graph.

Stories 4.2–4.10 and Story 5.1 consume this document. The scope is the minimum needed for daily work and does not
aim at parity with any existing machine. Native configuration formats stay authoritative; this document names
responsibilities and does not replace the configuration owned by each tool.

Normative decisions that this scope depends on:

- [ADR 0011](adr/0011-hyprland-compositor-provider.md): Hyprland is the provisional compositor provider.
- [ADR 0012](adr/0012-owned-quickshell-desktop-shell.md): the desktop shell is an owned Quickshell shell.

## Scope list

Each entry has an origin and a provider.

- **Origin** is `installation` when the capability is delivered by the installed system, or `configure` when it is
  applied by `configure` on a newly installed system.
- **Provider** is the decided provider, or `open — selected by Story 4.x` when the owning story still has to select
  it. Software is named only where it is a decided provider choice.
- Installation-delivered entries reference their authoritative source instead of listing packages.

Where a provider is open, the division of work between the desktop shell and a dedicated tool is a guideline for
exploration only. The one frozen principle is that authentication (screen lock and the polkit agent) is never
project-owned QML.

### System

| Capability | Origin | Provider | Notes |
|---|---|---|---|
| Base system, kernel, and boot | installation | Per installation policy | Source: `install/plan/policy.json`, [ADR 0003](adr/0003-storage-and-recovery-baseline.md), [ADR 0009](adr/0009-storage-option-promotion-and-esp-size.md) |
| Storage with snapshots and rollback | installation | Per installation policy | Source: [ADR 0003](adr/0003-storage-and-recovery-baseline.md), [ADR 0009](adr/0009-storage-option-promotion-and-esp-size.md) |
| zram and hibernation | installation | Per installation policy | Source: [ADR 0007](adr/0007-zram-and-hibernation-policy.md) |
| Wired and Wi-Fi network | installation | NetworkManager | Source: `install/plan/policy.json` |
| Time, locale, and console keyboard | installation | Per installation policy | Source: `install/plan/policy.json` |
| Administrative privilege | installation | sudo | Source: `install/plan/policy.json` |
| Audio | configure | open — selected by Story 4.6 | |
| Bluetooth | configure | open — selected by Story 4.6 | |
| Package updates with AUR review | configure | yay | Story 4.3 |

### Hardware

| Capability | Origin | Provider | Notes |
|---|---|---|---|
| CPU microcode | installation | Per hardware rules | Source: `hardware/rules/` |
| Graphics | installation | Per hardware rules | Source: `hardware/rules/` |
| Virtual machine guest support | installation | Per hardware rules | Source: `hardware/rules/` |
| Brightness, media keys, battery, lid, and suspend | configure | open — selected by Story 4.6 | |

### Desktop

| Capability | Origin | Provider | Notes |
|---|---|---|---|
| Wayland compositor and graphical session | configure | Hyprland (provisional) | [ADR 0011](adr/0011-hyprland-compositor-provider.md); Hyprland is the provider, not the architectural capability |
| Graphical login | configure | SDDM with its greeter on Hyprland and a small owned QML theme | Sessions always start through `uwsm start hyprland.desktop`; password login, no autologin |
| Desktop shell: bar, launcher, notifications, OSD, and session menu | configure | Owned Quickshell shell | [ADR 0012](adr/0012-owned-quickshell-desktop-shell.md); bounded to these surfaces |
| Screen lock and idle | configure | open — selected by Story 4.7 | Never project-owned QML |
| Polkit authentication agent | configure | open — selected by Story 4.6 | Never project-owned QML |
| Desktop portals | configure | open — selected by Story 4.6 | |
| Clipboard and history | configure | open — selected by Story 4.6 | |
| Screenshots | configure | open — selected by Story 4.6 | |
| Keyboard shortcuts | configure | Hyprland native configuration | Bindings belong to Story 4.7 |

### Workflow

| Capability | Origin | Provider | Notes |
|---|---|---|---|
| Terminal | configure | open — selected by Story 4.5 | |
| Interactive shell | configure | open — selected by Story 4.5 | |
| Terminal multiplexer | configure | tmux | |
| File manager | configure | open — selected by Story 4.5 | |
| Browser | configure | open — selected by Story 4.9 | |

### Development

| Capability | Origin | Provider | Notes |
|---|---|---|---|
| Version control | configure | Git | |
| Editor | configure | Neovim | Package delivered by installation; configuration applied by `configure` from an external configuration repository (Story 4.8) |
| Coding agent | configure | Pi | Configuration applied from an external configuration repository (Story 4.8) |
| Container runtime | configure | Docker | Story 4.8 |
| Command-line search utilities | configure | open — selected by Story 4.8 | |
| Node.js runtime for Pi and `verify` | configure | open — selected by Story 4.8 | |

### User

| Capability | Origin | Provider | Notes |
|---|---|---|---|
| User account | installation | Per installation policy | Source: `install/plan/policy.json` |
| User configuration linked from external repositories | configure | Per owning story | Linked, not copied (Stories 4.3 and 4.8) |
| Secrets and private state | external | None | Never stored in MirrorOS |

### Visual

| Capability | Origin | Provider | Notes |
|---|---|---|---|
| Typography | configure | open — selected by Story 4.10 | |
| Coherent color palette across components | configure | open — selected by Story 4.10 | |
| SDDM greeter theme | configure | Owned QML theme | Designed so that it can later match a boot splash |
| Cursor and icons | configure | open — selected by Story 4.10 | |

## Frequent-action list

The frequent actions of the daily environment, at action level. Key bindings are not part of this list; they belong
to Story 4.7. Actions inside tmux, Neovim, Pi, and the browser are owned by their own configuration and are not
listed here.

**Session and power**

- Lock the screen
- Log out
- Suspend
- Hibernate
- Reboot or power off

**Launching**

- Open the application launcher
- Open a terminal
- Open the browser
- Open the file manager

**Windows and workspaces**

- Close the active window
- Move focus directionally
- Move the active window directionally
- Resize the active window and toggle floating
- Toggle fullscreen
- Go to a workspace
- Move the active window to a workspace
- Return to the previous workspace
- Go to the next or previous workspace
- Pin a window
- Toggle grouping or tabbed layout and split orientation
- Move a workspace to another monitor
- Switch the monitor layout between external, mirrored, and laptop only
- Toggle the dropdown terminal scratchpad

**Desktop operations**

- Capture a region
- Capture the full screen
- Copy and paste in terminal and graphical applications
- Open the clipboard history
- Dismiss notifications and show their history

**Hardware controls**

- Raise, lower, and mute the volume
- Raise and lower the brightness
- Play or pause media

**Connectivity**

- Connect to a Wi-Fi network, through the shell or a terminal interface
- Connect a Bluetooth device, through the shell or a terminal interface

**Workflow**

- Start or reattach a tmux session

**Help**

- Show the keyboard-shortcut reference

## Change control

Changes to this document are classified as reviewed updates or scope changes.

**Reviewed updates:**

- Selecting an open provider, by the story that owns it.
- Adjusting the frequent actions before Story 4.7 completes.

**Scope changes:**

- Adding or removing a capability.
- Changing an installation-delivered capability.
- Changing the frequent actions after Story 4.7 completes.

Every change is a git commit that cites the owning story. A scope change also cites its justification: the story,
an ADR when a normative decision is affected, or the Story 6.5 evolution path. This document keeps no in-document
change history; git history is the record.

## Pending target-laptop availability

These items are decided through hardware adaptation once the target laptop can be validated:

- Firmware and BIOS updates (fwupd).
- The fingerprint reader.
- Other laptop-specific adjustments.

## Deferred and post-MVP candidates

These items are outside the frozen scope. None of them is decided here.

**Deferred candidate requiring an ADR:**

- Plymouth boot splash, optional LUKS encryption, and autologin with LUKS, considered together. Adopting them
  requires a new ADR amending [ADR 0003](adr/0003-storage-and-recovery-baseline.md), and installation would own
  them. Validation would be bounded to automated tests, one boot per bootloader, one hibernate and resume cycle,
  and one Limine snapshot boot.

**Post-MVP candidates**, entering through Story 6.5 or an ADR as applicable:

- Keyboard remapping (kanata or kmonad).
- tmuxinator.
- atuin.
- lazygit.
- gh and gcloud.
- Applications such as calibre, GIMP, and Insomnia.
