# Story 4.2 — Minimal Graphical Login Through Configure: Decision Log

Append-only record of the technical interview that plans Story 4.2 (walking skeleton of Epic 4).

## DEC-001
- **Question**: Does Story 4.2 fit in one plan, or should it be split?
- **Context/Nuances**: The story combines three risk blocks: (A) the `configure` mechanism (entry point, validation before mutation, failure outcome, rerun safety, evidence, script layout); (B) the skeleton content (SDDM stock theme, uwsm with minimal Hyprland, terminal, interactive shell, tmux, provider selection in `docs/mvp-scope.md`); (C) the target-root context (embedding in the ISO, installer hook after base postconditions, `arch-chroot` with units enabled but not started, `runuser`, no readiness claim when `configure` fails, clean-installation qualification in the reference VM). Block C touches critical, tested code (engine, ISO build, VM qualification) with its own expensive verification cycle.
- **User Response**: Agreed with the recommended split.
- **Decision**: Split Story 4.2 into two plans. Plan 02-15 delivers A and B in the running-installed-system context only, validated by running `operations/configure` on the installed reference VM. Plan 02-16 delivers C and closes the story. Scripts in 02-15 are designed from the start with a target-root/context abstraction so 02-16 does not rewrite them. Story 4.2 is not registered until 02-16 completes.
- **Status**: Accepted

## DEC-002
- **Question**: Which terminal and interactive-shell providers does Story 4.2 select?
- **Context/Nuances**: Research compared foot and kitty, and zsh, bash, and fish. foot has no ligature support (the maintainer closed issue #57, citing the renderer rewrite and performance cost; third-party PR #2278 is not known to be merged) and supports Sixel but not the kitty graphics protocol; it supports the kitty keyboard protocol, is CPU-rendered, lightweight, Wayland-only, and the current Omarchy default. kitty offers ligatures, its graphics protocol, and native tabs and splits, which tmux makes unnecessary. zsh is mature with slow releases (5.9 in 2022, test releases since); bash is universal and continuously maintained; fish is the most actively developed (Rust rewrite, 4.0 in 2025) but breaks POSIX. The maintainer has long used zsh with Starship; the recommendation was zsh with Starship.
- **User Response**: foot, and bash with Starship.
- **Decision**: The terminal provider is `foot`. The interactive-shell provider is `bash` with the `starship` prompt, and Starship is part of the skeleton. Both are recorded in `docs/mvp-scope.md` as a Story 4.2 reviewed update. Losing ligatures and the kitty graphics protocol is accepted. Bash is delivered by installation, so no login-shell change is needed. Starship adds one `extra` package with provenance and is initialized from neutral bash user configuration; the maintainer's personal Starship configuration arrives later from an external repository (Story 4.6). Interactive conveniences lost from zsh may be added later (for example `ble.sh`) as a reviewed update.
- **Status**: Accepted

## TODO-001
- **Question**: How does `configure` apply bash, foot, and Starship user configuration without overwriting the user's own files (for example a managed file sourced from `~/.bashrc` versus editing it directly)?
- **Status**: Resolved by DEC-005.

## DEC-003
- **Question**: Where do the configure scripts live and how is their order defined?
- **Context/Nuances**: The architecture reserves `capabilities/` organized by stable capability, places Hyprland under `desktop/compositor/providers/hyprland/`, and keeps `operations/configure` as a coordinator that does not absorb implementation. ADR 0010 rules out manifests and dependency graphs. `workflow/shell/`, `workflow/tmux/`, and `desktop/terminal/` already exist in the architecture tree; `desktop/login/` is new.
- **User Response**: Agreed with the recommended layout.
- **Decision**: `operations/configure` is the entry point and owns the common orchestration (arguments, validation before mutation, lock, execution context, evidence, outcome) and delegates to step scripts. `capabilities/lib/` holds shared configure helpers (packages, managed files, units, user execution, postconditions). `capabilities/configure-steps` is an explicit ordered list of step scripts as a plain Bash array, with no discovery and no graph. Skeleton capabilities: `desktop/login/` (SDDM stock theme without autologin, plus uwsm), `desktop/compositor/providers/hyprland/`, `desktop/terminal/` (foot), `workflow/shell/` (bash and Starship), and `workflow/tmux/`. Each capability has a Bash `apply` step script that declares its prerequisites, expected context variables, and postconditions, next to the native files it applies. `docs/architecture.md` gains `desktop/login/` in its tree.
- **Status**: Accepted

## DEC-004
- **Question**: In what form is package provenance recorded?
- **Context/Nuances**: The common contract requires name, source class, repository or URL, identity evidence where the source offers it, and review responsibility. ADR 0010 leaves the form open (native declarations next to the scripts, or the reserved `inventory/`), and the architecture forbids inventing final schemas speculatively. Every skeleton package comes from the official Arch repositories; there is no AUR package or external artifact.
- **User Response**: Agreed with the recommendation.
- **Decision**: Each capability has a plain-text `packages` file with one `<name> <repository>` line per package (for example `foot extra`), consumed directly by `pacman -S --needed`. `capabilities/README.md` states the provenance policy of the "official Arch repository" source class once: identity is guaranteed by pacman signature verification against the keyring; review responsibility is Arch for package content and the MirrorOS maintainer for inclusion. `configure` checks that the declared repository matches the one pacman resolves, and the evidence records the resolved version and repository. `inventory/` stays empty; AUR and external URL provenance forms are defined by the first slice that consumes them (Story 4.6 or 4.7).
- **Status**: Accepted

## DEC-005
- **Question**: How does `configure` apply user configuration without overwriting the user's own files? (Resolves TODO-001.)
- **Context/Nuances**: The skeleton needs per-user configuration (minimal Hyprland, Starship initialization in bash), while the maintainer's real configuration later arrives from linked external repositories (Story 4.6) and must not collide with MirrorOS defaults. The maintainer pointed out that Hyprland now uses Lua: since Hyprland 0.55 (May 2026) the configuration is `~/.config/hypr/hyprland.lua`, hyprlang is deprecated and kept for 1–2 releases only, and `hyprland.lua` takes precedence over `hyprland.conf` when both exist.
- **User Response**: Agreed with the three rules; the Hyprland example must use Lua.
- **Decision**: (1) Prefer system-wide defaults wherever the tool reads them (for example `/etc/xdg/foot/foot.ini`, `/etc/tmux.conf`, `/etc/sddm.conf.d/`), leaving `$HOME` untouched so later user configuration overrides them; actual lookup paths are confirmed during implementation. (2) Use managed user files only where no system-wide alternative exists, such as `~/.config/hypr/hyprland.lua` in Lua syntax: each carries a "managed by MirrorOS configure" header; it is created when absent, updated only when it carries the header and differs, and left untouched when it lacks the header or is a symbolic link (for example into an external repository), in which case it is reported as owned by the user and the postcondition only checks existence. (3) `~/.bashrc` is never rewritten: one marked, idempotent block sources a managed file (for example `~/.config/mirroros/bash/starship.bash`), and no change is made when the block is present. All writes under `$HOME` run as the user, never as root.
- **Status**: Accepted

## RISK-001
- **Description**: Lua enters as a native application configuration format for Hyprland, not as a project-owned language. Whether the architecture language table needs to reflect this is unconfirmed.
- **Status**: Resolved by codebase evidence: `docs/architecture.md` already lists Lua as "Tool-local only" for existing Neovim, Hyprland, or other tool-owned configuration; no architecture change is needed.

## TODO-002
- **Question**: How is an existing legacy `~/.config/hypr/hyprland.conf` without `hyprland.lua` handled, given that creating `hyprland.lua` would override it?
- **Status**: Resolved by DEC-006.

## DEC-007
- **Question**: How is `configure` invoked on the running system and with what privilege?
- **Context/Nuances**: In the installer context (plan 02-16) `configure` runs as root inside `arch-chroot` and needs `runuser` for user work. On the running system the alternatives were (a) run as the user and escalate with `sudo` per system step, or (b) run as root and drop to the user with `runuser`. Option (a) needs repeated `sudo` prompts or a keepalive and diverges from the chroot context, where there is no user session.
- **User Response**: Agreed with option (b).
- **Decision**: The running-system invocation is `sudo operations/configure [--user <name>]`. Without `--user`, the target user is `SUDO_USER`. When not run as root, or when the target user cannot be resolved (missing, nonexistent, or root), `configure` exits `2` before any mutation. Every operation under `$HOME` runs through `runuser -u <user> --`, so the same mechanism serves both execution contexts. System steps are explicit and user steps never run as root.
- **Status**: Accepted

## DEC-008
- **Question**: How does plan 02-15 prepare the execution-context abstraction required by DEC-001?
- **Context/Nuances**: The same step is expressed differently in each context: on the running system `pacman`, `systemctl enable`, and file writes act on `/`; in the installer the new system is mounted (for example at `/mnt`), commands run through `arch-chroot`, paths live under the target root, and units are enabled but never started. If step scripts call these commands directly, plan 02-16 would have to edit every step with context conditionals.
- **User Response**: Agreed after a worked explanation.
- **Decision**: The orchestrator sets `CONFIGURE_CONTEXT` (`running` or `target`) and `CONFIGURE_ROOT` (`/` or the target path); 02-15 only implements `running` with `/`. Step scripts never run effectful commands directly: they call helpers in `capabilities/lib/` (package installation, managed system file installation with owner, mode, and header, user file and user command execution through `runuser`, unit enabling, and read-only queries). Steps state what to do; helpers decide how for the context. Plan 02-16 adds the `target` branch only inside the helpers, without editing steps. A contract test fails when an `apply` script calls `pacman`, `systemctl`, `install`, or `runuser` directly. 02-15 exposes no public `--target-root` option; 02-16 adds it together with its integration and test.
- **Status**: Accepted

## DEC-009
- **Question**: Does `configure` start SDDM on the running system?
- **Context/Nuances**: Starting SDDM immediately would switch a TTY run to the graphical login mid-run, and a restart from a Hyprland session started by SDDM would end that session. The installer context can never start units.
- **User Response**: Agreed with the recommendation.
- **Decision**: In both contexts SDDM is enabled only, never started or restarted. The postcondition checks that `display-manager.service` resolves to `sddm.service`, that no other display manager is enabled, and that the default target is graphical. The final outcome states, as an informational line rather than a warning, that the graphical login is available at the next boot. The real SDDM → uwsm → Hyprland → foot path is checked in the reference VM by rebooting after `configure`; this is plan verification, not a `configure` self-check.
- **Status**: Accepted

## DEC-010
- **Question**: Where and how is the graphical path (SDDM → uwsm → Hyprland → foot → tmux) verified in plan 02-15?
- **Context/Nuances**: The reference VM (`vm/reference/reference-vm.conf`, version 2) runs headless (`-display none`) with the default QEMU VGA and no virtio-gpu, and changing it is an explicit qualification-contract decision. Hardware rules select nothing for VM graphics. With the standard VGA Hyprland would depend on fragile software rendering.
- **User Response**: Agreed with the recommendation.
- **Decision**: Automated verification in 02-15 consists of the `configure` postconditions (packages, files, enabled unit, graphical target) and Bats contract tests with doubles (validation before mutation, identified failure, rerun without mutation, and the ban on direct effectful commands in steps). `reference-vm.conf` is not changed. The real graphical path is a human checkpoint in a VM with a display and `virtio-vga` (`-display gtk` or `spice`) whose disk was installed by the MirrorOS installer, either the maintainer's laboratory or a QEMU invocation documented in the plan. The checkpoint covers SDDM password login, the uwsm-started session, the three minimal bindings, foot with bash and Starship, tmux creating and managing a session, and a rerun without mutation. VM GPU problems are recorded as evidence; any VM-specific package or variable Hyprland needs is raised as a finding, not anticipated. Plan 02-16 decides, as an explicit VM configuration decision, whether the reference harness gains a display or a screen capture (`screendump`) for the automated clean-installation-plus-`configure` proof.
- **Status**: Accepted; automated-test scope superseded by DEC-023

## DEC-011
- **Question**: Which minimal bindings does the skeleton carry, and how is the session exited?
- **Context/Nuances**: Only three actions are needed; Story 4.3 owns the conventions and may adjust them. uwsm and Hyprland documentation recommend `uwsm stop` instead of the Hyprland `exit` dispatcher so graphical-session units stop cleanly, and launching applications through `uwsm app --`. The recommendation was `SUPER + Q` to close; the maintainer prefers `SUPER + SHIFT + Q` to avoid closing windows by a quick accidental `SUPER + Q`.
- **User Response**: `SUPER + SHIFT + Q` to close; the other two as recommended.
- **Decision**: In `hyprland.lua`: `SUPER + Return` runs `uwsm app -- foot`; `SUPER + SHIFT + Q` runs `killactive`; `SUPER + SHIFT + E` runs `uwsm stop`. The configuration carries no visual customization (Story 4.8) and no `autogenerated` line. Story 4.3 may adjust these bindings when it sets the conventions.
- **Status**: Accepted

## DEC-012
- **Question**: Which display server runs the SDDM greeter?
- **Context/Nuances**: `docs/mvp-scope.md` already decides "SDDM with its greeter on Hyprland and a small owned QML theme"; the owned theme belongs to Story 4.8, but the greeter compositor is a decided provider. SDDM defaults to an X11 greeter (`DisplayServer=x11`), which would add `xorg-server` only for the login screen; its Wayland mode is documented as experimental by `sddm.conf(5)` and the ArchWiki and defaults to `weston`. Omarchy runs the greeter on Hyprland through `/etc/sddm.conf.d/10-wayland.conf` (`DisplayServer=wayland`, `CompositorCommand=start-hyprland -- --config <minimal greeter config>`), and a fork has already migrated that greeter configuration to `hyprland.lua`.
- **User Response**: Agreed with the recommendation.
- **Decision**: Story 4.2 complies with the frozen scope: the SDDM greeter runs on Hyprland in Wayland mode. `desktop/login/` owns a managed `/etc/sddm.conf.d/` drop-in with `DisplayServer=wayland` and a Hyprland `CompositorCommand`, and a minimal managed greeter `hyprland.lua` (no logo, splash, or animations) installed under a MirrorOS system path such as `/usr/share/mirroros/sddm/hyprland.lua`. No `xorg-server` is added; whether the `sddm` package pulls it as a dependency is checked and recorded during implementation. The exact launch command (`start-hyprland` versus `Hyprland`) is confirmed during implementation. The experimental-mode risk is validated by the DEC-010 VM checkpoint; if it fails, falling back to an X11 greeter contradicts `docs/mvp-scope.md` and requires a reviewed update citing the evidence, and is not anticipated.
- **Status**: Accepted

## DEC-013
- **Question**: Which keyboard layout do the greeter and the session use?
- **Context/Nuances**: Installation only records the console keymap (`KEYMAP=<value>` in `/etc/vconsole.conf`, default `us`, editable). Hyprland does not read it and defaults to `us`; a mismatch in the greeter makes password entry fail silently. Console keymap names do not always match XKB layout names (`us` and `es` do; `de-latin1` or `us-acentos` do not).
- **User Response**: Agreed with the recommendation.
- **Decision**: `configure` takes `KEYMAP` from the target `/etc/vconsole.conf` as the single source and adds no new choice. Before any mutation it validates the value as a known XKB layout against the `xkeyboard-config` `base.lst`; otherwise it exits `2` with an actionable message. No translation table is introduced. The layout is written as `kb_layout` into the greeter `hyprland.lua` and into the MirrorOS-managed session `hyprland.lua`; a user-owned session configuration (DEC-006) is left as is. Variants, options, and multiple layouts are outside the skeleton and may enter later as a reviewed update.
- **Status**: Superseded by DEC-021

## DEC-014
- **Question**: How does the `configure` code reach the installed system in plan 02-15, and what runtime does it need?
- **Context/Nuances**: The installed base (`install/plan/policy.json`) is `base`, `linux`, `linux-firmware`, `zram-generator`, `sudo`, `neovim`, `man-db`, and `man-pages`: no `git`, no `openssh`, no Node.js.
- **User Response**: Agreed with the recommendation.
- **Decision**: `configure` runs on Bash plus tools from `base` and `pacman` only, with no Node.js, `git`, or other dependency absent from the base installation; prerequisite validation checks this explicitly, so the same code serves the running system and, in 02-16, the chroot. In 02-15 delivering the code to the installed VM is a documented manual laboratory step outside the product (for example a `git archive` of the tested commit through a shared directory or auxiliary image, or installing `git` and cloning). `configure` requires an intact checkout and exits `6` when its scripts or helpers are missing, like the other lifecycle commands. Plan 02-16 decides how the installer leaves the code on the target (for example copying the ISO-embedded code to a system path) so later reruns need no clone. The manual step does not breach the common contract: "no manual steps" applies to the 02-16 clean-installation proof, and the story is not registered before it (DEC-001).
- **Status**: Accepted

## DEC-015
- **Question**: Where and in what form does `configure` record its evidence?
- **Context/Nuances**: The architecture places generated evidence under `evidence/<stage>/<run-id>/` in the checkout, but `configure` runs as root (root-owned files in the user's checkout) and in 02-16 the target code may be a read-only system copy. The first recommendation was a hand-written JSON run record without `jq`. The maintainer asked whether to use `jq`, which he will install anyway as a personal tool. `jq` is not in `base`: depending on it would require installing it first (a networked mutation), losing evidence exactly when prerequisites fail before mutation, a mirror is down, or a run is interrupted; adding it to the base installation would be a scope change touching tested installation code. No consumer needs JSON in Story 4.2: the structured summary belongs to `verify` (Epic 5, Node.js), and hand-escaping JSON in Bash is the main defect risk.
- **User Response**: Agreed with the revised recommendation.
- **Decision**: `configure` does not depend on `jq` and writes no JSON. Evidence defaults to `/var/log/mirroros/configure/<run-id>/` under `CONFIGURE_ROOT`, mode `0700`, owned by root, overridable with `--output <dir>` (absent or empty) as in `install`. Contents: `configure.log` (plain text: each step, its commands, and output); `configure-run.tsv` (line-oriented, one field per column, tabs and newlines in values replaced; a run header with context, target user, code identity, start, end, outcome, and failed step; one line per step with status `changed`, `unchanged`, `failed`, or `not_run` and its postcondition); and `packages.tsv` (resolved name, version, repository; DEC-004). If `verify` needs structure in Epic 5, it reads these files with Node.js; no JSON format is anticipated. Evidence is secret-free by construction (no secret inputs in 4.2); Gitleaks is not on the target, so evidence is scanned on the development host as part of the checkpoint and plan verification. `jq` enters with development tooling (Story 4.6), decoupled from the mechanism.
- **Status**: Accepted

## DEC-016
- **Question**: Which normalized outcomes, lock, and interruption behavior does `configure` use?
- **Context/Nuances**: The architecture defines outcomes `0/2/3/4/5/6`. The installation engine exits `128+n` on signals because an interrupted installation cannot be retried, and uses a lock file. `configure` is rerunnable.
- **User Response**: Agreed with the recommendation.
- **Decision**: `0` when every step completed and every postcondition holds, including a rerun without changes reported as already satisfied. `2`, always before any mutation, for invalid arguments, not running as root, an unresolvable target user, a non-XKB keymap, a missing base tool, a declared-repository mismatch (DEC-004), or another run holding the lock. `3` for explicit cancellation (SIGINT). `4` when execution completed but a postcondition does not hold. `5` when a step command fails (for example `pacman` without network) or the run ends by SIGTERM or SIGHUP. `6` for a damaged checkout or an internal contract violation. Execution is fail-fast: the first failing step stops the run and later steps are recorded `not_run`. For `3`, `4`, and `5` the final output names the step, the reason, and the next action (rerun `sudo operations/configure`) and never claims readiness. The lock is `flock` on `/run/mirroros/configure.lock` (under `CONFIGURE_ROOT` in the target context). There is no resume state: a rerun starts from the beginning and each step decides `changed` or `unchanged` from its postconditions (ADR 0010).
- **Status**: Accepted

## DEC-017
- **Question**: How are Hyprland-specific packages and configuration isolated beneath the provider boundary, and how are missing provider dependencies reported before mutation?
- **Context/Nuances**: A Story 4.2 criterion requires Hyprland-specific packages and configuration to sit beneath the compositor provider boundary and missing provider dependencies to be reported before mutation. DEC-012 had placed the greeter `hyprland.lua` and the SDDM `CompositorCommand` drop-in under `desktop/login/`, which leaks Hyprland into a provider-neutral capability.
- **User Response**: Agreed with the recommendation.
- **Decision**: `desktop/login/` is provider-neutral: the `sddm` package, a drop-in with the stock theme and no autologin, unit enabling, the graphical default target, and `uwsm` as the compositor-independent session start mechanism. `desktop/compositor/providers/hyprland/` owns every Hyprland-specific item: its packages, the session `hyprland.lua`, the greeter `hyprland.lua`, and the SDDM drop-in with `DisplayServer=wayland` and the Hyprland `CompositorCommand`. Replacing the provider means replacing that directory and its `configure-steps` entry without touching login, terminal, shell, or tmux. Before any mutation the orchestrator reads the `packages` files of every listed step and checks with read-only `pacman -Sp` that each package exists in its declared repository; a missing or mismatched package ends with `2` and lists every failure. This also implements the DEC-004 repository check. The check depends on current sync databases; how packages are refreshed without a partial upgrade is decided separately.
- **Status**: Accepted

## DEC-018
- **Question**: How does `configure` install packages without a partial upgrade and without mutating on reruns?
- **Context/Nuances**: In Arch, `pacman -Sy` followed by `pacman -S` is an unsupported partial upgrade; the safe way to install new packages is `pacman -Syu`, which upgrades the whole system. A rerun on a configured system must not mutate, and system updates belong to Story 4.7.
- **User Response**: Agreed with the recommendation.
- **Decision**: Validation (DEC-017) uses the existing sync databases, which `pacstrap` leaves on the target; when they are absent `configure` exits `2` advising to run `pacman -Syu` first, and it never refreshes them before mutation. In the package helper: when every declared package of a step is installed, `pacman` is not run and the step is `unchanged`, so a full rerun neither syncs nor upgrades. The first time in a run that packages are missing, the helper runs `pacman -Syu --needed --noconfirm <missing>` as one safe transaction; the implied full upgrade is a necessary mutation recorded in the evidence. Later missing packages in the same run use `pacman -S --needed --noconfirm <missing>`, which is not a partial upgrade because the system was just upgraded against the same databases. An invalid signature, an outdated keyring, or no network ends with `5`, naming the step and advising to update `archlinux-keyring` or check the network and rerun; the keyring is never changed automatically. The first run on a newly installed system may upgrade base packages when the ISO is old; this is correct for Arch and lengthens the run.
- **Status**: Superseded by DEC-019

## DEC-020
- **Question**: How is it guaranteed that SDDM offers only the uwsm-managed Hyprland session?
- **Context/Nuances**: `hyprland` 0.56.2 ships two sessions: `hyprland.desktop` (Hyprland started directly, without uwsm) and `hyprland-uwsm.desktop` (whose `Exec` is `uwsm start … hyprland.desktop`), plus `start-hyprland`. `docs/mvp-scope.md` requires sessions to always start through `uwsm start hyprland.desktop`. Omarchy (commit `41d2f9d`) does not hide upstream sessions; it adds its own `/usr/local/share/wayland-sessions/omarchy.desktop`, so SDDM lists several. Finding: the official `sddm` 0.21.0-7 package has `xorg-server` and `xorg-xauth` as mandatory dependencies; Omarchy declares only `sddm` and receives both implicitly. Omarchy also confirms the Wayland greeter on Hyprland with `start-hyprland -- --config /usr/share/sddm/hyprland.lua` (DEC-012).
- **User Response**: Agreed with the recommendation.
- **Decision**: The Hyprland provider manages `/usr/share/mirroros/wayland-sessions/` containing only a symbolic link to `/usr/share/wayland-sessions/hyprland-uwsm.desktop` (a link, not a copy, so package changes flow through), and its SDDM drop-in sets `[Wayland] SessionDir=` to that directory, so SDDM lists only the uwsm session without editing package files or relying on SDDM remembering the last session. The postcondition requires exactly one listed session whose `Exec` contains `uwsm start` and `hyprland.desktop`; otherwise `configure` ends with `4`. Everything lives under `desktop/compositor/providers/hyprland/` (DEC-017). `xorg-server` and `xorg-xauth` are installed as mandatory `sddm` dependencies even though the greeter runs on Wayland; this is recorded in the evidence through the resolved package list and does not change DEC-012. The DEC-012 launch command is confirmed as `start-hyprland`.
- **Status**: Accepted

## TODO-003
- **Question**: Revisit DEC-013: Omarchy's greeter `hyprland.lua` reads `XKBLAYOUT` from `/etc/vconsole.conf` at runtime (the key written by `localectl set-x11-keymap`), falls back to `us`, and prepends `us` for non-Latin layouts so a password can be typed. A runtime read would make later `localectl` changes apply without rerunning `configure`.
- **Status**: Resolved by DEC-021.

## DEC-022
- **Question**: Which font and default configuration do foot, Starship, and tmux use in the skeleton?
- **Context/Nuances**: Starship's documentation requires a Nerd Font, since several default modules use Nerd Font glyphs. `sddm` depends on the virtual `ttf-font`, and with `--noconfirm` pacman would pick a provider implicitly, an unreviewed provider choice. Typography is open and owned by Story 4.8.
- **User Response**: Agreed with the recommendation.
- **Decision**: The skeleton uses `ttf-jetbrains-mono-nerd` (`extra`) as a provisional font, declared explicitly in `desktop/terminal/packages`; installed before `sddm`, it is expected to satisfy `ttf-font` and avoid the implicit choice, which is verified during implementation. foot uses it through a minimal system-wide `/etc/xdg/foot/foot.ini` with `font=JetBrainsMono Nerd Font:size=11` and otherwise defaults. Starship ships no `starship.toml` and uses its defaults; the maintainer's configuration arrives with Story 4.6. tmux ships no `/etc/tmux.conf` and uses its defaults. In `docs/mvp-scope.md` typography stays open and owned by Story 4.8, with a note that Story 4.2 uses a provisional font that Story 4.8 may replace.
- **Status**: Accepted

## DEC-024
- **Question**: Which documentation changes in plan 02-15, and how is the Omarchy reference handled?
- **Context/Nuances**: Repository rules require attribution, tests, and documentation to change together with the behavior they govern. `docs/attribution.md` indexes incorporated material only; ideas may be cited without being represented as copied code.
- **User Response**: Agreed with the recommendation.
- **Decision**: `operations/configure` and its help describe the real running-context behavior, with the target context marked Pending (plan 02-16). `docs/procedures/configure.md` is rewritten with the implemented contract: invocation (`sudo`, `--user`, `--refresh`, `--output`), prerequisites, effects, evidence, outcomes, recovery, the "never run `pacman -Sy` alone" warning, and the add-a-package-and-rerun flow. `README.md` changes the `configure` lifecycle row from help only to running installed system with the installer context pending. `docs/mvp-scope.md` records Terminal = foot, Interactive shell = bash with Starship, and the provisional-font note under Typography. `docs/architecture.md` adds `capabilities/lib/`, `capabilities/configure-steps`, `capabilities/README.md`, and `desktop/login/` to the tree and nothing else. A new `capabilities/README.md` states the step contract (`apply`, prerequisites, postconditions, mandatory helpers, ban on direct effectful commands), the official-repository provenance policy, the managed-file rules, and how later slices add steps. Omarchy is cited as an idea reference in `capabilities/README.md` (greeter on Hyprland, runtime `vconsole.conf` reading) and gets no `docs/attribution.md` entry because MirrorOS writes its own files; if any fragment is copied during implementation, an MIT attribution entry is added in the same change. ADRs and `docs/epics.md` do not change. The VM checkpoint procedure (QEMU with a display, code delivery) lives in the plan verification section, not in `docs/`, because it is laboratory work outside the product. The interview artifacts are committed with the change.
- **Status**: Accepted
