-- managed by MirrorOS configure
-- Product defaults load before optional personal files in ~/.config/hypr/.
dofile("/usr/share/mirroros/hypr/defaults.lua")
local ok, loader = pcall(dofile, "/usr/share/mirroros/hypr/personal-loader.lua")
local home = os.getenv("HOME")
if ok and type(loader) == "function" and home and home ~= "" then
    loader(home .. "/.config/hypr", print)
else
    print("Cannot load personal Hyprland layers")
    if type(MirrorOSKeys) == "table" and type(MirrorOSKeys.finalize) == "function" then
        MirrorOSKeys.finalize()
        MirrorOSKeys.export()
    end
end
