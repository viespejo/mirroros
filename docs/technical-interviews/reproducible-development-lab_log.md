# Reproducible Development Laboratory — Decision Log

## DEC-001
- **Question**: Should this work prepare an isolated laboratory overlay only, or also promote the validated terminal and agent environment into MirrorOS?
- **Context/Nuances**: The current guest provides a minimal Foot configuration, Bash with Starship initialization, and Tmux without project configuration. The maintainer wants the desired Foot, shell, Tmux, and Pi environment both for ongoing guest-side research and eventually as the MirrorOS environment. Preparation must be reproducible rather than recoverable only through a VM checkpoint. Independent configuration repositories must remain authoritative; credentials and private state must remain outside product source. Earlier laboratory-only suggestions were proposals, not accepted decisions.
- **User Response**: The maintainer requested that the Foot, shell, Tmux, and Pi work be incorporated into MirrorOS after VM validation, then explicitly confirmed the revised DEC-001 and authorized immediate persistence in interview artifacts.
- **Decision**: Prepare the desired Foot, shell, Tmux, and Pi environment from the host, validate it inside the guest, and then incorporate the approved configurations and integrations into the product. Reuse authoritative configuration sources without copying configuration trees owned by independent repositories. Exclude credentials and private state from product source. Treat checkpoints as conveniences, not the reconstruction source of truth. Completion requires reconstructing the environment in another VM from the incorporated declarations, with explicit private-input steps and no undocumented manual adjustments.
- **Status**: Accepted

## Open Questions

- What exact host configuration and behavior should be reproduced?
- Which existing story responsibilities are advanced by this work?
- Should preparation and product promotion be delivered in one executable plan or separate plans?
- Where should the reproducible laboratory preparation procedure and any justified automation live?
- How should host-to-guest access, configuration ownership conflicts, source revisions, and private authentication be handled?

## DEC-002
- **Question**: Which host configuration sources may be inspected, and what access restrictions apply?
- **Context/Nuances**: The host uses Kitty, Zsh, and Tmux rather than the guest's minimal Foot and Bash environment. Relevant files are under `~/.dotfiles`. Inspection found terminal key mappings, Zsh plugins and tool integrations, and Tmux plugins. The general dotfiles installer copies unrelated configuration and must not be treated as an approved installation approach. Only the top-level structure of `~/.dotfiles-local` has been listed; its contents have not been read.
- **User Response**: The maintainer identified `~/.dotfiles` and optional personal additions in `~/.dotfiles-local`, explicitly prohibited reading `~/.zcustom` even when referenced, and approved this registration.
- **Decision**: Use the Kitty, Zsh, and Tmux configuration in `~/.dotfiles` as reference sources. Do not read or execute `~/.zcustom`, including through links or references. No configuration sourcing is authorized by this inspection. Do not incorporate private local additions at this stage; whether specific files in `~/.dotfiles-local` are needed remains unresolved. Select relevant configuration rather than executing the complete dotfiles installer. This decision does not select Kitty over Foot or finalize Zsh integration.
- **Status**: Accepted

## DEC-003
- **Question**: Should Neovim configuration be included in this work?
- **Context/Nuances**: The previously agreed scope covered Foot, shell, Tmux, and Pi. An independent Neovim configuration repository is available; its integration mechanism, dependencies, and validation have not yet been inspected or agreed.
- **User Response**: The maintainer explicitly added Neovim configuration to this plan and identified `https://github.com/viespejo/nvim-lua-new` as its repository.
- **Decision**: Include Neovim configuration in the scope of this work, using `https://github.com/viespejo/nvim-lua-new` as its authoritative configuration repository under the independent-repository boundary established by DEC-001. The installation and integration approach remains pending investigation and agreement.
- **Status**: Accepted

## DEC-004
- **Question**: Should the environment retain Foot or evaluate replacing it with the host's Kitty terminal?
- **Context/Nuances**: MirrorOS already declares Foot, whereas the host uses Kitty. Kitty configuration includes font preferences, key mappings, Shift+Enter encoding, and editor overlays for command output and scrollback. Equivalent behavior in Foot must not be assumed.
- **User Response**: The maintainer approved the recommendation to retain Foot initially and requested direct registration in the interview artifacts.
- **Decision**: Retain Foot initially and adapt the required host terminal behaviors rather than replacing it with Kitty. Validate Shift+Enter in Pi, clipboard behavior, fonts, and operation inside Tmux. Do not assume Kitty editor overlays have direct Foot equivalents; if an overlay capability proves essential, evaluate it explicitly before finalizing terminal suitability.
- **Status**: Accepted

## DEC-005
- **Question**: Which interactive shell should be used, given the maintainer's concern about slow shell startup on the host?
- **Context/Nuances**: The maintainer initially explored reproducing Zsh functionality in Bash and considered Fish, then explicitly chose to retain Zsh and improve startup performance. The inspected host configuration initializes Zplug, checks plugins during startup, and integrates Starship, Zoxide, Atuin, and completions. These are measurement candidates, not established causes of latency. Earlier Bash-enrichment and Fish-first proposals were not accepted decisions.
- **User Response**: The maintainer chose Zsh, requested an effort to make it faster than the host environment, and explicitly approved the revised decision for immediate registration.
- **Decision**: Use Zsh as the user's interactive shell; MirrorOS scripts remain Bash. Build the guest configuration around the approved interactive features, measure startup, and optimize demonstrated costs. Install plugins during preparation rather than checking them or prompting for installation whenever a terminal opens. Compare minimal and full guest configurations and verify that optimizations preserve approved completion, history, vi editing, and key-binding behavior. Do not read `~/.zcustom` or execute the host configuration. Do not claim a quantified improvement over the host without an authorized comparable measurement. Exact required features and a performance acceptance criterion remain open.
- **Status**: Accepted

## DEC-006
- **Question**: Which interactive Zsh features are essential for the initial usable environment and its performance validation?
- **Context/Nuances**: The host configuration provides a broad set of integrations. A defined functional baseline is needed to optimize startup without silently removing valued behavior. Extra aliases and alias advice need not block initial shell validation.
- **User Response**: The maintainer approved the proposed core feature list and requested direct registration in the interview artifacts.
- **Decision**: Preserve Starship as the prompt, vi editing mode, autosuggestions, syntax highlighting, menu completion with reverse navigation, Fzf file and directory search with previews, Zoxide navigation, Atuin history, and Ctrl+Space to accept suggestions. Atuin synchronization and authentication are not required to validate the environment. Additional aliases and alias-tips remain deferred for later review, not rejected and not prerequisites for the first startup validation. Exact implementations and initialization order remain subject to investigation and validation.
- **Status**: Accepted

## DEC-007
- **Question**: Should shell performance have an immediate numerical threshold, or should measurements establish a meaningful target first?
- **Context/Nuances**: The guest's performance baseline is unknown. Executing the host configuration is excluded, and a minimum-shell benchmark alone would not represent the required interactive experience. No numerical improvement over the host can be claimed from guest-only measurements.
- **User Response**: The maintainer approved delivering measurements and justified optimizations, with the numerical threshold deferred until the first VM measurement, and requested direct registration.
- **Decision**: Compare minimal Zsh and Zsh with all approved interactive features inside the VM. Measure repeated openings, distinguishing the first startup from subsequent startups, and assess both prompt availability and initial responsiveness. Identify major costs and repeat measurements after optimizing demonstrated bottlenecks. Do not accept improvements obtained by removing required features. Deliver measurements and justified optimizations; defer agreement on a numerical threshold until the first VM measurement. Do not execute the host configuration for comparison or claim a measured improvement over the host from these guest-only results.
- **Status**: Accepted

## DEC-008
- **Question**: Which session-management and restoration components should the Tmux environment retain?
- **Context/Nuances**: The host uses Ctrl+A as its prefix and binds Sessionx to lowercase o. The maintainer does not use Floax and wants to retain automatic restoration. After discussing Sessionx, the maintainer proposed Sesh as an alternative. Upstream Sesh documentation describes a standalone session-management CLI with Zoxide and Fzf integration; it is not a replacement for Resurrect/Continuum. Its reproducible installation mechanism has not been selected. The earlier proposal to retain Sessionx provisionally was not accepted or registered.
- **User Response**: The maintainer approved excluding Floax, preserving automatic restoration, and evaluating Sesh as a replacement for Sessionx, and requested direct registration.
- **Decision**: Exclude Floax from the intended environment. Retain automatic restoration through Resurrect and Continuum, validating their behavior without copying host session state. Evaluate Sesh in the VM as the candidate replacement for Sessionx, preserving Prefix+o (Ctrl+A followed by o) for its selector. Validate selecting an existing session, creating a session from a Zoxide directory, cancellation without side effects, and coexistence with session restoration. Do not adopt both Sesh and Sessionx as the permanent solution. Final Sesh adoption and its reproducible installation mechanism remain conditional on validation and review.
- **Status**: Accepted

## DEC-009
- **Question**: Should Neovim integration provision every supported development language, or focus external tooling on MirrorOS work?
- **Context/Nuances**: The authoritative Neovim repository uses lazy.nvim and declares integrations for language servers, formatting, debugging, and AI assistance. Integrating the configuration does not automatically provision or validate every external dependency or authenticated service.
- **User Response**: The maintainer approved the recommended bounded Neovim scope and requested direct registration.
- **Decision**: Integrate the complete Neovim configuration from its authoritative repository and install its plugins. Validate editing, fuzzy search, clipboard behavior, and navigation integration with Tmux. Provision external tools needed for working on MirrorOS rather than preinstalling every language server and debugger supported by the configuration. Account-dependent integrations remain available through explicit private authentication steps, without committing credentials or treating authentication as completed by configuration installation. The exact MirrorOS tooling list and dependency installation behavior still require inspection and agreement.
- **Status**: Accepted

## DEC-010
- **Question**: How should the host agent access the laboratory guest for preparation and diagnosis?
- **Context/Nuances**: Host-side preparation requires a recoverable guest access path. Graphical checks still require the guest's graphical session. The maintainer supplied a laboratory password in chat; its value must not be persisted in interview artifacts, product source, scripts, command arguments, or retained evidence. Whether SSH is already enabled remains unconfirmed.
- **User Response**: The maintainer approved the recommended host-to-guest access approach, requested registration, and supplied a private runtime credential for laboratory use.
- **Decision**: Use SSH with a dedicated laboratory key for host-agent access. Do not copy host private keys into the guest or enable root SSH access. Retain graphical-console access for Foot, clipboard, and key-binding validation. Handle any required bootstrap password through a protected interactive runtime step, not persisted configuration or command arguments. Inspect existing SSH availability before deciding whether enablement is required; existing access has not been confirmed.
- **Status**: Accepted

## DEC-011
- **Question**: Is the intended deliverable a laboratory checkpoint, or validated default configuration incorporated into MirrorOS?
- **Context/Nuances**: The existing laboratory is at `~/qemu/mirroros-lab`. Its launcher supports SPICE and optional localhost-only SSH forwarding. The maintainer confirmed that bidirectional clipboard already works and rejected reopening that validation as prerequisite work. The maintainer also deferred checkpoint decisions and clarified that validated component configuration must eventually become the MirrorOS defaults, not remain a permanent laboratory overlay.
- **User Response**: The maintainer approved the revised scope and requested direct registration.
- **Decision**: Reuse the existing laboratory and accept the maintainer's confirmation of working clipboard without reopening SPICE configuration. Validate the in-scope component configurations in the guest and incorporate the approved results as reproducible MirrorOS defaults, respecting authoritative external configuration repositories. Product promotion is a required outcome of this work, not optional follow-up work. Credentials, personal state, and laboratory-only transport tooling are excluded from product defaults. Leave checkpoint decisions outside the current agreed design. Conditional candidates such as Sesh still require their agreed validation before adoption.
- **Status**: Accepted

## DEC-012
- **Question**: Where should Zsh and Tmux configuration remain authoritative, and where should native Foot configuration live?
- **Context/Nuances**: The host's existing dotfiles contain Zsh and Tmux configuration, while its terminal is Kitty. Running the general dotfiles installer is excluded. External sources must retain ownership, and any shared-source changes need care to avoid host regressions.
- **User Response**: The maintainer approved the recommendation and requested direct registration.
- **Decision**: Keep the existing dotfiles repository represented by `~/.dotfiles` authoritative for Zsh and Tmux. Integrate only the selected configurations without running its general installer. Make required portability and shell-performance changes in that source repository while protecting host behavior. Keep native Foot configuration in MirrorOS rather than inventing a Kitty configuration conversion layer. The precise integration mechanism and repository revision policy remain unresolved.
- **Status**: Accepted

## DEC-013
- **Question**: What source owns the maintainer's personal Pi extensions, and what additional local configuration may be inspected?
- **Context/Nuances**: The maintainer supplied the remote for the already identified Pi configuration repository and authorized inspection of `~/.pi` for the remaining Pi configuration. That directory may also contain private runtime state, which is not needed for configuration discovery and must not be copied into product defaults.
- **User Response**: The maintainer identified `https://github.com/viespejo/pi-config` as the repository for personal Pi extensions, pointed to `~/.pi` for the remaining setup, and requested registration.
- **Decision**: Use `https://github.com/viespejo/pi-config` as the authoritative source for personal Pi extensions. Inspect the structure and relevant non-secret configuration in `~/.pi` to identify the rest of the intended integration, excluding credentials, session contents, and histories from inspection and product configuration. The final selected Pi components, installation mechanism, and private authentication procedure remain unresolved.
- **Status**: Accepted

## DEC-014
- **Question**: Where may Zsh and Tmux configuration changes be made without altering the host environment?
- **Context/Nuances**: DEC-012 retains the dotfiles repository as the authoritative configuration source. This does not authorize modifying its host checkout. Guest-side source changes must eventually be made available to MirrorOS, but the publication and revision-selection mechanism has not been agreed.
- **User Response**: The maintainer explicitly required all necessary Zsh and Tmux changes to be made inside the VM, never in the host's local repository.
- **Decision**: Make Zsh and Tmux configuration changes only in working copies inside the VM. Never modify the host's local dotfiles repository as part of this work. Host inspection remains limited by the existing access boundaries. Preserve the authoritative repository ownership established by DEC-012; how validated guest-side changes are published and selected for MirrorOS consumption remains unresolved and requires agreement.
- **Status**: Accepted

## DEC-015
- **Question**: How should validated guest-side dotfiles changes become available for reproducible MirrorOS integration?
- **Context/Nuances**: DEC-014 prohibits changing the host checkout. Leaving configuration changes only on the guest disk would not satisfy the reconstruction requirement. Approval of the publication workflow is not authorization to push a particular revision.
- **User Response**: The maintainer approved a dedicated guest-side branch, publication after explicit review and authorization, and consumption of the approved revision without updating the host checkout; immediate registration was requested.
- **Decision**: Work on Zsh and Tmux changes in a dedicated branch of the dotfiles repository inside the VM. Publish validated changes only after the maintainer reviews them and explicitly authorizes publication. MirrorOS must consume the approved revision without updating the host checkout. Do not interpret this decision as advance authorization to push changes. The branch name, exact revision, and revision handling for other external repositories remain unresolved.
- **Status**: Accepted

## DEC-016
- **Question**: Should MirrorOS consume Zsh and Tmux configuration from external dotfiles, or own these defaults directly?
- **Context/Nuances**: A normal branch of the host dotfiles repository retains unrelated configuration. The maintainer clarified that this is a personal distribution and that its Zsh and Tmux defaults should live in MirrorOS itself. Neovim and personal Pi extensions already have dedicated authoritative repositories. The proposal to pin commits for all three external repositories was not accepted; dotfiles is no longer an intended external integration.
- **User Response**: The maintainer explicitly approved MirrorOS ownership of Zsh and Tmux configuration and requested direct registration. A separate suggestion to expand pi-config beyond extensions still needs its precise boundary confirmed.
- **Decision**: Maintain native Zsh and Tmux configuration directly in MirrorOS as product defaults, alongside native Foot configuration. Use host dotfiles only as an initial reference, selecting necessary behavior and files without importing the full repository or its history. Preserve applicable third-party attribution. Make Zsh and Tmux adjustments and tests in the VM's MirrorOS checkout, never in the host's local dotfiles repository. This supersedes the external-dotfiles ownership and upstream-editing portions of DEC-012 and the dotfiles branch/publication workflow of DEC-015; the host protection boundary remains in force. Neovim and pi-config retain their independent authoritative repositories. External revision policy remains unresolved and no longer includes dotfiles.
- **Status**: Accepted

## DEC-017
- **Question**: Should all portable Pi configuration move into pi-config, or should MirrorOS own the application defaults separately from external extension resources?
- **Context/Nuances**: `~/.pi` is a runtime configuration and state location, not necessarily an authoritative source. It can mix portable settings with credentials and generated state. The earlier proposal to expand pi-config to all portable configuration was not accepted. Ownership must avoid two competing sources for the same file.
- **User Response**: The maintainer approved MirrorOS ownership of Pi defaults and separate pi-config ownership of its extensions and resources, and requested direct registration.
- **Decision**: MirrorOS owns Pi installation, portable default settings, key bindings, and component selection, applying them at the appropriate Pi configuration locations. `https://github.com/viespejo/pi-config` remains authoritative for its personal extensions and other resources maintained there. Integrate those external resources explicitly without copying their configuration trees into MirrorOS. Assign each managed file a single authoritative owner, with no duplicate competing versions. Credentials, sessions, caches, and local runtime state belong only on the device and must not be committed to either repository. Inspect relevant non-secret host configuration to determine the exact file ownership mapping before implementation.
- **Status**: Accepted

## DEC-018
- **Question**: Should configure pin external configuration indefinitely, or synchronize both new and existing devices with current external configuration?
- **Context/Nuances**: The maintainer wants future installations and existing devices to receive current personal configuration. Permanent commit pinning was proposed but not accepted. Idempotency means avoiding unnecessary mutations when inputs are unchanged, not refusing updates when declared external sources change. The same ISO can therefore apply different external revisions at different times. Updating the MirrorOS code that owns native defaults is a separate unresolved concern.
- **User Response**: The maintainer approved the proposed synchronization policy and requested direct registration.
- **Decision**: On new installations and subsequent synchronization runs, configure obtains the latest revision of the selected branches of the Neovim and pi-config repositories. Resolve each revision once per execution and record the applied commit. Avoid unnecessary changes when sources are unchanged. Stop with an actionable explanation for unsaved local changes or divergent histories; do not overwrite local work or force a reset. Report download or application failures without presenting the device as synchronized. Accept that the same ISO can apply different external configuration revisions over time. MirrorOS-owned defaults come from the checkout or installed code copy being executed; updating that code remains to be agreed separately.
- **Status**: Accepted

## DEC-019
- **Question**: How should an installed device receive newer MirrorOS-owned defaults without reinstalling?
- **Context/Nuances**: During ISO installation, native Foot, Zsh, Tmux, and Pi defaults come from the MirrorOS code included in the build, whereas external Neovim and pi-config sources follow DEC-018. Repeating configure from the same installed code copy does not update MirrorOS itself. The existing installed mirroros-configure snapshot is not automatically synchronized with a separate checkout.
- **User Response**: The maintainer confirmed that users should download or update the MirrorOS repository and run configure in running mode, then explicitly authorized registration.
- **Decision**: To apply newer MirrorOS-owned defaults on an installed device, explicitly clone MirrorOS or update an existing checkout to the desired revision, then execute that checkout's operations/configure in running mode. This applies that revision's product defaults and synchronizes external configuration under DEC-018 without reinstalling or rebuilding the ISO. Configure does not automatically update its own MirrorOS code. The older installed mirroros-configure snapshot remains distinct and is not implicitly updated by using the checkout.
- **Status**: Accepted

## DEC-020
- **Question**: How should the user Node.js runtime be managed without slowing interactive Zsh startup, and how does it relate to the existing live ISO runtime?
- **Context/Nuances**: Inspection of the explicitly identified `~/.dotfiles-local/zsh/zshrc_local` confirmed that the host adds an NVM-installed Node version's bin directory directly to PATH and loads NVM and its completions through the nvm_load alias only on demand. The file was read, not executed; unrelated personal configuration is not selected for incorporation. No references to `~/.zcustom` were followed. Repository inspection found nodejs in image/archiso/packages.x86_64 for live installation logic, but not in the target base package declaration in install/plan/policy.json or the current capability package declarations. Actual guest package state has not been inspected.
- **User Response**: The maintainer confirmed the direct-PATH and on-demand NVM pattern, asked about existing base installation, and then explicitly requested registration after the live-versus-target distinction was explained.
- **Decision**: Manage the user's Node.js runtime with NVM. Make the selected installed version's bin directory available through a portable PATH configuration without unconditionally sourcing NVM during Zsh startup. Provide nvm_load for on-demand loading of the manager and its completions. Do not require loading NVM manually before using Node.js, npm, or installed global executables such as Pi. Ensure the required runtime is explicitly available to relevant non-interactive operations rather than assuming they read interactive Zsh configuration. Retain the ISO's existing system nodejs for installer responsibilities; the user runtime decision does not replace it. The selected Node version, NVM installation and provenance, PATH implementation, and detailed non-interactive integration remain to be agreed or validated.
- **Status**: Accepted

## DEC-021
- **Question**: Which initial Node.js version should the NVM-managed user environment use, and how should future updates be selected?
- **Context/Nuances**: Matching the host's v24.15.0 was proposed but not accepted. The official release index at https://nodejs.org/dist/index.json was checked during the interview and listed v24.22.0 as LTS and v26.12.0 as Current, both dated 2026-10-14. This selects an initial runtime, not an automatic latest-version policy. Pi and Neovim integration still require VM validation.
- **User Response**: The maintainer approved proceeding with v24.22.0 and explicit future runtime updates in MirrorOS.
- **Decision**: Declare Node.js v24.22.0 as the initial user runtime installed through NVM under DEC-020. Future changes to the selected runtime version must be explicit changes in MirrorOS rather than automatic selection of the latest Node.js version during configure. This policy is separate from tracking the selected external configuration branches under DEC-018. Validate compatibility with Pi and the in-scope Neovim integrations in the VM.
- **Status**: Accepted

## DEC-022
- **Question**: Which installation mechanism should provide the Pi executable in the selected NVM-managed user runtime?
- **Context/Nuances**: The installed Pi documentation explicitly supports npm installation of @earendil-works/pi-coding-agent with --ignore-scripts and states that normal installation does not require dependency lifecycle scripts. Unlike the alternative Pi installer, this npm route does not itself pin all transitive dependencies. Selecting the installation mechanism does not select a Pi version or an update policy.
- **User Response**: The maintainer approved npm installation and requested direct registration.
- **Decision**: Install @earendil-works/pi-coding-agent with npm in the user's selected NVM environment, without sudo and with --ignore-scripts. Do not introduce a second Pi installation mechanism for this environment. Record the installed Pi version and do not claim that npm installation alone pins all transitive dependencies. Pi version selection and update policy remain unresolved.
- **Status**: Accepted

## DEC-023
- **Question**: How should configure update Pi, and who resolves compatibility problems with personal extensions?
- **Context/Nuances**: DEC-022 selected npm installation but left version policy open. The proposed policy tracks the latest stable Pi release while DEC-018 tracks current external configuration branches. Those moving sources do not guarantee mutual compatibility. Node.js retains its distinct explicitly declared version policy.
- **User Response**: The maintainer approved the proposed Pi update policy and clarified that extension integration problems will be resolved manually by the user, either by downgrading Pi or updating the extensions.
- **Decision**: Configure installs or updates Pi to the latest stable available release, resolving the selected version once per execution and recording the applied version. Do not reinstall unnecessarily when that version is already installed. Check extension loading and expose detected integration failures without claiming verified integration. Compatibility repair belongs to the user: do not add automatic extension repair, compatibility-version selection, or silent Pi downgrades. The user may manually downgrade Pi or update extensions to resolve a problem; how a subsequent configure run treats that manual downgrade remains unresolved. Node.js continues to use the explicit MirrorOS version declaration under DEC-021, not automatic latest-version tracking.
- **Status**: Accepted

## DEC-024
- **Question**: Should the Pi executable version follow the development dependency in pi-config, and what fallback applies when that declaration is absent?
- **Context/Nuances**: The maintainer tests Pi upgrades against personal extensions by updating local development dependencies before changing the global host executable. The inspected pi-config package.json declares an exact @earendil-works/pi-coding-agent version in devDependencies and a wildcard in peerDependencies. A declared version identifies the intended tested pairing but does not itself prove compatibility or pin every transitive dependency. This supersedes DEC-023's unconditional latest-stable selection, not its manual-repair boundary.
- **User Response**: The maintainer approved selecting the declared version with an exception for an absent declaration, then explicitly confirmed that the fallback means the latest stable published release and requested registration.
- **Decision**: Resolve the pi-config revision selected for the configure execution and use its exact devDependencies entry for @earendil-works/pi-coding-agent as the Pi executable version to install through the npm/NVM mechanism. If that dependency is absent, use the latest stable published Pi release, resolving the fallback version once per execution. If the dependency is present but contains a range or invalid value, stop with an actionable explanation rather than silently ignoring it or selecting another version. Record the resolved pi-config commit and applied Pi version. This replaces DEC-023's unconditional latest-stable policy; manual compatibility repair remains the user's responsibility. Do not claim that the declaration alone guarantees compatibility. The selected dependency version, when present, is authoritative for a subsequent configure run rather than any ad hoc manual global downgrade.
- **Status**: Accepted

## DEC-025
- **Question**: Where and how may necessary Neovim or pi-config adjustments be developed during guest validation?
- **Context/Nuances**: Neovim and pi-config retain independent authoritative repositories, unlike MirrorOS-owned terminal and Pi defaults. Guest validation may reveal integration adjustments. Experimental changes must not silently replace the normal configuration branches consumed by devices, and workflow approval does not authorize any specific publication.
- **User Response**: The maintainer approved the guest-side branch and explicit publication-review workflow for both external repositories and requested direct registration.
- **Decision**: Make necessary Neovim and pi-config adjustments on branches inside the VM, never in their host checkouts. Publish changes only after maintainer review and explicit authorization. MirrorOS continues to consume the repositories' usual branches under DEC-018; experimental branches do not automatically become product defaults. Concrete branch names and any publication or promotion require the appropriate explicit authorization.
- **Status**: Accepted

## DEC-026
- **Question**: Should the Pi environment omit voice/TTS because it is disabled on the host and the current VM has no audio device?
- **Context/Nuances**: Inspection of the authorized host settings and keybindings found personal UI/model/resource settings, additional Pi packages, and voice/TTS configuration with both features disabled. The maintainer rejected excluding these features merely because activation and hardware support differ between devices. Configuring a feature does not imply enabling it or copying downloaded model data.
- **User Response**: The maintainer required Pi to match the host's functional configuration, leaving activation to the user on the VM or target laptop, and approved registration of the clarified scope.
- **Decision**: Reproduce the host's functional Pi configuration, including settings, keybindings, package and resource selection, and voice/TTS configuration. Preserve current activation states; do not enable voice or TTS automatically. Exclude credentials, sessions, caches, generated state, and nonportable personal paths. Lack of working VM audio must not block validation of the remaining environment. Review dependencies and model downloads separately: including voice/TTS configuration does not authorize copying host models or require their automatic download. Retain DEC-017 ownership boundaries between MirrorOS defaults, pi-config resources, and device-local private state.
- **Status**: Accepted

## DEC-027
- **Question**: Should configure download local voice/TTS models even when those features are disabled?
- **Context/Nuances**: DEC-026 preserves the host's complete functional configuration without automatically activating voice/TTS or copying host models. Downloading models during ordinary configuration would add large transfers for disabled functionality. The extension's support for on-demand acquisition has not yet been verified.
- **User Response**: The maintainer approved on-demand model downloads and requested direct registration.
- **Decision**: Do not download local voice/TTS models during configure while those features are disabled. Obtain models on demand using the extension's supported mechanism if available; verify that mechanism before implementation and do not assume support. Do not copy downloaded models from the host. Preserve voice/TTS preferences independently of model availability. If upstream does not support the intended on-demand workflow, surface the limitation for review rather than silently introducing custom download automation or eager downloads.
- **Status**: Accepted

## DEC-028
- **Question**: Should configure continuously manage Pi's user configuration, or initialize ~/.pi only when absent?
- **Context/Nuances**: Pi reads settings and keybindings as strict JSON, so the existing comment-header ownership mechanism cannot be used directly. External ownership markers and selective JSON merging were discussed but never accepted. Pi and extensions can create or modify files under ~/.pi. The maintainer chose an initialization-only boundary instead of adding ownership and merge machinery. The directory can also contain credentials, sessions, and other private state.
- **User Response**: The maintainer requested installation-only handling: preserve an existing ~/.pi unchanged, and require manual removal to receive fresh configuration. The maintainer then explicitly approved the summarized decision and requested registration.
- **Decision**: Initialize ~/.pi with the approved initial configuration only when the directory does not exist. If ~/.pi already exists, leave it entirely untouched and report that it was preserved. Do not add ownership markers, merge JSON keys, adopt new files, or automatically reset the directory. Receiving new Pi defaults requires the user to manually move or remove ~/.pi and rerun configure; recommend renaming it as a backup rather than deleting credentials, sessions, and other state. This supersedes continuous management of Pi defaults inside ~/.pi, not the native Foot, Zsh, or Tmux policies. It does not by itself change Pi executable installation/version selection or synchronization policy for the external pi-config repository. Ensure implementation respects the preserved-directory boundary when arranging external resources. Initialization details must be validated without modifying an existing ~/.pi.
- **Status**: Accepted

## DEC-029
- **Question**: Where should the external Pi and Neovim configuration repositories be checked out?
- **Context/Nuances**: DEC-028 prohibits modifying an existing ~/.pi, while DEC-018 retains synchronization of external configuration sources. Keeping the pi-config checkout outside ~/.pi separates repository synchronization from initialization of Pi's configuration directory. User-accessible source locations also support manual review and development.
- **User Response**: The maintainer approved ~/code/pi-config and ~/code/nvim and requested direct registration.
- **Decision**: Use ~/code/pi-config for the user's clone of https://github.com/viespejo/pi-config and ~/code/nvim for the user's clone of https://github.com/viespejo/nvim-lua-new. Integrate the external sources through links from the appropriate configuration locations rather than copied trees. Create Pi resource links only when initializing an absent ~/.pi; do not add or change links inside an existing ~/.pi. Synchronize the external clones under DEC-018 and its local-change protections. Resolve paths for the selected target user's home, not the host user's absolute paths. Existing unrelated checkout or configuration-path conflicts must not be silently overwritten.
- **Status**: Accepted

## DEC-030
- **Question**: Which initial visual settings should native Foot configuration reproduce from the host's Kitty setup?
- **Context/Nuances**: Host Kitty selects the Tokyo Night palette, JetBrainsMono Nerd Font Mono at size 14, and padding 4. Current MirrorOS Foot configuration selects JetBrainsMono Nerd Font at size 11, and capabilities/desktop/terminal/packages already declares ttf-jetbrains-mono-nerd from extra. The host theme file identifies Folke Lemaitre's tokyonight.nvim as its MIT-licensed origin. Sharing a font package does not prove identical font matching or visual rendering across terminals.
- **User Response**: The maintainer approved the proposed Foot appearance and requested registration, also asking whether the font was already provided by MirrorOS.
- **Decision**: Translate the host's Tokyo Night palette, JetBrains Mono font at size 14, and padding 4 into native Foot configuration. Reuse the existing ttf-jetbrains-mono-nerd package; validate the selected family/Mono variant and visual result in the VM rather than assuming exact cross-terminal equivalence. Keep this change limited to the terminal, not global desktop theming, and preserve applicable theme attribution.
- **Status**: Accepted

## DEC-031
- **Question**: Should the agreed work be split into consecutive terminal and agent/editor plans, or delivered through one integrated plan?
- **Context/Nuances**: The scope includes Foot, Zsh, Tmux, NVM, Pi, Neovim, external configuration synchronization, guest validation, and required promotion to MirrorOS defaults. A split into 02-17 and 02-18 with an explicit dependency was proposed but not accepted. Internal task ordering does not require separate plan files.
- **User Response**: The maintainer explicitly selected a single plan.
- **Decision**: Deliver the entire agreed scope through one executable plan, with ordered tasks and validation gates rather than separate terminal and agent/editor plans. Do not introduce a second plan or a dependency from the rejected split. Preserve the selected empty dependency list and the requirement to deliver reproducible product defaults, not merely a disposable laboratory environment. The supplied 02-17 numbering remains the draft candidate.
- **Status**: Accepted

## DEC-032
- **Question**: How should NVM be installed, and does reviewing its installer imply runtime manual review by configure?
- **Context/Nuances**: A Git-based release installation was proposed but not accepted. Discussion clarified that curl and Bash are not inherently excluded and that upstream review is integration work, not distrust specific to NVM. The relevant review establishes official origin, selected version, installation effects, and how to prevent automatic shell-profile edits. It is not a full audit of NVM or a repeated interactive installation step.
- **User Response**: The maintainer confirmed using an identified version of the official installer as the user, without automatic shell-profile modification, and explicitly authorized registration after clarifying that review occurs during integration development rather than runtime.
- **Decision**: Use the official NVM installer from an identified version, executing it as the target user and preventing automatic shell-profile edits. Review its origin and relevant behavior while developing the configure integration and when changing the selected version or installation mechanism. Runtime configure performs automated prerequisite, source identity or integrity checks as supported by the source, installation-result checks, and postconditions; it does not audit code or prompt for manual installer review on each run. Keep the separately approved direct-PATH and on-demand nvm_load behavior. The concrete NVM version, retrieval details, and documented installer options must be established during source inspection before implementation; no installation has been authorized by this planning decision.
- **Status**: Accepted

## DEC-033
- **Question**: Should the guest initially retain the host's Zplug plugin manager or replace it before measuring startup costs?
- **Context/Nuances**: The host already uses Zplug for its interactive features. DEC-005 moves plugin installation out of shell startup, and DEC-007 requires guest measurements and justified optimizations. Retaining Zplug initially does not establish that it is fast enough or that it causes the host's latency.
- **User Response**: The maintainer approved Zplug as the initial guest configuration baseline and requested direct registration.
- **Decision**: Retain Zplug as the initial Zsh plugin manager in the VM. Provision plugins during configuration preparation rather than checking for installation or prompting on each shell startup. Measure Zplug's contribution within the complete approved interactive feature baseline before proposing replacement. Any replacement requires evidence and explicit review rather than an unsupported assumption that the manager is responsible for host startup latency.
- **Status**: Accepted

## DEC-034
- **Question**: Should final guest validation include a real Pi conversation, and how should provider authentication be handled?
- **Context/Nuances**: Binary installation and resource discovery alone do not demonstrate that the maintainer can investigate with Pi inside the guest. The host has multiple configured providers, but authenticating every provider is not necessary for this bounded functional check. Private credentials and conversation content are not reconstruction evidence.
- **User Response**: The maintainer approved a final real-conversation check with private guest-side authentication and requested direct registration.
- **Decision**: Include a manual final functional test consisting of a real Pi conversation inside the guest using one provider authenticated privately by the maintainer. Do not copy host credentials, require authentication of every configured provider, or retain secrets or conversation content as evidence. Record only a non-secret outcome where needed. Configuration and package installation must remain distinct from the private authentication step; do not imply authenticated readiness solely from successful installation.
- **Status**: Accepted

## DEC-035
- **Question**: Which remaining host Tmux behaviors should become the MirrorOS baseline beyond the session-management exceptions already agreed?
- **Context/Nuances**: DEC-008 excludes Floax, evaluates Sesh instead of Sessionx, and retains automatic restoration. The inspected host configuration also provides window/pane bindings, Neovim-aware navigation, selection/copy workflows, fuzzy text and URL selection, mouse support, and visual settings. It includes host-specific paths and inherited references to another user's directories that must not be carried into portable defaults.
- **User Response**: The maintainer approved preserving the remaining proposed Tmux experience and requested direct registration.
- **Decision**: Preserve Ctrl+A as the prefix, window and pane bindings, Neovim-integrated navigation, copy/selection workflows, text and URL search/selection, mouse support, and the host's Tmux appearance as the MirrorOS baseline. Retain DEC-008's Floax exclusion, conditional Sesh replacement of Sessionx, and automatic restoration. Adapt host-specific paths and omit inherited references to other users from the new MirrorOS defaults. Do not alter the host configuration or copy saved session state.
- **Status**: Accepted
