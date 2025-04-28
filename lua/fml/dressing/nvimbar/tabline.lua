local c = require("fml.dressing.nvimbar.components")

local dirtier = eve.status.dirtier_tabline ---@type eve.std.collection.IDirtier
local position = "f_tl" ---@type eve.ux.nvimbar.Position

local tabline ---@type eve.ux.INvimbar
tabline = eve.ux.Nvimbar.new({
  name = "tabline",
  comp_sep = "",
  comp_sep_hlname = position .. "_bg",
  comp_sep_hlname_active = position .. "_bg",
  render_delay = 256,
  silent = function()
    local devmode = eve.state.flight.devmode:snapshot() ---@type boolean
    return not devmode
  end,
  get_max_width = function()
    return vim.o.columns
  end,
  is_active = eve.std.fn.falsy,
  trigger_rerender = function()
    vim.o.tabline = tabline:snapshot()
  end,
})

tabline
  :place("left", c.neotree(position, "left"), 95)
  :place(
    "left",
    c.sidebar(position, eve.filetype.DIFFVIEW_FILES, function()
      local title = eve.icon.git.Git .. " Git Diffview" ---@type string
      return title
    end),
    95
  )
  :place(
    "left",
    c.sidebar(position, eve.filetype.DAP_UI_SCOPES, function()
      local title = eve.icon.ui.Bug .. " Debug" ---@type string
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
  local devmode = eve.state.flight.devmode:snapshot() ---@type boolean
  if devmode then
    return true
  end

  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  if tab_count > 1 then
    return true
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = eve.tab.resolve(tabnr, false) ---@type eve.builtin.tab.IMetaData|nil
  return meta == nil or #meta.bufs > 1
end

local last_showtabline = 0 ---@type integer
dirtier:subscribe(eve.std.Subscriber.new({
  on_next = function()
    if should_show_tabline() then
      vim.o.showtabline = 2

      if last_showtabline == 0 then
        local filetype = eve.filetype.NEOTREE ---@type string
        local winnrs = vim.api.nvim_list_wins() ---@type integer[]
        for _, winnr in ipairs(winnrs) do
          local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
          if vim.bo[bufnr].filetype == filetype then
            if not eve.win.is_floating(winnr) then
              vim.wo[winnr].winbar = nil
            end
          end
        end
      end

      last_showtabline = 2
      tabline:render()
    else
      vim.o.showtabline = 0

      if last_showtabline ~= 0 then
        local winnrs = vim.api.nvim_list_wins() ---@type integer[]
        for _, winnr in ipairs(winnrs) do
          eve.status.dirty_winline_nr:next(winnr)
        end
      end

      last_showtabline = 0
    end
  end,
}))

return tabline
