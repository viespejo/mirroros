-- managed by MirrorOS configure
-- Resolve and validate optional product borders before the provider applies them.
-- The caller supplies the trusted resolver and loader; the selection link is not a trust authority.
return function(resolve, load, validate, warn)
  local ok, path = pcall(resolve)
  local name = ok and type(path) == "string" and path:match("^/usr/share/mirroros/themes/([a-z0-9][a-z0-9-]*)/hyprland%.lua$")
  if not name or name:sub(-1) == "-" or name:find("--", 1, true) then
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
