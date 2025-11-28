local convert = require("eve.ux.widget.colorpicker.convert")

local POINT_CHAR = "󰫢"
local HISTORY_CHAR = "󱓻"
local BAR_CHAR = "█"
local BAR_LEN = 32

---@class eve.ux.widget.colorpicker.ui.IProps
---@field public bar_char                string|nil
---@field public bar_len                 integer|nil
---@field public point_char              string|nil
---@field public history_char            string|nil
---@field public empty_point_bg          boolean|nil
---@field public win_opts                vim.api.keyset.win_config|nil

---@class eve.ux.widget.colorpicker.UI
---@field private _ns_id                 integer
---@field private _bufnr                 integer|nil
---@field private _winnr                 integer|nil
---@field private _color                 eve.ux.widget.colorpicker.Color|nil
---@field private _before_color          eve.ux.widget.colorpicker.Color|nil
---@field private _bar_char              string
---@field private _bar_len               integer
---@field private _point_char            string
---@field private _history_char          string
---@field private _empty_point_bg        boolean
---@field private _win_opts              vim.api.keyset.win_config
---@field public on_quit_callback        (fun(): nil)|nil
---@field public is_quit                 boolean
local M = {}
M.__index = M

---@param props                         eve.ux.widget.colorpicker.ui.IProps|nil
---@return eve.ux.widget.colorpicker.UI
function M.new(props)
  props = props or {}

  local self = setmetatable({}, M)
  self._ns_id = vim.api.nvim_create_namespace("eve-colorpicker")
  self._bufnr = nil
  self._winnr = nil
  self._color = nil
  self._before_color = nil
  self._bar_char = props.bar_char or BAR_CHAR
  self._bar_len = props.bar_len or BAR_LEN
  self._point_char = props.point_char or POINT_CHAR
  self._history_char = props.history_char or HISTORY_CHAR
  self._empty_point_bg = props.empty_point_bg ~= false
  self._win_opts = vim.tbl_extend("force", {
    relative = "cursor",
    row = 1,
    col = 1,
    style = "minimal",
    border = "rounded",
  }, props.win_opts or {})
  self.on_quit_callback = nil
  self.is_quit = true
  return self
end

---@return vim.api.keyset.win_config
function M:get_win_opts()
  return vim.tbl_extend("force", self._win_opts, {
    height = 5,
    width = 50,
  })
end

---@param winnr                         integer
---@return nil
function M:set_winnr(winnr)
  self._winnr = winnr
end

---@param color                         eve.ux.widget.colorpicker.Color
---@param bufnr                         integer
---@param winnr                         integer
---@return nil
function M:render(color, bufnr, winnr)
  self._color = color
  self._before_color = color:copy()
  self._bufnr = bufnr
  self._winnr = winnr
  self.is_quit = true

  local buffer, width = self:__build_buffer__()
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, buffer)
  vim.bo[bufnr].modifiable = false
  self:__highlight__()

  vim.api.nvim_win_set_config(winnr, { height = #buffer, width = width })
  vim.api.nvim_win_set_hl_ns(winnr, self._ns_id)
end

---@return nil
function M:update()
  if self._winnr == nil or not vim.api.nvim_win_is_valid(self._winnr) then
    return
  end
  if self._bufnr == nil or not vim.api.nvim_buf_is_valid(self._bufnr) then
    return
  end

  local buffer, width = self:__build_buffer__()
  vim.bo[self._bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(self._bufnr, 0, -1, false, buffer)
  vim.bo[self._bufnr].modifiable = false
  self:__highlight__()
  vim.api.nvim_win_set_config(self._winnr, { height = #buffer, width = width })
  vim.api.nvim_win_set_hl_ns(self._winnr, self._ns_id)
end

---@return nil
function M:on_close()
  self._bufnr = nil
  self._winnr = nil
  self._before_color = nil
  if self.is_quit and self.on_quit_callback then
    self.on_quit_callback()
  end
end

---@return eve.ux.widget.colorpicker.IPoint
function M:point_at()
  if self._winnr == nil or not vim.api.nvim_win_is_valid(self._winnr) then
    return { type = "none", index = nil }
  end

  local row, _ = unpack(vim.api.nvim_win_get_cursor(self._winnr))
  local input = self._color:input()
  local num_color = #input.bar_name

  if row > 1 and row <= num_color + 1 then
    return { type = "color", index = row - 1 }
  elseif self._color:is_alpha_visible() and row == num_color + 2 then
    return { type = "alpha", index = nil }
  end
  return { type = "none", index = nil }
end

---@param point                         eve.ux.widget.colorpicker.IPoint
---@return nil
function M:set_point(point)
  if self._winnr == nil or not vim.api.nvim_win_is_valid(self._winnr) then
    return
  end

  local row = 1
  if point.type == "color" and point.index then
    row = point.index + 1
  elseif point.type == "alpha" and self._color:is_alpha_visible() then
    row = #self._color:input().bar_name + 2
  end
  vim.api.nvim_win_set_cursor(self._winnr, { row, 0 })
end

---@return integer|nil
function M:get_bufnr()
  return self._bufnr
end

---@return integer|nil
function M:get_winnr()
  return self._winnr
end

---@return integer
function M:get_bar_len()
  return self._bar_len
end

----------------------------------------------------------------------------------------------------

---@protected
---@param value                         integer
---@param max_val                       integer
---@return integer
function M:__adjust_to_bar__(value, max_val)
  local raw = convert.round(value / max_val * self._bar_len)
  return convert.clamp(raw, 1, self._bar_len)
end

---@protected
---@return string[]
---@return integer
function M:__build_buffer__()
  local input = self._color:input()
  local output = self._color:output()
  local buffer = {}

  local value = self._color:get()
  local sample_bar_line = string.format(
    "%s : %6d %s",
    input.bar_name[1],
    value[1],
    self:__create_bar__(value[1], input.max[1])
  )
  local width = vim.api.nvim_strwidth(sample_bar_line)

  local before_hex = self._before_color:hex()
  local after_hex = self._color:hex()

  local header_left = input.name
  local header_right = output.name
  local header_center = string.format(
    "%s %s -> %s %s",
    self._history_char,
    before_hex,
    self._history_char,
    after_hex
  )

  local left_width = vim.api.nvim_strwidth(header_left)
  local right_width = vim.api.nvim_strwidth(header_right)
  local center_width = vim.api.nvim_strwidth(header_center)

  local remaining = width - left_width - right_width - center_width
  local left_pad = math.floor(remaining / 2)
  local right_pad = remaining - left_pad
  if left_pad < 1 then
    left_pad = 1
  end
  if right_pad < 1 then
    right_pad = 1
  end

  local header_line = header_left .. string.rep(" ", left_pad) .. header_center .. string.rep(" ", right_pad) .. header_right
  table.insert(buffer, header_line)

  for i = 1, #input.bar_name do
    local line = string.format(
      "%s : %6d %s",
      input.bar_name[i],
      value[i],
      self:__create_bar__(value[i], input.max[i])
    )
    table.insert(buffer, line)
  end

  local alpha = self._color:get_alpha()
  if alpha then
    local alpha_bar_name = "A" .. string.rep(" ", #input.bar_name[1] - 1)
    local line = string.format("%s : %5d%% %s", alpha_bar_name, alpha, self:__create_bar__(alpha, 100))
    table.insert(buffer, line)
  end

  local history = eve.context.colorpicker.history:snapshot()
  if #history > 0 then
    local history_chars = {}
    for _ = 1, #history do
      table.insert(history_chars, self._history_char)
    end
    local history_line = table.concat(history_chars, " ")
    table.insert(buffer, history_line)
  end

  return buffer, width
end

---@protected
---@param value                         integer
---@param max_val                       integer
---@return string
function M:__create_bar__(value, max_val)
  local point_idx = self:__adjust_to_bar__(value, max_val)
  return self._bar_char:rep(point_idx - 1) .. self._point_char .. self._bar_char:rep(self._bar_len - point_idx)
end

---@protected
---@return nil
function M:__highlight__()
  if self._bufnr == nil or not vim.api.nvim_buf_is_valid(self._bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(self._bufnr, self._ns_id, 0, -1)

  local hl_point_dark = vim.api.nvim_get_hl(0, { name = "f_cp_point_dark" })
  local hl_point_light = vim.api.nvim_get_hl(0, { name = "f_cp_point_light" })
  local point_color_dark = hl_point_dark.fg and string.format("#%06x", hl_point_dark.fg) or "#000000"
  local point_color_light = hl_point_light.fg and string.format("#%06x", hl_point_light.fg) or "#ffffff"

  local input = self._color:input()
  local output = self._color:output()
  local bar_name_len = #input.bar_name[1]
  local value = self._color:get()

  local before_hex = self._before_color:hex()
  local after_hex = self._color:hex()
  local r1, g1, b1 = self._before_color:get_rgb()
  local r2, g2, b2 = self._color:get_rgb()

  local history_char_len = #self._history_char

  local header_left = input.name
  local header_right = output.name
  local header_center = string.format(
    "%s %s -> %s %s",
    self._history_char,
    before_hex,
    self._history_char,
    after_hex
  )

  local sample_bar_line = string.format(
    "%s : %6d %s",
    input.bar_name[1],
    value[1],
    self:__create_bar__(value[1], input.max[1])
  )
  local total_width = vim.api.nvim_strwidth(sample_bar_line)
  local left_width = vim.api.nvim_strwidth(header_left)
  local right_width = vim.api.nvim_strwidth(header_right)
  local center_width = vim.api.nvim_strwidth(header_center)

  local remaining = total_width - left_width - right_width - center_width
  local left_pad = math.floor(remaining / 2)
  if left_pad < 1 then
    left_pad = 1
  end

  local header_input_start = 0
  local header_input_end = left_width
  local center_start = left_width + left_pad
  local col = center_start
  local header_before_icon_start = col
  local header_before_icon_end = col + history_char_len
  col = header_before_icon_end + 1
  local header_before_start = col
  local header_before_end = col + #before_hex
  col = header_before_end + 4
  local header_after_icon_start = col
  local header_after_icon_end = col + history_char_len
  col = header_after_icon_end + 1
  local header_after_start = col
  local header_after_end = col + #after_hex
  local header_output_end = total_width
  local header_output_start = header_output_end - right_width

  vim.api.nvim_set_hl(self._ns_id, "f_cp_preview_before_icon", { fg = before_hex })
  vim.api.nvim_set_hl(self._ns_id, "f_cp_preview_after_icon", { fg = after_hex })
  vim.api.nvim_set_hl(self._ns_id, "f_cp_preview_before_dyn", {
    fg = convert.is_bright(r1, g1, b1) and point_color_dark or point_color_light,
  })
  vim.api.nvim_set_hl(self._ns_id, "f_cp_preview_after_dyn", {
    fg = convert.is_bright(r2, g2, b2) and point_color_dark or point_color_light,
  })

  vim.hl.range(self._bufnr, self._ns_id, "f_cp_title", { 0, header_input_start }, { 0, header_input_end })
  vim.hl.range(self._bufnr, self._ns_id, "f_cp_preview_before_icon", { 0, header_before_icon_start }, { 0, header_before_icon_end })
  vim.hl.range(self._bufnr, self._ns_id, "f_cp_preview_before_dyn", { 0, header_before_start }, { 0, header_before_end })
  vim.hl.range(self._bufnr, self._ns_id, "f_cp_preview_after_icon", { 0, header_after_icon_start }, { 0, header_after_icon_end })
  vim.hl.range(self._bufnr, self._ns_id, "f_cp_preview_after_dyn", { 0, header_after_start }, { 0, header_after_end })
  vim.hl.range(self._bufnr, self._ns_id, "f_cp_title", { 0, header_output_start }, { 0, header_output_end })

  local row = 1
  for i = 1, #value do
    local max_val = input.max[i]
    local point_idx = self:__adjust_to_bar__(value[i], max_val)

    vim.hl.range(self._bufnr, self._ns_id, "f_cp_bar_name", { row, 0 }, { row, bar_name_len })
    vim.hl.range(self._bufnr, self._ns_id, "f_cp_bar_value", { row, bar_name_len + 3 }, { row, bar_name_len + 9 })

    local start_col = bar_name_len + 10
    for j = 1, self._bar_len do
      local char_len = (j == point_idx) and #self._point_char or #self._bar_char
      local end_col = start_col + char_len

      local new_value = convert.round((j - 0.5) / self._bar_len * max_val)
      local hex = self._color:hex_at(i, new_value)
      local hl = { fg = hex }

      if j == point_idx then
        local r, g, b = self._color:get_rgb()
        if self._empty_point_bg then
          hl = { fg = convert.is_bright(r, g, b) and point_color_light or point_color_dark }
        else
          hl = {
            fg = convert.is_bright(r, g, b) and point_color_light or point_color_dark,
            bg = hex,
          }
        end
      end

      local hl_name = string.format("f_cp_bar_%d_%d", i, j)
      vim.api.nvim_set_hl(self._ns_id, hl_name, hl)
      vim.hl.range(self._bufnr, self._ns_id, hl_name, { row, start_col }, { row, end_col })

      start_col = end_col
    end
    row = row + 1
  end

  local alpha = self._color:get_alpha()
  if alpha then
    local point_idx = self:__adjust_to_bar__(alpha, 100)

    vim.hl.range(self._bufnr, self._ns_id, "f_cp_bar_name", { row, 0 }, { row, bar_name_len })
    vim.hl.range(self._bufnr, self._ns_id, "f_cp_bar_value", { row, bar_name_len + 3 }, { row, bar_name_len + 9 })

    local start_col = bar_name_len + 10

    for i = 1, self._bar_len do
      local char_len = (i == point_idx) and #self._point_char or #self._bar_char
      local end_col = start_col + char_len

      local alpha_ratio = (i - 0.5) / self._bar_len
      local r, g, b = self._color:get_rgb()
      local ar = convert.round(r * alpha_ratio)
      local ag = convert.round(g * alpha_ratio)
      local ab = convert.round(b * alpha_ratio)
      local hex = string.format("#%02x%02x%02x", ar, ag, ab)
      local hl = { fg = hex }

      if i == point_idx then
        if self._empty_point_bg then
          hl = { fg = alpha_ratio > 0.5 and point_color_dark or point_color_light }
        else
          hl = {
            fg = alpha_ratio > 0.5 and point_color_dark or point_color_light,
            bg = hex,
          }
        end
      end

      local hl_name = string.format("f_cp_alpha_%d", i)
      vim.api.nvim_set_hl(self._ns_id, hl_name, hl)
      vim.hl.range(self._bufnr, self._ns_id, hl_name, { row, start_col }, { row, end_col })

      start_col = end_col
    end
    row = row + 1
  end

  local history = eve.context.colorpicker.history:snapshot()
  if #history > 0 then
    local history_char_len = #self._history_char
    local start_col = 0
    for i, item in ipairs(history) do
      local end_col = start_col + history_char_len
      local hl_name = string.format("f_cp_history_%d", i)
      vim.api.nvim_set_hl(self._ns_id, hl_name, { fg = item.hex })
      vim.hl.range(self._bufnr, self._ns_id, hl_name, { row, start_col }, { row, end_col })
      start_col = end_col + 1
    end
  end
end

return M
