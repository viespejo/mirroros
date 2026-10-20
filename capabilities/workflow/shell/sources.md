# Interactive shell sources and ownership boundaries

## Native defaults

`zshenv`, `zshrc` and `zprofile` are MirrorOS-owned native Zsh files installed to
`~/.zshenv`, `~/.zshrc` and `~/.zprofile` under the managed-file policy: an absent or
marked file is installed or updated; an unmarked file or symbolic link is user-owned and
left untouched. They do not source host dotfiles, force `TERM`, start a display server,
install plugins or load NVM at startup. The user Node.js PATH comes from
`~/.config/mirroros/node/environment.zsh` (see the node sources).

- `zshenv` sources only trusted `~/.config/zsh/env.d/*.zsh` fragments, for exports.
- `zshrc` provides the approved baseline: vi editing, Starship, Zoxide, Atuin, Fzf with
  file/directory previews, autosuggestions with Ctrl+Space acceptance, syntax
  highlighting, completion menu with reverse navigation, and the `piw` wrapper. Trusted
  `~/.config/zsh/conf.d/*.zsh` fragments load last, so local overrides stay user-owned.
- `alias v` and `alias nvim` select the `vim` wrapper that the editor capability owns.
- The `git` and `common-aliases` oh-my-zsh plugins provide the maintainer's daily aliases. Their files are
  sourced directly from the identified clone, not through `zplug ... from:oh-my-zsh`: in the guest laboratory that
  loader made the first start about 6.8 s (cache rebuild) against about 0.5 s when sourcing directly.
- `mirroros_alias_hint` is MirrorOS-owned pure Zsh in a `preexec` hook. When a typed command starts with the
  expansion of an alias, it names the longest such alias. It starts no process, so it adds no per-command latency
  comparable to the `python3`-based `alias-tips` it replaces (about 22 ms per command in the guest laboratory).

The user's login shell becomes `/usr/bin/zsh` only when it is currently Bash; any other
choice is user-owned and preserved. Bash initialization for Starship stays in place.

## Starship prompt

`starship.toml` carries the maintainer-approved portable host prompt configuration,
including Nerd Font symbols, vi-mode indicators, module ordering, directory formatting
and `add_newline = false`. Configure installs it to `~/.config/starship.toml` using the
same absent-or-marked ownership policy; unrelated files and symbolic links are preserved.
It contains no credentials or personal paths and does not load host configuration at runtime.

## Zplug and plugin sources

Zplug is the selected plugin manager. `install-plugins` runs as the target user during
provisioning and clones each source at its identified commit; startup never installs
anything. An existing standalone clone of the expected origin is accepted at whatever
commit the user chose; anything else at a destination is preserved and stops the step.
Updates are explicit MirrorOS changes to these identities.

| Source | Commit | Notice at that commit |
| --- | --- | --- |
| https://github.com/zplug/zplug | `cc6906ea7ea18a5058e8b4862d4086148434ddde` | MIT; Masaki Ishiyama, 2016-present |
| https://github.com/jeffreytse/zsh-vi-mode | `91cafe4a09b6670cb8e761aa413e5f7b9e00816f` | MIT; Jeffrey Tse, 2020 |
| https://github.com/zsh-users/zsh-syntax-highlighting | `e6683f20e5c38d3e5447f45845d04ddda75d0f23` | BSD-3-Clause terms (COPYING.md); contributors, 2010-2020 |
| https://github.com/zsh-users/zsh-autosuggestions | `85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5` | MIT; Thiago de Arruda, 2013; Eric Freese, 2016-2021 |
| https://github.com/zsh-users/zsh-completions | `989b23277ab33e8d5e82df6aed936e846db9d8b8` | Zsh license with individual-file precedence; not MIT |
| https://github.com/ohmyzsh/ohmyzsh (`lib/completion`, `plugins/git`, `plugins/common-aliases`) | `964ddf789b022b6958b27d02d7fa54f552de21e9` | MIT; Robby Russell and contributors, 2009-2026 |

Zplug expects the oh-my-zsh sources under `repos/robbyrussell/oh-my-zsh`, so that
destination is cloned from the current `ohmyzsh/ohmyzsh` location. These sources are
downloaded, not incorporated into MirrorOS; their notices stay upstream-owned and are
preserved in the clones. Identities come from the reviewed prototype clones; no remote tip
is resolved at run time.

## Derived history options

The history `setopt` block in `zshrc` adapts option choices from Prezto's history module
(MIT; Robby Russell and contributors, 2009-2011; Sorin Ionescu and contributors,
2011-2017). The upstream MIT text reviewed at
https://raw.githubusercontent.com/sorin-ionescu/prezto/master/LICENSE is reproduced in
`LICENSE.prezto`. No other Prezto code is incorporated.

## Official packages and ownership

This capability declares `zsh`, `starship`, `fzf`, `zoxide`, `atuin`, `fd`, `bat`, `tree`
and `ripgrep` from the official `extra` repository. `git` is declared once by the node
capability, which runs first. Notices stay with the Arch packages (Zsh custom; Starship ISC;
Fzf, Zoxide and Atuin MIT; fd MIT OR Apache-2.0; bat Apache-2.0 OR MIT; tree
GPL-2.0-or-later; ripgrep MIT OR Unlicense, per installed package metadata).

## Startup acceptance

Accepted laboratory thresholds for the complete interactive Zsh in a pseudo-terminal:
subsequent-start median at most 300 ms, first observation at most 700 ms, and first-command
response median at most 50 ms, with every approved function preserved and no perceived
blocking. They do not cover Foot launch or rendering, cold boot, or any host-relative claim.
Prototype measurements were 455.9 ms first observed and a 237.4 ms subsequent median.
