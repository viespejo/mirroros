-- managed by MirrorOS configure
-- Resolve the reviewed theme through the product helper and load it as text without globals.
local loader = dofile("/usr/share/mirroros/hypr/theme-loader.lua")
local validate = dofile("/usr/share/mirroros/hypr/theme-validation.lua")

local function quote(value)
  return "'" .. value:gsub("'", "'\\''") .. "'"
end

return function()
  local state = os.getenv("XDG_STATE_HOME") or ""
  if state:sub(1, 1) ~= "/" then
    local home = os.getenv("HOME") or ""
    if home:sub(1, 1) ~= "/" then
      print("Cannot determine Hyprland theme state directory; using provider defaults")
      return nil
    end
    state = home .. "/.local/state"
  end
  local function resolve()
    local command = "/usr/bin/env -u BASH_ENV -u ENV /usr/bin/bash --noprofile --norc " ..
      "/usr/share/mirroros/themes/resolve-current / " .. quote(state) .. " 0 hyprland"
    local pipe = assert(io.popen(command, "r"))
    local output = pipe:read("*a")
    local ok = pipe:close()
    if not ok or output ~= "/usr/share/mirroros/themes/default/hyprland.lua\n" then return nil end
    return output:sub(1, -2)
  end
  local function load(path)
    local chunk, err = loadfile(path, "t", {})
    if not chunk then error(err) end
    return chunk()
  end
  return loader(resolve, load, validate, print)
end
