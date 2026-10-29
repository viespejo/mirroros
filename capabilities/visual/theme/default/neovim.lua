-- MirrorOS jade highlight adjustments. The editor chooses and loads its own colorscheme.
local backgrounds = {
  Normal = "#111c18",
  SignColumn = "#111c18",
  CursorLine = "#16241e",
  LineNr = "#111c18",
}
for group, background in pairs(backgrounds) do
  local highlight = vim.api.nvim_get_hl(0, { name = group, link = false })
  highlight.bg = background
  vim.api.nvim_set_hl(0, group, highlight)
end
