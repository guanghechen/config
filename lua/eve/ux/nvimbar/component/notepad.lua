local btn = eve.nvim.btn
local txt = eve.nvim.txt
local decode_btn_args = eve.nvim.decode_btn_args

---@type string
local fn_switch_notepad = eve.G.register_anonymous_fn(function(encoded)
  local args = decode_btn_args(tostring(encoded)) ---@type integer[]
  local index = args[1] ---@type integer|nil
  if index ~= nil then
    eve.notepad.focus_index(index)
  end
end) or "eve.G.noop"

---@type string
local fn_add_notepad = eve.G.register_anonymous_fn(function()
  vim.cmd(eve.command.definitions.notepad.create.uuid)
end) or "eve.G.noop"

---@class eve.ux.nvimbar.component.notepad
local M = {}

---@param position                      eve.ux.nvimbar.PositionEnum
---@return eve.ux.nvimbar.IRawComponent
function M.items(position)
  local hln_button = position .. "_notepad_button" ---@type string
  local hln_name = position .. "_notepad_name" ---@type string
  local hln_index = position .. "_notepad_index" ---@type string
  local hln_sep_left = position .. "_notepad_sep_left" ---@type string
  local hln_sep_middle = position .. "_notepad_sep_middle" ---@type string
  local hln_sep_right = position .. "_notepad_sep_right" ---@type string

  local hln_name_active = position .. "_notepadc_name" ---@type string
  local hln_index_active = position .. "_notepadc_index" ---@type string
  local hln_sep_left_active = position .. "_notepadc_sep_left" ---@type string
  local hln_sep_middle_active = position .. "_notepadc_sep_middle" ---@type string
  local hln_sep_right_active = position .. "_notepadc_sep_right" ---@type string

  local text_sep_left = eve.icon.symbols.sep_left ---@type string
  local text_sep_middle = " | " ---@type string
  local text_sep_right = eve.icon.symbols.sep_right ---@type string

  ---@param item                        eve.builtin.notepad.INotepadItem
  ---@return string
  local function format_name(item)
    local name = vim.trim(item.name or "") ---@type string
    if #name == 0 then
      name = eve.setting.BUF_UNTITLED
    end
    if #name > 12 then
      name = name:sub(1, 9) .. "..."
    end
    return name
  end

  ---@param item                        eve.builtin.notepad.INotepadItem
  ---@return string
  ---@return string
  local function render_item(item, index)
    local name = format_name(item) ---@type string
    local text_name = name .. " " ---@type string
    local text_index = " " .. tostring(index) ---@type string
    local text = text_sep_left .. text_name .. text_index .. text_sep_right ---@type string
    local hl_text = txt(text_sep_left, hln_sep_left)
      .. txt(text_name, hln_name)
      .. txt(text_index, hln_index)
      .. txt(text_sep_right, hln_sep_right)
    return text, btn(hl_text, fn_switch_notepad, { index })
  end

  ---@param item                        eve.builtin.notepad.INotepadItem
  ---@param index                       integer
  ---@return string
  ---@return string
  local function render_item_active(item, index)
    local name = format_name(item) ---@type string
    local text_name = name .. " " ---@type string
    local text_index = tostring(index) ---@type string
    local text = text_sep_left .. text_name .. text_sep_middle .. text_index .. text_sep_right ---@type string
    local hl_text = txt(text_sep_left, hln_sep_left_active)
      .. txt(text_name, hln_name_active)
      .. txt(text_sep_middle, hln_sep_middle_active)
      .. txt(text_index, hln_index_active)
      .. txt(text_sep_right, hln_sep_right_active)
    return text, btn(hl_text, fn_switch_notepad, { index })
  end

  ---@return string
  ---@return string
  local function render_add_button()
    local text = " +" ---@type string
    local hl_text = txt(text, hln_button)
    return text, btn(hl_text, fn_add_notepad)
  end

  ---@type eve.ux.nvimbar.IRawComponent
  local component = {
    name = "notepad:items",
    atomic = false,
    render = function(_, remain_width)
      eve.notepad.load()

      local text = " " ---@type string
      local hl_text = " " ---@type string

      local _, active_uuid = eve.notepad.current() ---@type integer, string|nil
      for item, index in eve.notepad:iterator() do
        local renderer = item.uuid == active_uuid and render_item_active or render_item
        local t, ht = renderer(item, index)
        local w = vim.api.nvim_strwidth(t) ---@type integer
        if remain_width < w then
          break
        end
        text = text .. t .. " "
        hl_text = hl_text .. ht .. " "
        remain_width = remain_width - w
      end

      local add_text, add_hl = render_add_button()
      local add_width = vim.api.nvim_strwidth(add_text) ---@type integer
      if remain_width >= add_width then
        text = text .. add_text .. " "
        hl_text = hl_text .. add_hl .. " "
      end

      if text == " " or text == "  " then
        return "", "", false
      end
      return text, hl_text, true
    end,
  }

  return component
end

return M
