# Configure capabilities

`operations/configure` coordinates bounded Bash steps over native Arch and application configuration, following
[ADR 0010](../docs/adr/0010-environment-configuration-mechanism-and-scope.md). This tree owns the steps and shared
helpers, not the installer or independent readiness verification. See the [configure procedure](../docs/procedures/configure.md)
for invocation, effects, evidence, and recovery.

## Step contract and order

`configure-steps` is an explicit Bash `CFG_STEPS` array of paths relative to this directory. There is no discovery,
dependency graph, or resume state. The current order is:

1. `desktop/terminal`: Foot, the approved native terminal defaults, Nerd Font Mono and emoji glyphs.
2. `workflow/node`: the user's NVM release and the declared Node.js runtime, with its managed environment file.
3. `workflow/shell`: Zsh as the interactive shell with its approved native startup files, Zplug and identified plugin sources, shell tools, and the Starship initialization for bash.
4. `workflow/tmux`: tmux with the approved native defaults, TPM and identified plugin sources, the compiled tmux-thumbs helper, and Sesh from a reviewed local recipe.
5. `workflow/editor`: Lazygit and the editor prerequisites, the `vim` wrapper, the external Neovim configuration cloned at `~/code/nvim` and linked from `~/.config/nvim`, with its locked plugins, tools and parsers prepared.
6. `workflow/pi`: ffmpeg, the external pi-config cloned at `~/code/pi-config`, the Pi executable in the user's NVM prefix and the pi-config runtime dependencies, the identified Google Cloud CLI archive under `~/.local/opt`, with the `pi-editor` and `gcloud` launcher links and the initialize-only `~/.pi` defaults, npm packages and owned skills.
7. `desktop/compositor/providers/hyprland`: session, keyboard module, greeter, and session selection.
8. `desktop/shell`: Quickshell, the reviewed shell runtime and its user unit enabled for the selected user.
9. `desktop/lock`: hyprlock and hypridle with native lock and idle configuration, enabled for the selected user.
10. `visual/branding`: the shared MirrorOS wordmark SVG and the PNG rendered from it under `/usr/share/mirroros/branding`.
11. `system/boot-splash`: Plymouth, the static MirrorOS theme, the `plymouth` hook drop-in, the `quiet splash`
    overlay of the recognized boot configuration, and the regenerated boot images ([ADR 0014](../docs/adr/0014-native-login-and-boot-presentation.md)).
12. `desktop/login`: SDDM with the MirrorOS theme, uwsm, an explicit generic font provider, and enable-only graphical login.

Each step supplies:

- `apply`: sourced by the coordinator in a fresh subshell with `set -Eeuo pipefail`. Its opening comments state
  prerequisites, expected context variables, and postconditions. It ends with `cfg_require` checks.
- `packages`: official repository declarations, validated for all steps before convergence starts.
- Only the native configuration files that capability needs, next to `apply`.

The coordinator supplies `STEP_DIR`, `CONFIGURE_CONTEXT`, `CONFIGURE_ROOT`, `TARGET_USER`, and shared helper state
including `CFG_OUTPUT`. A step uses helpers for packages, system files and links, user work, units, and read-only
queries. No `apply` calls `pacman`, `systemctl`, `install`, or `runuser` directly; the mechanism contract test checks
that boundary. Steps must not bypass helpers through `cfg_run` or introduce context-specific command execution.
Two bounded exceptions run a capability's own native tool without branching on context: `visual/branding` renders
with `rsvg-convert` through `cfg_exec`, and the capability-local `system/boot-splash/boot-splash.sh`, sourced by its
`apply`, routes `mkinitcpio`, `limine-update` and `lsinitcpio` through `cfg_run` or `cfg_exec` and writes boot
configuration on the live side through `cfg_run_host` and `cfg_path`. Neither adds a shared helper or a chroot branch.

Helpers in `lib/` own the effect boundary:

| Library | Responsibility |
|---|---|
| `common.sh` | Context guard, `cfg_exec` command routing, positioned step execution, change tracking, postcondition checks, outcomes and signals |
| `validate.sh` | Arguments, prerequisites, lock, keyboard validation, package resolution and upgrade guard |
| `packages.sh` | Missing-package transactions, installed-package postconditions, and the reviewed local-recipe package build |
| `files.sh` | Managed files and links, user work and scripts, bashrc block, Node.js declaration, and single-session query |
| `units.sh` | Enable-only units, default target, and read-only display-manager queries |
| `evidence.sh` | Private run directory, sanitized TSV records, package versions, source identities, and allowed logs |
| `repositories.sh` | User-level current-branch resolution and safe external source synchronization |

Both `CONFIGURE_CONTEXT=running` and `target` are implemented inside the helpers; steps do not branch on context.
The public `--target-root <mounted-dir>` requires root, an absolute existing mount point other than `/`, and an
explicit `--user` from the target's `passwd`. Validation collects problems before convergence. `cfg_exec` runs
commands directly in running context and through `arch-chroot "$CONFIGURE_ROOT"` in target context. All package,
user, and unit queries and commands use it; user writes run through `runuser` inside the target with its `HOME`.
System files and links, keyboard and session-file checks, the lock, and evidence remain live-side operations on
`cfg_path`-prefixed paths. SDDM is never started by either context.

The installer embeds this tree and `operations/configure` under the same code identity as the engine. After
base postconditions pass it copies the rerun code and `identity.json` to the installed system's
`/usr/local/lib/mirroros/` and creates `/usr/local/bin/mirroros-configure` before invoking target configure.
This snapshot enables `sudo mirroros-configure` without a clone, including after `not_configured`/`4`; it is not
automatically synchronized or updated. Target evidence is under `<root>/var/log/mirroros/configure/<run-id>/`,
records `context target`, and uses `identity.json` for commit and dirty state when git or `.git` is absent.
Markers `== <k>/<total> <step> ==` drive the engine's configure progress state.

`MIRROROS_CONFIGURE_ROOT` is a test-only running-context variable, analogous to `MIRROROS_DISCOVERY_ROOT`: it
redirects filesystem paths into a disposable root and cannot be combined with `--target-root`. It is not a safe
chroot interface: package, unit, and user commands still need test doubles and must never be exercised against
a real host through that variable.

## Packages and provenance

A `packages` file contains one `<name> <repository>` pair per line, for example:

```text
foot extra
```

Blank lines and full-line `#` comments are allowed. Declarations use official Arch repositories (`core`, `extra`,
or `multilib`); AUR and external repositories are outside this mechanism. Repository identity is checked with
read-only `pacman -Sp --print-format '%r %n %v'`. Package identity is provided by pacman's normal signature
verification against the Arch keyring. Arch reviews package content; the MirrorOS maintainer reviews inclusion
in the environment. Do not bypass signature checks, refresh keys automatically, or duplicate these declarations
in an inventory schema. Evidence records declared names, resolved or installed versions, and repositories, not a
complete transitive dependency inventory.

Without `--refresh`, missing packages use `pacman -S --needed --noconfirm` against existing sync databases. When
any package is missing, pending upgrades from `pacman -Qu`, excluding `[ignored]` lines, block that mode before
convergence. `--refresh` explicitly permits `pacman -Syu --needed --noconfirm` for the first missing-package
transaction; later transactions use `-S`. No transaction occurs if all declared packages are already installed,
even with `--refresh`; read-only preflight and evidence queries still occur. Never run `pacman -Sy` without `-u`.
Target-context transactions run as `env SNAP_PAC_SKIP=y pacman ...` through `cfg_exec`, avoiding installation-time
snap-pac snapshots after the engine configures Snapper. Running-context transactions retain normal snap-pac
behavior.

Package metadata evidence recorded in [Story 4.2 DEC-036](../docs/technical-interviews/story-4-2-target-context_log.md)
settles the font dependency: `ttf-jetbrains-mono-nerd` 3.5.1-2 provides only `ttf-font-nerd`, not `ttf-font`;
SDDM 0.21.0-7 depends on `ttf-font`; `noto-fonts` provides `ttf-font`. Login therefore explicitly declares
`noto-fonts` as a required provider, not as a precaution or an implicit pacman choice. These versions are observations, not pins. SDDM also pulls `xorg-server` and
`xorg-xauth` as mandatory dependencies although its configured greeter uses Wayland. `qt6-wayland` is not declared
speculatively; whether it is required remains a graphical-checkpoint finding.

## External repository synchronization

`cfg_repository_sync` supports the Neovim and pi-config consumers. The consumer supplies its public GitHub URL,
`master` branch and relative `code/` destination. Git runs through `cfg_exec` and `runuser`, including inside
arch-chroot in target context; neither root nor the live user's home executes external repository code.

The helper resolves the selected branch once per repository per execution and reuses the selected commit on
repeated calls. An absent destination is prepared in a unique sibling staging directory and published only
if the destination remains absent. Failed staging is retained for diagnosis, never adopted on retry; remove
only a reported owned staging directory manually when no longer needed. A clean matching checkout at the
selected commit performs no fetch, merge or configuration writes. An older clean checkout advances only by
fast-forward. Synchronization disables Git hooks, does not commit, and never resets, stashes or deletes work.

Modified/untracked files, unexpected origins or branches, divergent/local-only history, symlinked paths and
unrelated destinations stop synchronization with an actionable error. A failed status query is not considered
a clean checkout. Preserve local work and resolve the named conflict manually before rerunning configure.
Ignored dependency directories are not treated as untracked work; dependency provisioning is a separate effect.

When a source is consumed, evidence creates `sources.tsv` with `name`, public `source`, `ref`, `commit` and
`version` columns. Repeated records replace the same source's row rather than duplicating it. No source-file,
private configuration or credential-bearing URL dump belongs in this record. This is moving configuration
provenance, not a permanent configuration revision pin or an independent readiness verdict.

## User Node.js runtime

`workflow/node/environment.zsh` is the single declaration of the Node.js version (`MIRROROS_NODE_VERSION`) and
of the portable PATH entries; `cfg_node_version` parses it as data for provisioning. `cfg_user_script` runs a
reviewed capability script as the target user in a clean startup environment, through `cfg_exec` in both contexts.
The script's output begins with `changed` or `unchanged`.

`workflow/node/install-nvm` installs the identified NVM release without editing shell profiles. It verifies the
installer checksum before executing it, builds NVM in a unique staging directory owned by the run, verifies the
commit and publishes `~/.nvm` only while the path is absent. The declared Node.js version is then installed
through that NVM. A satisfied runtime causes no download. An existing `~/.nvm` that is not the unmodified
identified release is preserved: it is accepted when the declared Node.js is already present and otherwise stops
the step with an actionable error. NVM is never sourced from shell startup; `nvm_load` loads it on demand. See the
[node sources](workflow/node/sources.md) for release, installer and notice identities.

## Managed files and user ownership

Managed files carry `managed by MirrorOS configure` in their native comment syntax (`#` or `--` in the skeleton).
The helper creates an absent file and updates a differing header-managed file. Files without the header and
symbolic links are left untouched and reported as user-owned; their postconditions only check existence, not
MirrorOS contents. System files are installed root-owned with the declared mode. System links are created when
absent; conflicting existing entries are preserved, and dependent postconditions can fail.

All writes under the target user's home run through `runuser -u "$TARGET_USER" --`, including directory creation
and temporary files. A non-managed or linked legacy `~/.config/hypr/hyprland.conf` prevents creating a shadowing
`hyprland.lua`. A user-owned Lua file is likewise preserved.

`~/.bashrc` is not rewritten. The helper appends one block between `# BEGIN MirrorOS configure` and
`# END MirrorOS configure` to source `~/.config/mirroros/bash/starship.bash`. Repeated runs do not append another
block. A symbolic-link bashrc is preserved; malformed or duplicate markers require manual repair. Starship
initialization is guarded for interactive shells; no `starship.toml` is supplied. The prior Bash initialization stays in place.

`cfg_login_shell` changes the target user's login shell through `usermod` (inside the target in target context) only
when it is currently Bash and the shell is listed in `/etc/shells`; any other choice is user-owned and preserved.
The Zsh startup files (`~/.zshenv`, `~/.zshrc`, `~/.zprofile`) follow the managed-file policy. `install-plugins`
runs as the user, like `install-nvm`, and clones Zplug and each plugin source at its identified commit into a
run-owned staging directory that is published without overwriting. An existing clone of the expected origin is
accepted at the user's commit; any other path is preserved and stops the step. Zsh startup never installs or
fetches anything. See the [shell sources](workflow/shell/sources.md) for identities, notices and thresholds.

foot reads user configuration before `/etc/xdg/foot/foot.ini`. The package already owns that system file without
a MirrorOS header, so the implementation deliberately preserves it and manages `~/.config/foot/foot.ini` instead.
This approved exception to the original system-default preference uses the existing user-ownership rules.
The terminal-local workbench defaults select JetBrainsMono Nerd Font Mono size 14, centered 16x16 padding,
Tokyo Night colors and CSI-u Shift+Return / Alt+Shift+Return sequences. `noto-fonts-emoji` supplies the approved
emoji glyph prerequisite. Source, adaptations and notice scope are recorded in
[terminal sources](desktop/terminal/sources.md). Global typography and palette remain Story 4.8 work.

The Tmux files (`tmux.conf`, `tmux.bindings.conf`, `tmux.navigator.conf`, `tmux.theme.conf`) follow the
managed-file policy under `~/.config/tmux/`. `install-plugins` runs as the user, like the Zsh one: it clones TPM and
each plugin at its identified commit into an owned staging directory published without overwriting, accepts an
existing clone of the expected origin, preserves anything else, and compiles tmux-thumbs with
`cargo build --release --locked` only when its binaries are missing or differ from the clone, so Tmux itself never
installs or builds anything. Sesh is not an official package: `cfg_local_package_ensure` parses the reviewed recipe
`workflow/tmux/sesh/PKGBUILD` as data, has the target user build it with `makepkg` (no `-s`), and installs only the
resulting package with `pacman -U`, and only when `sesh-bin` is missing or its installed version differs from the
recipe. It is not a general AUR mechanism. See the [tmux sources](workflow/tmux/sources.md) for identities, the
recipe's changes from its AUR origin, and notices.

The editor step installs only its own official prerequisites; `neovim` stays installation-owned and `git`,
`base-devel` and `rust` stay with the earlier node and tmux steps. `cfg_user_file` takes an optional mode (`0644` by
default, `0755` for the managed `~/.local/bin/vim` wrapper, which opens Oil for no argument or one directory) and
repairs a drifted mode of a managed file. The Neovim configuration is the external repository synchronized by
`cfg_repository_sync`; `cfg_user_link` links `~/.config/nvim` to it only while that path is absent, and any other
existing path is user-owned and is neither replaced nor prepared. `workflow/editor/prepare-nvim` runs as the user
with the declared Node.js `bin` first on PATH and executes the repository's own explicit preparation (`Lazy! restore`,
`config.prepare_tools`, `config.treesitter`) once per applied commit, recorded in
`~/.local/state/mirroros/editor/nvim-prepared` only after all three succeed, so a failed run is repeated and an
unchanged commit performs no work. MirrorOS carries no parallel tool list and Neovim startup installs nothing. See
the [editor sources](workflow/editor/sources.md).

The Pi step synchronizes pi-config with `cfg_repository_sync` and links `~/.local/bin/pi-editor` to its launcher
only while that path is absent. `workflow/pi/install-pi` runs as the user with the declared Node.js `bin` first on
PATH. It runs `pi-version.mjs` once per execution against the synchronized `package.json` (exact devDependency, or
the latest stable release only when the declaration is absent; a range or malformed value fails with no fallback),
installs `@earendil-works/pi-coding-agent` with `npm install --global --ignore-scripts` into the NVM prefix only when
the installed version differs, and runs `npm ci --ignore-scripts --omit=dev --omit=peer` in pi-config only when
`node_modules` is missing or the identity of its manifest and lockfile recorded in
`~/.local/state/mirroros/pi/pi-config-dependencies` differs. The applied version and its selection source are
recorded in `sources.tsv`; transitive dependencies are not pinned and compatibility is never repaired automatically.

`~/.pi` is initialize-only and decided by `workflow/pi/init-pi`, which runs as the user before any command that
could create or write that path. Any existing `~/.pi`, including a symlink, a dangling symlink or an empty
directory, is preserved without a single write and the step reports the preservation; settings, bindings,
instructions, links, packages and diagnostics are never reconciled inside it. An absent `~/.pi` is built in an owned
sibling directory (`~/.pi.mirroros.*`, one initialization at a time through a lock under
`~/.local/state/mirroros/pi`), validated, and published with a no-clobber rename, so an interrupted or failed
initialization leaves neither a partial `~/.pi` nor staging, and a destination created concurrently is preserved.
The defaults in `workflow/pi/defaults/` (settings, keybindings, instructions and prompt templates; voice and
text-to-speech disabled, no credentials, sessions or models) are copied, and the extensions of pi-config are linked,
never copied. The npm packages declared in `workflow/pi/npm-packages` (exact versions, parsed as data) are installed
into the staged `agent/npm` with `npm install --ignore-scripts --legacy-peer-deps`, using an empty user and global npm
configuration, HOME and cache inside the staging (removed before publication); every `npm:` source of the shipped
settings must be present or nothing is published. The MirrorOS-owned skills in `workflow/pi/skills/` are delivered to
`~/.local/share/mirroros/pi/skills/<name>` without overwriting (an identical delivery is accepted; a different
directory, a symlink or a non-regular entry fails before publication) and linked from `agent/skills/<name>`, so they
become active only with a successful initialization. The external manual skills declared in
`workflow/pi/external-skills` (repository, directory and skill names, parsed as data) follow the current upstream
default branch: each repository is resolved once per run (`git ls-remote --symref`) and fetched by that exact commit,
the skills are installed from the local checkout with the `skills` CLI (exact version, project scope inside the staging,
isolated configuration, lifecycle scripts disabled), the installed payload must equal its upstream directory, and
`manual-skill.mjs` then sets only `disable-model-invocation: true` in `SKILL.md`. The upstream license file is
preserved with each skill (the repository one is copied when the skill directory has none; no license aborts).
They are copied into `agent/skills/<name>` inside the staging, never into MirrorOS source, and any failure aborts
before publication. Resolved branches and commits are recorded in `sources.tsv`. Newer defaults require moving the existing directory aside manually. See the
[Pi sources](workflow/pi/sources.md).

`workflow/pi/install-gcloud` runs as the user and installs the versioned Google Cloud CLI archive declared in the
script (size, MD5 and a locally computed SHA256 are all verified before extraction; the SHA256 is not published by
upstream) into an owned staging directory under `~/.local/opt`, then publishes `google-cloud-sdk-589.0.0` with a
no-clobber rename. It never runs `install.sh`, `gcloud init`, component or authentication commands and edits no profile.
A satisfied installation causes no download; a directory of another version, a symlink or a concurrently created
destination is preserved and reported. `~/.local/bin/gcloud` links to it only while that path is absent, and the
postcondition runs `gcloud --version` with a throwaway CLI configuration. The archive identity is recorded in
`sources.tsv` only when the installation changed. See the [Pi sources](workflow/pi/sources.md).

## Keyboard validation and provider boundary

The validation point is preflight, before package, managed-file, unit, or user convergence. `xkeyboard-config` is
a base-installation prerequisite; missing `base.lst` data ends with outcome `2`, rather than
installing it and deferring layout validation. Validation reads `/usr/share/xkeyboard-config-2/rules/base.lst`
under `cfg_path`, with `/usr/share/X11/xkb/rules/base.lst` supported for the legacy directory layout.
The [Arch package file list](https://archlinux.org/packages/extra/any/xkeyboard-config/files/) and the
`xkeyboard-config` 2.48-1 package archive inspected during the target checkpoint show that `/usr/share/X11/xkb`
is an absolute link to `/usr/share/xkeyboard-config-2`. Reading the real directory avoids resolving that alias
against the live medium instead of the target. This was an explicitly approved base-policy adjustment in plan
02-15. The resolved layout is `XKBLAYOUT` from `/etc/vconsole.conf`, otherwise `KEYMAP`, otherwise `us`; it must
appear in the layout section of `base.lst`. Configuration is parsed as data, never sourced as shell code.
Console-only keymap names are not guessed or translated. Multiple layouts, variants, arbitrary option selection and non-Latin
layout adaptation are outside the skeleton. The reviewed native session and greeter default to
`kb_options = "compose:ralt"` without replacing layout resolution. Right Alt then acts as Compose, not AltGr;
layouts requiring AltGr need the native ownership override described in the
[configure procedure](../docs/procedures/configure.md#right-alt-compose-and-native-overrides).

Every Hyprland-specific package and native file lives below `desktop/compositor/providers/hyprland/`, including
the SDDM Wayland drop-in and greeter configuration. Login remains provider-neutral. The greeter and managed
session load one shared layout list at runtime through absolute-path `require` (`layouts.lua`): the resolved
layout first, then the declared `us,es` without duplicates, so both start in the configured layout and changes to
the system layout apply on their next start. In the greeter, `SUPER+I` and `SUPER+SHIFT+I` switch layouts through
the one-shot `layout-indicator` helper, which records the active layout for the SDDM theme
([ADR 0015](../docs/adr/0015-greeter-keyboard-layout-switching.md)). Lua uses the Hyprland 0.55-or-later API; graphical usability is proven by the
human checkpoint, not by file-existence postconditions.

The provider creates a link to the upstream `hyprland-uwsm.desktop` in a dedicated session directory.
`cfg_session_is_only` checks that it contains exactly one entry and that the desktop entry's `Exec` contains
`uwsm start` and `hyprland.desktop`. Extra or incompatible entries produce outcome `4`, not deletion of local
state. SDDM is enabled last and is never started or restarted by configure.

### Clean-install checkpoint observations

- Greeter selector label and `es` password login: the maintainer reports `??zz` in the selector, but successful
  login with a Spanish-layout-sensitive password. The uwsm Hyprland session also uses the Spanish layout,
  checked with `localectl status`. The label is classified as cosmetic under SDDM #2149, not a keyboard defect.
- `sudo localectl set-x11-keymap es` produced no output; the subsequent `grep XKB /etc/vconsole.conf` returned
  `XKBLAYOUT=es`, as reported by the maintainer. This non-gating observation concerns later layout changes.
  The installer writes `KEYMAP`, which the shared keyboard module already uses as fallback.
- The maintainer confirms the laboratory VM used `--gl` and reports that the clean-install graphical path,
  foot with bash and Starship, tmux, and the three bindings work, with no GPU issue reported. Reviewed configure
  evidence records outcome `0` in both target and running contexts, with the same code identity. The installed
  rerun records all five steps `unchanged` and no pacman invocation in `configure.log`. Gitleaks scanned the
  copied evidence archive with archive traversal enabled and found no leaks. The reference VM configuration
  is unchanged; its tty2 login proof is not a graphical check.

## Adding a later slice

1. Add the capability's `apply`, `packages`, and minimal native files under its owning boundary.
2. State prerequisites and context variables; use shared helpers and check postconditions at the end.
3. Add its path to `configure-steps` after prerequisites and before dependents. Keep display-manager activation
   after the steps it depends on. Keep `Configure step: k/N <step>` within 80 columns, including the prefix;
   operation descriptions elsewhere in the engine are limited to 72 characters for their position prefix.
4. Review package inclusion and update the governing scope and procedure as needed.
5. Run shell checks and the mechanism and target contract suites. Exercise both contexts through a clean
   `qualify-install` run and the graphical laboratory checkpoint, including an installed-system rerun. Add
   mechanism tests only when shared behavior changes, not one test suite per capability.
6. Rerun configure from the beginning and verify a second run reports unchanged without package transactions.

## Idea references and attribution

[Omarchy](https://github.com/basecamp/omarchy) is an idea reference for running the SDDM greeter on Hyprland and
reading the system keyboard layout from `vconsole.conf` at runtime. Its explicit generic font declaration also
informed the SDDM dependency fix. MirrorOS's scripts and configuration are independently written; no Omarchy
fragment is incorporated, so these references do not add copied-material attribution entries. Any future copied
fragment must receive its applicable license and an entry in [attribution](../docs/attribution.md) in the same
change. The unchanged [interview log](../docs/technical-interviews/story-4-2-minimal-graphical-login_log.md) and
[consolidated plan](../docs/technical-interviews/story-4-2-minimal-graphical-login_plan.md) record the original
decisions; implementation adjustments are documented here and in the procedure.
