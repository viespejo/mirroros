-- managed by MirrorOS configure
-- MirrorOS Hyprland provider defaults.
hl.env("GDK_SCALE", "1")
dofile("/usr/share/mirroros/hypr/monitors.lua")
local borders = { active_border = "rgba(509475ff)", inactive_border = "rgba(595959aa)" }
local runtime_ok, runtime = pcall(dofile, "/usr/share/mirroros/hypr/theme-runtime.lua")
if runtime_ok and type(runtime) == "function" then
    local theme_ok, theme = pcall(runtime)
    if theme_ok and theme then borders = theme
    elseif not theme_ok then print("Cannot load Hyprland theme; using provider defaults") end
else
    print("Cannot load Hyprland theme runtime; using provider defaults")
end
hl.config({
    input = { kb_layout = require("/usr/share/mirroros/hypr/layouts.lua"), kb_options = "compose:ralt", repeat_delay = 230, repeat_rate = 62 },
    dwindle = { preserve_split = true },
    general = { border_size = 2, col = borders },
    decoration = { active_opacity = 0.985, inactive_opacity = 0.96, blur = { enabled = false } },
    -- As Omarchy looknfeel.lua: without a shell background the compositor shows a plain color.
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true },
})

-- Reference VM (QEMU) only. Hyprland 0.57 advertises only KMS-importable dmabuf formats by default, and the
-- virtio-gpu primary plane offers XRGB8888 alone, so transparent client surfaces render black. Keep the full set.
local vendor_file = io.open("/sys/class/dmi/id/sys_vendor", "r")
local vendor = vendor_file and vendor_file:read("l") or ""
if vendor_file then vendor_file:close() end
if vendor == "QEMU" then hl.config({ quirks = { skip_non_kms_dmabuf_formats = false } }) end

-- Approved Story 4.3 bindings. dofile runs them again at every configuration load; nothing is unbound at runtime.
MirrorOSStageBindings = true
dofile("/usr/share/mirroros/hypr/shell-bindings.lua")
dofile("/usr/share/mirroros/hypr/window-bindings.lua")
MirrorOSStageBindings = nil
