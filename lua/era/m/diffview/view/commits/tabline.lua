---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.commits.tabline" ---@type string

local config = require("era.m.diffview.config")
local commits_state = require("era.m.diffview.view.commits.state")
local commits_view = require("era.m.diffview.view.commits.view")
local pane_sbs = require("era.m.diffview.pane.sbs")

local btn = stl.nvim.fn.btn
local txt = stl.nvim.fn.txt

---Commits view tabline components and registration.
---@class era.m.diffview.view.commits.tabline
local M = {}

M.position = "f_tl" ---@type stl.t.NvimbarPositionEnum

----------------------------------------------------------------------------------------------------
-- Constants (hoisted for performance)
----------------------------------------------------------------------------------------------------

local LAYOUT_ICONS = {
  stl.icon.symbols.flag_layout_1, -- layout 1: commits_top
  stl.icon.symbols.flag_layout_2, -- layout 2: commits_left
  stl.icon.symbols.flag_layout_3, -- layout 3: sbs_only
  stl.icon.symbols.flag_layout_4, -- layout 4: commits_only
  stl.icon.symbols.flag_layout_5, -- layout 5: commits_filetree
} ---@type string[]

local SUBSCRIPT_DIGITS = { "₁", "₂", "₃", "₄", "₅" } ---@type string[]

local ICON_GIT = stl.icon.git.Git ---@type string
local ICON_FILTER = stl.icon.ui.Search ---@type string
local ICON_FLAG_TREE = stl.icon.symbols.flag_tree ---@type string
local ICON_FLAG_LIST = stl.icon.symbols.flag_list ---@type string
local ICON_FLAG_FOLD_EMPTY = stl.icon.symbols.flag_fold_empty_path ---@type string
local ICON_FLAG_FOLD_UNCHANGED = stl.icon.symbols.flag_fold_unchanged ---@type string

----------------------------------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------------------------------

---Get commits pane width for current tab
---@return integer
local function get_pane_width()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
    if filetype == config.FT.COMMITS then
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
  return get_or_create_callback("commits_viewtype", function()
    local current = dot.context.diffview.flag_panel_viewtype:snapshot() ---@type stl.m.diffview.PanelViewTypeEnum
    local next_viewtype = current == "tree" and "list" or "tree" ---@type stl.m.diffview.PanelViewTypeEnum
    dot.context.diffview.flag_panel_viewtype:next(next_viewtype)

    -- Re-render commits pane
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local state = commits_state.get(tabnr)
    local view = require("era.m.diffview.view.commits.view")
    local lyt = view.get_layout(tabnr)

    if state and lyt then
      view.render_commits({ layout = lyt, state = state })
    end
  end)
end

---Get callback path for foldempty toggle
---@return string
local function get_cb_foldempty()
  return get_or_create_callback("commits_foldempty", function()
    local current = dot.context.diffview.flag_foldempty:snapshot() ---@type boolean
    dot.context.diffview.flag_foldempty:next(not current)

    -- Re-render commits pane
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local state = commits_state.get(tabnr)
    local view = require("era.m.diffview.view.commits.view")
    local lyt = view.get_layout(tabnr)

    if state and lyt then
      view.render_commits({ layout = lyt, state = state })
    end
  end)
end

---Get callback path for fold unchanged toggle
---@return string
local function get_cb_fold_unchanged()
  return get_or_create_callback("commits_fold_unchanged", function()
    local current = dot.context.diffview.flag_fold_unchanges:snapshot() ---@type boolean
    dot.context.diffview.flag_fold_unchanges:next(not current)

    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local lyt = commits_view.get_layout(tabnr)
    if not lyt then
      return
    end
    pane_sbs.apply_fold_unchanged_pair(lyt.sbs_left_winnr, lyt.sbs_right_winnr)
    dot.state.status.dirtier_tabline:mark_dirty()
  end)
end

---Get callback path for layout toggle
---@return string
local function get_cb_layout()
  return get_or_create_callback("commits_layout", function()
    -- Cycle through all 5 layout types using action
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local state = commits_state.get(tabnr)
    local view = require("era.m.diffview.view.commits.view")
    local lyt = view.get_layout(tabnr)

    if not state or not lyt then
      return
    end

    local action = require("era.m.diffview.view.commits.action")
    action.cycle_layout({ layout = lyt, state = state })
  end)
end

----------------------------------------------------------------------------------------------------
-- Status component
----------------------------------------------------------------------------------------------------

---Create commits status component for nvimbar
---@return era.m.nvimbar.IRawComponent
function M.status_component()
  local pos = M.position ---@type string
  local hln_split = pos .. "_sidebar_split"
  local hln_pink = pos .. "_sidebar_pink"
  local hln_dim = pos .. "_sidebar_dim"
  local hln_flag_on = pos .. "_flag_on"
  local hln_flag_off = pos .. "_flag_off"
  local hln_flag_layout = pos .. "_flag_layout"

  local cb_viewtype = get_cb_viewtype()
  local cb_foldempty = get_cb_foldempty()
  local cb_layout = get_cb_layout()
  local cb_fold_unchanged = get_cb_fold_unchanged()

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "diffview:commits_status",
    atomic = true,
    render = function(_, remain_width)
      local width = math.min(remain_width, get_pane_width()) ---@type integer
      if width < 1 then
        return "", "", true
      end

      -- Get state from current tab
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local state = commits_state.get(tabnr)

      local total = state and state:get_commits_total() or 0 ---@type integer
      local page = state and state:get_commits_page() or 1 ---@type integer
      local page_count = state and state:get_commits_page_count() or 1 ---@type integer
      local per_page = config.COMMITS_PER_PAGE ---@type integer

      -- Calculate current commit index
      local commits = state and state:get_commits() or {} ---@type era.m.diffview.ICommit[]
      local current_commit = state and state:get_current_commit() ---@type era.m.diffview.ICommit|nil
      local index_in_page = 1 ---@type integer
      if current_commit then
        for i, c in ipairs(commits) do
          if c.hash == current_commit.hash then
            index_in_page = i
            break
          end
        end
      end
      local global_index = (page - 1) * per_page + index_in_page ---@type integer

      -- Get flags state
      local viewtype = dot.context.diffview.flag_panel_viewtype:snapshot() ---@type stl.m.diffview.PanelViewTypeEnum
      local foldempty = dot.context.diffview.flag_foldempty:snapshot() ---@type boolean
      local fold_unchanged = dot.context.diffview.flag_fold_unchanges:snapshot() ---@type boolean
      local is_tree = viewtype == "tree" ---@type boolean

      -- Get current layout type from layout
      local lyt = commits_view.get_layout(tabnr)
      local layout_type = lyt and lyt.layout_type or 1 ---@type integer

      -- Build flag texts (layout first for t0)
      local layout_icon = LAYOUT_ICONS[layout_type] or LAYOUT_ICONS[1] ---@type string
      local layout_subscript = SUBSCRIPT_DIGITS[layout_type] or SUBSCRIPT_DIGITS[1] ---@type string
      local flag0_text = " " .. layout_icon .. layout_subscript ---@type string
      local viewtype_icon = is_tree and ICON_FLAG_TREE or ICON_FLAG_LIST ---@type string
      local flag1_text = " " .. viewtype_icon .. "¹" ---@type string
      local flag2_text = "" ---@type string
      if is_tree then
        flag2_text = " " .. ICON_FLAG_FOLD_EMPTY .. "²"
      end
      local flag3_text = " " .. ICON_FLAG_FOLD_UNCHANGED .. "³" ---@type string
      local flag0_hln = hln_flag_layout ---@type string
      local flag1_hln = is_tree and hln_flag_on or hln_flag_off ---@type string
      local flag2_hln = foldempty and hln_flag_on or hln_flag_off ---@type string
      local flag3_hln = fold_unchanged and hln_flag_on or hln_flag_off ---@type string

      -- Build content
      -- Pad index to match total width, and page to match page_count width
      local total_width = #tostring(total) ---@type integer
      local page_count_width = #tostring(page_count) ---@type integer
      local index_str = string.format("%" .. total_width .. "d", global_index) ---@type string
      local page_str = string.format("%" .. page_count_width .. "d", page) ---@type string
      local commits_text = string.format("%s %s/%d", ICON_GIT, index_str, total) ---@type string
      local page_text = string.format(" │ 󰓩 %s/%d", page_str, page_count) ---@type string
      local flags_text = " │ " .. flag0_text .. flag1_text .. flag2_text .. flag3_text ---@type string
      local right_split = " " ---@type string

      local full_width = vim.api.nvim_strwidth(commits_text .. page_text .. flags_text) + 1 ---@type integer
      if width < full_width then
        -- Try without pagination if too narrow
        local no_page_width = vim.api.nvim_strwidth(commits_text .. flags_text) + 1 ---@type integer
        if width < no_page_width then
          -- Try without flags if still too narrow
          local min_width = vim.api.nvim_strwidth(commits_text) + 1 ---@type integer
          if width < min_width then
            return "", "", true
          end
          local text = commits_text .. right_split ---@type string
          local hl_text = txt(commits_text, hln_pink) .. txt(right_split, hln_split)
          return text, hl_text, true
        end
        -- Show commits + flags without pagination
        local text = commits_text .. flags_text .. right_split ---@type string
        local hl_text = txt(commits_text, hln_pink)
          .. txt(" │ ", hln_dim)
          .. btn(txt(flag0_text, flag0_hln), cb_layout)
          .. btn(txt(flag1_text, flag1_hln), cb_viewtype)
        if is_tree then
          hl_text = hl_text .. btn(txt(flag2_text, flag2_hln), cb_foldempty)
        end
        hl_text = hl_text .. btn(txt(flag3_text, flag3_hln), cb_fold_unchanged)
        hl_text = hl_text .. txt(right_split, hln_split)
        return text, hl_text, true
      end

      local text = commits_text .. page_text .. flags_text .. right_split ---@type string
      local hl_text = txt(commits_text, hln_pink)
        .. txt(page_text, hln_dim)
        .. txt(" │ ", hln_dim)
        .. btn(txt(flag0_text, flag0_hln), cb_layout)
        .. btn(txt(flag1_text, flag1_hln), cb_viewtype)
      if is_tree then
        hl_text = hl_text .. btn(txt(flag2_text, flag2_hln), cb_foldempty)
      end
      hl_text = hl_text .. btn(txt(flag3_text, flag3_hln), cb_fold_unchanged)
      hl_text = hl_text .. txt(right_split, hln_split)
      return text, hl_text, true
    end,
  }
  return component
end

----------------------------------------------------------------------------------------------------
-- Filter component
----------------------------------------------------------------------------------------------------

---Create filter display component for nvimbar (shows path_filter if set)
---@return era.m.nvimbar.IRawComponent
function M.filter_component()
  local pos = M.position ---@type string
  local hln_pink = pos .. "_sidebar_pink"
  local hln_dim = pos .. "_sidebar_dim"

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "diffview:commits_filter",
    atomic = true,
    render = function(_, remain_width)
      if remain_width < 10 then
        return "", "", true
      end

      -- Get state from current tab
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local state = commits_state.get(tabnr)
      local path_filter = state and state:get_path_filter() ---@type string|nil

      if not path_filter then
        -- No filter, don't show anything (tabtype component will show the badge)
        return "", "", true
      end

      -- Has filter: show file path with icon
      -- Check if it's a directory
      local is_dir = vim.fn.isdirectory(dot.path.join(dot.path.workspace() or "", path_filter)) == 1 ---@type boolean
      local filter_icon = is_dir and stl.icon.filetype.Folder or ICON_FILTER ---@type string

      -- Use relative path as display name
      local filter_name = path_filter ---@type string

      local filter_text = " " .. filter_icon .. " " .. filter_name ---@type string
      local display_width = vim.api.nvim_strwidth(filter_text) ---@type integer

      -- Truncate path from the left if too long (keep the rightmost part which is more informative)
      if display_width > remain_width then
        local prefix_width = vim.api.nvim_strwidth(" " .. filter_icon .. " ...") ---@type integer
        local max_name_len = remain_width - prefix_width ---@type integer
        if max_name_len > 3 then
          -- Truncate from left, keep the end
          local name_len = vim.api.nvim_strwidth(filter_name) ---@type integer
          if name_len > max_name_len then
            filter_name = "..." .. string.sub(filter_name, -(max_name_len - 3))
          end
          filter_text = " " .. filter_icon .. " " .. filter_name
        else
          -- Too narrow, just show icon
          filter_text = " " .. filter_icon
          return filter_text, txt(filter_text, hln_dim), true
        end
      end

      return filter_text, txt(" " .. filter_icon .. " ", hln_dim) .. txt(filter_name, hln_pink), true
    end,
  }
  return component
end

----------------------------------------------------------------------------------------------------
-- Tabline factory
----------------------------------------------------------------------------------------------------

---Create commits tabline nvimbar instance
---@return fun(): era.m.nvimbar.Nvimbar
function M.create_tabline()
  return function()
    local position = M.position
    local nvimbar ---@type era.m.nvimbar.Nvimbar
    local tabtype = stl.nvim.tab.TypeEnum.DIFFVIEW_COMMITS

    nvimbar = era.m.nvimbar.Nvimbar.new({
      name = "tabline_diffview_commits",
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
      :place("center", era.m.nvimbar.component.nvim.tabtype(position, ICON_GIT .. " "), 100)
      :place("center", M.filter_component(), 99)
      :place("right", era.m.nvimbar.component.nvim.tabs(position), 100)

    return nvimbar
  end
end

----------------------------------------------------------------------------------------------------
-- Registration
----------------------------------------------------------------------------------------------------

---Register nvimbar for DIFFVIEW_COMMITS tabtype (idempotent)
---@return nil
function M.register()
  era.m.tabline.register(stl.nvim.tab.TypeEnum.DIFFVIEW_COMMITS, M.create_tabline())
end

return M
