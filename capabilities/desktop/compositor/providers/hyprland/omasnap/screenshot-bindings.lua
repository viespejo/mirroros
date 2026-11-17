-- managed by MirrorOS configure
-- Adapted from Omarchy utilities.lua (520c3ed96, MIT) and Omasnap v1.26.2 README; see sources.md.
assert(type(MirrorOSKeys) == "table" and MirrorOSKeys.bind, "load shell-bindings.lua first")

MirrorOSKeys.bind("screenshot.capture", "PRINT", "Screenshot", hl.dsp.exec_cmd("/usr/share/mirroros/screenshot/screenshot"))
MirrorOSKeys.bind("screenshot.capture-alt", "SUPER + CTRL + ALT + C", "Screenshot", hl.dsp.exec_cmd("/usr/share/mirroros/screenshot/screenshot"))
MirrorOSKeys.bind("menu.capture", "SUPER + CTRL + C", "Capture menu", hl.dsp.exec_cmd("qs ipc -p /usr/share/mirroros/shell call menu open capture"))

hl.layer_rule({
  match = { namespace = "^omasnap$" },
  no_anim = true,
  animation = "none",
})

-- Omarchy default/hypr/apps/omarchy-shell.lua at 520c3ed96; see sources.md.
hl.layer_rule({
  match = { namespace = "^mirroros-menu$" },
  no_anim = true,
  animation = "none",
})

if not MirrorOSKeys.staged then MirrorOSKeys.export() end
