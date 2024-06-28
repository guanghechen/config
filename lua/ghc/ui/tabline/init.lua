---@class ghc.ui.tabline
local M = {}

---@type fml.types.ui.INvimbar
local statusline = fml.ui.Nvimbar.new({
  component_sep = fml.nvimbar.txt("", "f_transparent"),
})

statusline
---
    :add("left", require("ghc.ui.tabline.component.neotree"))
    :add("right", require("ghc.ui.tabline.component.tabs"))

---@return string
function M.render()
  local result = statusline:render()
  return result
end

return M
