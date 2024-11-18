local devmode = eve.context.state.flight.devmode:snapshot() ---@type boolean
local tabline_dirty = true ---@type boolean

local tabline ---@type t.fml.ux.INvimbar
tabline = fml.ux.Nvimbar.new({
  name = "tabline",
  component_sep = "",
  component_sep_hlname = "f_tl_bg",
  render_delay = 64,
  silent = not devmode,
  get_max_width = function()
    return vim.o.columns
  end,
  trigger_rerender = function()
    tabline_dirty = false
    vim.cmd("redrawtabline")
    vim.schedule(function()
      tabline:cancel_render()
    end)
  end,
  validate = function()
    return nil
  end,
})

local c = {
  bufs = "bufs",
  cwd = "cwd",
  devmode = "devmode",
  diffview = "diffview",
  neotree = "neotree",
  tabs = "tabs",
}
for _, name in pairs(c) do
  tabline:register(name, require("ghc.ux.tabline.component." .. name))
end

tabline
  ---
  :place(c.devmode, "right")
  :place(c.cwd, "right")
  :place(c.tabs, "right")
  :place(c.neotree, "left")
  :place(c.diffview, "left")
  :place(c.bufs, "left")

---@class ghc.ux.tabline
local M = { cnames = vim.deepcopy(c) }

---@return string
function M.render()
  local result = tabline:render(tabline_dirty) ---@type string
  tabline_dirty = true
  return result
end

return M
