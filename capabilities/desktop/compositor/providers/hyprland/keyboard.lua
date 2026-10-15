-- managed by MirrorOS configure
local layout, keymap
local file = io.open("/etc/vconsole.conf", "r")
if file then
    for line in file:lines() do
        local key, value = line:match("^%s*([%w_]+)%s*=%s*(.*)$")
        if key == "XKBLAYOUT" or key == "KEYMAP" then
            value = value:gsub("#.*$", ""):gsub("[\"'%s]", "")
            if key == "XKBLAYOUT" then
                layout = value
            else
                keymap = value
            end
        end
    end
    file:close()
end
if layout and layout ~= "" then return layout end
if keymap and keymap ~= "" then return keymap end
return "us"
