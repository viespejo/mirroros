-- managed by MirrorOS configure
-- Load optional user-owned Hyprland layers after provider defaults and theme.
-- A failing layer may already have changed compositor state; no rollback is implied.
return function(directory, warn)
    local layers = { "monitors", "input", "looknfeel", "bindings", "autostart" }
    for _, name in ipairs(layers) do
        local path = directory .. "/" .. name .. ".lua"
        local file, message, code = io.open(path, "r")
        if file then
            file:close()
            local ok, err = pcall(dofile, path)
            if not ok then warn("Cannot load personal Hyprland " .. name .. ": " .. tostring(err)) end
        elseif code ~= 2 then
            warn("Cannot read personal Hyprland " .. name .. ": " .. tostring(message))
        end
        if name == "bindings" and type(MirrorOSKeys) == "table" then
            if type(MirrorOSKeys.finalize) == "function" then MirrorOSKeys.finalize() end
            if type(MirrorOSKeys.export) == "function" then
                local ok, err = pcall(MirrorOSKeys.export)
                if not ok then warn("Cannot export Hyprland bindings: " .. tostring(err)) end
            end
        end
    end
end
