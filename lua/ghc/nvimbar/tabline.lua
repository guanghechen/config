local functional = require("eve.lib.functional")
local Nvimbar = require("eve.lib.ux.nvimbar")
local state = require("eve.state")
local c = require("ghc.nvimbar.components")

local devmode = state.state.flight.devmode:snapshot() ---@type boolean

local tabline ---@type eve.lib.ux.INvimbar
tabline = Nvimbar.new({
  name = "tabline",
  component_sep = "",
  component_sep_hlname = "f_sl_bg",
  component_sep_hlname_active = "f_sl_bg",
  render_delay = 128,
  silent = not devmode,
  get_max_width = function()
    return vim.o.columns
  end,
  is_active = functional.falsy,
  trigger_rerender = function()
    tabline:cancel_next_render()
    vim.cmd("redrawtabline")
  end,
  validate = function()
    return nil
  end,
})

tabline
  ---
  :register(c.devmode(), "right")
  :register(c.cwd(), "right")
  :register(c.tabs(), "right")
  --
  :register(c.debug_render_count(), "center")
  --
  :register(c.neotree(), "left")
  :register(c.diffview(), "left")
  :register(c.bufs(), "left")

---@class ghc.nvimbar.tabline
local M = {}

---@return string
function M.render()
  local result = tabline:render() ---@type string
  return result
end

return M
