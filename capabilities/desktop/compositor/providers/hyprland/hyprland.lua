-- managed by MirrorOS configure
hl.config({
    input = { kb_layout = "us,es", kb_options = "compose:ralt", repeat_delay = 230, repeat_rate = 62 },
    dwindle = { preserve_split = true },
})

-- Approved Story 4.3 bindings. dofile runs them again at every configuration load; nothing is unbound at runtime.
dofile("/usr/share/mirroros/hypr/shell-bindings.lua")
dofile("/usr/share/mirroros/hypr/window-bindings.lua")
