-- managed by MirrorOS configure
hl.config({
    input = { kb_layout = require("/usr/share/mirroros/hypr/layouts.lua"), kb_options = "compose:ralt" },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
    animations = { enabled = false },
})

-- Layout switching as in the session (ADR 0015); the helper records the active layout for the SDDM theme.
local indicator = "/usr/share/mirroros/sddm/layout-indicator"
hl.bind("SUPER + I", hl.dsp.exec_cmd(indicator .. " next"))
hl.bind("SUPER + SHIFT + I", hl.dsp.exec_cmd(indicator .. " prev"))
hl.on("hyprland.start", function()
    hl.exec_cmd(indicator .. " current")
end)
