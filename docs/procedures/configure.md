# Configure lifecycle procedure

**Availability:** implemented for the running installed system and a mounted installer target root. The guided
installer runs configure after the base postconditions pass, before the first normal reboot. Clean-installation
qualification and graphical usability still require the plan's blocking VM checkpoint.

## Current behavior

Invoke `operations/configure` by path from any working directory; it does not need to be installed on `PATH`.
The installer also leaves `/usr/local/bin/mirroros-configure` on the installed system for reruns without a clone.
It applies minimal graphical login and user tools through the ordered steps in
[`capabilities/configure-steps`](../../capabilities/configure-steps), following
[ADR 0010](../adr/0010-environment-configuration-mechanism-and-scope.md). This is not yet the complete MVP desktop.
The actual graphical path remains subject to the plan's blocking VM checkpoint; successful postconditions are
not a substitute for that proof or for independent readiness verification by `verify`.

The `visual/theme` step publishes the reviewed theme under `/usr/share/mirroros/themes/default`. It refuses
modified or unknown deliveries and unsafe parent directories. As the target user, it creates
`$XDG_STATE_HOME/mirroros/current/theme` pointing to the default theme if absent, preserving conflicting paths
and failing with an actionable diagnostic. It obtains `XDG_STATE_HOME` from the user's systemd manager when
available in the running system, not from the administrator's environment; without an available value it uses
`~/.local/state`. A mounted target always uses `~/.local/state`, not a session on the installation host.
If the session later uses another state directory, configure does not move an existing link automatically.
The step also publishes tracked selection and path-checking helpers under `/usr/share/mirroros/themes/`;
modified or unknown helper files are preserved as conflicts. This link is not itself a trust guarantee, and
the shell and Hyprland use the resolver and only accept the reviewed default. Other consumers do not yet use the link.
The same step publishes the theme's backgrounds inside its manifest-checked tree at
`/usr/share/mirroros/themes/default/backgrounds`; modified, removed, added or linked images are conflicts.
It initializes `$XDG_STATE_HOME/mirroros/current/background` to the approved logo image (`2-mirroros-jade.png`) only when absent, preserving
any existing link or other path. It never creates or writes personal backgrounds.
This step does not restart or reload the session. The terminal step publishes the standalone tracked
`/usr/share/mirroros/foot/recovery.ini`; edited or linked destinations are conflicts. It does not replace
personal Foot settings. From a working Wayland session, use `foot --config /usr/share/mirroros/foot/recovery.ini`
to bypass a broken personal configuration. Graphical recovery has not yet been validated.

```bash
sudo operations/configure
sudo operations/configure --user alice
sudo operations/configure --user alice --refresh --output /var/log/mirroros/configure/manual-run
sudo mirroros-configure
sudo operations/configure --target-root /run/mirroros/target --user alice
operations/configure --help
```

Replace `alice` with an existing non-root account. Only a sole `--help` returns help without mutation or root.
Help also requires intact configure helpers and listed steps. A missing or unloadable lifecycle helper, missing
capability helpers, or missing or invalid listed steps reports an incomplete or damaged checkout with outcome
`6`; restore the files from Git or reclone.

## Prerequisites and inputs

- Run as root (using `sudo` on the installed system). The target user is `--user <name>`, otherwise `SUDO_USER`
  in the running context only. With `--target-root`, `--user` is mandatory and must exist in the target's
  `passwd`; missing, nonexistent, invalid, and root target accounts are rejected. Bash must already be the intended interactive shell; configure
  changes the login shell to Zsh only when it is currently Bash; another chosen shell is preserved.
- Use a running MirrorOS-installed Arch system with Bash, pacman, flock, runuser, systemctl, install, usermod, and the
  standard text and filesystem tools checked by validation. In target context, the live medium needs
  `arch-chroot`, `flock`, and `mountpoint`; base tools are checked inside the target. No Node.js, jq, or git
  runtime dependency is added.
- Existing pacman sync databases and access to declared official repositories are required. Network access is
  needed for missing packages; configure never initializes databases or modifies the keyring automatically.
  The Node.js step also needs HTTPS access to GitHub and nodejs.org when the declared runtime is missing, and the
  editor step needs it for the Neovim configuration and its plugin and tool registries.
- `xkeyboard-config` must already supply `/usr/share/xkeyboard-config-2/rules/base.lst`, or
  `/usr/share/X11/xkb/rules/base.lst` in the legacy directory layout. Target validation reads the real directory
  under the target root, not the absolute X11 compatibility alias that would resolve against the live medium.
  Installation policy includes this prerequisite. Layout validation occurs before convergence, even if other
  packages are missing.
- The system keyboard layout is resolved from `XKBLAYOUT` in `/etc/vconsole.conf`, then `KEYMAP`, then `us`.
  It must be a known XKB layout. Set an explicit supported `XKBLAYOUT` when the console keymap name differs;
  configure does not translate names or support multiple layouts, variants, or arbitrary option selection.
  Session and greeter default to Right Alt Compose; see the native override below for layouts requiring AltGr.
- Native package and configuration files in `capabilities/` are the inputs. There are no secret inputs, personal
  configuration files, or external application repository checkouts in this slice.

Supported options:

| Option | Meaning |
|---|---|
| `--user <name>` | Override `SUDO_USER` in running context; mandatory in target context |
| `--target-root <mounted-dir>` | Configure an absolute, existing mount point other than `/`, with explicit `--user` |
| `--refresh` | Permit a full sync and upgrade in the first missing-package transaction |
| `--output <dir>` | Write evidence to an absent or empty directory; directory symlinks are rejected |
| `--help` | Show purpose, prerequisites, inputs, effects, evidence, and outcomes; use alone |

Unsupported arguments, including combined help, end with `2`. `MIRROROS_CONFIGURE_ROOT` remains test-only,
requires command doubles, and cannot be combined with `--target-root`.

### Installer target context and code delivery

`--target-root` requires an absolute, existing mounted directory other than `/` and an explicit non-root
`--user` from the target. Validation collects problems before any package, file, unit, or user convergence.
Package, user, and unit queries and commands enter the target through the helpers' `cfg_exec` wrapper using
`arch-chroot`; user writes use `runuser` inside that target with its own `HOME`. System files and links, keyboard
and session-file checks, the lock, and evidence use paths prefixed with the mounted root from the live medium.
Invalid target contexts create no lock or evidence.

The guided engine invokes configure only after all base postconditions pass and before unmounting the target.
Before invocation it copies `operations/configure`, `operations/lib/lifecycle-discovery.sh`,
`operations/lib/timing.sh`, `capabilities/`, and `identity.json` into the target's `/usr/local/lib/mirroros/`, root-owned with directories and executables
`0755` and other files `0644`. `/usr/local/bin/mirroros-configure` points to that copy's entry point. The entry
point resolves symlinks, so `sudo mirroros-configure` works without a clone. This is a snapshot for reruns, not
an automatically synchronized or updated installation of MirrorOS code; development still uses a checkout.

The engine appends combined output to `engine.log` and publishes the positioned step markers
`== <k>/<total> <step> ==`. Only configure outcome `0` permits `installed`/`0`. Any failure or interruption becomes
`not_configured`/`4`, preserving configure's outcome, failed step, and target-relative evidence directory in
the engine record. Normal cleanup still unmounts the target. Recovery is to boot the installed system, log in
at a console, inspect the evidence, and run `sudo mirroros-configure`; the assistant offers no live-medium retry.

## Validation and package safety

Before package, managed-file, unit, or user changes, validation collects detected problems: privilege and target
user, required tools, lock availability, output path, XKB layout data and layout, existing sync databases, and
resolution of every declared package to its declared repository. Concurrent runs are excluded by `flock` on
`/run/mirroros/configure.lock` on the configured system (under the mounted root in target context). The target's
on-disk `/run` is hidden by tmpfs at boot. Lock metadata and evidence are infrastructure writes, not convergence
changes.

Without `--refresh`, if any package is missing, non-ignored output from `pacman -Qu` blocks the run with outcome
`2`; the diagnostic advises a full `sudo pacman -Syu` or an explicit rerun with `--refresh`. Otherwise missing
packages are installed with `pacman -S --needed --noconfirm` against existing databases. With `--refresh`, the
first missing-package transaction uses `pacman -Syu --needed --noconfirm`; later transactions use `-S`.
Target-context transactions use `env SNAP_PAC_SKIP=y pacman ...` inside `arch-chroot` to avoid installation-time
snap-pac snapshots; transactions on the running installed system retain normal snap-pac behavior.

**Never run `pacman -Sy` alone:** refreshing databases without upgrading the system can produce an unsupported
partial upgrade. Configure never uses that operation. `--refresh` can upgrade the entire system and should be
chosen deliberately. If no declared package is missing, there is no package transaction, sync, or upgrade even
with `--refresh`; read-only validation and evidence queries still invoke pacman.

## Consequential effects

The fourteen steps run in this order:

| Step | Applied state |
|---|---|
| `visual/theme` | Reviewed product theme including its backgrounds, and initialize-only current theme/background links |
| `desktop/terminal` | Foot, `ttf-jetbrains-mono-nerd`, `noto-fonts-emoji`, approved native terminal-local defaults and Foot as the terminal for `Terminal=true` desktop entries |
| `desktop/files` | Nautilus from `extra`, with packaged dependencies; no personal settings, optional integrations or desktop-portal configuration ([sources](../../capabilities/desktop/files/sources.md)) |
| `workflow/node` | `git`, the identified NVM release and declared Node.js version under the user's `~/.nvm`, and a managed environment file |
| `workflow/shell` | Zsh with managed startup files, Zplug and identified plugin sources, shell tools, Starship, a marked bashrc source block, and Zsh as the login shell when it was Bash |
| `workflow/tmux` | tmux with managed native files, TPM and identified plugin sources, the compiled tmux-thumbs helper, wl-clipboard, inetutils, Rust, base-devel, and Sesh built by the user from a reviewed recipe; no `/etc/tmux.conf` |
| `workflow/editor` | Lazygit, tree-sitter-cli, unzip and Go, managed Lazygit and `vim` wrapper files, the external Neovim configuration at `~/code/nvim` linked from `~/.config/nvim`, and its locked plugins, tools and parsers prepared by the user |
| `workflow/pi` | ffmpeg, the external pi-config at `~/code/pi-config`, the Pi executable in the user's NVM prefix selected from pi-config's exact declaration, the pi-config runtime dependencies, the identified Google Cloud CLI archive under `~/.local/opt`, the `pi-editor` and `gcloud` links, and the initialize-only `~/.pi` defaults with their npm packages and owned skills |
| `desktop/compositor/providers/hyprland` | Session and greeter with the shared resolved-first layout list (`us,es` declared), the approved Story 4.3 bindings, the greeter layout indicator, Wayland greeter, and one uwsm session entry |
| `desktop/shell` | Quickshell and the shell's dependencies, the reviewed shell runtime under `/usr/share/mirroros/shell`, and its user unit enabled for the selected user |
| `desktop/lock` | hyprlock and hypridle, native lock and idle configuration, a hypridle drop-in, and hypridle enabled for the selected user |
| `visual/branding` | librsvg, the shared MirrorOS wordmark SVG and the PNG rendered from it by the installed `rsvg-convert` |
| `system/boot-splash` | Plymouth, the static MirrorOS theme and its selection, the `plymouth` hook drop-in, `quiet splash` on the normal boot entry, and boot images regenerated only when these inputs change |
| `desktop/login` | SDDM and uwsm, explicit `noto-fonts`, the MirrorOS theme without autologin, enable-only login, and graphical default target |

The Nerd Font supplies Starship glyphs but does not provide SDDM's required `ttf-font`; `noto-fonts` supplies that
virtual dependency explicitly. SDDM's mandatory dependencies still include Xorg even though its configured
greeter uses Wayland. No `qt6-wayland` dependency or VM-specific workaround is added without checkpoint evidence.

Managed destinations are:

- `~/.config/foot/foot.ini`: Osaka Jade palette, `JetBrainsMono Nerd Font Mono:size=9`, centered 14x14 padding,
  `term=foot`, and CSI-u Shift+Return / Alt+Shift+Return sequences. Foot reads this before its system default.
  The package-owned `/etc/xdg/foot/foot.ini` is deliberately left intact. See
  [terminal provenance and notices](../../capabilities/desktop/terminal/sources.md).
- `~/.config/mirroros/node/environment.zsh`: the declared Node.js version and PATH entry for the selected runtime,
  plus an on-demand `nvm_load`; NVM is installed by the user without profile edits. See
  [node sources](../../capabilities/workflow/node/sources.md).
- `~/.zshenv`, `~/.zshrc`, `~/.zprofile`: the approved interactive Zsh baseline. Plugins live under
  `~/.local/share/zplug`, provisioned by configure and never at shell startup. User-owned files and links are
  preserved. See [shell sources](../../capabilities/workflow/shell/sources.md).
- `~/.config/tmux/tmux.conf`, `tmux.bindings.conf`, `tmux.navigator.conf`, `tmux.theme.conf`: the approved Tmux
  baseline with Ctrl+A, Neovim-aware navigation, Tokyo Night styling and Prefix+o for Sesh; plugins live under
  `~/.config/tmux/plugins`, provisioned by configure (the tmux-thumbs helper is compiled there as the user) and
  never by Tmux. `sesh-bin` is the only package that is not from an official repository: it is built by the user
  from the reviewed recipe in the product and installed with `pacman -U`, and its package file stays in
  `~/.cache/mirroros/sesh`. User-owned files and links are preserved. See
  [tmux sources](../../capabilities/workflow/tmux/sources.md).
- `~/.config/lazygit/config.yml`, `~/.local/bin/vim`: the portable Lazygit input and the Neovim wrapper that opens Oil.
  `~/.config/nvim` links to the selected `master` of the external Neovim configuration cloned at `~/code/nvim`, only
  while that path is absent; a clone with local work, another origin or divergent history fails with an actionable
  message and is never reset. Preparation runs as the user once per applied commit; configuration revisions are
  intentionally not pinned. See [editor sources](../../capabilities/workflow/editor/sources.md).
- `~/code/pi-config`, `~/.local/bin/pi-editor`, and the Pi executable: pi-config is the selected `master` of the external
  repository, synchronized like the Neovim configuration (local work, another origin or divergent history fails and
  is never reset). The Pi version is selected once per run from its exact `devDependencies` entry; an absent entry
  selects the latest stable release, and a range or malformed value fails without fallback. Pi is installed by the
  user with npm lifecycle scripts disabled, and the pi-config runtime dependencies only when its manifest or
  lockfile changed. Transitive dependencies are not pinned and compatibility is never repaired automatically.
  `pi-editor` links to the pi-config launcher only while that path is absent. See
  [Pi sources](../../capabilities/workflow/pi/sources.md).
- `~/.local/opt/google-cloud-sdk-589.0.0` and `~/.local/bin/gcloud`: the versioned Google Cloud CLI archive, installed
  by the user after its size, MD5 and locally computed SHA256 are verified (the SHA256 is not published by upstream;
  this needs HTTPS access to `dl.google.com` only when the installation is missing). No installer script,
  component update, `gcloud init` or authentication runs, and no profile is edited. A directory of another version,
  a symlink or a concurrently created destination is preserved and reported; `gcloud` links to the installation only while
  that path is absent. Account setup, project selection and Application Default Credentials stay a private,
  attended step. See [Pi sources](../../capabilities/workflow/pi/sources.md).
- `~/.pi`: initialized only when the path is absent, with MirrorOS-owned settings, keybindings, instructions and prompt
  templates (voice and text-to-speech disabled; no credentials, sessions or models), the npm packages listed in
  `capabilities/workflow/pi/npm-packages` (installed with lifecycle scripts disabled and a private empty npm
  configuration; this needs access to the npm registry), the MirrorOS-owned skills (delivered without overwriting to
  `~/.local/share/mirroros/pi/skills`), the external manual skills listed in `capabilities/workflow/pi/external-skills`
  (current upstream, fetched by the commit resolved once per run into the staging, with `disable-model-invocation: true`
  as the only amendment; this needs access to GitHub and the npm registry) and links to the extensions of pi-config. Any existing `~/.pi`, including a symlink or an empty directory, is preserved entirely and reported;
  nothing is merged, reset or reconciled inside it. To adopt newer defaults, move the directory aside
  (for example `mv ~/.pi ~/.pi.backup`) and rerun configure. Initialization is staged outside `~/.pi` and published
  only after validation, so a failed run leaves no partial directory.
- `~/.config/mirroros/bash/starship.bash`: default Starship initialization for interactive bash; sourced through
  one marked block appended to `~/.bashrc`. No `starship.toml` is supplied.
- `~/.config/xdg-terminals.list`: `foot.desktop`, the terminal `uwsm app` uses for `Terminal=true` desktop entries.
  A user-owned list (or `~/.config/hyprland-xdg-terminals.list`) is preserved; when the effective list names no
  installed desktop entry, the step fails with an actionable message instead of passing.
- `~/.config/hypr/hyprland.lua`: the managed entry point loads `/usr/share/mirroros/hypr/defaults.lua`, then optional
  personal layers. Product defaults include layouts from `layouts.lua` (the resolved layout first, then `us,es`
  without duplicates), Right Alt Compose, repeat defaults, `dwindle.preserve_split`, the reviewed border theme and
  the approved bindings. Independently of the theme, window borders are 2 px, active and inactive opacity are
  0.985 and 0.96, and blur is disabled; no application-specific exceptions are supplied. Configure migrates only exact known earlier entry points and preserves modified files,
  links and existing `hyprland.conf`. The earlier `SUPER+SHIFT+Q` and `SUPER+SHIFT+E` bindings are removed (close:
  `SUPER+W` or `SUPER+Q`; logout: System menu); `SUPER+Return` still launches `uwsm app -- foot`.
- `/usr/share/mirroros/hypr/defaults.lua` and `personal-loader.lua`: tracked product files. After defaults and theme,
  the loader executes existing user-owned `~/.config/hypr/monitors.lua`, `input.lua`, `looknfeel.lua`, `bindings.lua`
  and `autostart.lua`, in that order. Configure creates commented `monitors.lua` and `bindings.lua` templates only when absent; it
  never overwrites personal layers or links and does not create the other layers. They are executable Lua;
  errors are reported and later files still load, but changes made before an error are not rolled back. The loader
  uses this HOME-relative path, not a custom `XDG_CONFIG_HOME`. Use `MirrorOSKeys.bind` to register personal
  shortcuts and avoid duplicate registered chords. To replace an existing action without changing its chord, use
  `MirrorOSKeys.replace(id, description, dispatcher)` in `bindings.lua`. Bindings are registered after this file
  runs, even when it fails after partial changes. Direct `hl.bind` can bypass the registry.
- `/usr/share/mirroros/hypr/shell-bindings.lua`, `window-bindings.lua`: the approved key table and the registry the
  shell's keyboard help reads (`$XDG_RUNTIME_DIR/mirroros-keybindings.tsv`). Nothing is unbound at runtime. See
  [Hyprland bindings provenance](../../capabilities/desktop/compositor/providers/hyprland/UPSTREAM.md).
- `/usr/share/mirroros/hypr/keyboard.lua`: runtime layout resolution for the greeter.
- `/usr/share/mirroros/sddm/hyprland.lua`: minimal greeter configuration without logo, splash, or animations,
  using the same layout resolver and Right Alt Compose default.
- `/usr/share/mirroros/wayland-sessions/hyprland-uwsm.desktop`: a link to the upstream session entry. Its directory
  must contain exactly that entry and its `Exec` must contain `uwsm start` and `hyprland.desktop`.
- `/etc/sddm.conf.d/20-mirroros-hyprland.conf`: Wayland greeter command and restricted Wayland session directory.
- `/etc/sddm.conf.d/10-mirroros-login.conf`: `Current=mirroros` and disabled autologin; the exact earlier
  stock-theme file is migrated, any other content is a conflict.
- `/usr/share/mirroros/themes/default/backgrounds`: the default theme's product backgrounds, published inside the
  theme tree and manifest; see [theme sources](../../capabilities/visual/theme/sources.md#backgrounds).
- `/usr/share/mirroros/branding`: the wordmark SVG and its rendered PNG, published as one manifest-checked tree; see
  [branding sources](../../capabilities/visual/branding/sources.md).
- `/usr/share/sddm/themes/mirroros`: the MirrorOS SDDM theme, published as one manifest-checked tree; see
  [login sources](../../capabilities/desktop/login/sources.md).
- `/usr/share/plymouth/themes/mirroros/`, `/etc/plymouth/plymouthd.conf` and
  `/etc/mkinitcpio.conf.d/90-mirroros-plymouth.conf`: the static Plymouth theme, its selection and the hook
  drop-in; the boot entry or `/etc/default/limine` gains `quiet splash`. See
  [Boot splash overlay](#boot-splash-overlay).
- `/usr/share/mirroros/shell`: the shell runtime, published as one manifest-checked tree; `/etc/systemd/user/
  mirroros-shell.service`: its user unit; `~/.config/systemd/user/graphical-session.target.wants/mirroros-shell.service`:
  its enablement for the selected user. Personal preferences (`~/.config/mirroros/shell.json`) and private state
  (`~/.local/state/mirroros/shell`) are never read or written. See
  [shell sources](../../capabilities/desktop/shell/sources.md) and the [desktop shell procedure](desktop-shell.md).
- `~/.config/hypr/hypridle.conf`, `~/.config/hypr/hyprlock.conf`: lock after 300 seconds idle and before sleep, the
  `us` layout before every lock, the while-away lock marker hooks, and one password field over the blurred selected
  background with the selected theme's colors (ADR 0021) and system PAM authentication; `/etc/systemd/user/hypridle.service.d/10-mirroros.conf`: stale-marker cleanup before hypridle
  starts; `~/.config/systemd/user/graphical-session.target.wants/hypridle.service`: enablement of the packaged unit
  for the selected user. See [lock sources](../../capabilities/desktop/lock/sources.md).

SDDM is enabled, **never started or restarted**; `graphical.target` becomes the default. Postconditions check the
SDDM display-manager alias, the absence of another enabled display manager, and the default target. Configure
does not automatically disable conflicting display managers. On outcome `0`, the final informational line says
the graphical login is available at the next boot. Reboot only after reviewing the outcome and evidence.

The user session's keyboard repeat defaults are a 230 ms initial delay and 62 repetitions per second,
matching the maintainer-approved host behavior. The greeter retains its compositor repeat defaults: the
reconstruction A/B check recovered login after removing the explicit repeat fields from that file.
This does not identify an individual offending field. These settings do not change pointer sensitivity.

### Virtual display defaults

The managed Hyprland session loads `/usr/share/mirroros/hypr/monitors.lua` through provider defaults, and the SDDM
greeter loads it directly with `dofile`, at each configuration load. A general rule requests preferred mode,
automatic position and scale 1. A specific `Virtual-1` rule requests `1920x1080@60`, automatic position and
scale 1.6. Any output named `Virtual-1` matches, not only the local QEMU lab. Personal monitor rules load after
product defaults in the user session; the greeter does not load them. The session also sets `GDK_SCALE=1`.

This rule does not configure the live console, kernel framebuffer, firmware or boot menu. Kernel `video=` changes
are a separate boot-policy decision, not an implicit part of desktop scaling. Configure publishes the files but
never reloads the compositor or restarts SDDM; review them at the next session and greeter start.

When `/sys/class/dmi/id/sys_vendor` reads `QEMU`, the reference VM identity of
`targets/reference-vm/target.json`, session defaults also set `quirks.skip_non_kms_dmabuf_formats = false`.
Hyprland 0.57 enables that quirk by default and then advertises only dmabuf formats that a monitor's primary
plane can import. The virtio-gpu plane offers `XRGB8888` alone, so GPU-rendered clients lose their alpha channel
and transparent surfaces, such as the idle notification layer, render black. Other machines keep Hyprland's
default. A runtime `hl.config` change did not alter the formats offered to a new client; a new session did.
The greeter does not load it. `tests/capabilities/desktop/hyprland/vm-dmabuf-formats.test.lua` covers the
condition.

### Right Alt Compose and native overrides

`kb_options = "compose:ralt"` makes Right Alt a Compose key in the managed session and greeter. The console keeps
`/etc/vconsole.conf`, which is not changed. The session and the greeter load one list from `layouts.lua`: the
resolved layout first, then the declared product layouts `us,es` (DEC-017) without duplicates, switched with
`SUPER+I` and `SUPER+SHIFT+I` in both ([ADR 0015](../adr/0015-greeter-keyboard-layout-switching.md)); the lock
screen uses the resolved layout without switching and restores the previous layout after unlocking.
Validation rejects a declared layout missing from the XKB data
before any package change.
This replaces Right Alt's normal AltGr role. Do not assume layouts that depend on AltGr are unaffected.

To retain AltGr in a session using the managed entry point, put the desired native configuration in the personal
`~/.config/hypr/input.lua`, for example `hl.config({ input = { kb_options = "" } })`. It loads after the product
defaults. The greeter uses `/usr/share/mirroros/sddm/hyprland.lua` and requires a separately reviewed root edit.
Review the resulting native configuration before the next session/greeter start; configure never reloads the
compositor or restarts SDDM. Existing customized session entry points remain user-owned and do not automatically
adopt personal layers.

The prototype confirmed the reported accented-character sequence in the graphical session. Contract checks
prove native declaration delivery and unchanged layout resolution, not all keyboard layouts or graphical
greeter behavior; fresh-session and greeter interaction remain attended verification.

### File ownership and safe rerun

All home-directory writes run as the target user through `runuser`. Files are created when absent and updated
only when they carry the `managed by MirrorOS configure` header and differ. Non-managed files and symbolic links
are preserved and reported as user-owned; their postconditions only check existence, not the managed contents.
A user-owned legacy `~/.config/hypr/hyprland.conf` prevents creating a shadowing Lua configuration. Hyprland's
entry point is a stricter exception: only exact known earlier contents are migrated, even if a modified file retains
the managed header. Personal layer files are not written by configure.

The shell runtime, the shell unit, the hypridle drop-in and the binding files are tracked deliveries: configure
records what it delivered (`/var/lib/mirroros/configure/delivered/`, or the runtime's `.mirroros-manifest`), so a
local edit is detected even when it keeps the managed header. An absent destination is created and the intact
previous delivery is updated; an edited, unknown or linked destination is a conflict that fails the step with
outcome `4` and is never overwritten. Move it aside (or restore it) and rerun.

User units are enabled offline by creating the selected user's own `graphical-session.target.wants` link, as
that user; no user manager or bus is needed and no other account is affected. A user's own unit file or mask in
`~/.config/systemd/user/` is preserved. Configure never starts, restarts or reloads the shell, hypridle or the
desktop in either context: a running session picks up the new units at its next login.

`~/.bashrc` is never rewritten: one block between `# BEGIN MirrorOS configure` and `# END MirrorOS configure`
sources the managed Starship file. A linked bashrc is preserved; malformed or duplicate markers require manual
repair. Existing conflicting system links are also preserved rather than removed.

A full rerun starts from the beginning. Satisfied steps report `unchanged`, changed steps report `changed`, and
execution stops at the first failure. Later steps are recorded as `not_run`; there is no resume state. An already
configured rerun performs no package transaction. The complete graphical and rerun proof belongs to the VM
checkpoint, not just the mechanism tests.

### Boot splash overlay

`system/boot-splash` changes only a recognized MirrorOS boot configuration: the shipped systemd-boot entries and
preset (`ext4-systemd-boot`, `btrfs-rescue`) or the shipped `/etc/default/limine` and hook drop-in
(`btrfs-limine`). Inspected files are parsed as data before anything is written; an ambiguous boot loader, an
unknown hook override, a link, an edited entry or a local Plymouth theme selection is preserved and fails the step
with outcome `4`. The ESP must be mounted at `/boot`.

Only `quiet` and `splash` are appended; root, subvolume, zswap and resume parameters keep their values. The
systemd-boot fallback entry keeps the base command line and is the menu path without the splash. Boot images are
regenerated with `mkinitcpio -p linux` (systemd-boot) or `limine-update` (Limine) only when a managed input changed
or an earlier regeneration is still pending in `/var/lib/mirroros/configure/boot-splash.state`. Completion is
recorded only after the effective parameters, the referenced boot files and the theme inside each normal boot image
are checked; a failed or interrupted regeneration stays pending and is retried by the next run. Configure never
reboots. See the [greeter and Plymouth procedure](greeter-plymouth.md) for diagnostics and recovery, and its
[VM qualification record](greeter-plymouth.md#vm-qualification-record) for the bounded VM evidence.

## Evidence

Root runs that pass argument parsing attempt to create a run directory under
`/var/log/mirroros/configure/<run-id>/`, or at `--output`. Run IDs contain a UTC timestamp and UUID. The directory
is root-owned and mode `0700` on the real system; output must be absent or empty and must not itself be a symlink.
With `--target-root <dir>`, the default is `<dir>/var/log/mirroros/configure/<run-id>/` and the TSV records
`context target`; on the installed system the same evidence is visible under `/var/log/mirroros/configure/`.
An explicit `--output` is used as supplied to the coordinator, not automatically prefixed by the target root.

| File | Contents |
|---|---|
| `configure.log` | Allowed step commands and their output, validation failures, and step diagnostics |
| `configure-run.tsv` | Run format 2, identity, context, target user, code identity/dirty flag, start/end, outcome, failed step, reason, package mode, guard result, every step's status/postcondition, and total/validation/started-step timing |
| `packages.tsv` | Declared package names, resolved or installed versions, and repositories; not a full dependency inventory |
| `sources.tsv` (when consumed) | Public external source names/URLs, selected refs/commits and declared versions; no configuration or private-state dumps |

TSV values have tabs and newlines replaced. Git identity uses `git rev-parse HEAD` and a dirty flag when git
and `.git` exist. Otherwise configure reads `commit` and `dirty` from the code root's `identity.json`, using
Bash without Node.js or jq; missing identity data is `unavailable`. The TSV dirty flag is `yes` or `no` when
known. Git is optional. No JSON output, shell trace, user-file dump, or secret input is recorded. Scan copied evidence on the development host with
`gitleaks dir --no-banner --redact <evidence-dir>`; Gitleaks is not a target prerequisite.

Help, parsing failures, damaged-checkout failures before execution, and unprivileged rejections produce no run
evidence. Invalid target-root contexts also produce no run evidence. A non-root process cannot create
root-owned evidence and does not escalate. If the output directory
cannot be created, configure reports that failure; evidence is not guaranteed for an unwritable or invalid path.

### Timing interpretation and collection

Configure records `total`, `validation`, and each started `step.<capability-path>` in its existing TSV.
Validation includes preflight and evidence initialization, not work attributed to the first capability.
Timing rows have five columns (`timing`, interval id, status, duration_ms, reason), distinct from four-column
step-status rows. Available durations are non-negative integer milliseconds at 10 ms effective resolution,
from the first `/proc/uptime` value. Unavailable readings have a safe reason and an empty duration, never a
wall-clock fallback or a placeholder zero. Unstarted steps have no timing row. Historical pre-timing TSV
remains readable without invented timings. See the [field contract](../../capabilities/README.md#configure-timing-evidence).

Total closes before evidence serialization and includes validation, steps, and orchestration. Handled failures
and signals close reached intervals without changing outcomes; hard kills and unwritable evidence gain no
persistence guarantee. Engine `configure` contains this total, which contains validation and steps: do not add
nested durations. The engine retains only this invocation's native `configure-run.tsv`, `packages.tsv`, and
`sources.tsv` when available under `engine/configure/`, through the existing safe VM collection boundary.
The helper is embedded in the ISO/development overlay and copied with installed rerun code; no Node.js timing
dependency or live per-step timing display is added. For the authorization-gated three-run protocol and private
report, see [Installation time measurements](installation-time-measurements.md).

## Normalized outcomes and recovery

| Outcome | Meaning | Next action |
|---|---|---|
| `0` | Help, or all reached steps completed and all postconditions passed | Review evidence; graphical usability still needs the checkpoint |
| `2` | Invalid input or unmet prerequisite; no convergence applied | Resolve every listed problem, then rerun |
| `3` | Explicit cancellation through SIGINT (`Ctrl+C`) | Inspect evidence, then rerun from the beginning |
| `4` | A step's postcondition was not satisfied | Inspect the named step and `configure.log`, resolve the conflict, then rerun |
| `5` | Step command failure, SIGTERM, or SIGHUP | Inspect upstream diagnostics, fix the cause, then rerun |
| `6` | Damaged checkout, unsupported internal context, or contract failure | Restore the checkout or fix the internal contract before rerunning |

For execution failures, output names the step, reason, and next action. From a checkout, rerun
`sudo operations/configure`; after an installer run, boot the installed system and use `sudo mirroros-configure`.
Outcomes `3`, `4`, and `5` never claim readiness. Package download, signature, or keyring failures remain failures;
check network and mirror availability or repair the system keyring deliberately, rather than disabling signature
checks. A missing mirror version may require a full system upgrade or `--refresh`. Preserve the failed run's
evidence and choose a new absent or empty `--output` directory for each rerun.

## Story 4.3 reconstruction checkpoint

Plan 02-19 Task 3 has reference evidence at clean candidate
`8c3c3cccc46421598b1fce47a330452c78230a80`; final story acceptance is still open. The installation used a
verified older base ISO plus explicit candidate input, not an unchanged candidate release ISO.

| Context | Native run ID | Outcome |
|---|---|---|
| Installer target | `20261025T035115Z-de1ed53d-f217-4779-b44d-5b1694a3661a` | 0; all 10 steps changed and passed |
| First running | `20261025T043055Z-f62449d8-855f-4317-8644-cc74fb9860d9` | 0; 9 unchanged, Hyprland changed |
| Identical second running | `20261025T043109Z-c3882350-3144-4618-941c-7c42f2f2fce7` | 0; all 10 unchanged and passed |

All runs record the same clean candidate. Running package/source records are byte-identical; 34 declared package
mappings match target/running. Neither running run performed a package transaction or restarted compositor,
shell or hypridle. The first running run rewrote the managed session file; no pre-run bytes/mode snapshot exists
and the cause is not established. The maintainer reported opening it without modification. Do not relabel that
run unchanged or attribute the difference to a user edit. A later, explicitly reviewed local QEMU resolution
exception is separate from this observation.

Evidence: `evidence/desktop-shell-production/candidate-20261025T032813Z-amended/configure-contexts/` and
`configure-context-comparison.txt`, with selected records hash-checked and secret-scanned. Actual native reload,
logout/startup, one-failure recovery and attended results are recorded in the [shell procedure](desktop-shell.md).
Mouse drag and quiet-runtime failures still block a blanket ready claim; successful configure is not complete
Story 4.3 or full-MVP readiness. No private preferences, notification history or credentials were exported.

## Add a package and rerun

1. Add `<name> <official-repository>` to the owning capability's `packages` file and review its inclusion.
2. Update native configuration and postconditions only when that capability needs them. For a new step, follow
   the [step contract](../../capabilities/README.md#adding-a-later-slice) and add it to the explicit order.
3. Run the shell and mechanism checks, then run `sudo operations/configure` on the installed system.
4. If the pending-upgrade guard blocks the run, deliberately choose a full `sudo pacman -Syu` or rerun with
   `--refresh`; do not refresh databases alone.
5. Review outcome and evidence, exercise the capability, then rerun to check unchanged steps and no package
   transaction. Routine system updates remain outside this stage's role.
