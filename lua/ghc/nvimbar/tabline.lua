local functional = require("eve.lib.functional")
local state = require("eve.state")
local c = require("ghc.nvimbar.components")

local devmode = state.state.flight.devmode:snapshot() ---@type boolean
local tabline_dirty = true ---@type boolean

local tabline ---@type fml.t.ux.INvimbar
tabline = fml.ux.Nvimbar.new({
  name = "tabline",
  component_sep = "",
  component_sep_hlname = "f_tl_bg",
  component_sep_hlname_active = "f_tl_bg",
  render_delay = 64,
  silent = not devmode,
  get_max_width = function()
    return vim.o.columns
  end,
  is_active = functional.falsy,
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

tabline
  :register(c.bufs())
  :register(c.cwd())
  :register(c.devmode())
  :register(c.diffview())
  :register(c.neotree())
  :register(c.tabs())

tabline
  ---
  :place("devmode", "right")
  :place("cwd", "right")
  :place("tabs", "right")
  --
  :place("neotree", "left")
  :place("diffview", "left")
  :place("bufs", "left")

---@class ghc.nvimbar.tabline
local M = { cnames = vim.deepcopy(c) }

---@return string
function M.render()
  local result = tabline:render(tabline_dirty) ---@type string
  tabline_dirty = true
  return result
end

return M
