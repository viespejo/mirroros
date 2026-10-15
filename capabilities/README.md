# Configure capabilities

`operations/configure` coordinates bounded Bash steps over native Arch and application configuration, following
[ADR 0010](../docs/adr/0010-environment-configuration-mechanism-and-scope.md). This tree owns the steps and shared
helpers, not the installer or independent readiness verification. See the [configure procedure](../docs/procedures/configure.md)
for invocation, effects, evidence, and recovery.

## Step contract and order

`configure-steps` is an explicit Bash `CFG_STEPS` array of paths relative to this directory. There is no discovery,
dependency graph, or resume state. The current order is:

1. `desktop/terminal`: foot and its provisional Nerd Font.
2. `workflow/shell`: Starship initialization for the target user's bash.
3. `workflow/tmux`: tmux with upstream defaults.
4. `desktop/compositor/providers/hyprland`: session, keyboard module, greeter, and session selection.
5. `desktop/login`: SDDM, uwsm, an explicit generic font provider, and enable-only graphical login.

Each step supplies:

- `apply`: sourced by the coordinator in a fresh subshell with `set -Eeuo pipefail`. Its opening comments state
  prerequisites, expected context variables, and postconditions. It ends with `cfg_require` checks.
- `packages`: official repository declarations, validated for all steps before convergence starts.
- Only the native configuration files that capability needs, next to `apply`.

The coordinator supplies `STEP_DIR`, `CONFIGURE_CONTEXT`, `CONFIGURE_ROOT`, `TARGET_USER`, and shared helper state
including `CFG_OUTPUT`. A step uses helpers for packages, system files and links, user work, units, and read-only
queries. No `apply` calls `pacman`, `systemctl`, `install`, or `runuser` directly; the mechanism contract test checks
that boundary. Steps must not bypass helpers through `cfg_run` or introduce context-specific command execution.

Helpers in `lib/` own the effect boundary:

| Library | Responsibility |
|---|---|
| `common.sh` | Context guard, step execution, change tracking, postcondition checks, outcomes and signals |
| `validate.sh` | Arguments, prerequisites, lock, keyboard validation, package resolution and upgrade guard |
| `packages.sh` | Missing-package transactions and installed-package postconditions |
| `files.sh` | Managed files and links, user work, bashrc block, and single-session query |
| `units.sh` | Enable-only units, default target, and read-only display-manager queries |
| `evidence.sh` | Private run directory, sanitized TSV records, package versions, and allowed logs |

Only `CONFIGURE_CONTEXT=running` is implemented. Helpers reject `target` with outcome `6` and a pending-plan
message; plan 02-16 will add that context inside helpers, not steps. There is no public target-root option.
`MIRROROS_CONFIGURE_ROOT` is a test-only process context, analogous to `MIRROROS_DISCOVERY_ROOT`: it redirects
filesystem paths into a disposable root. It is not a safe chroot interface: package, unit, and user commands still
need test doubles and must never be exercised against a real host through that variable.

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

Implementation checks found that `ttf-jetbrains-mono-nerd` 3.5.1-2 provides `ttf-font-nerd`, not the `ttf-font`
required by SDDM 0.21.0-7. Login therefore declares `noto-fonts`, which explicitly provides `ttf-font`, rather than
letting pacman choose implicitly. These versions are observations, not pins. SDDM also pulls `xorg-server` and
`xorg-xauth` as mandatory dependencies although its configured greeter uses Wayland. `qt6-wayland` is not declared
speculatively; whether it is required remains a graphical-checkpoint finding.

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
initialization is guarded for interactive shells; no `starship.toml` or login-shell change is supplied.

foot reads user configuration before `/etc/xdg/foot/foot.ini`. The package already owns that system file without
a MirrorOS header, so the implementation deliberately preserves it and manages `~/.config/foot/foot.ini` instead.
This approved exception to the original system-default preference uses the existing user-ownership rules and
sets only `font=JetBrainsMono Nerd Font:size=11`. Typography remains provisional for Story 4.8. tmux receives no
configuration file.

## Keyboard validation and provider boundary

The validation point is preflight, before package, managed-file, unit, or user convergence. `xkeyboard-config` is
a base-installation prerequisite; a missing `/usr/share/X11/xkb/rules/base.lst` ends with outcome `2`, rather than
installing it and deferring layout validation. This was an explicitly approved base-policy adjustment in plan
02-15. The resolved layout is `XKBLAYOUT` from `/etc/vconsole.conf`, otherwise `KEYMAP`, otherwise `us`; it must
appear in the layout section of `base.lst`. Configuration is parsed as data, never sourced as shell code.
Console-only keymap names are not guessed or translated. Multiple layouts, variants, options, and non-Latin
layout adaptation are outside the skeleton.

Every Hyprland-specific package and native file lives below `desktop/compositor/providers/hyprland/`, including
the SDDM Wayland drop-in and greeter configuration. Login remains provider-neutral. The greeter and managed
session load one shared keyboard module at runtime through absolute-path `require`, so changes to the system
layout apply on their next start. Lua uses the Hyprland 0.55-or-later API; graphical usability is proven by the
human checkpoint, not by file-existence postconditions.

The provider creates a link to the upstream `hyprland-uwsm.desktop` in a dedicated session directory.
`cfg_session_is_only` checks that it contains exactly one entry and that the desktop entry's `Exec` contains
`uwsm start` and `hyprland.desktop`. Extra or incompatible entries produce outcome `4`, not deletion of local
state. SDDM is enabled last and is never started or restarted by configure.

## Adding a later slice

1. Add the capability's `apply`, `packages`, and minimal native files under its owning boundary.
2. State prerequisites and context variables; use shared helpers and check postconditions at the end.
3. Add its path to `configure-steps` after prerequisites and before dependents. Keep display-manager activation
   after the steps it depends on.
4. Review package inclusion and update the governing scope and procedure as needed.
5. Run shell checks and the mechanism contract suite; validate the real configuration in the VM. Add mechanism
   tests only when shared behavior changes, not one test suite per capability.
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
