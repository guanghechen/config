local btn = stl.nvim.fn.btn
local txt = stl.nvim.fn.txt

---@type string[]
local location_levels = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }

local location_step = 100 / (#location_levels - 1) ---@type number

---@return integer
---@return integer
---@return integer
---@return string
---@return integer
local function calc_cursor_location()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
  local row = cursor[1] ---@type integer
  local col = cursor[2] + 1 ---@type integer
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local total_lines = math.max(vim.api.nvim_buf_line_count(bufnr), 1) ---@type integer
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

---@param position                      stl.e.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.mode(position)
  local hln_text = position .. "_nvim_mode_text" ---@type string
  local hln_sep = position .. "_nvim_mode_sep" ---@type string

  local icon = " " .. stl.icon.app.Vim .. " " ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:mode",
    atomic = true,
    tight = true,
    will_change = function(context, prev_context)
      return prev_context == nil or context.mode ~= prev_context.mode
    end,
    render = function(context)
      local text = icon .. context.mode_name ---@type string
      local hl_text = txt(text, hln_text) ---@type string

      text = text .. stl.icon.symbols.sep_right ---@type string
      hl_text = hl_text .. txt(stl.icon.symbols.sep_right, hln_sep) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      stl.e.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.msg_changes(position)
  local hln_text = position .. "_nvim_msg_changes" ---@type string

  local last_text = "" ---@type string
  local last_timestamp = os.time() ---@type integer
  local timeout = 3 ---@type integer

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:msg_changes",
    atomic = true,
    render = function()
      local text = dot.state.status.msg_changes:snapshot() ---@type string
      if text == "" then
        return "", "", true
      end

      local timestamp = os.time() ---@type integer
      if last_text == text then
        if last_timestamp + timeout < timestamp then
          return "", "", true
        end
      else
        last_text = text
        last_timestamp = timestamp
      end

      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      stl.e.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.msg_command(position)
  local hln_text = position .. "_nvim_msg_command" ---@type string

  local last_text = "" ---@type string
  local last_timestamp = os.time() ---@type integer
  local timeout = 3 ---@type integer

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:msg_command",
    atomic = true,
    render = function()
      local text = dot.state.status.msg_command:snapshot() ---@type string
      if text == "" then
        return "", "", true
      end

      local timestamp = os.time() ---@type integer
      if last_text == text then
        if last_timestamp + timeout < timestamp then
          return "", "", true
        end
      else
        last_text = text
        last_timestamp = timestamp
      end

      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      stl.e.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.msg_lsp(position)
  local hln_text = position .. "_nvim_msg_lsp" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:msg_lsp",
    atomic = true,
    render = function()
      local text = dot.state.status.msg_lsp:snapshot() ---@type string
      if text == "" then
        return "", "", true
      end

      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      stl.e.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.msg_mode(position)
  local hln_text = position .. "_nvim_msg_mode" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:msg_mode",
    atomic = true,
    render = function()
      local text = dot.state.status.msg_mode:snapshot() ---@type string
      if text == "" then
        return "", "", true
      end

      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      stl.e.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.nr(position)
  local hln_sep = position .. "_nvim_nr_sep" ---@type string
  local hln_text = position .. "_nvim_nr_text" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:nr",
    atomic = true,
    tight = true,
    render = function(context)
      local winnr = context.winnr ---@type integer
      local bufnr = context.bufnr ---@type integer
      local content = string.format("%d:%d ", winnr, bufnr) ---@type string
      local text = stl.icon.symbols.sep_left .. content ---@type string
      local hl_text = txt(stl.icon.symbols.sep_left, hln_sep) .. txt(content, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      stl.e.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.pid(position)
  local hln_text = position .. "_nvim_pid" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:pid",
    atomic = true,
    render = function(context)
      local bufnr = context.bufnr ---@type integer
      local pid = vim.b[bufnr].terminal_job_pid ---@type integer|nil
      if pid == nil or pid <= 0 then
        return "", "", true
      end

      local text = string.format("%s %d", "", pid) ---@type string
      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      stl.e.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.pos(position)
  local hln_sep = position .. "_nvim_pos_sep" ---@type string
  local hln_text = position .. "_nvim_pos_text" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:pos",
    atomic = true,
    tight = true,
    render = function()
      local row, col, _, location_icon, bar_index = calc_cursor_location() ---@type integer, integer, integer, string, integer
      local hln_bar = position .. "_nvim_pos_bar_" .. tostring(bar_index) ---@type string
      local prefix = string.format("%s %3d·%-2d ", stl.icon.ui.Location, row, col) ---@type string
      local bar = location_icon ---@type string
      local text = stl.icon.symbols.sep_left .. prefix .. bar ---@type string
      local hl_text = txt(stl.icon.symbols.sep_left, hln_sep) .. txt(prefix, hln_text) .. txt(bar, hln_bar) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      stl.e.NvimbarPositionEnum
---@param icon                          ?string
---@return era.m.nvimbar.IRawComponent
function M.tabtype(position, icon)
  local hln_text = position .. "_nvim_tabtype_text" ---@type string
  local hln_sep = position .. "_nvim_tabtype_sep" ---@type string

  icon = icon or "󰓩 " ---@type string
  local last_tabtype = "" ---@type string

  ---@type era.m.nvimbar.IRawComponent
  local component = {
    name = "nvim:tabtype",
    atomic = true,
    tight = false,
    will_change = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local tabtype = vim.t[tabnr].tabtype or "" ---@type string
      local changed = last_tabtype ~= tabtype ---@type boolean
      last_tabtype = tabtype
      return changed
    end,
    render = function()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local tabtype = vim.t[tabnr].tabtype ---@type string|nil

      -- Don't render for normal tabs (tabtype is nil or "normal")
      if tabtype == nil or tabtype == stl.nvim.tab.TypeEnum.NORMAL then
        return "", "", true
      end

      local content = icon .. tabtype ---@type string
      local text = stl.icon.symbols.sep_left .. content .. stl.icon.symbols.sep_right ---@type string

      ---@type string
      local hl_text = txt(stl.icon.symbols.sep_left, hln_sep)
        .. txt(content, hln_text)
        .. txt(stl.icon.symbols.sep_right, hln_sep)
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      stl.e.NvimbarPositionEnum
---@return era.m.nvimbar.IRawComponent
function M.tabs(position)
  local hln_toggle = position .. "_nvim_tab_toggle" ---@type string
  local hln_tab_item = position .. "_nvim_tab_item" ---@type string
  local hln_tab_item_cur = position .. "_nvim_tab_item_cur" ---@type string

  local folded = false ---@type boolean
  local last_tab_cur = 0 ---@type integer
  local last_tab_count = 0 ---@type integer

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
    atomic = true,
    will_change = function()
      local tab_cur = vim.fn.tabpagenr() ---@type integer
      local tab_count = vim.fn.tabpagenr("$") ---@type integer
      local changed = last_tab_cur ~= tab_cur or last_tab_count ~= tab_count ---@type boolean
      last_tab_cur = tab_cur
      last_tab_count = tab_count
      return changed
    end,
    render = function()
      if last_tab_count <= 1 then
        return "", "", true
      end

      if folded then
        local text = " 󰅁 "
        local hl_text = txt(text, hln_toggle)
        hl_text = btn(hl_text, fn_toggle_tabs_folded)
        return text, hl_text, true
      end

      local text = " 󰅂 " ---@type string
      local hl_text = txt(text, hln_toggle)
      hl_text = btn(hl_text, fn_toggle_tabs_folded)

      local tabnrs = vim.api.nvim_list_tabpages() ---@type integer[]
      for tabid = 1, last_tab_count, 1 do
        local hlname = last_tab_cur == tabid and hln_tab_item_cur or hln_tab_item
        local text_btn = " " .. tabid .. " "
        local hl_text_btn = txt(text_btn, hlname)

        text = text .. text_btn
        hl_text = hl_text .. btn(hl_text_btn, fn_active_tab, tabnrs[tabid])
      end
      return text, hl_text, true
    end,
  }
  return component
end

return M
