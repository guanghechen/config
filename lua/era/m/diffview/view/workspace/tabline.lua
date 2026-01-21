---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.workspace.tabline" ---@type string

local config = require("era.m.diffview.config")
local workspace_state = require("era.m.diffview.view.workspace.state")
local workspace_view = require("era.m.diffview.view.workspace.view")
local pane_sbs = require("era.m.diffview.pane.sbs")

local btn = stl.nvim.fn.btn
local txt = stl.nvim.fn.txt

---Workspace view tabline components and registration.
---@class era.m.diffview.view.workspace.tabline
local M = {}

M.position = "f_tl" ---@type stl.t.NvimbarPositionEnum

----------------------------------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------------------------------

---Get changes pane width for current tab
---@return integer
local function get_pane_width()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
    if filetype == config.FT.CHANGES then
      if not stl.nvim.win.is_float(winnr) then
        return vim.api.nvim_win_get_width(winnr)
      end
    end
  end
  return 0
end

----------------------------------------------------------------------------------------------------
-- Callbacks
----------------------------------------------------------------------------------------------------

---@type table<string, string|nil>
local __cached_callbacks__ = {}

---Get or create callback path for a flag toggle
---@param cache_key                     string
---@param toggle_fn                     fun(): nil
---@return string
local function get_or_create_callback(cache_key, toggle_fn)
  if __cached_callbacks__[cache_key] then
    return __cached_callbacks__[cache_key]
  end

  local cb_path = dot.G.register_anonymous_fn(toggle_fn) or "dot.G.noop"
  __cached_callbacks__[cache_key] = cb_path
  return cb_path
end

---Get callback path for viewtype toggle
---@return string
local function get_cb_viewtype()
  return get_or_create_callback("workspace_viewtype", function()
    local current = dot.context.diffview.flag_panel_viewtype:snapshot() ---@type stl.m.diffview.PanelViewTypeEnum
    local next_viewtype = current == "tree" and "list" or "tree" ---@type stl.m.diffview.PanelViewTypeEnum
    dot.context.diffview.flag_panel_viewtype:next(next_viewtype)

    -- Re-render changes pane
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local state = workspace_state.get(tabnr)
    local view = require("era.m.diffview.view.workspace.view")
    local lyt = view.get_layout(tabnr)

    if state and lyt then
      view.render_changes({ layout = lyt, state = state })
    end
  end)
end

---Get callback path for foldempty toggle
---@return string
local function get_cb_foldempty()
  return get_or_create_callback("workspace_foldempty", function()
    local current = dot.context.diffview.flag_foldempty:snapshot() ---@type boolean
    dot.context.diffview.flag_foldempty:next(not current)

    -- Re-render changes pane
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local state = workspace_state.get(tabnr)
    local view = require("era.m.diffview.view.workspace.view")
    local lyt = view.get_layout(tabnr)

    if state and lyt then
      view.render_changes({ layout = lyt, state = state })
    end
  end)
end

----------------------------------------------------------------------------------------------------
-- Status component
----------------------------------------------------------------------------------------------------

---Create workspace status component for nvimbar
---@return era.m.nvimbar.IRawComponent
function M.status_component()
  local pos = M.position ---@type string
  local hln_blank = pos .. "_sidebar_blank"
  local hln_split = pos .. "_sidebar_split"
  local hln_pink = pos .. "_sidebar_pink"
  local hln_flag_on = pos .. "_flag_on"
  local hln_flag_off = pos .. "_flag_off"
  local hln_flag_viewtype = pos .. "_flag_viewtype"

  local cb_viewtype = get_cb_viewtype()
  local cb_foldempty = get_cb_foldempty()
  local cb_fold_unchanged = get_or_create_callback("workspace_fold_unchanged", function()
    local current = dot.context.diffview.flag_fold_unchanges:snapshot() ---@type boolean
    dot.context.diffview.flag_fold_unchanges:next(not current)

    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local lyt = workspace_view.get_layout(tabnr)
    if not lyt then
      return
    end
    pane_sbs.apply_fold_unchanged_pair(lyt.sbs_left_winnr, lyt.sbs_right_winnr)
    dot.state.status.dirtier_tabline:mark_dirty()
  end)

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "diffview:workspace_status",
    atomic = true,
    render = function(_, remain_width)
      local width = math.min(remain_width, get_pane_width()) ---@type integer
      if width < 1 then
        return "", "", true
      end

      -- Get state from current tab
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local state = workspace_state.get(tabnr)

      local entries = state and state:get_entries() or {} ---@type era.m.diffview.IFileEntry[]
      local total = #entries ---@type integer

      -- Get flags state
      local viewtype = dot.context.diffview.flag_panel_viewtype:snapshot() ---@type stl.m.diffview.PanelViewTypeEnum
      local foldempty = dot.context.diffview.flag_foldempty:snapshot() ---@type boolean
      local fold_unchanged = dot.context.diffview.flag_fold_unchanges:snapshot() ---@type boolean
      local is_tree = viewtype == "tree" ---@type boolean

      -- Build flag texts
      local viewtype_icon = is_tree and stl.icon.symbols.flag_tree or stl.icon.symbols.flag_list ---@type string
      local flag1_text = " " .. viewtype_icon .. "¹" ---@type string
      local flag3_text = " " .. stl.icon.symbols.flag_fold_unchanged .. "³" ---@type string

      -- Build content: " Git Changes (N)  [flags]"
      local git_icon = stl.icon.git.Git ---@type string
      local title_prefix = git_icon .. " Changes (" ---@type string
      local title_suffix = tostring(total) .. ")" ---@type string
      local title_text = title_prefix .. title_suffix ---@type string
      local title_width = vim.api.nvim_strwidth(title_text) ---@type integer

      -- Calculate flags width (flag2 only shown in tree mode)
      local flags_width = vim.api.nvim_strwidth(flag1_text) + vim.api.nvim_strwidth(flag3_text) ---@type integer
      local flag2_text = "" ---@type string
      if is_tree then
        local foldempty_icon = stl.icon.symbols.flag_fold_empty_path ---@type string
        flag2_text = " " .. foldempty_icon .. "²"
        flags_width = flags_width + vim.api.nvim_strwidth(flag2_text)
      end

      if width < title_width + flags_width + 2 then
        local text = string.rep(" ", width) ---@type string
        local hl_text = txt(text, hln_blank)
        return text, hl_text, true
      end

      local padding_width = width - title_width - flags_width - 1 ---@type integer
      local padding = string.rep(" ", padding_width) ---@type string
      local right_split = " " ---@type string

      local text = title_text .. padding .. flag1_text .. flag2_text .. flag3_text .. right_split ---@type string
      local hl_text = txt(title_text, hln_pink) .. txt(padding, hln_blank) .. btn(txt(flag1_text, hln_flag_viewtype), cb_viewtype)
      if is_tree then
        local flag2_hln = foldempty and hln_flag_on or hln_flag_off ---@type string
        hl_text = hl_text .. btn(txt(flag2_text, flag2_hln), cb_foldempty)
      end
      local flag3_hln = fold_unchanged and hln_flag_on or hln_flag_off ---@type string
      hl_text = hl_text .. btn(txt(flag3_text, flag3_hln), cb_fold_unchanged)
      hl_text = hl_text .. txt(right_split, hln_split)
      return text, hl_text, true
    end,
  }
  return component
end

----------------------------------------------------------------------------------------------------
-- Tabline factory
----------------------------------------------------------------------------------------------------

---Create workspace tabline nvimbar instance
---@return fun(): era.m.nvimbar.Nvimbar
function M.create_tabline()
  return function()
    local position = M.position
    local nvimbar ---@type era.m.nvimbar.Nvimbar
    local tabtype = stl.nvim.tab.TypeEnum.DIFFVIEW_WORKSPACE

    nvimbar = era.m.nvimbar.Nvimbar.new({
      name = "tabline_diffview_workspace",
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
        if vim.t.tabtype == tabtype then
          vim.o.tabline = nvimbar:snapshot()
        end
      end,
    })

    nvimbar
      :place("left", M.status_component(), 95)
      :place("center", era.m.nvimbar.component.nvim.tabtype(position, stl.icon.git.Git .. " "), 100)
      :place("right", era.m.nvimbar.component.nvim.tabs(position), 100)

    return nvimbar
  end
end

----------------------------------------------------------------------------------------------------
-- Registration
----------------------------------------------------------------------------------------------------

---Register nvimbar for DIFFVIEW_WORKSPACE tabtype (idempotent)
---@return nil
function M.register()
  era.m.tabline.register(stl.nvim.tab.TypeEnum.DIFFVIEW_WORKSPACE, M.create_tabline())
end

return M
