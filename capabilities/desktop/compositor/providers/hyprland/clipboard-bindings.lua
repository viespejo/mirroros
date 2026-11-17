-- managed by MirrorOS configure
-- Adapted from Omarchy default/hypr/bindings/clipboard.lua (520c3ed96, MIT); see UPSTREAM.md.
assert(type(MirrorOSKeys) == "table" and MirrorOSKeys.bind, "load shell-bindings.lua first")

-- Omit the window target so the focused surface can also be a shell panel. Split down/up to avoid stuck keys.
local function send_shortcut_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then return false end
  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then return true end
  end
  return false
end

local function universal_clipboard_shortcut(key)
  return function()
    send_shortcut_once(active_window_is_terminal() and "CTRL SHIFT" or "CTRL", key)()
  end
end

MirrorOSKeys.bind("clipboard.select-all", "SUPER + A", "Select all", send_shortcut_once("CTRL", "A"))
MirrorOSKeys.bind("clipboard.copy", "SUPER + C", "Universal copy", universal_clipboard_shortcut("C"))
MirrorOSKeys.bind("clipboard.paste", "SUPER + V", "Universal paste", universal_clipboard_shortcut("V"))
MirrorOSKeys.bind("clipboard.cut", "SUPER + X", "Universal cut", send_shortcut_once("CTRL", "X"))
MirrorOSKeys.bind("clipboard.history", "SUPER + CTRL + V", "Clipboard history", hl.dsp.global("mirroros:clipboard"))

if not MirrorOSKeys.staged then MirrorOSKeys.export() end
