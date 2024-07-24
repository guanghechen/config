---@type fml.types.ui.INvimbar
local tabline = fml.ui.Nvimbar.new({
  name = "tabline",
  component_sep = "",
  component_sep_hlname = "f_tl_bg",
  get_max_width = function()
    return vim.o.columns
  end,
})

local c = {
  bufs = "bufs",
  neotree = "neotree",
  search = "search",
  tabs = "tabs",
}
for _, name in pairs(c) do
  tabline:register(name, require("ghc.ui.tabline.component." .. name))
end

tabline
  ---
  :place(c.tabs, "right")
  :place(c.neotree, "left")
  :place(c.search, "left")
  :place(c.bufs, "left")

local dirty = true
local running = false
local last_tabline_result = "" ---@type string

---@class ghc.ui.tabline
local M = { cnames = vim.deepcopy(c) }

---@return string
function M.render()
  if running then
    dirty = true
    return last_tabline_result
  end

  if not dirty then
    return last_tabline_result
  end

  dirty = false
  running = true
  vim.defer_fn(function()
    local ok, result = pcall(tabline.render, tabline)
    if ok then
      last_tabline_result = result
      dirty = false
      vim.cmd("redrawtabline")
    else
      fml.reporter.error({
        from = "ghc.ui.tabline",
        subject = "render",
        message = "Encounter errors while render tabline",
        details = { result = result },
      })
    end

    running = false
    if dirty then
      M.render()
    end
  end, 32)
  return last_tabline_result
end

return M
