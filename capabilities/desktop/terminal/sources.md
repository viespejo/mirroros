# Terminal sources and native defaults

## Tokyo Night palette

- Upstream: [folke/tokyonight.nvim](https://github.com/folke/tokyonight.nvim).
- Versioned comparison/reference: `v4.11.0`, commit `b262293ef481b0d1f7a14c708ea7ca649672e200`.
- Material: [`extras/kitty/tokyonight_night.conf`](https://github.com/folke/tokyonight.nvim/blob/b262293ef481b0d1f7a14c708ea7ca649672e200/extras/kitty/tokyonight_night.conf).
- The extra explicitly declares `license: MIT` and `author: Folke Lemaitre`.
  The repository-level LICENSE at this revision is Apache-2.0. The explicit
  per-file MIT declaration governs this palette; no upstream Lua implementation
  or other repository material is incorporated here. See `LICENSE.tokyonight`
  for the MIT text and author attribution.

The previous MirrorOS configuration translated the terminal palette to Foot's native fields. That
palette retained the reference background, foreground, selection, URL, cursor,
normal colors, bright black and bright white. Bright red, green, yellow, blue,
magenta and cyan deliberately use their corresponding normal colors instead of
that reference's brighter variants. These are retained maintainer-approved
prototype choices, not a claim of an unmodified upstream extra. The original
host import revision is unknown; the fixed reference above documents a
reconstructible source comparison, not that historical import identity.

The guest-approved native choices are `term=foot`, `JetBrainsMono Nerd Font Mono`
size 9, centered 14x14 padding, disabled bell and cursor blink, 10000 scrollback
lines and CSI-u Shift+Return / Alt+Shift+Return sequences. The padding supersedes
the interview's original 4-pixel proposal. These terminal-local choices do not
select a global theme, Kitty overlays or a different Wayland session model.

## Fixed jade palette

The current `foot.ini` uses native Foot color fields derived from the reviewed Osaka Jade palette in
[`visual/theme/default/colors.toml`](../../visual/theme/default/colors.toml); its source and MIT notice are
recorded in [`visual/theme/sources.md`](../../visual/theme/sources.md). The mapping to terminal roles is
MirrorOS-owned. The colors are embedded, so Foot does not depend on an included file being present: Foot
1.28.0 rejects a configuration with a missing include. Palette changes must be synchronized and tested explicitly;
this is not dynamic theme loading. The font size and padding follow the maintainer-approved guest settings.
The product also prepares tracked `/usr/share/mirroros/foot/defaults.ini` and theme `foot.ini` files for future
layered configuration. For a new personal entry, configure uses the layered template only when Foot validates it;
otherwise it uses the standalone configuration. Existing personal entries are not automatically migrated to layers.
Missing includes prevent Foot startup, so later recovery remains manual. The personal template uses
`~/.local/state/mirroros/current/theme/foot.ini` directly; Foot does not validate the selected target, and an
untrusted configuration can contain settings that launch commands. Only use themes you trust. A missing include
prevents startup; use the standalone recovery command below. Custom `XDG_STATE_HOME` locations are not supported
by this template.

## Official packages and ownership

`packages` owns Foot, `ttf-jetbrains-mono-nerd` and `noto-fonts-emoji` from the
Arch `extra` repository. Their package versions remain rolling; pacman supplies
their own licenses and notices. The Nerd Font's Mono family and emoji glyphs
were checked in the guest prototype; this is not a universal font fallback claim.

Configure creates `~/.config/foot/foot.ini` if absent, using validated layers or standalone fallback, and migrates the exact previous Tokyo Night
configuration by its SHA-256. Any other existing configuration, including a modified file with the managed header,
and all symlinks remain user-owned and are left untouched. An identical jade configuration is unchanged; later
modifications are also preserved. The package-owned system Foot
configuration is not overwritten. Configure also publishes a tracked standalone copy at
`/usr/share/mirroros/foot/recovery.ini`; modified or linked copies are conflicts and are not replaced.
Before publication, configure checks its parent directories for trusted ownership, permissions and symlinks.
This point-in-time check does not prevent concurrent privileged changes.
From a working Wayland session, an existing terminal or launcher can request it with
`foot --config /usr/share/mirroros/foot/recovery.ini`. It does not load or repair the personal file.
It uses the product font and padding; temporary options can be supplied with `--override`. The file and
options have passed Foot's configuration check; an earlier installed copy was also launched successfully in the guest. If the
session or this copy is unavailable, another terminal or a TTY is needed to investigate.
A successful file/package postcondition does
not establish graphical, clipboard or Tmux/Pi key-path acceptance on a new guest;
those checks remain attended runtime verification.

## Terminal preference for desktop entries

Configure manages `~/.config/xdg-terminals.list` with the single entry
`foot.desktop`, the native preference list `uwsm app` follows for desktop
entries with `Terminal=true`. `foot.desktop` runs a standalone Foot, so no
`foot-server` or `footclient` is required. An unmarked list, or a
desktop-specific `~/.config/hyprland-xdg-terminals.list`, stays user-owned;
`check-terminal-list` runs as the user and fails the step with an actionable
message when the effective list names no installed desktop entry, instead of
reporting a passing postcondition. Launching a `Terminal=true` entry remains an
attended session check.
