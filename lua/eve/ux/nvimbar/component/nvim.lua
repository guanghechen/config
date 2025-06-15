local btn = eve.nvim.btn
local txt = eve.nvim.txt

---@return integer
---@return integer
---@return string
local function calc_row_percentage()
  local total_lines = vim.fn.line("$")
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] ---@type integer
  local col = cursor[2] + 1 ---@type integer

  if row == 1 then
    return row, col, "top"
  elseif row == total_lines then
    return row, col, "bot"
  else
    local text = std.string.pad_start(tostring(math.floor(100 * row / total_lines)), 2, " ") .. "%" ---@type string
    return row, col, text
  end
end

---@class eve.ux.nvimbar.component.nvim
local M = {}

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.mode(position)
  local hln_text = position .. "_nvim_mode_text" ---@type string
  local hln_sep = position .. "_nvim_mode_sep" ---@type string

  local icon = " " .. eve.icon.app.Vim .. " " ---@type string

  ---@type eve.ux.nvimbar.IRawComponent
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

      text = text .. eve.icon.symbols.sep_right ---@type string
      hl_text = hl_text .. txt(eve.icon.symbols.sep_right, hln_sep) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.msg_changes(position)
  local hln_text = position .. "_nvim_msg_changes" ---@type string

  local last_text = "" ---@type string
  local last_timestamp = os.time() ---@type integer
  local timeout = 3 ---@type integer

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "nvim:msg_changes",
    atomic = true,
    render = function()
      local text = eve.status.msg_changes:snapshot() ---@type string
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

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.msg_command(position)
  local hln_text = position .. "_nvim_msg_command" ---@type string

  local last_text = "" ---@type string
  local last_timestamp = os.time() ---@type integer
  local timeout = 3 ---@type integer

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "nvim:msg_command",
    atomic = true,
    render = function()
      local text = eve.status.msg_command:snapshot() ---@type string
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

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.msg_lsp(position)
  local hln_text = position .. "_nvim_msg_lsp" ---@type string

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "nvim:msg_lsp",
    atomic = true,
    render = function()
      local text = eve.status.msg_lsp:snapshot() ---@type string
      if text == "" then
        return "", "", true
      end

      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.msg_mode(position)
  local hln_text = position .. "_nvim_msg_mode" ---@type string

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "nvim:msg_mode",
    atomic = true,
    render = function()
      local text = eve.status.msg_mode:snapshot() ---@type string
      if text == "" then
        return "", "", true
      end

      local hl_text = txt(text, hln_text) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.nr(position)
  local hln_text = position .. "_nvim_nr" ---@type string

  ---@type eve.ux.nvimbar.IRawComponent
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

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.pos(position)
  local hln_sep = position .. "_nvim_pos_sep" ---@type string
  local hln_text_anchor = position .. "_nvim_pos_text_anchor" ---@type string
  local hln_text_percentage = position .. "_nvim_pos_text_percentage" ---@type string

  local text_sep = eve.icon.symbols.sep_right ---@type string
  local hl_text_sep = txt(eve.icon.symbols.sep_right, hln_sep) ---@type string

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "win:pos",
    atomic = true,
    tight = true,
    will_change = function(context, prev_context)
      return prev_context == nil or context.winnr ~= prev_context.winnr or context.bufnr ~= prev_context.bufnr
    end,
    render = function()
      local row, col, percentage = calc_row_percentage() ---@type integer, integer, string
      local text_percentage = " " .. percentage ---@type string
      local text_anchor = " " .. tostring(row) .. "·" .. tostring(col) ---@type string

      local text = text_percentage .. text_sep .. text_anchor ---@type string
      local hl_text = txt(text_percentage, hln_text_percentage) .. hl_text_sep .. txt(text_anchor, hln_text_anchor) ---@type string
      return text, hl_text, true
    end,
  }
  return component
end

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.tabs(position)
  local hln_toggle = position .. "_nvim_tab_toggle" ---@type string
  local hln_tab_item = position .. "_nvim_tab_item" ---@type string
  local hln_tab_item_cur = position .. "_nvim_tab_item_cur" ---@type string

  local folded = false ---@type boolean
  local last_tab_cur = 0 ---@type integer
  local last_tab_count = 0 ---@type integer

  ---@type string
  local fn_active_tab = eve.G.register_anonymous_fn(function(tabid)
    vim.cmd(eve.command.definitions.tab.focus.uuid .. " " .. tostring(tabid))
  end) or ""

  ---@type string
  local fn_toggle_tabs_folded = eve.G.register_anonymous_fn(function()
    folded = not folded
    eve.status.dirtier_tabline:mark_dirty()
  end) or ""

  ---@type eve.ux.nvimbar.IRawComponent
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
