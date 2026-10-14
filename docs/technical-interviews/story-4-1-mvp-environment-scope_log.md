# Story 4.1 Technical Interview — Decision Log

## DEC-001
- **Question**: Where does the MVP scope list and the frequent-action list live, and in what form?
- **Context/Nuances**: ADR 0010 replaces the formal capability inventory with a human-readable scope list owned and frozen by Story 4.1; no schema, identifier grammar, or dependency graph is allowed. `capabilities/` does not exist yet and creating it now would pre-empt Story 4.2. Stories 4.7 and 5.1 consume both lists, so a single reference point is preferable. Alternatives: two separate documents, or `capabilities/README.md`.
- **User Response**: Accepted the recommendation (single document).
- **Decision**: A single Markdown document `docs/mvp-scope.md` with three sections: Scope list (grouped by the seven stable responsibilities: system, hardware, desktop, workflow, development, user, visual), Frequent-action list, and a short Change control section. Plain tables (capability | provider | notes) without formal identifiers or dependency graph.
- **Status**: Accepted

## DEC-002
- **Question**: Does the scope list include capabilities already delivered by installation (Epic 2), or only what `configure` adds?
- **Context/Nuances**: NFR27 and Story 5.1 need the complete capability set of the ready environment. The user raised the risk that duplicating installation content would drift from the native sources (`install/plan/policy.json`, `hardware/rules/`). ADR 0010 keeps a single native source per concern. Capabilities change rarely; package lists change often.
- **User Response**: Accepted the refined option A'.
- **Decision**: The list covers the whole ready environment, including installation-delivered capabilities, and marks the origin of each entry (installation or configure). Installation-delivered capabilities are named at capability level with a reference to their authoritative source, without enumerating packages. Software is named only as a provider when it is a visible provider choice. Adding or removing an installation capability is a scope change subject to change control.
- **Status**: Accepted

## DEC-003
- **Question**: Which compositor provider does the frozen MVP scope list name?
- **Context/Nuances**: Story 4.1 acceptance criteria, the PRD, the product brief, and the architecture name Niri as the provisional compositor. Niri appears only in documentation; no code depends on it. Options were to freeze Niri, freeze Hyprland with an ADR, or leave the provider pending.
- **User Response**: Hyprland is clearly preferred; Niri will be a future trial.
- **Decision**: Hyprland is the provisional compositor provider in the frozen MVP scope list. Niri leaves the MVP scope and remains an uncommitted future trial. The architectural capability stays "Wayland compositor / graphical session" and the provider remains replaceable beneath the compositor provider boundary. The change is recorded in a new ADR (0011) delivered with this plan. Dependent provider choices (portal, bar, launcher, lock, shortcuts) are resolved against Hyprland.
- **Status**: Accepted

## TODO-001
- **Question**: Which documents are amended for the Niri-to-Hyprland change?
- **Status**: Resolved by DEC-004

## DEC-004
- **Question**: Which documents are amended for the Niri-to-Hyprland change? (resolves TODO-001)
- **Context/Nuances**: Niri appears in the PRD (3), product brief (2), architecture (9), and epics (5, one of them the PRD-derived NFR33 copy). Precedent: Epic 3 DEC-021 left the PRD and research unchanged and let the ADR prevail; PRD-derived copies in `docs/epics.md` kept the PRD wording.
- **User Response**: Option A.
- **Decision**: ADR 0011 (Accepted) records the change and states that it prevails over the Niri mentions in the PRD and product brief, which stay unchanged. `docs/architecture.md` is amended: Niri mentions become Hyprland with a reference to ADR 0011, the tree path `desktop/compositor/providers/niri/` becomes `providers/hyprland/`, and Hyprland replaces Niri as the example of tool-owned Lua configuration in the language table and rule. `docs/epics.md` is amended in Stories 4.1 and 4.4 and in the Additional Requirements line on the compositor provider. NFR33 in `docs/epics.md` stays as a literal PRD copy. Research, brainstorming, and earlier interview records are not changed.
- **Correction**: The original entry dropped Niri as a Lua example on the claim that Hyprland configuration is not Lua. Since Hyprland 0.55 configuration is Lua (`~/.config/hypr/hyprland.lua`) and hyprlang is deprecated (hypr.land news "Lua-ification of Hyprland configs", Hyprland wiki, ArchWiki). Corrected with user approval.
- **Status**: Accepted

## DEC-005
- **Question**: How does the graphical session start (display manager / greeter)?
- **Context/Nuances**: Options were greetd + tuigreet (TUI, minimal), SDDM with a greeter on Hyprland (Omarchy model), and greetd + ReGreet. Omarchy moved from its own seamless-login to SDDM with autologin (PR #2242, v3.1) for standard session handling, keyring unlock through PAM, multi-user/session choice, and mainly a coherent boot appearance (v3.8: "fully matching theme for SDDM logins to the decryption style"); on unencrypted installs it autologins only on the first boot. Lock, logout, and compositor switching do not depend on the display manager (locking is done in-session; both greeters read `/usr/share/wayland-sessions`). If the SDDM greeter fails on graphics, another TTY remains available for diagnosis. MirrorOS sets the user password during installation and keeps the root unencrypted, so autologin adds no value. The maintainer, who usually prefers TUI, wants a premium appearance on the target laptop (Framework 13 Pro).
- **User Response**: Option B.
- **Decision**: The session starts through SDDM with its greeter running on Hyprland and a small MirrorOS-owned QML theme. The session always starts through `uwsm start hyprland.desktop`, with password and without autologin. The theme is a small owned QML theme, not a theming framework. greetd + tuigreet (no visual identity) and ReGreet (less proven) are rejected.
- **Status**: Accepted

## TODO-002
- **Question**: Does Plymouth (graphical boot splash) enter the MVP scope, so the boot-to-login sequence looks continuous? It touches boot (Limine/UKI, initramfs) governed by Epic 2 ADRs.
- **Status**: Resolved by DEC-006

## DEC-006
- **Question**: Does Plymouth enter the MVP scope? (resolves TODO-002)
- **Context/Nuances**: The installed boot chain is owned by the installation engine (mkinitcpio hook constants, plan kernel command line, three storage options, postconditions on command line and resume). In Omarchy, Plymouth hosts the LUKS password prompt, which is why its SDDM theme matches it; with an unencrypted root it would be a brief splash only. The maintainer refuses a full Epic 2 revalidation; a bounded validation would suffice (automated tests, one boot per bootloader, one hibernate/resume cycle, one Limine snapshot boot). The maintainer expects to eventually offer optional LUKS encryption and autologin in that case, which contradicts ADR 0003 ("Every root filesystem remains unencrypted").
- **User Response**: Accepted.
- **Decision**: Plymouth is out of the frozen MVP scope; the premium appearance starts at the SDDM greeter. Plymouth, optional LUKS encryption, and autologin with LUKS are recorded as one future candidate that the maintainer expects to adopt, requiring a new ADR amending ADR 0003 and owned by installation if adopted. DEC-005 holds until then (password, no autologin). The SDDM QML theme should be designed so it can later match a Plymouth theme, without any Plymouth work now. Expected validation on adoption is bounded, not a full Epic 2 revalidation. `docs/mvp-scope.md` lists it in a short Deferred candidates section outside the frozen scope.
- **Status**: Accepted

## DEC-007
- **Question**: Desktop shell architecture (bar, launcher, notifications, lock/idle, OSD), and what "Omarchy is our mirror" means for it.
- **Context/Nuances**: Omarchy now runs a custom Quickshell desktop (one long-lived QML process, about 45,000 QML lines, plugins for bar, menus, notifications, lock, clipboard, OSD, polkit); earlier it used Waybar, Walker, mako, hyprlock/hypridle, and SwayOSD. Options were modular single-purpose components, a third-party Quickshell shell, or an owned Quickshell shell. The maintainer wants control of the shell and is set on Quickshell. Constraints: the architecture language table does not include QML; NFR37 requires a documented recurring need for custom code; the PRD excludes a control panel, welcome application, or background management service. Omarchy is MIT-licensed. Sub-options for the Omarchy relationship were design reference with an owned minimal implementation, a trimmed fork/vendor of Omarchy's shell, or Omarchy as-is (rejected).
- **User Response**: Owned Quickshell shell; Omarchy as design reference (option A).
- **Decision**: The desktop shell is a MirrorOS-owned, minimal Quickshell shell bounded to MVP capabilities. Omarchy is the design reference; specific fragments may be copied with MIT attribution in `docs/attribution.md`. The Omarchy shell is not forked or vendored, and Omarchy is not used as-is.
- **Status**: Accepted

## TODO-003
- **Question**: ADR 0012 admitting QML as a project-owned language for the shell, documenting the NFR37 justification (control and coherent premium appearance that separate components do not achieve equally) and the exclusion of control-panel functionality; delivered with this plan together with the architecture language amendment.
- **Status**: Pending

## TODO-004
- **Question**: Which capabilities the owned shell takes on and which remain in dedicated tools (for example screen lock).
- **Status**: Deferred by DEC-008 (guideline only; selected during VM exploration by the owning stories)

## DEC-008
- **Question**: Must Story 4.1 decide every provider now? (defers TODO-004)
- **Context/Nuances**: The maintainer wants to build incrementally: explore in a VM with a MirrorOS installation and record in MirrorOS only what proves right. The Story 4.1 acceptance criterion currently requires naming every piece of software. A proposed split (shell: bar, launcher, notifications, OSD, session menu, clipboard-history picker, wallpaper; dedicated tools: hyprlock, hypridle, hyprpolkitagent, wl-clipboard + cliphist, grim + slurp) was not frozen.
- **User Response**: Accepted.
- **Decision**: Story 4.1 freezes the capabilities of the seven responsibilities, the frequent-action list at action level (key bindings belong to Story 4.7), and the providers already decided (Hyprland, SDDM with uwsm, the owned Quickshell shell). Undecided providers are marked "open — selected by Story 4.x" with their owning story. Selecting a provider for an open entry is a reviewed update, not a scope change; adding or removing a capability is a scope change. The Story 4.1 acceptance criterion in `docs/epics.md` is amended from naming every piece of software to naming every capability, the providers already selected, and the owning story of each open provider choice. The shell/dedicated-tool split is a guideline for exploration; the frozen principle is that authentication (screen lock, polkit agent) is never project-owned QML.
- **Status**: Accepted

## DEC-009
- **Question**: How are exploration and registration orchestrated?
- **Context/Nuances**: The existing `vm/reference` tooling is ephemeral and headless and removes the VM after each run, so it does not support hands-on exploration.
- **User Response**: Accepted.
- **Decision**: Exploration happens in a personal persistent VM (for example virt-manager or QEMU with qcow2) installed from a MirrorOS ISO, using a clean-install snapshot to revert; it stays outside the product and is not committed. A decision enters MirrorOS only through the plan of its owning story, implemented as `configure` scripts and native configuration, and proven by a clean installation plus `configure` in the VM without manual steps, followed by a change-controlled update of `docs/mvp-scope.md`.
- **Status**: Accepted

## TODO-005
- **Question**: Should a persistent exploration VM become product tooling? (Not recommended for the MVP.)
- **Status**: Resolved by DEC-014

## DEC-010
- **Question**: What criterion decides which capabilities enter the frozen list?
- **Context/Nuances**: Epic 4 is the longest epic, and open-ended exploration and the owned shell invite endless polishing. The daily laptop is only migrated in Story 6.4, after Epics 5 and 6. The PRD defines the MVP as a finite, frozen inventory (FR20, NFR27), and post-MVP evolution has its own path (Journey 4, Story 6.5). The maintainer's current machine includes many tools (for example calibre, GIMP, Insomnia, docker, gcloud, tmuxinator, atuin) that need not be in the MVP. Options were minimum for daily work, parity with the current machine, or case-by-case.
- **User Response**: Accepted.
- **Decision**: The frozen list holds the minimum for daily work: the capabilities the PRD requires plus the indispensable parts of the maintainer's current workflow, with no aim of parity with the current machine. Everything else is listed in a Post-MVP candidates section outside the frozen scope and enters later through the evolution path (Story 6.5). The shell and visual polish may keep evolving after migration.
- **Status**: Accepted

## DEC-011
- **Question**: Which capabilities form the frozen MVP list?
- **Context/Nuances**: Draft built from the PRD must-haves, installation-delivered facts (`install/plan/policy.json`: NetworkManager, systemd-timesyncd, fstrim, locale/console/hostname, sudo, Snapper cleanup, zram/hibernation, hardware rules, bootloader; Neovim in base packages), and the maintainer's current workflow. Omarchy ships Nautilus as file manager; the maintainer uses yazi. fwupd delivers Framework BIOS/firmware updates through LVFS and can only be validated on the laptop.
- **User Response**: Docker is indispensable; a file manager is needed but its provider stays open; laptop-specific items are handled when the Framework laptop is available.
- **Decision**: The draft list is approved with adjustments.
  - System: base system/kernel/boot (I), storage and snapshots/rollback (I), zram and hibernation (I), wired/Wi-Fi network via NetworkManager (I), time/locale/console keyboard (I), administrative privilege via sudo (I), audio (C, open → 4.6), Bluetooth (C, open → 4.6), package updates with AUR review via yay (C, Story 4.3).
  - Hardware: microcode, graphics, VM guest via hardware rules (I); brightness, media keys, battery, lid and suspend (C, open → 4.6).
  - Desktop: compositor Hyprland (C, decided), graphical login SDDM + uwsm (C, decided), owned Quickshell desktop shell for bar, launcher, notifications, OSD, session menu (C, decided), screen lock and idle (C, open → 4.7, never owned QML), polkit agent (C, open → 4.6, never owned QML), portals (C, open → 4.6), clipboard and history (C, open → 4.6), screenshots (C, open → 4.6), keyboard shortcuts (C, Story 4.7, Hyprland native configuration).
  - Workflow: terminal (C, open → 4.5), interactive shell (C, open → 4.5), multiplexer tmux (C, decided), file manager (C, open → 4.5; candidates yazi and Nautilus), browser (C, open → 4.9).
  - Development: Git (C, decided), Neovim with external configuration (I package, C configuration, Story 4.8), Pi with external configuration (C, Story 4.8), container runtime Docker (C, decided, Story 4.8), CLI search utilities (C, open → 4.8), Node.js runtime for Pi and `verify` (C, open → 4.8).
  - User: user account (I), user configuration from external repositories linked not copied (C, Stories 4.3/4.8), secrets and private state (external, never in MirrorOS).
  - Visual: typography (C, open → 4.10), coherent color palette across components (C, open → 4.10), SDDM greeter theme as owned QML (C, decided), cursor and icons (C, open → 4.10).
  - Pending target-laptop availability (not frozen, not post-MVP): firmware/BIOS updates (fwupd), fingerprint reader, other Framework-specific adjustments, decided through hardware adaptation.
  - Post-MVP candidates: Plymouth + LUKS + autologin (DEC-006), tmuxinator, atuin, lazygit, gh/gcloud, applications (calibre, GIMP, Insomnia, and similar).
  - Provider suggestions given during the interview for open entries (for example kitty, zsh, PipeWire) are indicative and not frozen.
- **Status**: Accepted

## DEC-012
- **Question**: What is the frequent-action list, and how does it evolve?
- **Context/Nuances**: NFR48 requires a documented keyboard path for 100 percent of frozen frequent actions, so each action becomes a verifiable obligation (Story 5.1). Hyprland can bind any key to any command or dispatcher, so it does not restrict the action list; it shapes the bindings, which belong to Story 4.7. The maintainer uses i3 today with about 160 bindings (vim-style and arrow navigation, 20 workspaces, scratchpads, tabbed/stacking/split layouts, sticky, back-and-forth, moving workspaces between outputs, monitor-layout switching, hibernate). tmux configuration lives in the external `.dotfiles` repository, Neovim in `nvim-lua-new`, and Pi in `pi-config`. Hyprland reproduces most i3 behavior (workspaces, special workspaces, pin, floating, fullscreen, groups, moving workspaces to outputs) but not the i3 tree model (manual split orientation, stacking), which uses dwindle/master layouts instead.
- **User Response**: Accepted as a starting point, explicitly not set in stone.
- **Decision**: The baseline frequent-action list contains: lock screen; log out; suspend; hibernate; reboot or power off; open the application launcher; open the terminal; open the browser; open the file manager; close the active window; move focus directionally; move the active window directionally; resize and toggle floating; toggle fullscreen; go to a workspace; move the window to a workspace; capture a region; capture the full screen; copy and paste in terminal and graphical applications; open clipboard history; dismiss notifications and show their history; raise, lower, and mute volume; raise and lower brightness; play or pause media; connect to a Wi-Fi network; connect a Bluetooth device; start or reattach a tmux session; show the keyboard-shortcut reference; switch monitor layout (external, mirrored, laptop only); toggle the dropdown terminal scratchpad; toggle grouping/tabbed and split orientation; pin a window (sticky); return to the previous workspace; go to the next or previous workspace; move a workspace to another monitor. Until Story 4.7 completes, adding, removing, or rewording actions is a reviewed update fed by VM exploration; after Story 4.7, a change is a scope change. Story 4.7 takes the maintainer's current i3 configuration as the primary source of muscle memory, translated to Hyprland equivalents, with Omarchy and the community as secondary sources, and documents unavoidable differences such as the i3 tree model versus dwindle/master. tmux, Neovim, and Pi bindings stay owned by their external repositories and are not part of this list. Wi-Fi and Bluetooth actions only require a keyboard path (shell or TUI).
- **Status**: Accepted

## TODO-006
- **Question**: Does keyboard remapping (the maintainer uses kanata/kmonad configurations, including Miryoku, and a Glove80) enter the frozen capability list (DEC-011)?
- **Status**: Resolved by DEC-013

## DEC-013
- **Question**: Does keyboard remapping enter the frozen capability list? (resolves TODO-006)
- **Context/Nuances**: kanata and kmonad are installed on the current machine, but their services are disabled, no process runs, and their configurations were last changed in October 2024. The maintainer's daily keyboard is a Ferris Sweep (correcting the earlier Glove80 assumption), which remaps in its own firmware, so no OS-level remapping is needed for it. kanata works on Wayland at evdev level, so nothing must be prepared now.
- **User Response**: Option B; the daily keyboard is a Ferris Sweep.
- **Decision**: Keyboard remapping (kanata/kmonad) is a Post-MVP candidate. If the Framework built-in keyboard needs home-row mods or Miryoku, it enters through the evolution path (Story 6.5).
- **Status**: Accepted

## DEC-014
- **Question**: Does a persistent exploration VM become product tooling or a repository procedure? (resolves TODO-005)
- **Context/Nuances**: The maintainer already has a private local laboratory at `~/qemu/mirroros-lab/` with its own README: `vm init`, `vm boot --select-iso` (ISO picker over `~/mirroros/dist`), restorable checkpoints of disk and UEFI variables, opt-in VirGL (`--gl`), and localhost SSH forwarding. A repository procedure would duplicate that README and reference a personal path outside the repository.
- **User Response**: Accepted.
- **Decision**: MirrorOS has no exploration-VM tooling or procedure for the MVP. Exploration uses the existing private laboratory, which remains local workflow tooling outside the product and source control, like `.agents/`. The product only requires that a registered choice is proven by a clean installation plus `configure` (DEC-009). Exploring Hyprland and SDDM requires `--gl`; the laboratory configures no audio device, so audio (Story 4.6) needs a laboratory improvement or validation on the laptop. In-product automation is reconsidered only if repeated use justifies it.
- **Status**: Accepted

## DEC-015
- **Question**: How are changes to `docs/mvp-scope.md` recorded?
- **Context/Nuances**: Classification is already decided: selecting an open provider, or adjusting actions before Story 4.7, is a reviewed update; adding or removing capabilities, changing installation capabilities, or changing actions after Story 4.7 is a scope change (DEC-002, DEC-008, DEC-012). Options were git only, git plus an in-document scope-change table, or an ADR per scope change. Normative decisions already require ADRs under repository rules.
- **User Response**: Option A.
- **Decision**: Change control relies on git only. The Change control section of `docs/mvp-scope.md` lists the classification. Every change is a commit citing the owning story; a scope change also cites its justification (the story, an ADR when it affects normative decisions, or the Story 6.5 evolution path). There is no in-document change history and no ADR per scope change.
- **Status**: Accepted

## DEC-016
- **Question**: Which artifacts are aligned, and does any automated check apply?
- **Context/Nuances**: `docs/adr/README.md` has no ADR index to update; the README links only governance documents. No Omarchy code is copied by this story. A validator for a Markdown scope document would be custom code without a recurring need (NFR37).
- **User Response**: Accepted.
- **Decision**: Deliverables: (1) new `docs/mvp-scope.md` with Scope list (per responsibility, origin, decided or open provider with owning story), baseline Frequent-action list, Change control, Pending target-laptop availability, and Deferred and Post-MVP candidates, naming no personal repositories, personal i3 configuration, or the private laboratory; (2) ADR 0011 (Accepted) for Hyprland as provisional compositor provider, prevailing over Niri mentions in the PRD and product brief; (3) ADR 0012 (Accepted) for the owned Quickshell shell, admitting QML as project-owned language bounded to the shell, with the NFR37 justification, the exclusion of control-panel, welcome, and background-management functionality, authentication never in owned QML, and Omarchy as design reference; (4) `docs/architecture.md` amendments: Niri to Hyprland per DEC-004, language table and Language Selection with QML per ADR 0012, MVP scope list paragraph linking `docs/mvp-scope.md`, and the Future Enhancement item reduced to keyboard bindings (Story 4.7), without deciding the shell's location under `capabilities/`; (5) `docs/epics.md` amendments to Story 4.1 acceptance criteria (DEC-008 wording and Hyprland), Story 4.4 (Hyprland), and the Additional Requirements compositor line; (6) no changes to `docs/attribution.md`, the PRD, the product brief, research, `operations/`, or tests. No new automated test; verification by commands (Niri search, ADR template heading diff, FR coverage loop, untouched configure contract tests, `git diff --check`, gitleaks). The interview artifacts are committed with the change.
- **Status**: Accepted
