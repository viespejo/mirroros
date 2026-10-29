local loader = dofile("capabilities/desktop/compositor/providers/hyprland/theme-loader.lua")
local validate = dofile("capabilities/desktop/compositor/providers/hyprland/theme-validation.lua")
local path = "/usr/share/mirroros/themes/default/hyprland.lua"
local output = path .. "\n"
local success = true
local command, load_count, messages = nil, 0, {}
local environment = {
  os = { getenv = function(key)
    if key == "XDG_STATE_HOME" then return "/tmp/state'quoted" end
    return "/home/user"
  end },
  io = { popen = function(value, mode)
    command = value
    assert(mode == "r")
    return { read = function(_, format) assert(format == "*a"); return output end,
      close = function() return success end }
  end },
  dofile = function(name)
    if name == "/usr/share/mirroros/hypr/theme-loader.lua" then return loader end
    if name == "/usr/share/mirroros/hypr/theme-validation.lua" then return validate end
    error("unexpected module")
  end,
  loadfile = function(name, mode, globals)
    assert(name == path and mode == "t" and next(globals) == nil)
    load_count = load_count + 1
    return assert(load('return { active_border="rgba(509475ff)", inactive_border="rgba(595959aa)" }', name, mode, globals))
  end,
  print = function(message) messages[#messages + 1] = message end,
  assert = assert, error = error, type = type,
}
local runtime = assert(loadfile("capabilities/desktop/compositor/providers/hyprland/theme-runtime.lua", "t", environment))()
local value = assert(runtime())
assert(value.active_border == "rgba(509475ff)")
assert(command:find("'/tmp/state'\\''quoted'", 1, true))
assert(load_count == 1 and #messages == 0)
output = "/tmp/unknown\n"
assert(runtime() == nil and load_count == 1)
output = path .. "\nextra\n"
assert(runtime() == nil and load_count == 1)
output = path .. "\n"
success = false
assert(runtime() == nil and load_count == 1)
assert(#messages == 3)
print("PASS Hyprland theme runtime adapter")
