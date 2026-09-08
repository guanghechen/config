---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.nvimbar.component.nvim" ---@type string

local btn = stl.nvim.fn.btn
local txt = stl.nvim.fn.txt

---@type string[]
local location_levels = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }

local MIN_TRANSIENT_WIDTH = 5
local location_step = 100 / (#location_levels - 1) ---@type number

---@param text                          string
---@param max_width                     integer
---@return string
local function truncate_middle(text, max_width)
  if vim.api.nvim_strwidth(text) <= max_width then
    return text
  end
  if max_width <= 1 then
    return "…"
  end

  local chars = vim.fn.strchars(text) ---@type integer
  local content_width = max_width - 1
  local left_max_width = math.ceil(content_width / 2)
  local right_max_width = content_width - left_max_width

  local left = "" ---@type string
  local left_width = 0 ---@type integer
  local left_chars = 0 ---@type integer
  while left_chars < chars do
    local char = vim.fn.strcharpart(text, left_chars, 1) ---@type string
    local width = vim.api.nvim_strwidth(char) ---@type integer
    if left_width + width > left_max_width then
      break
    end
    left = left .. char
    left_width = left_width + width
    left_chars = left_chars + 1
  end

  local right = "" ---@type string
  local right_width = 0 ---@type integer
  local right_chars = 0 ---@type integer
  while left_chars + right_chars < chars do
    local char = vim.fn.strcharpart(text, chars - right_chars - 1, 1) ---@type string
    local width = vim.api.nvim_strwidth(char) ---@type integer
    if right_width + width > right_max_width then
      break
    end
    right = char .. right
    right_width = right_width + width
    right_chars = right_chars + 1
  end

  return left .. "…" .. right
end

---@return integer
---@return integer
---@return integer
---@return string
---@return integer
local function calc_cursor_location(context)
  local cursor = context.cursor ---@type integer[]
  local row = cursor[1] ---@type integer
  local col = cursor[2] + 1 ---@type integer
  local total_lines = math.max(context.line_count, 1) ---@type integer
  local denom = math.max(total_lines - 1, 1) ---@type integer
  local percent = math.floor(math.max(total_lines - row, 0) * 100 / denom) ---@type integer

  local icon_index = math.floor((percent / location_step) + 0.5) + 1 ---@type integer
  if icon_index > #location_levels then
    icon_index = #location_levels
  end

  local location_icon = location_levels[icon_index] ---@type string
  return row, col, percent, location_icon, icon_index
end

---@class era.m.nvimbar.component.nvim
local M = {}

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.mode(position)
  local hln_text = position .. "_nvim_mode_text" ---@type string
  local hln_sep = position .. "_nvim_mode_sep" ---@type string

  local icon = " " .. stl.icon.app.Vim .. " " ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:mode",

    tight = true,
    will_change = function(context, prev_context)
      return context.mode ~= prev_context.mode
    end,
    refresh = function(context)
      local text = icon .. context.mode_name ---@type string
      local hl_text = txt(text, hln_text) ---@type string

      text = text .. stl.icon.symbols.sep_right ---@type string
      hl_text = hl_text .. txt(stl.icon.symbols.sep_right, hln_sep) ---@type string
      return { text = text, hltext = hl_text }
    end,
  }
  return component
end

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.msg_transient(position)
  local hln_text = position .. "_nvim_msg_transient" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:msg_transient",

    will_change = function(_, _, snapshot)
      return dot.state.status.msg_transient:snapshot() ~= snapshot
    end,
    refresh = function()
      return dot.state.status.msg_transient:snapshot()
    end,
    render = function(text, _, remain_width)
      if text == "" or remain_width < MIN_TRANSIENT_WIDTH then
        return "", ""
      end

      text = truncate_middle(text, remain_width)
      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text
    end,
  }
  return component
end

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.msg_command(position)
  local hln_text = position .. "_nvim_msg_command" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:msg_command",

    refresh = function()
      local text = dot.state.status.msg_command:snapshot() ---@type string
      if text == "" then
        return { text = "", hltext = "" }
      end

      local hl_text = txt(text, hln_text) ---@type string
      return { text = text, hltext = hl_text }
    end,
  }
  return component
end

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.msg_lsp(position)
  local hln_text = position .. "_nvim_msg_lsp" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:msg_lsp",

    refresh = function()
      local text = dot.state.status.msg_lsp:snapshot() ---@type string
      if text == "" then
        return { text = "", hltext = "" }
      end

      local hl_text = txt(text, hln_text) ---@type string
      return { text = text, hltext = hl_text }
    end,
  }
  return component
end

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.msg_mode(position)
  local hln_text = position .. "_nvim_msg_mode" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:msg_mode",

    refresh = function()
      local text = dot.state.status.msg_mode:snapshot() ---@type string
      if text == "" then
        return { text = "", hltext = "" }
      end

      local hl_text = txt(text, hln_text) ---@type string
      return { text = text, hltext = hl_text }
    end,
  }
  return component
end

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.search_count(position)
  local hln_text = position .. "_nvim_search_count" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:search_count",

    condition = function(context)
      return dot.state.status.get_search(context.winnr) ~= nil
    end,
    refresh = function(context)
      local pattern, count = dot.state.status.get_search(context.winnr) ---@type string|nil, string|nil
      if pattern == nil then
        return nil
      end

      local text = string.format(" %s %s", stl.icon.ui.Search, pattern) ---@type string
      if count ~= nil then
        text = string.format("%s %s", text, count)
      end
      return text
    end,
    render = function(text, _, remain_width)
      text = truncate_middle(text, remain_width)
      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text
    end,
  }
  return component
end

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.nr(position)
  local hln_sep = position .. "_nvim_nr_sep" ---@type string
  local hln_text = position .. "_nvim_nr_text" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:nr",

    tight = true,
    will_change = function(context, prev_context)
      return context.winnr ~= prev_context.winnr or context.bufnr ~= prev_context.bufnr
    end,
    refresh = function(context)
      local winnr = context.winnr ---@type integer
      local bufnr = context.bufnr ---@type integer
      local content = string.format("%d:%d ", winnr, bufnr) ---@type string
      local text = stl.icon.symbols.sep_left .. content ---@type string
      local hl_text = txt(stl.icon.symbols.sep_left, hln_sep) .. txt(content, hln_text) ---@type string
      return { text = text, hltext = hl_text }
    end,
  }
  return component
end

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.pid(position)
  local hln_text = position .. "_nvim_pid" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:pid",

    refresh = function(context)
      local bufnr = context.bufnr ---@type integer
      local pid = vim.b[bufnr].terminal_job_pid ---@type integer|nil
      if pid == nil or pid <= 0 then
        return { text = "", hltext = "" }
      end

      local text = string.format("%s %d", "", pid) ---@type string
      local hl_text = txt(text, hln_text) ---@type string
      return { text = text, hltext = hl_text }
    end,
  }
  return component
end

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.pos(position)
  local hln_sep = position .. "_nvim_pos_sep" ---@type string
  local hln_text = position .. "_nvim_pos_text" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:pos",

    tight = true,
    will_change = function(context, prev_context)
      return context.cursor[1] ~= prev_context.cursor[1]
        or context.cursor[2] ~= prev_context.cursor[2]
        or context.line_count ~= prev_context.line_count
    end,
    refresh = function(context)
      local row, col, _, location_icon, bar_index = calc_cursor_location(context) ---@type integer, integer, integer, string, integer
      local hln_bar = position .. "_nvim_pos_bar_" .. tostring(bar_index) ---@type string
      local prefix = string.format("%s %3d·%-2d ", stl.icon.ui.Location, row, col) ---@type string
      local bar = location_icon ---@type string
      local text = stl.icon.symbols.sep_left .. prefix .. bar ---@type string
      local hl_text = txt(stl.icon.symbols.sep_left, hln_sep) .. txt(prefix, hln_text) .. txt(bar, hln_bar) ---@type string
      return { text = text, hltext = hl_text }
    end,
  }
  return component
end

---@param position                      stl.t.NvimbarPositionEnum
---@param icon                          ?string
---@return era.m.nvimbar.IRawComponent
function M.tabtype(position, icon)
  local hln_text = position .. "_nvim_tabtype_text" ---@type string
  local hln_sep = position .. "_nvim_tabtype_sep" ---@type string

  icon = icon or "󰓩 " ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:tabtype",

    tight = false,
    will_change = function(context, _, snapshot)
      return vim.t[context.tabnr].tabtype ~= snapshot.tabtype
    end,
    refresh = function(context)
      local tabnr = context.tabnr ---@type integer
      local tabtype = vim.t[tabnr].tabtype ---@type stl.e.TabTypeEnum|nil

      -- Don't render for normal tabs (tabtype is nil or "normal")
      if tabtype == nil or tabtype == stl.e.TabTypeEnum.NORMAL then
        return { text = "", hltext = "", tabtype = tabtype }
      end

      local content = icon .. tabtype ---@type string
      local text = stl.icon.symbols.sep_left .. content .. stl.icon.symbols.sep_right ---@type string

      ---@type string
      local hl_text = txt(stl.icon.symbols.sep_left, hln_sep)
        .. txt(content, hln_text)
        .. txt(stl.icon.symbols.sep_right, hln_sep)
      return { text = text, hltext = hl_text, tabtype = tabtype }
    end,
  }
  return component
end

---@param position                      stl.t.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.tabs(position)
  local hln_toggle = position .. "_nvim_tab_toggle" ---@type string
  local hln_tab_item = position .. "_nvim_tab_item" ---@type string
  local hln_tab_item_cur = position .. "_nvim_tab_item_cur" ---@type string

  local folded = false ---@type boolean

  ---@type string
  local fn_active_tab = dot.G.register_anonymous_fn(function(tabid)
    dot.command.definitions.tab.focus:execute(tostring(tabid))
  end) or ""

  ---@type string
  local fn_toggle_tabs_folded = dot.G.register_anonymous_fn(function()
    folded = not folded
    dot.state.status.dirtier_tabline:mark_dirty()
  end) or ""

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:tabs",

    will_change = function(context, prev_context, snapshot)
      return context.tabnr ~= prev_context.tabnr
        or folded ~= snapshot.folded
        or not vim.deep_equal(vim.api.nvim_list_tabpages(), snapshot.tabnrs)
    end,
    refresh = function(context)
      local last_tab_cur = vim.api.nvim_tabpage_get_number(context.tabnr)
      local tabnrs = vim.api.nvim_list_tabpages()
      local last_tab_count = #tabnrs
      if last_tab_count <= 1 then
        return { text = "", hltext = "", tabnrs = tabnrs, folded = folded }
      end

      if folded then
        local text = " 󰅁 "
        local hl_text = txt(text, hln_toggle)
        hl_text = btn(hl_text, fn_toggle_tabs_folded)
        return { text = text, hltext = hl_text, tabnrs = tabnrs, folded = folded }
      end

      local text = " 󰅂 " ---@type string
      local hl_text = txt(text, hln_toggle)
      hl_text = btn(hl_text, fn_toggle_tabs_folded)

      for tabid = 1, last_tab_count, 1 do
        local hlname = last_tab_cur == tabid and hln_tab_item_cur or hln_tab_item
        local text_btn = " " .. tabid .. " "
        local hl_text_btn = txt(text_btn, hlname)

        text = text .. text_btn
        hl_text = hl_text .. btn(hl_text_btn, fn_active_tab, tabnrs[tabid])
      end
      return { text = text, hltext = hl_text, tabnrs = tabnrs, folded = folded }
    end,
  }
  return component
end

return M
