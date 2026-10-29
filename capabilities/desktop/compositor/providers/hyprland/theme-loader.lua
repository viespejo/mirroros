-- managed by MirrorOS configure
-- Resolve and validate optional product borders before the provider applies them.
-- The caller supplies the trusted resolver and loader; the selection link is not a trust authority.
return function(resolve, load, validate, warn)
  local ok, path = pcall(resolve)
  if not ok or type(path) ~= "string" or path ~= "/usr/share/mirroros/themes/default/hyprland.lua" then
    warn("Cannot resolve trusted Hyprland theme; using provider defaults")
    return nil
  end
  local loaded, value = pcall(load, path)
  if not loaded then
    warn("Cannot load Hyprland theme; using provider defaults")
    return nil
  end
  local checked, borders, message = pcall(validate, value)
  if not checked or not borders then
    warn("Invalid Hyprland theme; using provider defaults" .. (checked and message and (": " .. message) or ""))
    return nil
  end
  return borders
end
