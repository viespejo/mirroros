-- managed by MirrorOS configure
-- Story 4.3 shell bindings and the binding registry. Loaded by the managed hyprland.lua with dofile at every
-- configuration load, before window-bindings.lua.
--
-- Every binding declares a description, and its dispatcher is kept under a stable id so the shell's keyboard help
-- can list (MirrorOSKeys.export) and invoke (MirrorOSKeys.dispatch) exactly what is bound. Hyprland keeps this Lua
-- state between configuration loads and drops the previous load's bindings itself, so the registry starts empty at
-- every load and nothing is ever unbound at runtime (runtime unbind crashed Hyprland 0.56.2 once, cause unknown).
-- A repeated id or chord is a source error, caught by tests/capabilities/desktop/hyprland-bindings.test.mjs.

local shell_path = "/usr/share/mirroros/shell"

MirrorOSKeys = { entries = {}, chords = {}, pending = {}, staged = MirrorOSStageBindings == true }

local modifiers = { SUPER = true, SHIFT = true, CTRL = true, CONTROL = true, ALT = true }

-- Modifiers in a fixed order, then the key, all upper case: "SUPER + SHIFT + I" and "SHIFT+SUPER+i" are one chord.
local function chord(keys)
  local mods, key = {}, nil
  for part in keys:gmatch("[^+]+") do
    local name = part:match("^%s*(.-)%s*$"):upper()
    if name == "CONTROL" then name = "CTRL" end
    if modifiers[name] then mods[#mods + 1] = name else key = name end
  end
  table.sort(mods)
  mods[#mods + 1] = key or ""
  return table.concat(mods, "+")
end

-- options: Hyprland bind options (locked, repeating, mouse, ...) plus `launchable = false` for entries keyboard help
-- must not run (mouse drags and wheel scrolling); those are bound but not exported.
function MirrorOSKeys.bind(id, keys, description, dispatcher, options)
  assert(id:match("^[a-z0-9][a-z0-9._-]*$"), "invalid id: " .. id)
  assert(not MirrorOSKeys.entries[id], "repeated binding id: " .. id)
  local normalized = chord(keys)
  assert(not MirrorOSKeys.chords[normalized], "repeated chord " .. keys .. " for " .. id)
  local opts = { description = description }
  local launchable = true
  for name, value in pairs(options or {}) do
    if name == "launchable" then launchable = value ~= false else opts[name] = value end
  end
  if MirrorOSKeys.staged then
    MirrorOSKeys.pending[#MirrorOSKeys.pending + 1] = id
  else
    hl.bind(keys, dispatcher, opts)
  end
  MirrorOSKeys.chords[normalized] = id
  MirrorOSKeys.entries[id] = { keys = keys, description = description, dispatcher = dispatcher, launchable = launchable, options = opts }
end

-- Replace an existing action before bindings are registered; the chord and options stay unchanged.
function MirrorOSKeys.replace(id, description, dispatcher)
  assert(MirrorOSKeys.staged, "binding replacements require staged configuration")
  local entry = assert(MirrorOSKeys.entries[id], "unknown binding id: " .. tostring(id))
  assert(not entry.replaced, "binding already replaced: " .. id)
  assert(type(description) == "string" and description ~= "", "replacement description is required")
  local dispatcher_type = type(dispatcher)
  assert(dispatcher_type == "table" or dispatcher_type == "userdata" or dispatcher_type == "function", "invalid replacement dispatcher")
  entry.description = description
  entry.dispatcher = dispatcher
  entry.options.description = description
  entry.replaced = true
end

function MirrorOSKeys.finalize()
  if not MirrorOSKeys.staged then return end
  for _, id in ipairs(MirrorOSKeys.pending) do
    local entry = MirrorOSKeys.entries[id]
    hl.bind(entry.keys, entry.dispatcher, entry.options)
  end
  MirrorOSKeys.pending = {}
  MirrorOSKeys.staged = false
end

function MirrorOSKeys.dispatch(id)
  local entry = MirrorOSKeys.entries[id]
  if not entry or not entry.launchable then return end
  -- A Lua function dispatcher (several steps on one chord) is called; any other is dispatched.
  if type(entry.dispatcher) == "function" then entry.dispatcher() else hl.dispatch(entry.dispatcher) end
end

-- "<id>\t<keys>\t<description>" lines of launchable entries, sorted by id. The description (tabs and newlines
-- replaced by spaces) lets the shell match bindings that `hyprctl binds -j` reports without a key (`code:N`).
function MirrorOSKeys.list()
  local ids = {}
  for id, entry in pairs(MirrorOSKeys.entries) do
    if entry.launchable then ids[#ids + 1] = id end
  end
  table.sort(ids)
  local lines = {}
  for _, id in ipairs(ids) do
    local entry = MirrorOSKeys.entries[id]
    lines[#lines + 1] = id .. "\t" .. entry.keys .. "\t" .. entry.description:gsub("[\t\r\n]", " ")
  end
  return table.concat(lines, "\n")
end

-- Registry file read by the shell's keyboard help: a "# instance <signature>" header, then MirrorOSKeys.list().
-- The header lets the shell reject a file left by another Hyprland instance. Written atomically (rename).
local runtime_dir = os.getenv("XDG_RUNTIME_DIR")
MirrorOSKeys.file = runtime_dir and (runtime_dir .. "/mirroros-keybindings.tsv") or nil

function MirrorOSKeys.export()
  if not MirrorOSKeys.file then return end
  local tmp = MirrorOSKeys.file .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return end
  f:write("# instance ", os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or "", "\n", MirrorOSKeys.list(), "\n")
  f:close()
  os.rename(tmp, MirrorOSKeys.file)
end

local function shell_ipc(target, args)
  return hl.dsp.exec_cmd("qs ipc -p " .. shell_path .. " call " .. target .. " " .. args)
end

local function menu(args)
  return shell_ipc("menu", args)
end

-- Approved keyboard table (Omarchy-first families, brief-3-keyboard-table.md). Keys and descriptions follow the
-- pinned Omarchy default/hypr/bindings (7075b61c, MIT); actions use MirrorOS mechanisms.

-- Menus and help (Omarchy utilities.lua:1-2, 7-10).
MirrorOSKeys.bind("menu.root", "SUPER + SPACE", "Menu", menu("toggle root"))
MirrorOSKeys.bind("menu.root-copilot", "SUPER + SHIFT + code:201", "Menu", menu("toggle root"))
MirrorOSKeys.bind("menu.apps", "SUPER + D", "Apps", menu("toggle apps"))
MirrorOSKeys.bind("menu.apps-alt", "SUPER + ALT + SPACE", "Apps", menu("toggle apps"))
MirrorOSKeys.bind("menu.system", "SUPER + ESCAPE", "System menu", menu("toggle system"))
MirrorOSKeys.bind("menu.system-power", "XF86PowerOff", "Power menu", menu("toggle system"), { locked = true })
MirrorOSKeys.bind("help.keybindings", "SUPER + K", "Keybindings", menu("keybindings"))

-- Background switcher (installed Omarchy 4.0.6 default/hypr/bindings/utilities.lua:17; shell wallpaper IPC).
MirrorOSKeys.bind("style.background", "SUPER + CTRL + SPACE", "Background switcher", shell_ipc("wallpaper", "open"))

-- Keyboard layouts (Omarchy input-method.lua:19-20, on XKB layouts instead of fcitx). Not active while locked:
-- the lock screen always uses the configured layout (ADR 0015).
MirrorOSKeys.bind("input.layout-next", "SUPER + I", "Switch input language",
  hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))
MirrorOSKeys.bind("input.layout-prev", "SUPER + SHIFT + I", "Switch input language back",
  hl.dsp.exec_cmd("hyprctl switchxkblayout all prev"))

-- Notifications (Omarchy utilities.lua:24-28; shell notifications IPC).
MirrorOSKeys.bind("notifications.dismiss-one", "SUPER + comma", "Dismiss last notification",
  shell_ipc("notifications", "dismissOne"))
MirrorOSKeys.bind("notifications.dismiss-all", "SUPER + SHIFT + comma", "Dismiss all notifications",
  shell_ipc("notifications", "dismissAll"))
MirrorOSKeys.bind("notifications.dnd", "SUPER + CTRL + comma", "Toggle silencing notifications",
  shell_ipc("notifications", "toggleDnd"))
MirrorOSKeys.bind("notifications.invoke-last", "SUPER + ALT + comma", "Invoke last notification",
  shell_ipc("notifications", "invokeLast"))
MirrorOSKeys.bind("notifications.history", "SUPER + SHIFT + ALT + comma", "Open notification history",
  shell_ipc("notifications", "showHistory"))

-- Ferris Sweep: its ZMK mapping sends Shift+comma as an apostrophe without Shift, so SUPER+Shift+comma reaches
-- Hyprland as SUPER+apostrophe. MirrorOS exception kept beside the Omarchy keys above, which stay for keyboards that
-- send Shift+comma; SUPER+ALT+apostrophe is the expected form of SUPER+Shift+Alt+comma on that keyboard.
MirrorOSKeys.bind("notifications.dismiss-all-apostrophe", "SUPER + apostrophe", "Dismiss all notifications",
  shell_ipc("notifications", "dismissAll"))
MirrorOSKeys.bind("notifications.history-apostrophe", "SUPER + ALT + apostrophe", "Open notification history",
  shell_ipc("notifications", "showHistory"))

-- Session (Omarchy utilities.lua:130; logind forwards the request to hypridle's lock_cmd).
MirrorOSKeys.bind("session.lock", "SUPER + CTRL + L", "Lock system", hl.dsp.exec_cmd("loginctl lock-session"))
