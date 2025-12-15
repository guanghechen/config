local btn = ark.nvim.btn
local txt = ark.nvim.txt
local decode_btn_args = ark.nvim.decode_btn_args
local K = dot.command.definitions ---@type table<string, any>

---@type string
local fn_switch_term = dot.G.register_anonymous_fn(function(encoded)
  local argv = decode_btn_args(tostring(encoded)) ---@type integer[]
  local index = argv[1] ---@type integer|nil
  if index ~= nil then
    dot.term.focus(index)
  end
end) or "dot.G.noop"

---@type string
local fn_add_term = dot.G.register_anonymous_fn(function()
  K.term.create:execute()
end) or "dot.G.noop"

---@type string
local fn_focus_prev_term = dot.G.register_anonymous_fn(function()
  K.term.focus_left:execute()
end) or "dot.G.noop"

---@type string
local fn_focus_next_term = dot.G.register_anonymous_fn(function()
  K.term.focus_right:execute()
end) or "dot.G.noop"

---@class dot.module.nvimbar.component.term
local M = {}

---@param termmeta                      dot.t.ITermMeta
---@return string
local function format_name(termmeta)
  local name = vim.trim(termmeta.name or "") ---@type string
  if #name == 0 then
    name = "Terminal"
  end
  if #name > 12 then
    name = name:sub(1, 9) .. "..."
  end
  return name
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.items(position)
  local hln_button = position .. "_term_button" ---@type string
  local hln_name = position .. "_term_name" ---@type string
  local hln_index = position .. "_term_index" ---@type string
  local hln_sep_left = position .. "_term_sep_left" ---@type string
  local hln_sep_right = position .. "_term_sep_right" ---@type string

  local hln_name_active = position .. "_termc_name" ---@type string
  local hln_index_active = position .. "_termc_index" ---@type string
  local hln_sep_left_active = position .. "_termc_sep_left" ---@type string
  local hln_sep_middle_active = position .. "_termc_sep_middle" ---@type string
  local hln_sep_right_active = position .. "_termc_sep_right" ---@type string

  local text_sep_left = dot.icon.symbols.sep_left ---@type string
  local text_sep_middle = " | " ---@type string
  local text_sep_right = dot.icon.symbols.sep_right ---@type string

  local icon_arrow_left = dot.icon.ui.Left ---@type string
  local icon_arrow_right = dot.icon.ui.Right ---@type string
  local arrow_reserved_width = vim.api.nvim_strwidth(" " .. icon_arrow_left .. "  99 ") ---@type integer
  local hln_arrow = ark.nvim.make_bg_transparency(hln_button) ---@type string

  ---@param termmeta                    dot.t.ITermMeta
  ---@param index                       integer
  ---@return string
  ---@return string
  local function render_item(termmeta, index)
    local name = format_name(termmeta) ---@type string
    local text_name = name .. " " ---@type string
    local text_index = " " .. tostring(index) ---@type string
    local text = text_sep_left .. text_name .. text_index .. text_sep_right .. " " ---@type string
    local hl_text = txt(text_sep_left, hln_sep_left)
      .. txt(text_name, hln_name)
      .. txt(text_index, hln_index)
      .. txt(text_sep_right, hln_sep_right)
      .. txt(" ", hln_sep_right)
    return text, btn(hl_text, fn_switch_term, { index })
  end

  ---@param termmeta                    dot.t.ITermMeta
  ---@param index                       integer
  ---@return string
  ---@return string
  local function render_item_active(termmeta, index)
    local name = format_name(termmeta) ---@type string
    local text_name = name ---@type string
    local text_index = tostring(index) ---@type string
    local text = text_sep_left .. text_name .. text_sep_middle .. text_index .. text_sep_right .. " " ---@type string
    local hl_text = txt(text_sep_left, hln_sep_left_active)
      .. txt(text_name, hln_name_active)
      .. txt(text_sep_middle, hln_sep_middle_active)
      .. txt(text_index, hln_index_active)
      .. txt(text_sep_right, hln_sep_right_active)
      .. txt(" ", hln_sep_right_active)
    return text, btn(hl_text, fn_switch_term, { index })
  end

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "term:items",
    atomic = false,
    render = function(_, remain_width)
      local entries = {} ---@type { term: dot.t.ITermMeta, index: integer }[]
      local total_terms = dot.term.size() ---@type integer
      for idx = 1, total_terms do
        local termuuid, termmeta = dot.term.at(idx) ---@type string|nil, dot.t.ITermMeta|nil
        if termuuid ~= nil and termmeta ~= nil then
          entries[#entries + 1] = { term = termmeta, index = idx }
        end
      end

      local total = #entries ---@type integer
      if total == 0 then
        return "", "", false
      end

      local active_index = dot.term.current() ---@type integer
      if active_index < 1 or active_index > total_terms then
        active_index = entries[1].index
      end

      local active_display_index = nil ---@type integer|nil
      for display_index, entry in ipairs(entries) do
        if entry.index == active_index then
          active_display_index = display_index
          break
        end
      end
      if active_display_index == nil then
        active_display_index = 1
        active_index = entries[1].index
      end

      local segments = {} ---@type { text: string, hl: string, width: integer }[]
      for idx, entry in ipairs(entries) do
        local renderer = idx == active_display_index and render_item_active or render_item
        local item_text, item_hl = renderer(entry.term, entry.index)
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
      local is_complete = left_hidden_count == 0 and right_hidden_count == 0 ---@type boolean

      if left_hidden_count > 0 then
        local count = math.min(99, left_hidden_count) ---@type integer
        local arrow_text = " " .. icon_arrow_left .. "  " .. tostring(count) .. " " ---@type string
        local arrow_hl = txt(arrow_text, hln_arrow) ---@type string
        text = arrow_text .. text
        hl_text = btn(arrow_hl, fn_focus_prev_term) .. hl_text
      end

      if right_hidden_count > 0 then
        local count = math.min(99, right_hidden_count) ---@type integer
        local arrow_text = tostring(count) .. " " .. icon_arrow_right .. "  " ---@type string
        local arrow_hl = txt(arrow_text, hln_arrow) ---@type string
        text = text .. arrow_text
        hl_text = hl_text .. btn(arrow_hl, fn_focus_next_term)
      end

      return text, hl_text, is_complete
    end,
  }

  return component
end

---@param position                      dot.module.nvimbar.PositionEnum
---@return dot.module.nvimbar.IRawComponent
function M.add_button(position)
  local hln_button = position .. "_term_button" ---@type string

  ---@type dot.module.nvimbar.IRawComponent
  local component = {
    name = "term:add_button",
    atomic = true,
    render = function(_, remain_width)
      local text = " + " ---@type string
      local width = vim.api.nvim_strwidth(text) ---@type integer
      if width <= 0 or remain_width < width then
        return "", "", false
      end

      local hl_text = txt(text, hln_button)
      return text, btn(hl_text, fn_add_term), true
    end,
  }

  return component
end

-- Backwards compatibility for legacy consumers
M.terms = M.items

return M
