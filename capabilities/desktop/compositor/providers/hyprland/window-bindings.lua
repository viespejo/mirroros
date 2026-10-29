-- managed by MirrorOS configure
-- Story 4.3 window, workspace and terminal bindings (approved keyboard table, families A, C, D and E). Loaded by the
-- managed hyprland.lua with dofile after shell-bindings.lua, whose MirrorOSKeys helper and registry it uses.
--
-- Keys, descriptions and dispatcher shapes follow the pinned Omarchy default/hypr/bindings/tiling.lua and
-- utilities.lua (7075b61c, MIT); Omarchy scripts and its per-monitor workspace helper are not used. MirrorOS changes:
-- SUPER+Tab is back-and-forth, workspaces 1-10 are global, SUPER+Shift+Tab and SUPER+Ctrl+Tab are unassigned.
--
-- Verification levels: [S] shape used by the packaged /usr/share/hypr/hyprland.lua;
-- [O] used by Omarchy at the pin; [N] dispatcher name in the stubs only.
assert(type(MirrorOSKeys) == "table" and MirrorOSKeys.bind, "load shell-bindings.lua first")

local dsp = hl.dsp
local bind = MirrorOSKeys.bind
local not_launchable = { launchable = false }
-- Per direction: dispatcher argument, id suffix and Omarchy's description words.
local directions = {
  LEFT = { dir = "l", name = "left", focus = "left", swap = "to the left", group = "left" },
  RIGHT = { dir = "r", name = "right", focus = "right", swap = "to the right", group = "right" },
  UP = { dir = "u", name = "up", focus = "above", swap = "up", group = "top" },
  DOWN = { dir = "d", name = "down", focus = "below", swap = "down", group = "bottom" },
}

-- Windows (tiling.lua:1-2, 5-8, 10).
bind("window.close", "SUPER + W", "Close window", dsp.window.close()) -- [S]
bind("window.close-q", "SUPER + Q", "Close window", dsp.window.close()) -- [S]
bind("window.split", "SUPER + J", "Toggle window split", dsp.layout("togglesplit")) -- [S]
bind("window.pseudo", "SUPER + P", "Pseudo window", dsp.window.pseudo()) -- [S]
bind("window.float", "SUPER + T", "Toggle window floating/tiling", dsp.window.float({ action = "toggle" })) -- [S]
bind("window.fullscreen", "SUPER + F", "Full screen", dsp.window.fullscreen({ mode = "fullscreen" })) -- [O]
bind("window.maximize", "SUPER + ALT + F", "Full width", dsp.window.fullscreen({ mode = "maximized" })) -- [O]

-- Focus, swap and monitors by direction (tiling.lua:17-20, 40-53).
for key, d in pairs(directions) do
  bind("focus." .. d.name, "SUPER + " .. key, "Focus on " .. d.focus .. " window", dsp.focus({ direction = d.dir })) -- [O]
  bind("window.swap-" .. d.name, "SUPER + SHIFT + " .. key, "Swap window " .. d.swap,
    dsp.window.swap({ direction = d.dir })) -- [O]
  bind("workspace.to-monitor-" .. d.name, "SUPER + SHIFT + ALT + " .. key, "Move workspace to " .. d.name .. " monitor",
    dsp.workspace.move({ monitor = d.dir })) -- [N] direction as monitor selector (Omarchy resolves a monitor name)
  bind("window.to-monitor-" .. d.name, "SUPER + SHIFT + CTRL + " .. key, "Move window to " .. d.name .. " monitor",
    dsp.window.move({ monitor = d.dir })) -- [N] direction as monitor selector (Omarchy resolves a monitor name)
  bind("group.move-into-" .. d.name, "SUPER + ALT + " .. key, "Move window to group on " .. d.group,
    dsp.window.move({ into_group = d.dir })) -- [O]
end

-- Workspaces 1-10, global (tiling.lua:23-27 keys; native dispatchers).
for workspace = 1, 10 do
  local key = "code:" .. tostring(workspace + 9)
  bind("workspace." .. workspace, "SUPER + " .. key, "Switch to workspace " .. workspace,
    dsp.focus({ workspace = workspace })) -- [S]
  bind("workspace.move-" .. workspace, "SUPER + SHIFT + " .. key, "Move window to workspace " .. workspace,
    dsp.window.move({ workspace = workspace })) -- [S]
  bind("workspace.move-silent-" .. workspace, "SUPER + SHIFT + ALT + " .. key,
    "Move window silently to workspace " .. workspace, dsp.window.move({ workspace = workspace, follow = false })) -- [O]
end

-- Back-and-forth (MirrorOS choice on Omarchy's SUPER+Tab) and workspace scrolling (tiling.lua:78-79).
bind("workspace.previous", "SUPER + TAB", "Former workspace", dsp.focus({ workspace = "previous" })) -- [N] "previous"
bind("workspace.scroll-next", "SUPER + mouse_down", "Scroll active workspace forward",
  dsp.focus({ workspace = "m+1" }), not_launchable) -- [O]
bind("workspace.scroll-prev", "SUPER + mouse_up", "Scroll active workspace backward",
  dsp.focus({ workspace = "m-1" }), not_launchable) -- [O]

-- Scratchpad (tiling.lua:30-34).
bind("scratchpad.toggle", "SUPER + S", "Toggle scratchpad", dsp.workspace.toggle_special("scratchpad")) -- [O]
bind("scratchpad.toggle-grave", "SUPER + grave", "Toggle scratchpad", dsp.workspace.toggle_special("scratchpad")) -- [O]
bind("scratchpad.move", "SUPER + ALT + S", "Move window to scratchpad",
  dsp.window.move({ workspace = "special:scratchpad", follow = false })) -- [O]
bind("scratchpad.move-grave", "SUPER + SHIFT + grave", "Move window to scratchpad",
  dsp.window.move({ workspace = "special:scratchpad", follow = false })) -- [O]

-- Resize with minus (code:20) and equal (code:21) (tiling.lua:63-76).
local resize_steps = {
  { mods = "SUPER", id = "", label = "", step = 100 },
  { mods = "SUPER + ALT", id = "-little", label = " a little", step = 25 },
  { mods = "SUPER + CTRL", id = "-lot", label = " a lot", step = 300 },
}
for _, s in ipairs(resize_steps) do
  bind("resize.expand-left" .. s.id, s.mods .. " + code:20", "Expand window left" .. s.label,
    dsp.window.resize({ x = -s.step, y = 0, relative = true })) -- [O]
  bind("resize.shrink-left" .. s.id, s.mods .. " + code:21", "Shrink window left" .. s.label,
    dsp.window.resize({ x = s.step, y = 0, relative = true })) -- [O]
  bind("resize.shrink-up" .. s.id, s.mods .. " + SHIFT + code:20", "Shrink window up" .. s.label,
    dsp.window.resize({ x = 0, y = -s.step, relative = true })) -- [O]
  bind("resize.expand-down" .. s.id, s.mods .. " + SHIFT + code:21", "Expand window down" .. s.label,
    dsp.window.resize({ x = 0, y = s.step, relative = true })) -- [O]
end

-- Mouse move and resize (tiling.lua:81-82).
bind("mouse.move", "SUPER + mouse:272", "Move window", dsp.window.drag(), { mouse = true, launchable = false }) -- [S]
bind("mouse.resize", "SUPER + mouse:273", "Resize window", dsp.window.resize(), { mouse = true, launchable = false }) -- [S]

-- Groups (tiling.lua:84-103).
bind("group.toggle", "SUPER + G", "Toggle window grouping", dsp.group.toggle()) -- [O]
bind("group.move-out", "SUPER + ALT + G", "Move active window out of group", dsp.window.move({ out_of_group = true })) -- [O]
bind("group.next", "SUPER + ALT + TAB", "Next window in group", dsp.group.next()) -- [O]
bind("group.prev", "SUPER + ALT + SHIFT + TAB", "Previous window in group", dsp.group.prev()) -- [O]
bind("group.focus-left", "SUPER + CTRL + LEFT", "Move grouped window focus left", dsp.group.prev()) -- [O]
bind("group.focus-right", "SUPER + CTRL + RIGHT", "Move grouped window focus right", dsp.group.next()) -- [O]
bind("group.scroll-next", "SUPER + ALT + mouse_down", "Next window in group", dsp.group.next(), not_launchable) -- [O]
bind("group.scroll-prev", "SUPER + ALT + mouse_up", "Previous window in group", dsp.group.prev(), not_launchable) -- [O]
for index = 1, 5 do
  bind("group.window-" .. index, "SUPER + ALT + code:" .. tostring(index + 9), "Switch to group window " .. index,
    dsp.group.active({ index = index })) -- [O]
end

-- Window cycling and monitor focus without SUPER (tiling.lua:55-61). Omarchy binds two dispatchers to each
-- Alt+Tab chord (cycle, then bring to top); in the Brief 3 runtime test the second one had no visible effect, so
-- each chord is one Lua function that runs both in order. Function dispatchers are run by MirrorOSKeys.dispatch.
bind("window.cycle-next", "ALT + TAB", "Focus on next window", function()
  hl.dispatch(dsp.window.cycle_next())
  hl.dispatch(dsp.window.bring_to_top())
end) -- [O] dispatchers, MirrorOS function wrapper
bind("window.cycle-prev", "ALT + SHIFT + TAB", "Focus on previous window", function()
  hl.dispatch(dsp.window.cycle_next({ next = false }))
  hl.dispatch(dsp.window.bring_to_top())
end) -- [O] dispatchers, MirrorOS function wrapper
bind("monitor.focus-next", "CTRL + ALT + TAB", "Focus on next monitor", dsp.focus({ monitor = "+1" })) -- [O]
bind("monitor.focus-prev", "CTRL + ALT + SHIFT + TAB", "Focus on previous monitor", dsp.focus({ monitor = "-1" })) -- [O]

-- Cursor zoom (utilities.lua:121-128).
bind("cursor.zoom-in", "SUPER + CTRL + Z", "Zoom in", function()
  local zoom = hl.get_config("cursor.zoom_factor") or 1
  hl.config({ cursor = { zoom_factor = zoom + 1 } })
end) -- [O]
bind("cursor.zoom-reset", "SUPER + CTRL + ALT + Z", "Reset zoom", function()
  hl.config({ cursor = { zoom_factor = 1 } })
end) -- [O]

-- Terminal (applications.lua:2; previously the only terminal binding of the managed hyprland.lua).
bind("terminal.open", "SUPER + RETURN", "Terminal", dsp.exec_cmd("uwsm app -- foot"))

-- Terminal with tmux (applications.lua:12; Omarchy bin/omarchy-launch-terminal-tmux command).
bind("terminal.tmux", "SUPER + ALT + RETURN", "Tmux",
  dsp.exec_cmd("uwsm app -- foot bash -c 'tmux attach || tmux new -s Work'"))

if not MirrorOSKeys.staged then MirrorOSKeys.export() end
