-- managed by MirrorOS configure
-- Validate the complete reviewed border subset before passing it to Hyprland.
local function borders(value)
  if type(value) ~= "table" or getmetatable(value) ~= nil then return nil, "theme must return a plain table" end
  for key in pairs(value) do
    if key ~= "active_border" and key ~= "inactive_border" then
      return nil, "unsupported border setting"
    end
  end
  for _, key in ipairs({ "active_border", "inactive_border" }) do
    local color = value[key]
    if type(color) ~= "string" or not color:match("^rgba%(%x%x%x%x%x%x%x%x%)$") then
      return nil, "invalid " .. key
    end
  end
  return { active_border = value.active_border, inactive_border = value.inactive_border }
end

return borders
