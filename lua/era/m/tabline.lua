---@class era.m.tabline
local M = {}

local dirtier = dot.state.status.dirtier_tabline ---@type stl.c.Dirtier
local position = "f_tl" ---@type stl.e.NvimbarPositionEnum

local tabline ---@type era.m.nvimbar.Nvimbar
tabline = era.m.nvimbar.Nvimbar.new({
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
  is_active = stl.fn.falsy,
  on_fulfilled = function()
    vim.o.tabline = tabline:snapshot()
  end,
})

tabline
  :place("left", era.m.nvimbar.component.explorer.tabline(position), 95)
  :place(
    "left",
    era.m.nvimbar.component.sidebar.of(position, stl.filetype.DIFFVIEW_FILES, function()
      local title = stl.icon.git.Git .. " Git Diffview" ---@type string
      return title
    end),
    95
  )
  :place(
    "left",
    era.m.nvimbar.component.sidebar.of(position, stl.filetype.DAP_UI_SCOPES, function()
      local title = stl.icon.ui.Bug .. " Debug" ---@type string
      return title
    end),
    95
  )
  :place("left", era.m.nvimbar.component.buf.bufs(position), 95)
  --
  :place("center", era.m.nvimbar.component.devmode.render_count(position), 100)
  --
  -- :place("right", era.m.nvimbar.component.cwd.cwd(position), 100)
  -- :place("right", era.m.nvimbar.component.devmode.devmode(position), 100)
  :place(
    "right",
    era.m.nvimbar.component.nvim.tabs(position),
    100
  )
--
-- :place("right", era.m.nvimbar.component.cwd.cwd(position), 100)

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

---@return nil
function M.dressing()
  local last_showtabline = 0 ---@type integer
  dirtier:subscribe(stl.c.Subscriber.new({
    on_next = function()
      if should_show_tabline() then
        vim.o.showtabline = 2

        if last_showtabline == 0 then
          if era.widget.explorer.widget ~= nil and era.widget.explorer.widget:isvisible() then
            era.widget.explorer.widget:render_winbar()
          end
        end

        last_showtabline = 2
        tabline:render()
      else
        vim.o.showtabline = 0

        if last_showtabline ~= 0 then
          if era.widget.explorer.widget ~= nil and era.widget.explorer.widget:isvisible() then
            era.widget.explorer.widget:render_winbar()
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
end

return M
