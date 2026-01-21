---@class era.m.tabline
local M = {}

local dirtier = dot.state.status.dirtier_tabline ---@type stl.c.Dirtier
local position = "f_tl" ---@type stl.e.NvimbarPositionEnum

----------------------------------------------------------------------------------------------------
-- Default nvimbar
----------------------------------------------------------------------------------------------------

local normal_tabline ---@type era.m.nvimbar.Nvimbar
normal_tabline = era.m.nvimbar.Nvimbar.new({
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
    if vim.t.tabtype == nil or vim.t.tabtype == stl.nvim.tab.TypeEnum.NORMAL then
      vim.o.tabline = normal_tabline:snapshot()
    end
  end,
})
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

----------------------------------------------------------------------------------------------------
-- Nvimbar registry
----------------------------------------------------------------------------------------------------

---@type table<stl.nvim.tab.TypeEnum, era.m.nvimbar.Nvimbar|fun(): era.m.nvimbar.Nvimbar>
local tabline_nvimbar_map = {
  [stl.nvim.tab.TypeEnum.NORMAL] = normal_tabline,
}

---Register a nvimbar factory for a specific tabtype (idempotent).
---The factory is called lazily on first render.
---@param tabtype                        stl.nvim.tab.TypeEnum
---@param factory                        fun(): era.m.nvimbar.Nvimbar
---@return nil
function M.register(tabtype, factory)
  if tabline_nvimbar_map[tabtype] then
    return
  end
  tabline_nvimbar_map[tabtype] = factory
end

---Resolve nvimbar for a specific tabtype (lazily creates from factory).
---@param tabtype                        stl.nvim.tab.TypeEnum
---@return era.m.nvimbar.Nvimbar
local function resolve_nvimbar(tabtype)
  local entry = tabline_nvimbar_map[tabtype]
  if entry == nil then
    return normal_tabline
  end
  if type(entry) == "function" then
    local nvimbar = entry() ---@type era.m.nvimbar.Nvimbar
    tabline_nvimbar_map[tabtype] = nvimbar
    return nvimbar
  end
  return entry
end

----------------------------------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------------------------------

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
  local tabtype = vim.t[tabnr].tabtype ---@type stl.nvim.tab.TypeEnum|nil
  if tabtype ~= nil and tabtype ~= stl.nvim.tab.TypeEnum.NORMAL then
    return true
  end

  local meta = dot.tab.resolve(tabnr, false) ---@type dot.tab.IMeta|nil
  return meta == nil or #meta.bufs > 1
end

---@return boolean
local function is_explorer_visible_in_current_tab()
  if era.widget.explorer.widget == nil then
    return false
  end
  return era.widget.explorer.widget:has_win_in_tab()
end

----------------------------------------------------------------------------------------------------
-- Dressing
----------------------------------------------------------------------------------------------------

---@return nil
function M.dressing()
  local last_showtabline = 0 ---@type integer
  dirtier:subscribe(stl.c.Subscriber.new({
    on_next = function()
      if should_show_tabline() then
        vim.o.showtabline = 2

        if last_showtabline == 0 then
          if is_explorer_visible_in_current_tab() then
            era.widget.explorer.widget:render_winbar()
          end
        end

        last_showtabline = 2

        -- Get nvimbar for current tabtype and render
        local tabtype = vim.t.tabtype or stl.nvim.tab.TypeEnum.NORMAL ---@type stl.nvim.tab.TypeEnum
        local nvimbar = resolve_nvimbar(tabtype)
        nvimbar:render()
      else
        vim.o.showtabline = 0

        if last_showtabline ~= 0 then
          if is_explorer_visible_in_current_tab() then
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
