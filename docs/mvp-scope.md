# MVP Environment Scope

This document freezes the scope of the MirrorOS MVP daily environment: the capabilities the ready environment
provides, the providers already decided, the story that owns each open provider choice, and the baseline list of
frequent actions. It is owned by Story 4.1 and replaces a formal capability inventory, as decided by
[ADR 0010](adr/0010-environment-configuration-mechanism-and-scope.md). It defines no schema, identifier grammar, or
dependency graph.

Stories 4.2–4.8 and Story 5.1 consume this document. The scope is the minimum needed for daily work and does not
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
| Audio | configure | open — selected by Story 4.4 | |
| Bluetooth | configure | open — selected by Story 4.4 | |
| Package updates with AUR review | configure | yay | Story 4.7 |

### Hardware

| Capability | Origin | Provider | Notes |
|---|---|---|---|
| CPU microcode | installation | Per hardware rules | Source: `hardware/rules/` |
| Graphics | installation | Per hardware rules | Source: `hardware/rules/` |
| Virtual machine guest support | installation | Per hardware rules | Source: `hardware/rules/` |
| Brightness, media keys, battery, lid, and suspend | configure | open — selected by Story 4.4 | |

### Desktop

| Capability | Origin | Provider | Notes |
|---|---|---|---|
| Wayland compositor and graphical session | configure | Hyprland (provisional) | [ADR 0011](adr/0011-hyprland-compositor-provider.md); Hyprland is the provider, not the architectural capability |
| Graphical login | configure | SDDM with its greeter on Hyprland and a small owned QML theme | Sessions always start through `uwsm start hyprland.desktop`; password login, no autologin; theme bounded by [ADR 0014](adr/0014-native-login-and-boot-presentation.md) |
| Desktop shell: bar, launcher, notifications, OSD, and session menu | configure | Owned Quickshell shell | [ADR 0012](adr/0012-owned-quickshell-desktop-shell.md); bounded to these surfaces; started by its own systemd user unit with the uwsm graphical session |
| Screen lock and idle | configure | hyprlock and hypridle (Story 4.3) | Never project-owned QML; system PAM authentication; packaged hypridle user unit; lock after 5 minutes idle and before sleep; no DPMS or automatic suspend policy |
| Polkit authentication agent | configure | open — selected by Story 4.5 | Never project-owned QML |
| Desktop portals | configure | open — selected by Story 4.5 | |
| Clipboard and history | configure | open — selected by Story 4.5 | |
| Screenshots | configure | open — selected by Story 4.5 | |
| Keyboard shortcuts | configure | Hyprland native configuration | Conventions belong to Story 4.3, which delivers the approved Omarchy-first key table; each later slice binds its own reserved actions. The session provides `us` and `es` (`us` first); the greeter keeps the resolved layout; both default to Right Alt Compose; AltGr overrides use native ownership rules in the configure procedure |

Story 4.3 source is delivered through configure at reviewed candidate `8c3c3cc` (plan 02-19). Clean-reference
target/running application, an unchanged second running run, native binding reload, session stop/start, one
shell-failure recovery and bounded attended lock/counter checks have evidence. Final acceptance remains open:
mouse drag remains failed under the reference-VM-only DEC-029 exception, and absent-provider quiet diagnostics
retain their failures under temporary DEC-030 review until Stories 4.4/4.5 deliver their owners. Unperformed
keyboard, output and hardware checks are not passes. See the [desktop shell procedure](procedures/desktop-shell.md#final-source-verification-checkpoint).
This checkpoint selects no additional providers and does not qualify the complete MVP or target laptop.

### Workflow

| Capability | Origin | Provider | Notes |
|---|---|---|---|
| Terminal | configure | foot | Workbench-local Tokyo Night palette, JetBrainsMono Nerd Font Mono 14, centered 16x16 padding and CSI-u key paths; not a global visual provider selection |
| Interactive shell | configure | Zsh with Starship | Default interactive login shell with Zplug, vi editing, autosuggestions, syntax highlighting, Fzf, Zoxide and local-only Atuin; plugins are provisioned by `configure`, never at shell startup. Bash remains the implementation language of bounded scripts |
| Terminal multiplexer | configure | tmux | Native configuration with TPM plugins (Resurrect/Continuum, Neovim-aware navigation) and Sesh as the session selector from a reviewed local package recipe; Floax is excluded |
| File manager | configure | Nautilus (Story 4.5) | Maintainer-selected during wallpaper review; package-only delivery, optional integrations remain separate ([sources](../capabilities/desktop/files/sources.md)) |
| Browser | configure | open — selected by Story 4.5 | |

### Development

| Capability | Origin | Provider | Notes |
|---|---|---|---|
| Version control | configure | Git and Lazygit | Lazygit is an approved editor integration; portable native settings, no personal state or pager/browser expansion |
| Editor | configure | Neovim | Package delivered by installation; configuration applied by `configure` from an external configuration repository (Story 4.6). The workbench synchronizes the current branch tip and prepares only the bounded external tools |
| Coding agent | configure | Pi | Configuration applied from an external configuration repository (Story 4.6). The workbench installs the executable in the user's NVM runtime and initializes `~/.pi` only when it is absent; an existing directory is never reconciled |
| Container runtime | configure | Docker | Story 4.6 |
| Command-line search utilities | configure | open — selected by Story 4.6 | |
| Node.js runtime for Pi and `verify` | configure | NVM-managed Node.js for Pi; `verify` runtime open — selected by Story 4.6 | User-level installation; the live-ISO Node.js keeps its installer responsibilities |
| Cloud CLI | configure | Google Cloud CLI | User-level SDK from a verified archive; authentication and Vertex AI setup stay attended |

### User

| Capability | Origin | Provider | Notes |
|---|---|---|---|
| User account | installation | Per installation policy | Source: `install/plan/policy.json` |
| User configuration linked from external repositories | configure | Per owning story | Linked, not copied (Epic 4 common contract and Story 4.6) |
| Secrets and private state | external | None | Never stored in MirrorOS |

### Visual

| Capability | Origin | Provider | Notes |
|---|---|---|---|
| Typography | configure | open — selected by Story 4.8 | The workbench terminal uses `ttf-jetbrains-mono-nerd` and `noto-fonts-emoji`; global typography remains Story 4.8 work |
| Coherent color palette across components | configure | open — selected by Story 4.8 | |
| Wallpaper display and selection | configure | Owned Quickshell shell | Story 4.8; bounded by [ADR 0020](adr/0020-wallpaper-selection.md); no separate wallpaper daemon or theme manager |
| SDDM greeter theme | configure | Owned QML theme | [ADR 0014](adr/0014-native-login-and-boot-presentation.md); lock-screen palette and the shared MirrorOS wordmark (`visual/branding`), reused by the boot splash; VM-qualified with the splash by plan 02-20, without hardware readiness ([record](procedures/greeter-plymouth.md#vm-qualification-record)) |
| Cursor and icons | configure | open — selected by Story 4.8 | |

## Frequent-action list

The frequent actions of the daily environment, at action level. Key bindings are not part of this list; they belong
to the slice that delivers each action, under the binding conventions owned by Story 4.3. Actions inside tmux,
Neovim, Pi, and the browser are owned by their own configuration and are not listed here.

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
- Adjusting the frequent actions before Story 4.8 completes.

**Scope changes:**

- Adding or removing a capability.
- Changing an installation-delivered capability.
- Changing the frequent actions after Story 4.8 completes.

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
  and one Limine snapshot boot. [ADR 0014](adr/0014-native-login-and-boot-presentation.md) adopts only a static
  splash as a configure-owned visual overlay, without encryption or autologin and without amending ADR 0003;
  LUKS encryption and autologin remain deferred under this candidate.

**Post-MVP candidates**, entering through Story 6.5 or an ADR as applicable:

- Keyboard remapping (kanata or kmonad).
- tmuxinator.
- gh.
- Applications such as calibre, GIMP, and Insomnia.
