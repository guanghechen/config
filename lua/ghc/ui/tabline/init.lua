---@class ghc.ui.tabline
local M = {}

---@type fml.types.ui.INvimbar
local tabline = fml.ui.Nvimbar.new({
  component_sep = "",
  component_sep_hlname = "f_transparent",
})

tabline
---
    :add("left", require("ghc.ui.tabline.component.neotree"))
    :add("right", require("ghc.ui.tabline.component.tabs"))

local dirty = true
local running = false
local last_tabline_result = '' ---@type string
local render_tabline = fml.fn.throttle_leading(function()
  running = true
  local ok, result = pcall(tabline.render, tabline)
  running = false
  if ok then
    last_tabline_result = result
    dirty = false
    vim.cmd("redrawtabline")
  else
    fml.reporter.error({
      from = "ghc.ui.tabline",
      subject = "render",
      message = "Encounter errors while render tabline",
      details = { result = result }
    })
  end
end, 200).throttled

---@return string
function M.render()
  if not running and dirty then
    render_tabline()
  end
  dirty = true
  return last_tabline_result
end

return M
