local icons = require("eve.constant.icon")
local state = require("eve.state")

local Nvimbar = require("fml.ux.nvimbar")
local c = require("fml.dressing.nvimbar.components")

local dirtier = state.status.dirtier_tabline ---@type eve.collection.IDirtier
local position = "f_tl" ---@type fml.ux.nvimbar.Position

local tabline ---@type fml.ux.INvimbar
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
  is_active = eve.fn.falsy,
  trigger_rerender = function()
    vim.o.tabline = tabline:snapshot()
  end,
})

tabline
  :place(
    "left",
    c.sidebar(position, eve.filetype.NEOTREE, function(context)
      local cwd_name = context.cwd:match("([^/\\]+)[/\\]*$") or context.cwd ---@type string
      local title = icons.filetype.FolderRootOpened .. " " .. cwd_name ---@type string
      return title
    end),
    95
  )
  :place(
    "left",
    c.sidebar(position, eve.filetype.DIFFVIEW_FILES, function()
      local title = icons.git.Git .. " Git Diffview" ---@type string
      return title
    end),
    95
  )
  :place(
    "left",
    c.sidebar(position, eve.filetype.DAP_UI_SCOPES, function()
      local title = icons.ui.Bug .. " Debug" ---@type string
      return title
    end),
    95
  )
  :place("left", c.bufs(position), 95)
  --
  :place("center", c.debug_render_count(position), 100)
  --
  -- :place("right", c.cwd(position), 100)
  -- :place("right", c.devmode(position), 100)
  :place(
    "right",
    c.tabs(position),
    100
  )
--
-- :place("right", c.cwd(position), 100)

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

dirtier:subscribe(eve.col.Subscriber.new({
  on_next = function()
    if should_show_tabline() then
      vim.o.showtabline = 2
      tabline:render()
    else
      vim.o.showtabline = 0
    end
  end,
}))

return tabline
