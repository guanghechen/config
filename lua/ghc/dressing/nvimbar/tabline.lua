local functional = require("eve.lib.functional")
local Nvimbar = require("eve.lib.ux.nvimbar")
local Subscriber = require("eve.lib.collection.subscriber")
local state = require("eve.state")
local c = require("ghc.dressing.nvimbar.components")

local dirtier = state.status.dirtier_tabline ---@type eve.lib.collection.IDirtier
local position = "f_tl" ---@type eve.lib.ux.nvimbar.Position

---@return boolean
local function should_show_tabline()
  local devmode = state.flight.devmode:snapshot() ---@type boolean
  if devmode then
    return true
  end

  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  if tab_count > 1 then
    return true
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = state.tab.resolve(tabnr)
  return meta == nil or #meta.bufs > 1
end

local tabline ---@type eve.lib.ux.INvimbar
tabline = Nvimbar.new({
  name = "tabline",
  comp_sep = "",
  comp_sep_hlname = position .. "_bg",
  comp_sep_hlname_active = position .. "_bg",
  render_delay = 256,
  silent = function()
    local devmode = state.flight.devmode:snapshot() ---@type boolean
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
  :place("left", c.neotree(position), 95)
  :place("left", c.diffview(position), 95)
  :place("left", c.bufs(position), 95)
  --
  :place("center", c.debug_render_count(position), 100)
  --
  -- :place("right", c.devmode(position), 100)
  :place("right", c.tabs(position), 100)
--
-- :place("right", c.cwd(position), 100)

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
