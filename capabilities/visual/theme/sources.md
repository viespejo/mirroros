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
