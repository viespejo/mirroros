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
Before invocation it copies `operations/configure`, `operations/lib/lifecycle-discovery.sh`, `capabilities/`,
and `identity.json` into the target's `/usr/local/lib/mirroros/`, root-owned with directories and executables
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

The eight steps run in this order:

| Step | Applied state |
|---|---|
| `desktop/terminal` | Foot, `ttf-jetbrains-mono-nerd`, `noto-fonts-emoji` and approved native terminal-local defaults |
| `workflow/node` | `git`, the identified NVM release and declared Node.js version under the user's `~/.nvm`, and a managed environment file |
| `workflow/shell` | Zsh with managed startup files, Zplug and identified plugin sources, shell tools, Starship, a marked bashrc source block, and Zsh as the login shell when it was Bash |
| `workflow/tmux` | tmux with managed native files, TPM and identified plugin sources, the compiled tmux-thumbs helper, wl-clipboard, inetutils, Rust, base-devel, and Sesh built by the user from a reviewed recipe; no `/etc/tmux.conf` |
| `workflow/editor` | Lazygit, tree-sitter-cli, unzip and Go, managed Lazygit and `vim` wrapper files, the external Neovim configuration at `~/code/nvim` linked from `~/.config/nvim`, and its locked plugins, tools and parsers prepared by the user |
| `workflow/pi` | ffmpeg, the external pi-config at `~/code/pi-config`, the Pi executable in the user's NVM prefix selected from pi-config's exact declaration, the pi-config runtime dependencies, the identified Google Cloud CLI archive under `~/.local/opt`, the `pi-editor` and `gcloud` links, and the initialize-only `~/.pi` defaults with their npm packages and owned skills |
| `desktop/compositor/providers/hyprland` | Minimal session, shared keyboard module, Wayland greeter, and one uwsm session entry |
| `desktop/login` | SDDM and uwsm, explicit `noto-fonts`, stock theme without autologin, enable-only login, and graphical default target |

The Nerd Font supplies Starship glyphs but does not provide SDDM's required `ttf-font`; `noto-fonts` supplies that
virtual dependency explicitly. SDDM's mandatory dependencies still include Xorg even though its configured
greeter uses Wayland. No `qt6-wayland` dependency or VM-specific workaround is added without checkpoint evidence.

Managed destinations are:

- `~/.config/foot/foot.ini`: Tokyo Night palette, `JetBrainsMono Nerd Font Mono:size=14`, centered 16x16 padding,
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
- `~/.config/hypr/hyprland.lua`: the shared keyboard module, Right Alt Compose and exactly three bindings: `SUPER+Return` launches
  `uwsm app -- foot`, `SUPER+SHIFT+Q` closes the active window, and `SUPER+SHIFT+E` runs `uwsm stop`.
- `/usr/share/mirroros/hypr/keyboard.lua`: runtime layout resolution, shared by the greeter and managed session.
- `/usr/share/mirroros/sddm/hyprland.lua`: minimal greeter configuration without logo, splash, or animations,
  using the same layout resolver and Right Alt Compose default.
- `/usr/share/mirroros/wayland-sessions/hyprland-uwsm.desktop`: a link to the upstream session entry. Its directory
  must contain exactly that entry and its `Exec` must contain `uwsm start` and `hyprland.desktop`.
- `/etc/sddm.conf.d/20-mirroros-hyprland.conf`: Wayland greeter command and restricted Wayland session directory.
- `/etc/sddm.conf.d/10-mirroros-login.conf`: stock theme with an empty `Current` and disabled autologin.

SDDM is enabled, **never started or restarted**; `graphical.target` becomes the default. Postconditions check the
SDDM display-manager alias, the absence of another enabled display manager, and the default target. Configure
does not automatically disable conflicting display managers. On outcome `0`, the final informational line says
the graphical login is available at the next boot. Reboot only after reviewing the outcome and evidence.

Session and greeter keyboard repeat defaults are a 230 ms initial delay and 62 repetitions per second,
matching the maintainer-approved host behavior. These settings do not change pointer sensitivity.

### Right Alt Compose and native overrides

`kb_options = "compose:ralt"` makes Right Alt a Compose key in the managed session and greeter. The layout
still comes from the shared keyboard module; adding Compose never forces `us` or changes `/etc/vconsole.conf`.
This replaces Right Alt's normal AltGr role. Do not assume layouts that depend on AltGr are unaffected.

To retain AltGr, deliberately take ownership of each applicable native file: remove its
`managed by MirrorOS configure` comment and set `kb_options = ""` or the options required by the chosen layout.
The session file is `~/.config/hypr/hyprland.lua`; the greeter file is
`/usr/share/mirroros/sddm/hyprland.lua` and requires a separately reviewed root edit. Configure preserves those
unmarked files. Review the resulting native configuration before the next session/greeter start; configure
never reloads the compositor or restarts SDDM. No additional override schema is introduced.

The prototype confirmed the reported accented-character sequence in the graphical session. Contract checks
prove native declaration delivery and unchanged layout resolution, not all keyboard layouts or graphical
greeter behavior; fresh-session and greeter interaction remain attended verification.

### File ownership and safe rerun

All home-directory writes run as the target user through `runuser`. Files are created when absent and updated
only when they carry the `managed by MirrorOS configure` header and differ. Non-managed files and symbolic links
are preserved and reported as user-owned; their postconditions only check existence, not the managed contents.
A user-owned legacy `~/.config/hypr/hyprland.conf` prevents creating a shadowing Lua configuration.

`~/.bashrc` is never rewritten: one block between `# BEGIN MirrorOS configure` and `# END MirrorOS configure`
sources the managed Starship file. A linked bashrc is preserved; malformed or duplicate markers require manual
repair. Existing conflicting system links are also preserved rather than removed.

A full rerun starts from the beginning. Satisfied steps report `unchanged`, changed steps report `changed`, and
execution stops at the first failure. Later steps are recorded as `not_run`; there is no resume state. An already
configured rerun performs no package transaction. The complete graphical and rerun proof belongs to the VM
checkpoint, not just the mechanism tests.

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
| `configure-run.tsv` | Run identity, context, target user, code identity/dirty flag, start/end, outcome, failed step, reason, package mode, guard result, and every step's status/postcondition |
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

## Add a package and rerun

1. Add `<name> <official-repository>` to the owning capability's `packages` file and review its inclusion.
2. Update native configuration and postconditions only when that capability needs them. For a new step, follow
   the [step contract](../../capabilities/README.md#adding-a-later-slice) and add it to the explicit order.
3. Run the shell and mechanism checks, then run `sudo operations/configure` on the installed system.
4. If the pending-upgrade guard blocks the run, deliberately choose a full `sudo pacman -Syu` or rerun with
   `--refresh`; do not refresh databases alone.
5. Review outcome and evidence, exercise the capability, then rerun to check unchanged steps and no package
   transaction. Routine system updates remain outside this stage's role.
