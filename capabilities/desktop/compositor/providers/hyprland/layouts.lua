-- managed by MirrorOS configure
-- Keyboard layouts of the managed session and the greeter (ADR 0015): the layout resolved from /etc/vconsole.conf
-- first, then the declared MirrorOS layouts without duplicates, so both start in the configured layout and
-- SUPER+I cycles through the others.
local declared = "us,es"
local first = require("/usr/share/mirroros/hypr/keyboard.lua")
local layouts, seen = { first }, { [first] = true }
for layout in declared:gmatch("[^,]+") do
    if not seen[layout] then
        layouts[#layouts + 1] = layout
        seen[layout] = true
    end
end
return table.concat(layouts, ",")
