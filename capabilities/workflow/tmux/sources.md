# Tmux sources and ownership boundaries

## Native defaults

`tmux.conf`, `tmux.bindings.conf`, `tmux.navigator.conf` and `tmux.theme.conf` are MirrorOS-owned native Tmux
files installed to `~/.config/tmux/` under the managed-file policy: an absent or marked file is installed or
updated; an unmarked file or symbolic link is user-owned and left untouched. Tmux reads
`~/.config/tmux/tmux.conf` natively, so no system file is written. The files use no host path, user name or
session state, and they do not load Floax or Sessionx.

- `tmux.conf` keeps the Ctrl+A prefix, one-based windows, vi copy mode, mouse support, zero escape time, CSI-u
  extended keys, system clipboard, status line at the top, and the plugin selection below.
- `tmux.bindings.conf` keeps the window, pane and copy-mode bindings, `Shift+Enter` (CSI-u, for Pi through Foot and
  Tmux), and Prefix+o, which opens the Sesh session selector in place of Sessionx.
- `tmux.navigator.conf` provides Neovim-aware Ctrl+H/J/K/L/\ pane navigation.
- `tmux.theme.conf` is the Tokyo Night status, message, menu, chooser and copy-mode styling.

Provenance of derived content:

- Navigation adapts the pattern of [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator)
  (MIT, Chris Toomey, 2017; reviewed license blob `046c81da30206ea9c71b1ffc5ed56e6727c62567`). The plugin itself
  is not installed.
- The theme uses the Tokyo Night (night) palette of [tokyonight.nvim](https://github.com/folke/tokyonight.nvim)
  `extras/tmux/tokyonight_night.tmux` (MIT, Folke Lemaitre) and reproduces the module and window layout of the
  [omerxx/catppuccin-tmux](https://github.com/omerxx/catppuccin-tmux) fork (MIT, Catppuccin, 2021, reviewed
  revision `e30336b79986e87b1f99e6bd9ec83cffd1da2017`), which is not loaded. The Tokyo Night scope and its
  reviewed tag are described in the [terminal sources](../../desktop/terminal/sources.md); its [MIT notice](../../desktop/terminal/LICENSE.tokyonight)
  is co-located there. The other two notices are reproduced in [`LICENSE.notices`](LICENSE.notices).

## TPM and plugin sources

TPM and the selected plugins are provisioned by `install-plugins` as the target user: each source is cloned at its
identified commit into `~/.config/tmux/plugins/<name>`, in an owned staging directory published without
overwriting anything. An existing standalone clone of the expected origin is accepted at whatever commit the user
chose; anything else at a destination is preserved and stops the step. Tmux never installs or updates plugins:
updates are explicit MirrorOS changes to these identities, and TPM's interactive install/update bindings are not
part of the contract.

| Source | Commit | Notice at that commit |
| --- | --- | --- |
| https://github.com/tmux-plugins/tpm | `e261deb1b47614eed3400089ce7197dc68acc4eb` | MIT (LICENSE.md); Bruno Sutic |
| https://github.com/tmux-plugins/tmux-sensible | `25cb91f42d020f675bb0a2ce3fbd3a5d96119efa` | MIT (LICENSE.md); Bruno Sutic |
| https://github.com/tmux-plugins/tmux-yank | `acfd36e4fcba99f8310a7dfb432111c242fe7392` | MIT (LICENSE.md); Bruno Sutic, 2014/2017; Christian Hoeltje, 2017 |
| https://github.com/tmux-plugins/tmux-resurrect | `cff343cf9e81983d3da0c8562b01616f12e8d548` | MIT (LICENSE.md); Bruno Sutic |
| https://github.com/tmux-plugins/tmux-continuum | `0698e8f4b17d6454c71bf5212895ec055c578da0` | MIT (LICENSE.md); Bruno Sutic |
| https://github.com/fcsonline/tmux-thumbs | `ae91d5f7c0d989933e86409833c46a1eca521b6a` | MIT (LICENSE); Ferran Basora, 2019 |
| https://github.com/sainnhe/tmux-fzf | `2839d6bd0e13b7c5e385e131e4c217917fa73555` | MIT (LICENSE); Sainnhepark, 2019 |
| https://github.com/wfxr/tmux-fzf-url | `7c4838e95fde660b7f2aaf514323ac8498e0d4f4` | LICENSE.txt points to https://wfxr.mit-license.org/2018, which declares MIT, Wenxuan Zhang, 2018-2026 |

The clones keep their own notice files; nothing from them is copied into MirrorOS source.

`tmux-thumbs` needs a compiled helper. `install-plugins` compiles it as the user with
`cargo build --release --locked --target-dir=target` (Rust from the official `rust` package) instead of the
plugin's interactive Compile/Download prompt, and repeats the build only when the binaries are missing or their
version differs from the clone, which is the same check the plugin performs at startup. The build downloads crates
from the network once; `--locked` keeps the crate versions of the identified commit's `Cargo.lock`. Resurrect and
Continuum need `hostname`, which the official `inetutils` package provides. `wl-clipboard` serves `tmux-yank`, and
`fzf` and `zoxide` (declared by `workflow/shell`) serve the fzf plugins and Sesh.

## Sesh

Sesh is not in an official repository. `sesh/PKGBUILD` is a MirrorOS derivative of the reviewed AUR recipe
`sesh-bin` 2.33.0-1 (revision `e2965e02ffbbb63fc2af817456c4fde99a843f8c`, maintainer Lucas Schwiderski), kept
with its maintainer line. It packages the upstream release asset `sesh_Linux_x86_64.tar.gz` of `v2.33.0`
(tag commit `863935c8caa3cc40cac6adcd344ac9742e51739f`, MIT, Josh Medeski, 2023). Changes from the AUR recipe:

- x86_64 only; the AUR recipe repeated the x86_64 checksum for aarch64 and i686.
- The x86_64 asset checksum `e04fe35778eaf768a1fbbaa6e01d008ae22038c52b8d7834d38c9e7ad4822daa` matches the
  digest published for the GitHub release asset.
- The release archive contains no license, so the MIT text is installed to
  `/usr/share/licenses/sesh-bin/LICENSE` from the tag's `LICENSE` blob, verified by its SHA-256
  (`7a2c197fc6bf5df1035db087764b94f78dede904b6a9e04d73d6a7bf849bbc60`).
- `options=('!strip')` keeps the prebuilt binary unmodified, and `pkgrel` is `1.1` to distinguish the derivative.

Configure builds it as the target user with `makepkg` (no `-s`, so nothing is installed with privileges during the
build) and installs the resulting package with `pacman -U`. The recipe has no install hook. A build only happens
when `sesh-bin` is missing or its installed version differs from the recipe; the package stays in
`~/.cache/mirroros/sesh`. This is not a generic AUR flow: no helper, no other recipe and no third-party binary
repository is involved, and updating Sesh is an explicit change to this recipe and its reviewed checksums.

The functional review of the prototype used a `dev` build of upstream commit
`ac21f7f832e3e3270d4ba365a29041e070964159`, not this release. The packaged binary still needs its own functional
check (Prefix+o, creation from Zoxide directories, selection, cancellation and restoration coexistence) on a
configured system before the Sesh result is accepted for the product.

## Resurrect and Continuum

Session state is created by the user's own sessions under `~/.local/share/tmux/resurrect`; nothing from a
previous host is imported. Continuum restores the last saved environment when the server starts
(`@continuum-restore 'on'`), and no systemd unit is installed or enabled.
