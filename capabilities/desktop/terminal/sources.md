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

MirrorOS translates the terminal palette to Foot's native fields. The approved
palette retains the reference background, foreground, selection, URL, cursor,
normal colors, bright black and bright white. Bright red, green, yellow, blue,
magenta and cyan deliberately use their corresponding normal colors instead of
that reference's brighter variants. These are retained maintainer-approved
prototype choices, not a claim of an unmodified upstream extra. The original
host import revision is unknown; the fixed reference above documents a
reconstructible source comparison, not that historical import identity.

The guest-approved native choices are `term=foot`, `JetBrainsMono Nerd Font Mono`
size 14, centered 16x16 padding, disabled bell and cursor blink, 10000 scrollback
lines and CSI-u Shift+Return / Alt+Shift+Return sequences. The padding supersedes
the interview's original 4-pixel proposal. These terminal-local choices do not
select a global theme, Kitty overlays or a different Wayland session model.

## Official packages and ownership

`packages` owns Foot, `ttf-jetbrains-mono-nerd` and `noto-fonts-emoji` from the
Arch `extra` repository. Their package versions remain rolling; pacman supplies
their own licenses and notices. The Nerd Font's Mono family and emoji glyphs
were checked in the guest prototype; this is not a universal font fallback claim.

Configure manages `~/.config/foot/foot.ini` through its native ownership header.
Unmarked files and symlinks remain user-owned. The package-owned system Foot
configuration is not overwritten. A successful file/package postcondition does
not establish graphical, clipboard or Tmux/Pi key-path acceptance on a new guest;
those checks remain attended runtime verification.
