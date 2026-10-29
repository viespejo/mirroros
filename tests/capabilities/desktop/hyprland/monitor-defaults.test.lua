-- Run from the repository root: lua tests/capabilities/desktop/hyprland/monitor-defaults.test.lua
local rules = {}
hl = { monitor = function(rule) rules[#rules + 1] = rule end }
dofile("capabilities/desktop/compositor/providers/hyprland/monitors.lua")
assert(#rules == 2)
assert(rules[1].output == "" and rules[1].mode == "preferred" and rules[1].position == "auto" and rules[1].scale == 1)
assert(rules[2].output == "Virtual-1" and rules[2].mode == "1920x1080@60" and rules[2].position == "auto" and rules[2].scale == 1.6)

local template = assert(io.open("capabilities/desktop/compositor/providers/hyprland/personal-monitors.lua")):read("*a")
local chunk = assert(load(template, "personal-monitors", "t", { hl = hl }))
chunk()
assert(#rules == 2)
print("Monitor defaults and inactive personal examples verified")
