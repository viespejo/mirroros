local resolve_theme = dofile("capabilities/desktop/compositor/providers/hyprland/theme-loader.lua")
local validate = dofile("capabilities/desktop/compositor/providers/hyprland/theme-validation.lua")
local path = "/usr/share/mirroros/themes/default/hyprland.lua"
local theme = dofile("capabilities/visual/theme/default/hyprland.lua")
local warnings = {}
local function warn(message) warnings[#warnings + 1] = message end
local function load(value) assert(value == path); return theme end
local borders = assert(resolve_theme(function() return path end, load, validate, warn))
assert(borders.active_border == "rgba(509475ff)")
assert(borders.inactive_border == "rgba(595959aa)")
assert(#warnings == 0)

local loaded = false
local function unexpected_load() loaded = true; return theme end
assert(resolve_theme(function() error("unavailable") end, unexpected_load, validate, warn) == nil)
assert(resolve_theme(function() return "/tmp/untrusted.lua" end, unexpected_load, validate, warn) == nil)
assert(resolve_theme(function() return nil end, unexpected_load, validate, warn) == nil)
assert(not loaded)
assert(resolve_theme(function() return path end, function() error("broken Lua") end, validate, warn) == nil)
assert(resolve_theme(function() return path end, function() return { active_border = "bad" } end, validate, warn) == nil)
assert(resolve_theme(function() return path end, load, function() error("validator failure") end, warn) == nil)
assert(#warnings == 6)
for _, message in ipairs(warnings) do assert(message:match("using provider defaults")) end
print("PASS Hyprland theme loader")
