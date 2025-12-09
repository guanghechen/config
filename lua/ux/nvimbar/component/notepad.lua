local btn = std.nvim.btn
local txt = std.nvim.txt
local decode_btn_args = std.nvim.decode_btn_args

---@type string
local fn_switch_notepad = eve.G.register_anonymous_fn(function(encoded)
  local args = decode_btn_args(tostring(encoded)) ---@type integer[]
  local index = args[1] ---@type integer|nil
  if index ~= nil then
    local cmd_key = "focus_" .. tostring(index)
    local cmd = eve.command.definitions.notepad[cmd_key]
    if cmd ~= nil then
      vim.cmd(cmd.uuid)
    end
  end
end) or "eve.G.noop"

---@type string
local fn_add_notepad = eve.G.register_anonymous_fn(function()
  vim.cmd(eve.command.definitions.notepad.create.uuid)
end) or "eve.G.noop"

---@type string
local fn_focus_prev_notepad = eve.G.register_anonymous_fn(function()
  vim.cmd(eve.command.definitions.notepad.focus_left.uuid)
end) or "eve.G.noop"

---@type string
local fn_focus_next_notepad = eve.G.register_anonymous_fn(function()
  vim.cmd(eve.command.definitions.notepad.focus_right.uuid)
end) or "eve.G.noop"

---@type table<string, fun(): nil>
local fn_switch_source_registry = {}

---@class ux.nvimbar.component.notepad
local M = {}

---@param position                      ux.nvimbar.PositionEnum
---@param notepad                       ux.widget.Notepad
---@return ux.nvimbar.IRawComponent
function M.items(position, notepad)
  local hln_button = position .. "_notepad_button" ---@type string
  local hln_name = position .. "_notepad_name" ---@type string
  local hln_sep_left = position .. "_notepad_sep_left" ---@type string
  local hln_sep_right = position .. "_notepad_sep_right" ---@type string

  local hln_name_active = position .. "_notepadc_name" ---@type string
  local hln_index_active = position .. "_notepadc_index" ---@type string
  local hln_sep_left_active = position .. "_notepadc_sep_left" ---@type string
  local hln_sep_right_active = position .. "_notepadc_sep_right" ---@type string

  local text_sep_left = dot.icon.symbols.sep_left ---@type string
  local text_sep_right = dot.icon.symbols.sep_right ---@type string

  local icon_arrow_left = dot.icon.ui.Left ---@type string
  local icon_arrow_right = dot.icon.ui.Right ---@type string
  local arrow_reserved_width = vim.api.nvim_strwidth(" " .. icon_arrow_left .. "  99 ") ---@type integer
  local hln_arrow = std.nvim.make_bg_transparency(hln_button) ---@type string

  ---@param item                        std.t.INotepadItemMeta
  ---@return string
  local function format_name(item)
    local name = vim.trim(item.name or "") ---@type string
    if #name == 0 then
      name = dot.var.BUF_UNTITLED
    end
    if #name > 20 then
      name = name:sub(1, 17) .. "..."
    end
    return name
  end

  ---@param item                        std.t.INotepadItemMeta
  ---@param index                       integer
  ---@param relative_distance           integer|nil
  ---@return string
  ---@return string
  local function render_item(item, index, relative_distance)
    local name = format_name(item) ---@type string
    local text_index ---@type string
    if relative_distance ~= nil then
      local distance = math.abs(relative_distance) ---@type integer
      local marker = relative_distance < 0 and "₋" or "₊" ---@type string
      text_index = dot.icon.todigit_subscript(distance) .. marker ---@type string
    else
      text_index = tostring(index) .. " " ---@type string
    end
    local text_name = name ---@type string
    local text = text_sep_left .. text_index .. text_name .. text_sep_right .. " " ---@type string
    local hl_text = txt(text_sep_left, hln_sep_left)
      .. txt(text_index .. text_name, hln_name)
      .. txt(text_sep_right, hln_sep_right)
      .. txt(" ", hln_sep_right)
    return text, btn(hl_text, fn_switch_notepad, { index })
  end

  ---@param item                        std.t.INotepadItemMeta
  ---@param index                       integer
  ---@return string
  ---@return string
  local function render_item_active(item, index)
    local name = format_name(item) ---@type string
    local text_index = dot.icon.todigit_subscript(index) .. "." ---@type string
    local text_name = name ---@type string
    local text = text_sep_left .. text_index .. text_name .. text_sep_right .. " " ---@type string
    local hl_text = txt(text_sep_left, hln_sep_left_active)
      .. txt(text_index, hln_index_active)
      .. txt(text_name, hln_name_active)
      .. txt(text_sep_right, hln_sep_right_active)
      .. txt(" ", hln_sep_right_active)
    return text, btn(hl_text, fn_switch_notepad, { index })
  end

  ---@type ux.nvimbar.IRawComponent
  local component = {
    name = "notepad:items",
    atomic = false,
    render = function(_, remain_width)
      local entries = {} ---@type { item: std.t.INotepadItemMeta, index: integer }[]
      for item, index in notepad:iterator() do
        entries[#entries + 1] = { item = item, index = index }
      end

      local total = #entries ---@type integer
      if total == 0 then
        return "", "", false
      end

      local active_index, active_uuid = notepad:current()
      local active_uuid_text = type(active_uuid) == "string" and active_uuid or nil ---@type string|nil
      local active_display_index = nil ---@type integer|nil

      if active_uuid_text ~= nil then
        for idx, entry in ipairs(entries) do
          if entry.item.uuid == active_uuid_text then
            active_display_index = idx
            break
          end
        end
      end

      if active_display_index == nil then
        if type(active_index) == "number" and active_index >= 1 and active_index <= total then
          active_display_index = active_index
          active_uuid_text = entries[active_display_index].item.uuid
        else
          active_display_index = 1
          active_uuid_text = entries[1].item.uuid
        end
      end

      local segments = {} ---@type { text: string, hl: string, width: integer }[]
      for idx, entry in ipairs(entries) do
        local is_active = entry.item.uuid == active_uuid_text ---@type boolean
        local item_text, item_hl ---@type string, string
        if is_active then
          item_text, item_hl = render_item_active(entry.item, entry.index)
        else
          local relative_distance = idx - active_display_index ---@type integer
          item_text, item_hl = render_item(entry.item, entry.index, relative_distance)
        end
        segments[idx] = {
          text = item_text,
          hl = item_hl,
          width = vim.api.nvim_strwidth(item_text),
        }
      end

      local center = segments[active_display_index]
      if center == nil then
        return "", "", false
      end

      remain_width = remain_width - center.width
      if remain_width < 0 then
        return "", "", false
      end

      local left_reserved_width = active_display_index > 1 and arrow_reserved_width or 0
      local right_reserved_width = active_display_index < total and arrow_reserved_width or 0
      remain_width = remain_width - left_reserved_width - right_reserved_width

      local text = center.text ---@type string
      local hl_text = center.hl ---@type string

      local first_visible_left = active_display_index ---@type integer
      for idx = active_display_index - 1, 1, -1 do
        local segment = segments[idx]
        local width = segment.width
        if idx == 1 then
          if remain_width + left_reserved_width >= width then
            text = segment.text .. text
            hl_text = segment.hl .. hl_text
            remain_width = remain_width + left_reserved_width - width
            first_visible_left = 1
          end
          break
        end

        if remain_width < width then
          break
        end

        text = segment.text .. text
        hl_text = segment.hl .. hl_text
        remain_width = remain_width - width
        first_visible_left = idx
      end

      local last_visible_right = active_display_index ---@type integer
      for idx = active_display_index + 1, total do
        local segment = segments[idx]
        local width = segment.width
        if idx == total then
          if remain_width + right_reserved_width >= width then
            text = text .. segment.text
            hl_text = hl_text .. segment.hl
            remain_width = remain_width + right_reserved_width - width
            last_visible_right = total
          end
          break
        end

        if remain_width < width then
          break
        end

        text = text .. segment.text
        hl_text = hl_text .. segment.hl
        remain_width = remain_width - width
        last_visible_right = idx
      end

      local left_hidden_count = first_visible_left - 1 ---@type integer
      local right_hidden_count = total - last_visible_right ---@type integer
      local is_complete = (left_hidden_count == 0 and right_hidden_count == 0) ---@type boolean

      if left_hidden_count > 0 then
        local count = math.min(99, left_hidden_count) ---@type integer
        local arrow_text = " " .. icon_arrow_left .. "  " .. tostring(count) .. " " ---@type string
        local arrow_hl = txt(arrow_text, hln_arrow) ---@type string
        text = arrow_text .. text
        hl_text = btn(arrow_hl, fn_focus_prev_notepad) .. hl_text
      end

      if right_hidden_count > 0 then
        local count = math.min(99, right_hidden_count) ---@type integer
        local arrow_text = tostring(count) .. " " .. icon_arrow_right .. "  " ---@type string
        local arrow_hl = txt(arrow_text, hln_arrow) ---@type string
        text = text .. arrow_text
        hl_text = hl_text .. btn(arrow_hl, fn_focus_next_notepad)
      end

      return text, hl_text, is_complete
    end,
  }

  return component
end

---@param position                      ux.nvimbar.PositionEnum
---@return ux.nvimbar.IRawComponent
function M.add_button(position)
  local hln_button = position .. "_notepad_button" ---@type string

  ---@type ux.nvimbar.IRawComponent
  local component = {
    name = "notepad:add_button",
    atomic = true,
    render = function(_, remain_width)
      local text = " " ---@type string
      local hl_text = txt(text, hln_button)
      local width = vim.api.nvim_strwidth(text) ---@type integer
      if width <= 0 or remain_width < width then
        return "", "", false
      end
      return text, btn(hl_text, fn_add_notepad), true
    end,
  }

  return component
end

---@param position                      ux.nvimbar.PositionEnum
---@param notepad                       ux.widget.Notepad
---@return ux.nvimbar.IRawComponent
function M.source(position, notepad)
  local hln_source = position .. "_notepad_source" ---@type string
  local hln_source_sep = position .. "_notepad_source_sep" ---@type string
  local widget_id = tostring(notepad) ---@type string

  if fn_switch_source_registry[widget_id] == nil then
    fn_switch_source_registry[widget_id] = function()
      vim.cmd(eve.command.definitions.notepad.source_select.uuid)
    end
  end

  local fn_switch_source = eve.G.register_anonymous_fn(fn_switch_source_registry[widget_id]) or "eve.G.noop"

  local text_sep_left = dot.icon.symbols.sep_left ---@type string
  local icon_source = dot.icon.notepad.Source ---@type string

  ---@type ux.nvimbar.IRawComponent
  local component = {
    name = "notepad:source",
    atomic = true,
    render = function(_, remain_width)
      local source = notepad:get_source() ---@type std.t.INotepadSource
      local source_name = source.name ---@type string
      local _, config = eve.state.notepad.retrieve_source(source_name)
      local engine = config.engine ---@type 'json'|'folder'

      local text_source = source_name .. "@" .. engine .. " " .. icon_source .. " " ---@type string
      local text = text_sep_left .. text_source ---@type string
      local hl_text = txt(text_sep_left, hln_source_sep) .. btn(txt(text_source, hln_source), fn_switch_source)
      local width = vim.api.nvim_strwidth(text) ---@type integer
      if width <= 0 or remain_width < width then
        return "", "", false
      end
      return text, hl_text, true
    end,
  }

  return component
end

return M
