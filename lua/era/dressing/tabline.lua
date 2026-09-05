---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.tabline" ---@type string
local initialized = false ---@type boolean

---@class era.dressing.tabline
local M = {}

local dirtier = dot.state.status.dirtier_tabline ---@type stl.c.Dirtier
local position = "f_tl" ---@type stl.t.NvimbarPositionEnum

----------------------------------------------------------------------------------------------------
-- Default nvimbar
----------------------------------------------------------------------------------------------------

local normal_tabline ---@type era.m.nvimbar.Nvimbar
normal_tabline = era
  .m
  .nvimbar
  .Nvimbar
  .new({
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
      if vim.t.tabtype == nil or vim.t.tabtype == stl.e.TabTypeEnum.NORMAL then
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

local function create_maximize_tabline()
  local content = "󰓩 MAXIMIZED" ---@type string
  local text = stl.icon.symbols.sep_left .. content .. stl.icon.symbols.sep_right ---@type string
  local hl_text = stl.nvim.fn.txt(stl.icon.symbols.sep_left, position .. "_nvim_tabtype_sep")
    .. stl.nvim.fn.txt(content, position .. "_nvim_tabtype_text")
    .. stl.nvim.fn.txt(stl.icon.symbols.sep_right, position .. "_nvim_tabtype_sep") ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local indicator = {
    name = "maximize:indicator",
    atomic = true,
    render = function()
      return text, hl_text, true
    end,
  }

  local nvimbar ---@type era.m.nvimbar.Nvimbar
  nvimbar = era.m.nvimbar.Nvimbar
    .new({
      name = "tabline_maximize",
      comp_sep = "",
      comp_sep_hlname = position .. "_bg",
      comp_sep_hlname_active = position .. "_bg",
      delay = 256,
      silent = function()
        return not dot.context.flight.devmode:snapshot()
      end,
      get_max_width = function()
        return vim.o.columns
      end,
      is_active = stl.fn.falsy,
      on_fulfilled = function()
        if vim.t.tabtype == stl.e.TabTypeEnum.MAXIMIZE then
          vim.o.tabline = nvimbar:snapshot()
        end
      end,
    })
    :place("center", indicator, 100)
  return nvimbar
end

----------------------------------------------------------------------------------------------------
-- Nvimbar registry
----------------------------------------------------------------------------------------------------

---@type table<stl.e.TabTypeEnum, era.m.nvimbar.Nvimbar|fun(): era.m.nvimbar.Nvimbar>
local tabline_nvimbar_map = {
  [stl.e.TabTypeEnum.NORMAL] = normal_tabline,
  [stl.e.TabTypeEnum.MAXIMIZE] = create_maximize_tabline,
}

---Register a nvimbar factory for a specific tabtype (idempotent).
---The factory is called lazily on first render.
---@param tabtype                        stl.e.TabTypeEnum
---@param factory                        fun(): era.m.nvimbar.Nvimbar
---@return nil
function M.register(tabtype, factory)
  if tabline_nvimbar_map[tabtype] then
    return
  end
  tabline_nvimbar_map[tabtype] = factory
end

---Resolve nvimbar for a specific tabtype (lazily creates from factory).
---@param tabtype                        stl.e.TabTypeEnum
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
  local tabtype = vim.t[tabnr].tabtype ---@type stl.e.TabTypeEnum|nil
  if tabtype ~= nil and tabtype ~= stl.e.TabTypeEnum.NORMAL then
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

--- Subscribe once; dirty updates own subsequent rendering and visibility transitions.
---@return nil
function M.dressing()
  if initialized then
    return
  end
  initialized = true

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
        local tabtype = vim.t.tabtype or stl.e.TabTypeEnum.NORMAL ---@type stl.e.TabTypeEnum
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
