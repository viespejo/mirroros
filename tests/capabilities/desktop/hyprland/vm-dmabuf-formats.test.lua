-- Run from the repository root: lua tests/capabilities/desktop/hyprland/vm-dmabuf-formats.test.lua
local defaults = "capabilities/desktop/compositor/providers/hyprland/defaults.lua"
local sys_vendor = "/sys/class/dmi/id/sys_vendor"
local original_open, original_dofile = io.open, dofile

local function load_defaults(vendor)
    local configs = {}
    hl = {
        env = function() end,
        config = function(spec) configs[#configs + 1] = spec end,
    }
    package.loaded["/usr/share/mirroros/hypr/layouts.lua"] = "us"
    dofile = function(file)
        if file == "/usr/share/mirroros/hypr/theme-runtime.lua" then return function() return nil end end
        assert(file == "/usr/share/mirroros/hypr/monitors.lua"
            or file == "/usr/share/mirroros/hypr/shell-bindings.lua"
            or file == "/usr/share/mirroros/hypr/window-bindings.lua", file)
    end
    io.open = function(path, mode)
        if path ~= sys_vendor then return original_open(path, mode) end
        if vendor == nil then return nil, path .. ": No such file or directory", 2 end
        return { read = function() return vendor end, close = function() end }
    end
    local ok, err = pcall(original_dofile, defaults)
    io.open, dofile = original_open, original_dofile
    assert(ok, err)
    local quirks = {}
    for _, spec in ipairs(configs) do
        if spec.quirks then quirks[#quirks + 1] = spec.quirks end
    end
    return quirks
end

local qemu = load_defaults("QEMU")
assert(#qemu == 1 and qemu[1].skip_non_kms_dmabuf_formats == false)
assert(#load_defaults("Framework") == 0)
assert(#load_defaults(nil) == 0)
print("Reference VM dmabuf format default verified")
