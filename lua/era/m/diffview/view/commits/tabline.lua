---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.commits.tabline" ---@type string

local config = require("era.m.diffview.config")
local commits_state = require("era.m.diffview.view.commits.state")
local commits_view = require("era.m.diffview.view.commits.view")

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
local ICON_FLAG_FOLD = stl.icon.symbols.flag_fold ---@type string

----------------------------------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------------------------------

---Use the commits pane when present; SBS-only layouts inherit the left diff pane width.
---@param tabnr                         integer
---@return integer|nil
local function get_pane_winnr(tabnr)
  local lyt = commits_view.get_layout(tabnr)
  if not lyt then
    return nil
  end

  local winnr = lyt.commits_winnr ---@type integer|nil
  if not winnr or not vim.api.nvim_win_is_valid(winnr) then
    winnr = lyt.sbs_left_winnr
  end
  if not winnr or not vim.api.nvim_win_is_valid(winnr) or stl.nvim.win.is_float(winnr) then
    return nil
  end

  return winnr
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

---Get callback path for the default diff fold toggle.
---@return string
local function get_cb_default_folds()
  return get_or_create_callback("commits_default_folds", function()
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local state = commits_state.get(tabnr)
    local lyt = commits_view.get_layout(tabnr)
    if not state or not lyt then
      return
    end
    require("era.m.diffview.view.commits.action").toggle_default_folds({ layout = lyt, state = state })
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

    local binding = require("era.m.diffview.view.binding")
    local action = require("era.m.diffview.view.commits.action")
    action.cycle_layout(binding.commits({ layout = lyt, state = state }))
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
  local cb_default_folds = get_cb_default_folds()

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "diffview:commits_status",

    refresh = function(context)
      -- Get state from current tab
      local tabnr = context.tabnr ---@type integer
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
      local default_folds = dot.context.diffview.flag_fold_unchanges:snapshot() ---@type boolean
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
      local flag3_text = " " .. ICON_FLAG_FOLD .. "³" ---@type string
      local flag0_hln = hln_flag_layout ---@type string
      local flag1_hln = is_tree and hln_flag_on or hln_flag_off ---@type string
      local flag2_hln = foldempty and hln_flag_on or hln_flag_off ---@type string
      local flag3_hln = default_folds and hln_flag_on or hln_flag_off ---@type string

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

      local flags_hltext = txt(" │ ", hln_dim)
        .. btn(txt(flag0_text, flag0_hln), cb_layout)
        .. btn(txt(flag1_text, flag1_hln), cb_viewtype)
      if is_tree then
        flags_hltext = flags_hltext .. btn(txt(flag2_text, flag2_hln), cb_foldempty)
      end
      flags_hltext = flags_hltext .. btn(txt(flag3_text, flag3_hln), cb_default_folds)
      local split = txt(right_split, hln_split)
      local commits_hltext = txt(commits_text, hln_pink)
      return {
        winnr = get_pane_winnr(tabnr),
        variants = {
          {
            text = commits_text .. page_text .. flags_text .. right_split,
            hltext = commits_hltext .. txt(page_text, hln_dim) .. flags_hltext .. split,
          },
          { text = commits_text .. flags_text .. right_split, hltext = commits_hltext .. flags_hltext .. split },
          { text = commits_text .. right_split, hltext = commits_hltext .. split },
        },
      }
    end,
    render = function(snapshot, context, remain_width)
      local winnr = snapshot.winnr
      if
        winnr == nil
        or not vim.api.nvim_win_is_valid(winnr)
        or vim.api.nvim_win_get_tabpage(winnr) ~= context.tabnr
      then
        return "", ""
      end
      local width = math.min(remain_width, vim.api.nvim_win_get_width(winnr))
      for _, variant in ipairs(snapshot.variants) do
        if vim.api.nvim_strwidth(variant.text) <= width then
          return variant.text, variant.hltext
        end
      end
      return "", ""
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

    refresh = function(context)
      local state = commits_state.get(context.tabnr)
      local path = state and state:get_path_filter()
      if not path then
        return nil
      end
      local stat = vim.uv.fs_stat(dot.path.join(dot.path.workspace() or "", path))
      return { name = path, icon = stat and stat.type == "directory" and stl.icon.filetype.Folder or ICON_FILTER }
    end,
    render = function(snapshot, _, remain_width)
      if remain_width < 10 then
        return "", ""
      end
      local name, icon = snapshot.name, snapshot.icon
      local prefix = " " .. icon .. " "
      if vim.api.nvim_strwidth(prefix .. name) > remain_width then
        local available = remain_width - vim.api.nvim_strwidth(prefix .. "...")
        if available <= 0 then
          return " " .. icon, txt(" " .. icon, hln_dim)
        end
        local start = math.max(0, vim.fn.strchars(name) - available)
        while vim.api.nvim_strwidth(vim.fn.strcharpart(name, start)) > available do
          start = start + 1
        end
        name = "..." .. vim.fn.strcharpart(name, start)
      end
      return prefix .. name, txt(prefix, hln_dim) .. txt(name, hln_pink)
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
    local c = era.m.nvimbar.component
    local position = M.position
    local nvimbar ---@type era.m.nvimbar.Nvimbar
    local tabtype = stl.e.TabTypeEnum.DIFFVIEW_COMMITS

    nvimbar = era.m.nvimbar.Nvimbar.new({
      name = "tabline_diffview_commits",
      comp_sep = "",
      comp_sep_hlname = position .. "_bg",
      comp_sep_hlname_active = position .. "_bg",
      get_max_width = function()
        return vim.o.columns
      end,
      is_active = stl.fn.falsy,
      on_fulfilled = function(result)
        if vim.t.tabtype == tabtype then
          vim.o.tabline = result
        end
      end,
    })

    nvimbar
      :place({
        position = "left",
        priority = 95,
        component = c.lazy(M.status_component),
      })
      :place({
        position = "center",
        priority = 100,
        component = c.lazy(function()
          return c.nvim.tabtype(position, ICON_GIT .. " ")
        end),
      })
      :place({
        position = "center",
        priority = 99,
        component = c.lazy(M.filter_component),
      })
      :place({
        position = "right",
        priority = 100,
        component = c.lazy(function()
          return c.nvim.tabs(position)
        end),
      })

    return nvimbar
  end
end

----------------------------------------------------------------------------------------------------
-- Registration
----------------------------------------------------------------------------------------------------

---Register nvimbar for DIFFVIEW_COMMITS tabtype (idempotent)
---@return nil
function M.register()
  era.dressing.tabline.register(stl.e.TabTypeEnum.DIFFVIEW_COMMITS, M.create_tabline())
end

return M
