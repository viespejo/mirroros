# Configure lifecycle procedure

**Availability:** implemented for the running installed system. Installer context: **Pending, plan 02-16**.
Story 4.2 is not complete until that follow-up delivers installer integration and the clean-installation proof.

## Current behavior

Invoke `operations/configure` by path from any working directory; it does not need to be installed on `PATH`.
It applies minimal graphical login and user tools through the ordered steps in
[`capabilities/configure-steps`](../../capabilities/configure-steps), following
[ADR 0010](../adr/0010-environment-configuration-mechanism-and-scope.md). This is not yet the complete MVP desktop.
The actual graphical path remains subject to the plan's blocking VM checkpoint; successful postconditions are
not a substitute for that proof or for independent readiness verification by `verify`.

```bash
sudo operations/configure
sudo operations/configure --user alice
sudo operations/configure --user alice --refresh --output /var/log/mirroros/configure/manual-run
operations/configure --help
```

Replace `alice` with an existing non-root account. Only a sole `--help` returns help without mutation or root.
Help also requires intact configure helpers and listed steps. A missing or unloadable lifecycle helper, missing
capability helpers, or missing or invalid listed steps reports an incomplete or damaged checkout with outcome
`6`; restore the files from Git or reclone.

## Prerequisites and inputs

- Run as root using `sudo`. The target user is `--user <name>`, otherwise `SUDO_USER`; missing, nonexistent,
  invalid, and root target accounts are rejected. Bash must already be the intended interactive shell; configure
  does not change the login shell.
- Use a running MirrorOS-installed Arch system with Bash, pacman, flock, runuser, systemctl, install, and the
  standard text and filesystem tools checked by validation. No Node.js, jq, or git runtime dependency is added.
- Existing pacman sync databases and access to declared official repositories are required. Network access is
  needed for missing packages; configure never initializes databases or modifies the keyring automatically.
- `xkeyboard-config` must already supply `/usr/share/X11/xkb/rules/base.lst`. Installation policy includes this
  prerequisite. Layout validation occurs before convergence, even if other packages are missing.
- The system keyboard layout is resolved from `XKBLAYOUT` in `/etc/vconsole.conf`, then `KEYMAP`, then `us`.
  It must be a known XKB layout. Set an explicit supported `XKBLAYOUT` when the console keymap name differs;
  configure does not translate names or support multiple layouts, variants, or options in this skeleton.
- Native package and configuration files in `capabilities/` are the inputs. There are no secret inputs, personal
  configuration files, or external application repository checkouts in this slice.

Supported options:

| Option | Meaning |
|---|---|
| `--user <name>` | Override the target user inferred from `SUDO_USER` |
| `--refresh` | Permit a full sync and upgrade in the first missing-package transaction |
| `--output <dir>` | Write evidence to an absent or empty directory; directory symlinks are rejected |
| `--help` | Show purpose, prerequisites, inputs, effects, evidence, and outcomes; use alone |

Unsupported arguments, including combined help, end with `2`. There is no public target-root option. The
`MIRROROS_CONFIGURE_ROOT` environment variable is test-only, requires command doubles, and must not be used as an
installer interface. The guided-installer hook, ISO embedding, and target-context execution belong to plan 02-16.

## Validation and package safety

Before package, managed-file, unit, or user changes, validation collects detected problems: privilege and target
user, required tools, lock availability, output path, XKB layout data and layout, existing sync databases, and
resolution of every declared package to its declared repository. Concurrent runs are excluded by `flock` on
`/run/mirroros/configure.lock`. Lock metadata and evidence are infrastructure writes, not convergence changes.

Without `--refresh`, if any package is missing, non-ignored output from `pacman -Qu` blocks the run with outcome
`2`; the diagnostic advises a full `sudo pacman -Syu` or an explicit rerun with `--refresh`. Otherwise missing
packages are installed with `pacman -S --needed --noconfirm` against existing databases. With `--refresh`, the
first missing-package transaction uses `pacman -Syu --needed --noconfirm`; later transactions use `-S`.

**Never run `pacman -Sy` alone:** refreshing databases without upgrading the system can produce an unsupported
partial upgrade. Configure never uses that operation. `--refresh` can upgrade the entire system and should be
chosen deliberately. If no declared package is missing, there is no package transaction, sync, or upgrade even
with `--refresh`; read-only validation and evidence queries still invoke pacman.

## Consequential effects

The five steps run in this order:

| Step | Applied state |
|---|---|
| `desktop/terminal` | foot, provisional `ttf-jetbrains-mono-nerd`, and user foot font configuration |
| `workflow/shell` | Starship, managed interactive bash initialization, and a marked bashrc source block |
| `workflow/tmux` | tmux with defaults; no `/etc/tmux.conf` |
| `desktop/compositor/providers/hyprland` | Minimal session, shared keyboard module, Wayland greeter, and one uwsm session entry |
| `desktop/login` | SDDM and uwsm, explicit `noto-fonts`, stock theme without autologin, enable-only login, and graphical default target |

The Nerd Font supplies Starship glyphs but does not provide SDDM's required `ttf-font`; `noto-fonts` supplies that
virtual dependency explicitly. SDDM's mandatory dependencies still include Xorg even though its configured
greeter uses Wayland. No `qt6-wayland` dependency or VM-specific workaround is added without checkpoint evidence.

Managed destinations are:

- `~/.config/foot/foot.ini`: only `font=JetBrainsMono Nerd Font:size=11` beyond its management header. foot reads
  this before its system default. The package-owned `/etc/xdg/foot/foot.ini` is deliberately left intact.
- `~/.config/mirroros/bash/starship.bash`: default Starship initialization for interactive bash; sourced through
  one marked block appended to `~/.bashrc`. No `starship.toml` is supplied.
- `~/.config/hypr/hyprland.lua`: the shared keyboard module and exactly three bindings: `SUPER+Return` launches
  `uwsm app -- foot`, `SUPER+SHIFT+Q` closes the active window, and `SUPER+SHIFT+E` runs `uwsm stop`.
- `/usr/share/mirroros/hypr/keyboard.lua`: runtime layout resolution, shared by the greeter and managed session.
- `/usr/share/mirroros/sddm/hyprland.lua`: minimal greeter configuration without logo, splash, or animations.
- `/usr/share/mirroros/wayland-sessions/hyprland-uwsm.desktop`: a link to the upstream session entry. Its directory
  must contain exactly that entry and its `Exec` must contain `uwsm start` and `hyprland.desktop`.
- `/etc/sddm.conf.d/20-mirroros-hyprland.conf`: Wayland greeter command and restricted Wayland session directory.
- `/etc/sddm.conf.d/10-mirroros-login.conf`: stock theme with an empty `Current` and disabled autologin.

SDDM is enabled, **never started or restarted**; `graphical.target` becomes the default. Postconditions check the
SDDM display-manager alias, the absence of another enabled display manager, and the default target. Configure
does not automatically disable conflicting display managers. On outcome `0`, the final informational line says
the graphical login is available at the next boot. Reboot only after reviewing the outcome and evidence.

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

| File | Contents |
|---|---|
| `configure.log` | Allowed step commands and their output, validation failures, and step diagnostics |
| `configure-run.tsv` | Run identity, context, target user, code identity/dirty flag, start/end, outcome, failed step, reason, package mode, guard result, and every step's status/postcondition |
| `packages.tsv` | Declared package names, resolved or installed versions, and repositories; not a full dependency inventory |

TSV values have tabs and newlines replaced. Git identity uses `git rev-parse HEAD` and a dirty flag only when git
and `.git` exist; otherwise it is `unavailable`. Git is optional. No JSON, shell trace, user-file dump, or secret
input is recorded. Scan copied evidence on the development host with
`gitleaks dir --no-banner --redact <evidence-dir>`; Gitleaks is not a target prerequisite.

Help, parsing failures, damaged-checkout failures before execution, and unprivileged rejections produce no run
evidence. A non-root process cannot create root-owned evidence and does not escalate. If the output directory
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

For execution failures, output names the step, reason, and next action: rerun `sudo operations/configure`.
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
