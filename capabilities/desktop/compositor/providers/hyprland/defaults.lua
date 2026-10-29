-- managed by MirrorOS configure
-- MirrorOS Hyprland provider defaults.
hl.env("GDK_SCALE", "1")
dofile("/usr/share/mirroros/hypr/monitors.lua")
local borders = { active_border = "rgba(509475ff)", inactive_border = "rgba(595959aa)" }
hl.config({
    input = { kb_layout = require("/usr/share/mirroros/hypr/layouts.lua"), kb_options = "compose:ralt", repeat_delay = 230, repeat_rate = 62 },
    dwindle = { preserve_split = true },
    general = { border_size = 2, col = borders },
    decoration = { active_opacity = 0.985, inactive_opacity = 0.96, blur = { enabled = false } },
})

-- Approved Story 4.3 bindings. dofile runs them again at every configuration load; nothing is unbound at runtime.
MirrorOSStageBindings = true
dofile("/usr/share/mirroros/hypr/shell-bindings.lua")
dofile("/usr/share/mirroros/hypr/window-bindings.lua")
MirrorOSStageBindings = nil
