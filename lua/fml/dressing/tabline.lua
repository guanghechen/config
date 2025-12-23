local c = require("dot.module.nvimbar").component
local Nvimbar = require("dot.module.nvimbar").Nvimbar

local dirtier = dot.state.status.dirtier_tabline ---@type ark.c.Dirtier
local position = "f_tl" ---@type dot.module.nvimbar.PositionEnum

local tabline ---@type dot.module.nvimbar.Nvimbar
tabline = Nvimbar.new({
  name = "tabline",
  comp_sep = "",
  comp_sep_hlname = position .. "_bg",
  comp_sep_hlname_active = position .. "_bg",
  delay = 256,
  silent = function()
    local devmode = dot.context.flight.devmode:snapshot() ---@type boolean
    return not devmode
  end,
  get_max_width = function()
    return vim.o.columns
  end,
  is_active = ark.fn.falsy,
  on_fulfilled = function()
    vim.o.tabline = tabline:snapshot()
  end,
})

tabline
  :place("left", c.explorer.tabline(position), 95)
  :place(
    "left",
    c.sidebar.of(position, ark.filetype.DIFFVIEW_FILES, function()
      local title = dot.icon.git.Git .. " Git Diffview" ---@type string
      return title
    end),
    95
  )
  :place(
    "left",
    c.sidebar.of(position, ark.filetype.DAP_UI_SCOPES, function()
      local title = dot.icon.ui.Bug .. " Debug" ---@type string
      return title
    end),
    95
  )
  :place("left", c.buf.bufs(position), 95)
  --
  :place("center", c.devmode.render_count(position), 100)
  --
  -- :place("right", c.cwd.cwd(position), 100)
  -- :place("right", c.devmode.devmode(position), 100)
  :place(
    "right",
    c.nvim.tabs(position),
    100
  )
--
-- :place("right", c.cwd.cwd(position), 100)

---@return boolean
local function should_show_tabline()
  local devmode = dot.context.flight.devmode:snapshot() ---@type boolean
  if devmode then
    return true
  end

  local tab_count = vim.fn.tabpagenr("$") ---@type integer
  if tab_count > 1 then
    return true
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local meta = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  return meta == nil or #meta.bufs > 1
end

local last_showtabline = 0 ---@type integer
dirtier:subscribe(ark.c.Subscriber.new({
  on_next = function()
    if should_show_tabline() then
      vim.o.showtabline = 2

      if last_showtabline == 0 then
        if dot.widget.explorer.widget ~= nil then
          local winnr = dot.widget.explorer.widget:get_winnr() ---@type integer|nil
          if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
            vim.wo[winnr].winbar = nil
          end
        end
      end

      last_showtabline = 2
      tabline:render()
    else
      vim.o.showtabline = 0

      if last_showtabline ~= 0 then
        if dot.widget.explorer.widget ~= nil and dot.widget.explorer.widget:isvisible() then
          dot.widget.explorer.widget:render_winbar()
        end

        local winnrs = vim.api.nvim_list_wins() ---@type integer[]
        for _, winnr in ipairs(winnrs) do
          dot.state.status.dirty_winline_nr:next(winnr)
        end
      end

      last_showtabline = 0
    end
  end,
}))

return tabline
