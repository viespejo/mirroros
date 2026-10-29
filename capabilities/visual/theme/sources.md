# Fixed theme source

The initial palette in `default/colors.toml` adapts Osaka Jade from
[Omarchy](https://github.com/omacom/omarchy/blob/237f1b4071a0bff2296c6d740ba2b9fd695ebfa0/themes/osaka-jade/colors.toml)
`v4.0.6`, commit `237f1b4071a0bff2296c6d740ba2b9fd695ebfa0`. It retains the
reference keys and values with an added provenance comment. Omarchy's MIT license
and copyright notice are retained in `default/LICENSE.omarchy`.

The reference VM reported `omarchy 4.0.6-1`. A text comparison of its installed
palette and the fetched source showed only an extra trailing blank line in the
fetched copy. This does not establish the package's build commit or byte identity.

The isolated `install-theme` publisher stages and checks the `default/` tree,
including its license. The `apply` step publishes the tree through configure in running and target
contexts, before consumer steps. The shell reads five validated colors from the published palette and the
MirrorOS-owned `default/shell.toml` surface settings; their values correspond to the reviewed Omarchy reference,
but the file is not copied from it. Personal surface settings are optional and take precedence per valid key.
Foot and the
Hyprland provider use separately reviewed native values, with tests checking their consistency with the palette.
The MirrorOS-owned `default/hyprland.lua` returns the same two border values. The provider resolves only its
reviewed product path, loads text in an empty global environment and validates both border strings before applying
them, with provider literals as fallback. The user-controlled selection link is not a trust authority. Validating
returned data does not make executing untrusted Lua safe, and the empty environment is not a resource sandbox.
Isolated config verification passed; installed-session validation remains pending. Other consumers are not integrated yet. `default/neovim.lua` is MirrorOS-owned highlight code, not copied from
Omarchy: it changes only the four tested background roles and preserves the existing highlight attributes;
`CursorLineNr` is left untouched. It is
published but not automatically executed. Integration belongs to the independent Neovim configuration and must
validate the entire trusted product path before loading it; a user-writable theme link is not a trust authority.
It rejects unknown or modified destination trees but does not establish trust in
ancestor directories or protect against concurrent privileged changes. The separate
`check-trusted-path` checks each component below a trusted anchor for owner,
permissions and symlinks; running-system callers must use `/` as the anchor. It
is a point-in-time check, not an atomic open-and-execute operation. The product resolver checks the default
palette and, in its explicit Hyprland mode, the reviewed `hyprland.lua` path separately. These checks do not
establish file-content integrity or protect against concurrent
privileged modification; the resolver is not a general executable-theme trust guarantee. The configure step checks theme-parent directories before publication; its
configure root and the ancestors above that root remain the caller's
responsibility. These boundaries must be reviewed before executing theme code. No compatibility with arbitrary
Omarchy themes is claimed. The theme's backgrounds are described below; opacity and application-specific
presentation remain separate decisions.

## Lock colors

The MirrorOS-owned `default/hyprlock.conf` defines only five hyprlock color variables for the lock screen
([ADR 0021](../../../docs/adr/0021-neutral-greeter-and-themed-lock.md)): `$background`, `$field` (the background at
80%), `$foreground`, `$accent` and `$failure` (the palette's `red`). It is not copied from Omarchy's theme files; a
test checks it against `colors.toml`. The managed lock configuration sources it through the `current/theme` link,
like Foot, after its own neutral fallbacks; it is data for hyprlock, not executable Lua, so no trusted-path
resolution is involved. Every future theme must publish this file.

## Backgrounds

The images in `default/backgrounds/` are the default theme's reviewed backgrounds, displayed and selected by the shell
wallpaper capability ([ADR 0020](../../../docs/adr/0020-wallpaper-selection.md)). They share the theme's jade
palette and style. They are distributed under the project license (GPL-3.0, see [`LICENSE`](../../../LICENSE)) to
the extent that copyright or related rights exist in them; machine-generated output may not be protected. No
third-party image material is knowingly incorporated. The committed PNG files are the authoritative sources: they
are not rebuilt by configure, and their bytes must not be recompressed or edited without a new review. As in
Omarchy's themes, a numeric filename prefix sets the catalog order. The maintainer selected the logo image
`2-mirroros-jade.png` as the initial background. Existing names are retained so saved image paths remain valid;
`prepare-current` selects this explicit default only when no selection exists.

| File | SHA-256 | Size | Origin |
|---|---|---|---|
| `1-phase-space-jade.png` | `f1fde4145b25d4b91196cb87077fa20c1bdc530d6bb0c06ba82e9f5bd12a3494` | 2560×1440, 8-bit RGB | MirrorOS-generated |
| `2-mirroros-jade.png` | `07785f03f617942df63eaec3511f54c0bd420af804191938ba8f12f4a1835745` | 2560×1440, 16-bit RGB | MirrorOS-composed from the shared symbol, approved default |
| `3-emerald-circuit-cathedral.png` | `3e9ac7e4f465e7b6c49202a82748bc5060a423c438ea5e7b33247c96aec9fc42` | 1672×941, 8-bit RGB | Maintainer-generated with ChatGPT |
| `4-emerald-mobius-valley-of-mist.png` | `8640f33c8f893b51183e781ff06d246d52760156d76bf86497afb1d8aa2a8422` | 1672×941, 8-bit RGB | Maintainer-generated with ChatGPT |
| `5-emerald-night-over-seville.png` | `e6902df271830e3af7c00bbc361394c6617dd9f9c842ba54f8c15e739014effc` | 1672×941, 8-bit RGB | Maintainer-generated with ChatGPT |
| `6-emerald-penguin-mountain-at-dusk.png` | `d6f0346b6d6ab42a787b7e98605bf91318e20e81ee9d3dfd3133df399f401b63` | 1672×941, 8-bit RGB | Maintainer-generated with ChatGPT |

### Phase space

`1-phase-space-jade.png` was produced for MirrorOS by a one-off Pillow script (Python 3.13.1, Pillow 11.1.0) that
was recovered and reproduced the file byte for byte. The script is not part of the repository because the
architecture does not admit project-owned Python. Method: a 2560×1440 near-black background with an elliptical
exponential jade glow; 100 trajectories, seed 37, of the unforced damped Duffing system `x' = y`,
`y' = x - x³ - 0.16y`, integrated with RK4 (step 0.025, at most 1350 steps) and drawn as translucent jade lines;
a Gaussian-blurred copy (radius 9) is composited beneath the lines. The description documents the method; it is not
a byte-reproducible specification.

### Minimal symbol

`2-mirroros-jade.png` places the original [`mirroros-symbol.svg`](../branding/mirroros-symbol.svg) in `#79b396` at the
center of a `#111c18` background, over a subtle blurred `#509475` glow. It was composed with ImageMagick 7.1.1-43;
the exact command was not retained. The symbol is MirrorOS material ([branding sources](../branding/sources.md)),
so the image introduces no external material.

### Emerald images

The maintainer generated the four `*-emerald-*` images in ChatGPT from a text prompt asking for original dark-jade
mathematical scenes in the understated style of Omarchy's Osaka Jade theme, without text, logos or watermarks, and
reports that no reference images were supplied. Only that general style was requested; no Omarchy image or other
work was provided as input. The files were renamed without changing their bytes.

Each file embeds one C2PA manifest (`caBX` chunk, specification 2.2.0) naming claim generator
`OpenAI Media Service API`, software agent `ChatGPT` `gpt-image`, digital source type `trainedAlgorithmicMedia`,
`c2pa.created` actions on 2026-10-29 and a signing chain for `OpenAI OpCo, LLC`; no ingredient assertion is present.
The signatures were not cryptographically validated. The manifest is retained deliberately: any byte change would
invalidate its data-hash binding. OpenAI's [terms of use](https://openai.com/policies/terms-of-use/) assign output
rights to the user to the extent permitted by law, while noting that output may not be unique. Further evidence is
in the [wallpaper research record](../../../docs/technical-interviews/wallpaper-selection-research.md).

### Background delivery

| Item | Location | Owner |
|---|---|---|
| Theme backgrounds | `/usr/share/mirroros/themes/default/backgrounds/*.png` | MirrorOS, inside the theme tree and manifest |
| Personal backgrounds | `~/.config/mirroros/backgrounds/<theme>/` | User; created only on request from the menu |
| Selection | `$XDG_STATE_HOME/mirroros/current/background` (fallback `~/.local/state`) | Link; created by configure only if absent, then written by the shell |

As in Omarchy, backgrounds live inside the theme, and the theme step publishes them with the rest of the tree, so
modified, removed, extra or linked images are reported as conflicts without being overwritten. Like
`omarchy-theme-set`, the step selects the theme's first background, but only when no selection exists; any
existing link or path is left untouched. Configure neither validates image decoding nor reloads a running shell.
