local btn = ark.nvim.btn
local txt = ark.nvim.txt

---@return integer
---@return integer
local function calc_cursor_pos()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
  local row = cursor[1] ---@type integer
  local col = cursor[2] + 1 ---@type integer
  return row, col
end

---@return string
local function calc_location()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local total_lines = vim.fn.line("$") ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
  local row = cursor[1] ---@type integer
  if row == 1 then
    return "top"
  elseif row == total_lines then
    return "bot"
  else
    return ark.string.pad_start(tostring(math.floor(100 * row / total_lines)), 2, " ") .. "%"
  end
end

---@class dot.module.nvimbar.component.nvim
local M = {}

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.mode(position)
  local hln_text = position .. "_nvim_mode_text" ---@type string
  local hln_sep = position .. "_nvim_mode_sep" ---@type string

  local icon = " " .. dot.icon.app.Vim .. " " ---@type string

  ---@type dot.module.nvimbar.IRawComponent
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

      text = text .. dot.icon.symbols.sep_right ---@type string
      hl_text = hl_text .. txt(dot.icon.symbols.sep_right, hln_sep) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.msg_changes(position)
  local hln_text = position .. "_nvim_msg_changes" ---@type string

  local last_text = "" ---@type string
  local last_timestamp = os.time() ---@type integer
  local timeout = 3 ---@type integer

  ---@type dot.module.nvimbar.IRawComponent
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

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.msg_command(position)
  local hln_text = position .. "_nvim_msg_command" ---@type string

  local last_text = "" ---@type string
  local last_timestamp = os.time() ---@type integer
  local timeout = 3 ---@type integer

  ---@type dot.module.nvimbar.IRawComponent
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

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.msg_lsp(position)
  local hln_text = position .. "_nvim_msg_lsp" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
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

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.msg_mode(position)
  local hln_text = position .. "_nvim_msg_mode" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
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

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.nr(position)
  local hln_text = position .. "_nvim_nr" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "nvim:nr",
    atomic = true,
    render = function(context)
      local winnr = context.winnr ---@type integer
      local bufnr = context.bufnr ---@type integer
      local text = string.format("%s %d:%d", "", winnr, bufnr) ---@type string
      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.pid(position)
  local hln_text = position .. "_nvim_pid" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
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

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.pos(position)
  local hln_sep = position .. "_nvim_pos_sep" ---@type string
  local hln_text = position .. "_nvim_pos_text" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "nvim:pos",
    atomic = true,
    tight = true,
    render = function()
      local row, col = calc_cursor_pos() ---@type integer, integer
      local location = calc_location() ---@type string
      local content = dot.icon.ui.Location .. " " .. tostring(row) .. "·" .. tostring(col) .. " " .. location .. " " ---@type string
      local text = dot.icon.symbols.sep_left .. content ---@type string
      local hl_text = txt(dot.icon.symbols.sep_left, hln_sep) .. txt(content, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.pos_primary(position)
  local hln_sep = position .. "_nvim_pos_primary_sep" ---@type string
  local hln_text = position .. "_nvim_pos_primary_text" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "nvim:pos_primary",
    atomic = true,
    tight = true,
    render = function()
      local row, col = calc_cursor_pos() ---@type integer, integer
      local location = calc_location() ---@type string
      local text = " " .. dot.icon.ui.Location .. " " .. location .. " " .. tostring(row) .. "·" .. tostring(col) .. " " .. dot.icon.symbols.sep_right ---@type string
      local hl_text = txt(" " .. dot.icon.ui.Location .. " " .. location .. " " .. tostring(row) .. "·" .. tostring(col) .. " ", hln_text) .. txt(dot.icon.symbols.sep_right, hln_sep) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
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

  ---@type dot.module.nvimbar.IRawComponent
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
