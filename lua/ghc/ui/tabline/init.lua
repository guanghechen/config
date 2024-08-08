local tabline_dirty = true ---@type boolean

---@type fml.types.ui.INvimbar
local tabline = fml.ui.Nvimbar.new({
  name = "tabline",
  component_sep = "",
  component_sep_hlname = "f_tl_bg",
  get_max_width = function()
    return vim.o.columns
  end,
  trigger_rerender = function()
    tabline_dirty = false
    vim.cmd("redrawtabline")
  end,
})

local c = {
  bufs = "bufs",
  neotree = "neotree",
  tabs = "tabs",
}
for _, name in pairs(c) do
  tabline:register(name, require("ghc.ui.tabline.component." .. name))
end

tabline
  ---
  :place(c.tabs, "right")
  :place(c.neotree, "left")
  :place(c.bufs, "left")

---@class ghc.ui.tabline
local M = { cnames = vim.deepcopy(c) }

---@return string
function M.render()
  local result = tabline:render(tabline_dirty) ---@type string
  tabline_dirty = true
  return result
end

return M
