# Reproducible Development Laboratory — Consolidated Interview Plan

## Interview State

Persistence is active at the maintainer's explicit request. This document tracks the agreed design, not execution results. The maintainer explicitly waived the in-chat draft and separate draft-approval gate and authorized direct materialization. The executable artifact is `.agents/plans/02-17-reproducible-development-workbench.md`, with status `pending`; materialization does not authorize or imply implementation, VM operations, commits, or pushes.

## Agreed Objective and Approach

Prepare the desired Foot, Zsh, Tmux, NVM-managed Node.js, Pi, and Neovim environment from the host so the maintainer can continue investigation directly inside the guest. [DEC-003, DEC-005, DEC-020] Validate that environment in the VM, then incorporate the approved configurations and integrations as reproducible MirrorOS defaults rather than maintaining a permanent laboratory-only substitute. Product promotion is a required deliverable of this work, not optional follow-up work. [DEC-001, DEC-011]

Independent configuration repositories remain authoritative: reuse their sources through explicit integrations rather than copying their configuration trees into MirrorOS. Credentials and private state remain outside product source. VM checkpoints are not the reconstruction source of truth, and checkpoint decisions are outside the current agreed design. [DEC-001, DEC-011]

Completion requires reconstructing the environment in another VM from the incorporated declarations. Required private-input steps must be explicit, and the reconstruction must not depend on undocumented manual adjustments made to the exploration guest. [DEC-001]

## Configuration Sources and Access Boundaries

Use the host's Kitty, Zsh, and Tmux configuration under `~/.dotfiles` as reference sources. Select relevant configuration rather than running the complete dotfiles installer. Foot is retained initially under DEC-004; Zsh is selected as the interactive shell under DEC-005, with integration details still unresolved. Initially only the structure of `~/.dotfiles-local` was inspected; the later explicitly authorized inspection of `zshrc_local` verified the NVM pattern under DEC-020. No unrelated private additions are selected for inclusion. Do not read or execute `~/.zcustom`, directly or through links and references, and do not source host configurations as part of inspection. [DEC-002]

Neovim configuration is also in scope. Its authoritative repository is `https://github.com/viespejo/nvim-lua-new`; retain that repository's ownership rather than copying its configuration tree into MirrorOS. The installation mechanism, dependencies, and validation remain to be investigated and agreed. [DEC-001, DEC-003]

## Configuration Ownership

MirrorOS owns native Foot, Zsh, and Tmux configuration as product defaults. Host dotfiles are an initial reference only: select the required behavior and files without importing the entire repository or its history, and preserve applicable third-party attribution. Make Zsh and Tmux changes and tests in the VM's MirrorOS checkout, never in the host's local dotfiles repository. This replaces the external-dotfiles ownership and editing approach in DEC-012 and the dotfiles publication workflow in DEC-015. No external dotfiles branch, publication, or revision pin is required. Neovim and pi-config remain independently authoritative. [DEC-014, DEC-016]

Use `https://github.com/viespejo/pi-config` as the authoritative source for personal Pi extensions. Inspect the structure and relevant non-secret configuration under `~/.pi` for the remaining setup, without reading credentials, session contents, or histories. MirrorOS owns the application defaults under DEC-017; exact component selection, installation, file ownership mapping, and private authentication remain unresolved. [DEC-013, DEC-017]

## Pi Defaults and External Resources

MirrorOS owns Pi installation and the initial portable default settings, key bindings, and component selection. Apply the initial user configuration only when `~/.pi` does not exist; preserve an existing directory entirely unchanged. The independent `pi-config` repository remains authoritative for its extensions and other resources maintained there; integrate those resources explicitly without copying their configuration trees into MirrorOS or modifying an existing `~/.pi`. The detailed initial resource mapping still requires inspection. [DEC-013, DEC-017, DEC-028]

Credentials, sessions, caches, and local runtime state remain device-local and must not be committed to either repository. Do not add JSON ownership markers, merge keys, adopt generated files, or automatically reset `~/.pi`. To receive new initial defaults, the user must manually move or remove the directory and rerun configure; recommend renaming it as a backup because it can contain credentials and sessions. Continuous management of Pi defaults inside `~/.pi` is superseded, while Pi executable and external repository policies remain separately applicable. The proposal to move all portable defaults into pi-config was not accepted. [DEC-001, DEC-017, DEC-028]

## External Configuration Synchronization

Use configure for both new installations and subsequent device synchronization. Obtain the latest revision of the selected branches of Neovim and pi-config, resolve each revision once per execution, and record the applied commits. Avoid unnecessary mutations when sources are unchanged. Stop with an actionable explanation for unsaved local work or divergent histories; do not overwrite changes or force resets. Download and application failures must not be reported as successful synchronization. [DEC-018]

The same ISO can apply different external configuration revisions over time; this is intentional. Permanent commit pinning was not accepted. MirrorOS-owned defaults come from the checkout or installed code copy being executed. Updating that code uses the explicit checkout workflow in DEC-019, not implicit self-updating during external synchronization. Selected branch names and detailed repository integration remain to be agreed. [DEC-018, DEC-019]

## Updating MirrorOS-Owned Defaults

For newer product defaults on an installed device, explicitly clone MirrorOS or update an existing checkout to the desired revision, then run that checkout's `operations/configure` in running mode. This applies its product defaults and synchronizes the external configuration sources without reinstalling or rebuilding an ISO. Configure does not update its own MirrorOS code automatically. [DEC-018, DEC-019]

During installation, native defaults come from the MirrorOS code included in the ISO build. The installed `mirroros-configure` snapshot remains distinct from a separately updated checkout and is not implicitly updated by running configure from that checkout. Documentation must distinguish which code source is being executed. [DEC-019]

## Node.js Runtime and NVM

Manage the user's Node.js runtime with NVM. Expose the selected installed version's bin directory through portable PATH configuration so Node.js, npm, and global executables such as Pi work without loading the manager. Do not source NVM unconditionally during interactive Zsh startup; provide `nvm_load` for loading NVM and its completions on demand. Relevant non-interactive operations must receive the runtime explicitly rather than relying on interactive shell initialization. [DEC-020]

Retain the existing system `nodejs` in the live ISO for installer responsibilities. It is separate from the user's NVM-managed runtime. Source inspection found no current target base or capability declaration installing Node.js; actual guest package state is unverified. Use Node.js `v24.22.0` as the initial NVM-managed user runtime. Future runtime version updates require explicit changes in MirrorOS, not automatic latest-version selection during configure. Validate compatibility with Pi and the in-scope Neovim integrations in the VM. Use an identified version of the official NVM installer, running as the target user without automatic shell-profile edits. Review origin and relevant installer behavior during integration development and when changing its version or mechanism, not as an interactive runtime requirement. Runtime checks cover prerequisites, source identity or integrity as supported by upstream, installation results, and postconditions. The concrete NVM version, retrieval details, documented installer options, portable PATH details, and non-interactive integration still require source inspection. [DEC-020, DEC-021, DEC-032]

The specifically authorized `~/.dotfiles-local/zsh/zshrc_local` was inspected to verify the host's direct-PATH and `nvm_load` pattern, without executing it or following references. This limited inspection does not approve unrelated private aliases or configuration for inclusion. The `~/.zcustom` prohibition remains unchanged. [DEC-002, DEC-020]

## Host Pi Functional Configuration

When initializing an absent `~/.pi`, reproduce the host's functional Pi configuration, including settings, keybindings, package/resource selection, and voice/TTS settings. Preserve the current activation states; do not enable voice or TTS automatically. Device-specific activation remains the user's choice. Exclude credentials, sessions, caches, generated state, and nonportable personal paths. On subsequent runs, preserve an existing `~/.pi` entirely unchanged rather than updating these defaults. [DEC-017, DEC-026, DEC-028]

Do not exclude voice/TTS merely because the laboratory currently lacks audio. Working VM audio is not required to validate the rest of the environment. Do not download local voice/TTS models during configure while those features are disabled, and do not copy host models. Preserve preferences independently of model availability. Obtain models on demand through the extension's supported mechanism if available, verifying that support before implementation. If upstream cannot support this workflow, surface the limitation for review rather than silently adding custom download automation or eager downloads. Other dependency details still require inspection. [DEC-026, DEC-027]

## Pi Executable Installation

Install `@earendil-works/pi-coding-agent` with npm in the user's selected NVM environment, without sudo and with `--ignore-scripts`. Use this as the single Pi installation mechanism for the environment and record the installed Pi version. The documented npm route does not itself pin all transitive dependencies; do not claim otherwise. Resolve the selected pi-config revision first and install the exact version declared in its `devDependencies["@earendil-works/pi-coding-agent"]`. If that dependency is absent, resolve the latest stable published Pi release once per execution. If it is present but specifies a range or invalid value, stop with an actionable explanation instead of silently choosing another version. Record both the pi-config commit and applied Pi version, and avoid unnecessary reinstallation when that version is already installed. This supersedes the unconditional latest-stable selection in DEC-023. Node.js retains its separately declared version policy. [DEC-021, DEC-022, DEC-024]

Check extension loading and expose detected integration failures without claiming verified integration. Compatibility repair is manual and belongs to the user, who may downgrade Pi or update extensions. Do not introduce automatic repair, automatic compatibility-version selection, or silent downgrades. A subsequent configure run converges to the version selected under DEC-024, not an ad hoc manual global downgrade. The declared pairing identifies the intended tested versions but does not itself prove compatibility or pin every transitive dependency. [DEC-023, DEC-024]

## External Repository Locations

Check out `https://github.com/viespejo/pi-config` at the target user's `~/code/pi-config` and `https://github.com/viespejo/nvim-lua-new` at `~/code/nvim`. Resolve these paths from the selected user's home, never from hardcoded host paths. Integrate through links from the appropriate configuration locations, not copied configuration trees. [DEC-029]

Create Pi resource links only while initializing an absent `~/.pi`; do not add or modify links within an existing directory. External clones remain independently synchronizable under DEC-018, including its local-change protections. Do not silently overwrite unrelated checkouts or conflicting configuration paths. [DEC-018, DEC-028, DEC-029]

## External Repository Changes During Validation

Develop necessary Neovim and pi-config adjustments on branches inside the VM, never in their host checkouts. Publication requires maintainer review and explicit authorization; this workflow decision is not permission to push specific changes. MirrorOS continues to consume the usual repository branches under DEC-018, and experimental branches do not automatically become defaults. [DEC-025]

## Final Pi Functional Test

Include a manual real Pi conversation inside the guest using one provider authenticated privately by the maintainer. Do not copy host credentials or require authentication of every configured provider. Retain only a non-secret test outcome if needed, never credentials or conversation content as evidence. Package/configuration installation and private authentication are separate; successful installation alone does not establish authenticated readiness. [DEC-034]

## Observed Starting Point

- `capabilities/desktop/terminal/apply` installs Foot packages and provides `foot.ini` through the existing file ownership mechanism.
- `capabilities/workflow/shell/apply` provides Starship initialization for the target user's Bash.
- `capabilities/workflow/tmux/apply` installs Tmux without introducing a configuration file.
- Root `.agents/` is ignored local workflow tooling, outside authoritative product source and runtime.

These are repository observations, not additional design decisions.

## Unresolved Design

The remaining host features, dependencies, and detailed integration mechanisms still need inspection and agreement. Pi user configuration uses initialization-only handling under DEC-028; JSON ownership markers and merge machinery are not part of the design. Foot behavior validation, Zsh integration details, Neovim dependency details, the initial Pi resource mapping, external artifact installation details, and private authentication procedures remain to be concretized. Zsh's feature baseline is approved under DEC-006; its numerical performance threshold is deliberately deferred until initial VM measurements under DEC-007. Host access and configuration synchronization policies are already agreed; operational connection parameters and exact source identities still need inspection. One integrated executable plan must deliver the entire scope, including product defaults and reconstruction validation; the proposed split was rejected. Story ownership, procedure placement, and detailed validation still need to be reflected in the draft. [DEC-006, DEC-007, DEC-010, DEC-011, DEC-018, DEC-031]

## Materialized Executable Plan

The single integrated plan is `.agents/plans/02-17-reproducible-development-workbench.md`, with phase `02-new-phase`, plan `17`, date `2026-10-18`, status `pending`, type `execute`, and `dependencies: []`. The proposed 02-17/02-18 split and its dependency were rejected. Remaining source inspection, prototype acceptance, and reconstruction checks are explicit execution tasks and blocking gates, not completed observations. No dependencies may be added without explicit agreement. [DEC-031]

## Interactive Shell Direction

Use Zsh as the user's interactive shell while retaining Bash for MirrorOS scripts. Product implementation must explicitly update the current Bash-with-Starship provider declaration in `docs/mvp-scope.md`. Build the guest configuration around approved interactive features, measure startup, and optimize demonstrated costs rather than assuming Zsh itself or any particular plugin is responsible for the host's latency. [DEC-005]

Retain Zplug as the initial plugin manager. Install plugins during preparation, not through startup-time installation checks or prompts. Measure the manager's contribution before proposing replacement; any replacement requires evidence and explicit review. [DEC-033] Compare minimal and full guest configurations and verify that optimizations preserve approved completion, history, vi editing, and key bindings. Do not execute the host configuration or read `~/.zcustom`. A quantified claim of improvement over the host requires an authorized comparable measurement; the feature baseline is defined in DEC-006 and a numerical performance threshold is deferred until initial VM measurement under DEC-007. [DEC-002, DEC-005, DEC-006, DEC-007]

## Terminal Direction

Use native Foot configuration for the host's Tokyo Night palette, JetBrains Mono at size 14, and padding 4. Reuse the existing `ttf-jetbrains-mono-nerd` package and validate family/Mono variant selection and rendering inside the VM. Preserve applicable theme attribution. This does not extend to global desktop theming. [DEC-030]

Retain Foot initially and adapt the required host terminal behaviors. Validate Shift+Enter in Pi, clipboard behavior, fonts, and operation inside Tmux. Kitty editor overlays are not assumed to have direct equivalents in Foot; any essential overlay capability must be evaluated explicitly before terminal suitability is finalized. [DEC-004]

## Required Interactive Shell Features

The initial functional baseline includes Starship, vi editing mode, autosuggestions, syntax highlighting, menu completion with reverse navigation, Fzf searches for files and directories with previews, Zoxide navigation, Atuin history, and Ctrl+Space acceptance of suggestions. Validate startup performance with this approved baseline rather than obtaining a faster result by omitting required behavior. Implementations and initialization order remain to be resolved. [DEC-006]

Atuin synchronization and authentication are not prerequisites for environment validation. Additional aliases and alias-tips are deferred for later review rather than rejected; they do not block the first startup validation. [DEC-006]

## Shell Performance Validation

Compare minimal Zsh with the complete approved interactive baseline inside the VM. Measure repeated openings, report the first startup separately from subsequent startups, and assess both prompt availability and initial responsiveness. Identify the major costs and repeat measurements after optimizing demonstrated bottlenecks. Functional checks must continue to pass; removing required features is not an acceptable performance improvement. [DEC-006, DEC-007]

This work must deliver measurements and justified optimizations. Agreement on a numerical threshold is deferred until the first VM measurement. Do not execute the host configuration or claim a measured host-relative improvement based on guest-only results. [DEC-005, DEC-007]

## Tmux Session Management and Restoration

Preserve Ctrl+A as the prefix, window and pane bindings, Neovim-aware navigation, copy/selection, text and URL search/selection, mouse support, and the host's Tmux appearance. Adapt host-specific paths and omit inherited references to other users from the new defaults; do not modify the host configuration or copy saved session state. Apply the session-management exceptions below. [DEC-035]

Exclude Floax, which the maintainer does not use. Preserve automatic session restoration through Resurrect and Continuum, validate restoration separately, and do not copy saved session state from the host. [DEC-008]

Evaluate Sesh (`https://github.com/joshmedeski/sesh`) in the VM as the candidate replacement for Sessionx. Preserve Prefix+o (Ctrl+A followed by lowercase o) as the session-selector binding. Validate selecting an existing session, creating a session from a Zoxide directory, cancelling without side effects, and coexistence with automatic restoration. Sesh manages session selection and creation; it does not replace Resurrect/Continuum. Final adoption and the reproducible package installation approach remain conditional on VM validation and review; installing both Sesh and Sessionx is not the intended permanent solution. [DEC-008]

## Neovim Integration Scope

Integrate the complete configuration from `https://github.com/viespejo/nvim-lua-new` and install its plugins, preserving the repository as the authoritative source. Validate editing, fuzzy search, clipboard behavior, and navigation with Tmux. Provision the external tools required to work on MirrorOS, not every supported language server or debugger. The exact tooling list and installation behavior still require inspection and agreement. [DEC-003, DEC-009]

Account-dependent integrations remain available through explicit private authentication steps. Configuration installation must neither commit credentials nor imply that an authenticated service is ready. [DEC-001, DEC-009]

## Existing Laboratory and Product Boundary

Reuse `~/qemu/mirroros-lab`. Accept the maintainer's confirmation that bidirectional clipboard works; do not reopen SPICE configuration or make renewed clipboard validation a preparation prerequisite. Do not plan a new checkpoint at this stage. [DEC-011]

Validated component configuration must become the MirrorOS defaults through the agreed integration boundaries. Credentials, personal state, and laboratory-only transport tooling are not product defaults. Conditional candidates, including Sesh, still require their agreed validation before adoption. [DEC-008, DEC-011]

## Host Configuration Protection

Make all necessary Zsh and Tmux configuration changes inside the VM's MirrorOS checkout, never in the host's local dotfiles checkout. This restriction applies even though the host agent coordinates preparation. MirrorOS, not external dotfiles, owns the resulting product defaults. [DEC-014, DEC-016]

## Superseded Dotfiles Publication Approach

The dedicated external dotfiles branch and publication workflow from DEC-015 are superseded. Zsh and Tmux defaults are developed within MirrorOS inside the VM. Host dotfiles remain reference material only. [DEC-016]

## Host-to-Guest Access

Use SSH with a dedicated laboratory key for preparation and diagnosis from the host, without copying host private keys into the guest or enabling root SSH access. Keep graphical-console access for Foot, clipboard, and key-binding validation. Inspect whether SSH is already available; enablement is conditional on that inspection, not an established prerequisite already satisfied. [DEC-010]

Any bootstrap password must be supplied through a protected interactive runtime step. Do not persist its value in source, interview artifacts, scripts, command arguments, or retained evidence. No supplied credential value is recorded here. [DEC-001, DEC-010]
