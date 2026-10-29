local groups = { "Normal", "SignColumn", "CursorLine", "LineNr" }
for _, group in ipairs(groups) do
  vim.api.nvim_set_hl(0, group, { fg = "#abcdef", bg = "#123456", bold = true })
end
vim.api.nvim_set_hl(0, "Comment", { fg = "#aabbcc" })
vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#aabbcc", bg = "#123456" })
dofile("capabilities/visual/theme/default/neovim.lua")
for _, group in ipairs(groups) do
  local highlight = vim.api.nvim_get_hl(0, { name = group, link = false })
  assert(highlight.fg == 0xabcdef and highlight.bold, group .. " lost existing attributes")
  local expected = group == "CursorLine" and 0x16241e or 0x111c18
  assert(highlight.bg == expected, group .. " has the wrong background")
end
assert(vim.api.nvim_get_hl(0, { name = "Comment", link = false }).fg == 0xaabbcc)
local line_number = vim.api.nvim_get_hl(0, { name = "CursorLineNr", link = false })
assert(line_number.fg == 0xaabbcc and line_number.bg == 0x123456)
