# Editor source and ownership boundaries

## Authoritative Neovim configuration

- Repository: https://github.com/viespejo/nvim-lua-new.
- Selected normal branch: `master`; destination: `~/code/nvim`.
- Published workbench implementation reviewed initially at
  `bdf02dd9b726c215c31d3a64c6cb38e56bbdac58`.

This is a provenance observation, not a permanent configuration pin. A configure
execution must resolve the selected branch once and record its applied commit.
The external repository owns its complete configuration, `lazy-lock.json`,
explicit `config.prepare_tools` and `config.treesitter` preparation, and the desired
tool/parser lists. MirrorOS must not carry a parallel desired-tool list, update
plugins beyond the selected lockfile, or install tools on ordinary editor startup.
Neovim's official package remains installation-owned.

## Portable Lazygit input

`lazygit.yml` is MirrorOS-owned native YAML for `~/.config/lazygit/config.yml`.
Its header uses the existing managed-file policy: absent or marked files may be
installed/updated; unmarked files and symlinks remain user-owned. No `state.yml`
or other personal Git/UI state is a source input.

The approved settings select Nerd Fonts 3 and selected-line background `#1f212e`.
Field support was reviewed against Lazygit 0.66.2:

- https://github.com/jesseduffield/lazygit/blob/v0.66.2/docs/Config.md
- https://github.com/jesseduffield/lazygit/blob/v0.66.2/pkg/config/user_config.go

The editor provisioning step owns the official Arch `extra/lazygit`
dependency and this native input. The application is MIT-licensed; pacman keeps
its packaged notice. No upstream application code is incorporated in this file.
Obsolete `selectedRangeBgColor`/`git.paging`, private browser profiles and Delta
are not selected. Native opener and standard diff behavior remain unchanged.

## Wrapper, link and preparation

`vim` is MirrorOS-owned and installed as the executable managed `~/.local/bin/vim`: it opens Oil when started
without arguments or with one directory and otherwise passes its arguments to `nvim`. The Zsh `v` and `nvim`
aliases depend on it. `~/.config/nvim` links to `~/code/nvim` only while that path is absent.

`prepare-nvim` runs the three commands documented by the external repository, as the user, with the declared Node.js
`bin` first on PATH, once per applied commit. Its stamp under `~/.local/state/mirroros/editor` is written only after
all three succeed. Official prerequisites are `lazygit`, `tree-sitter-cli`, `unzip` and `go` (`curl`, `tar` and
`gzip` come with the base system; `git`, `base-devel` and `rust` belong to earlier steps). No Mason language server
or debugger list is carried here.

The prototype's isolated PTY startup and maintainer-reported editor launch do not
prove all UI, browser, private-account or reconstruction behavior. Source-only
ownership contracts are not graphical readiness evidence.
