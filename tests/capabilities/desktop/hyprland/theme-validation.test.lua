local validate = dofile("capabilities/desktop/compositor/providers/hyprland/theme-validation.lua")
local shipped = dofile("capabilities/visual/theme/default/hyprland.lua")
local valid, err = validate(shipped)
assert(valid, err)
assert(valid ~= shipped)
assert(valid.active_border == "rgba(509475ff)")
assert(valid.inactive_border == "rgba(595959aa)")

local invalid = {
  false,
  {},
  { active_border = "rgba(509475ff)" },
  { active_border = "rgba(509475ff)", inactive_border = "rgba(595959)" },
  { active_border = "rgba(509475ff)", inactive_border = "rgba(595959zz)" },
  { active_border = "rgba(509475ff)", inactive_border = "rgba(595959aa)", extra = true },
  setmetatable({ active_border = "rgba(509475ff)", inactive_border = "rgba(595959aa)" }, {}),
}
assert(validate(nil) == nil)
for _, value in ipairs(invalid) do
  local result, message = validate(value)
  assert(result == nil and type(message) == "string")
end
local uppercase = assert(validate({ active_border = "rgba(509475FF)", inactive_border = "rgba(595959AA)" }))
assert(uppercase.active_border == "rgba(509475FF)")
print("PASS Hyprland theme border validation")
