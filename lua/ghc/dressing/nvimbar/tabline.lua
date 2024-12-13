local functional = require("eve.lib.functional")
local Nvimbar = require("eve.lib.ux.nvimbar")
local Subscriber = require("eve.lib.collection.subscriber")
local status = require("eve.builtin.status")
local state = require("eve.state")
local c = require("ghc.dressing.nvimbar.components")

local dirtier = status.tabline_dirtier ---@type eve.lib.collection.IDirtier
local position = "f_tl" ---@type eve.lib.ux.nvimbar.Position

---@return boolean
local function should_show_tabline()
  local devmode = state.state.flight.devmode:snapshot() ---@type boolean
  if devmode then
    return true
  end

  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  if tab_count > 1 then
    return true
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = eve.tab.resolve(tabnr)
  return meta == nil or #meta.bufs > 1
end

local tabline ---@type eve.lib.ux.INvimbar
tabline = Nvimbar.new({
  name = "tabline",
  component_sep = "",
  component_sep_hlname = position .. "_bg",
  component_sep_hlname_active = position .. "_bg",
  render_delay = 256,
  silent = function()
    local devmode = state.state.flight.devmode:snapshot() ---@type boolean
    return not devmode
  end,
  get_max_width = function()
    return vim.o.columns
  end,
  is_active = functional.falsy,
  trigger_rerender = function()
    vim.o.tabline = tabline:snapshot()
  end,
})

tabline
  ---
  :register(c.devmode(position), "right")
  -- :register(c.cwd(position), "right")
  :register(c.tabs(position), "right")
  --
  :register(c.debug_render_count(position), "center")
  --
  :register(c.neotree(position), "left")
  :register(c.diffview(position), "left")
  :register(c.bufs(position), "left")

dirtier:subscribe(Subscriber.new({
  on_next = function()
    if should_show_tabline() then
      vim.o.showtabline = 2
      tabline:render()
    else
      vim.o.showtabline = 0
    end
  end,
}))
