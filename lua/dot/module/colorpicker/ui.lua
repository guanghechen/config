local convert = require("dot.module.colorpicker.convert")

local POINT_CHAR = "󰫢"
local HISTORY_CHAR = "󱓻"
local BAR_CHAR = "█"
local BAR_LEN = 32

---@param hex                           string
---@return string
local function contrast_color(hex)
  local r, g, b = convert.hex_parse(hex)
  if not r or not g or not b then
    return "#000000"
  end
  local luminance = 0.299 * r + 0.587 * g + 0.114 * b
  return luminance > 127 and "#000000" or "#ffffff"
end

---@class dot.module.colorpicker.ui.IProps
---@field public bar_char               string|nil
---@field public bar_len                integer|nil
---@field public point_char             string|nil
---@field public history_char           string|nil
---@field public win_opts               vim.api.keyset.win_config|nil

---@class dot.module.colorpicker.UI
---@field protected _ns_id              integer
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---@field protected _color              dot.module.colorpicker.Color|nil
---@field protected _before_color       dot.module.colorpicker.Color|nil
---@field protected _bar_char           string
---@field protected _bar_len            integer
---@field protected _point_char         string
---@field protected _history_char       string
---@field protected _history_index      integer
---@field protected _win_opts           vim.api.keyset.win_config
local M = {}
M.__index = M

---@param props                         dot.module.colorpicker.ui.IProps|nil
---@return dot.module.colorpicker.UI
function M.new(props)
  props = props or {}
  local self = setmetatable({}, M)
  self._ns_id = vim.api.nvim_create_namespace("dot-colorpicker")
  self._bufnr = nil
  self._winnr = nil
  self._color = nil
  self._before_color = nil
  self._bar_char = props.bar_char or BAR_CHAR
  self._bar_len = props.bar_len or BAR_LEN
  self._point_char = props.point_char or POINT_CHAR
  self._history_char = props.history_char or HISTORY_CHAR
  self._history_index = 0
  self._win_opts = vim.tbl_extend("force", {
    relative = "cursor",
    row = 1,
    col = 1,
    style = "minimal",
    border = "rounded",
  }, props.win_opts or {})
  return self
end

---@return vim.api.keyset.win_config
function M:get_win_opts()
  return vim.tbl_extend("force", self._win_opts, { height = 5, width = 50 })
end

---@param winnr                         integer
---@return nil
function M:set_winnr(winnr)
  self._winnr = winnr
end

---@param color                         dot.module.colorpicker.Color
---@param bufnr                         integer
---@param winnr                         integer
---@return nil
function M:render(color, bufnr, winnr)
  self._color = color
  self._before_color = color:copy()
  self._bufnr = bufnr
  self._winnr = winnr
  self:__refresh__()
end

---@return nil
function M:update()
  if not self._winnr or not vim.api.nvim_win_is_valid(self._winnr) then
    return
  end
  if not self._bufnr or not vim.api.nvim_buf_is_valid(self._bufnr) then
    return
  end
  self:__refresh__()
end

---@param index                         integer
---@return nil
function M:set_history_index(index)
  self._history_index = index
end

---@return dot.module.colorpicker.Color|nil
function M:get_before_color()
  return self._before_color
end

---@return nil
function M:on_close()
  self._bufnr = nil
  self._winnr = nil
  self._before_color = nil
end

---@return dot.module.colorpicker.IPoint
function M:point_at()
  if not self._winnr or not vim.api.nvim_win_is_valid(self._winnr) then
    return { type = "none", index = nil }
  end

  local row = vim.api.nvim_win_get_cursor(self._winnr)[1]
  local input = self._color:input()
  local num_color = #input.bar_name

  if row >= 1 and row <= num_color then
    return { type = "color", index = row }
  elseif self._color:is_alpha_visible() and row == num_color + 1 then
    return { type = "alpha", index = nil }
  end
  return { type = "none", index = nil }
end

---@return integer
function M:get_bar_len()
  return self._bar_len
end

---@return integer
function M:get_bar_char_width()
  return vim.api.nvim_strwidth(self._bar_char)
end

---@return integer
function M:get_point_char_width()
  return vim.api.nvim_strwidth(self._point_char)
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__refresh__()
  local buffer, width = self:__build_buffer__()
  vim.bo[self._bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(self._bufnr, 0, -1, false, buffer)
  vim.bo[self._bufnr].modifiable = false
  self:__highlight__()

  vim.api.nvim_win_set_config(self._winnr, {
    height = #buffer + 1,
    width = width + 2,
    title = self:__build_title__(),
    title_pos = "center",
    footer = self:__build_footer__(),
    footer_pos = "right",
  })
  vim.wo[self._winnr].winbar = self:__build_winbar__()
  vim.api.nvim_win_set_hl_ns(self._winnr, self._ns_id)
end

---@protected
---@param value                         integer
---@param max_val                       integer
---@return integer
function M:__adjust_to_bar__(value, max_val)
  local raw = convert.round(value / max_val * self._bar_len)
  return convert.clamp(raw, 1, self._bar_len)
end

---@protected
---@return string[], integer
function M:__build_buffer__()
  local input = self._color:input()
  local buffer = {}
  local value = self._color:get()

  for i = 1, #input.bar_name do
    local line = string.format("%s : %4d %s", input.bar_name[i], value[i], self:__create_bar__(value[i], input.max[i]))
    table.insert(buffer, line)
  end

  local alpha = self._color:get_alpha()
  if alpha then
    local alpha_bar_name = "A" .. string.rep(" ", #input.bar_name[1] - 1)
    local line = string.format("%s : %3d%% %s", alpha_bar_name, alpha, self:__create_bar__(alpha, 100))
    table.insert(buffer, line)
  end

  local width = 0
  for _, line in ipairs(buffer) do
    local w = vim.api.nvim_strwidth(line)
    if w > width then
      width = w
    end
  end

  return buffer, width
end

---@protected
---@return string
function M:__build_winbar__()
  local input = self._color:input()
  local output = self._color:output()
  local hex = self._color:hex()
  local alpha = self._color:get_alpha()
  local value = self._color:get()

  vim.api.nvim_set_hl(self._ns_id, "m_cp_preview_icon", { fg = hex })

  local input_str
  if input.name == "HEX" then
    if alpha then
      input_str = string.format("#%02x%02x%02x%02x", value[1], value[2], value[3], convert.round(alpha * 255 / 100))
    else
      input_str = string.format("#%02x%02x%02x", value[1], value[2], value[3])
    end
  elseif input.name == "RGB" then
    if alpha then
      input_str = string.format("rgb(%d %d %d / %d%%)", value[1], value[2], value[3], alpha)
    else
      input_str = string.format("rgb(%d,%d,%d)", value[1], value[2], value[3])
    end
  elseif input.name == "HSL" then
    if alpha then
      input_str = string.format("hsl(%d %d%% %d%% / %d%%)", value[1], value[2], value[3], alpha)
    else
      input_str = string.format("hsl(%d,%d%%,%d%%)", value[1], value[2], value[3])
    end
  elseif input.name == "HSV" then
    if alpha then
      input_str = string.format("hsv(%d %d%% %d%% / %d%%)", value[1], value[2], value[3], alpha)
    else
      input_str = string.format("hsv(%d,%d%%,%d%%)", value[1], value[2], value[3])
    end
  end
  input_str = input_str:gsub("%%", "%%%%")

  if input.name == output.name then
    return string.format("%%=%%#m_cp_preview_icon#%s %%#m_cp_bar_name#%s%%=", self._point_char, input_str)
  end

  local r, g, b = self._color:get_rgb()
  local output_str = output.str(r, g, b, alpha):gsub("%%", "%%%%")

  return string.format(
    "%%=%%#m_cp_preview_icon#%s %%#m_cp_bar_name#%s%%#m_cp_normal# -> %s%%=",
    self._point_char,
    input_str,
    output_str
  )
end

---@protected
---@return { [1]: string, [2]: string }[]
function M:__build_title__()
  local input = self._color:input()
  return { { string.format(" Color Picker (%s) ", input.name), "m_cp_title" } }
end

---@protected
---@return { [1]: string, [2]: string }[]
function M:__build_footer__()
  local history = dot.context.colorpicker.history:snapshot()
  local output = self._color:output()
  local current_hex = self._color:hex()

  ---@type { [1]: string, [2]: string }[]
  local footer = {}

  for i = #history, 1, -1 do
    local item = history[i]
    local hl_name = string.format("m_cp_history_%d", i)
    vim.api.nvim_set_hl(self._ns_id, hl_name, { fg = item.hex })
    local char = self._history_index == i and self._point_char or self._history_char
    table.insert(footer, { " ", "m_cp_normal" })
    table.insert(footer, { char, hl_name })
  end

  vim.api.nvim_set_hl(self._ns_id, "m_cp_current", { fg = current_hex })
  local current_char = self._history_index == 0 and self._point_char or self._history_char
  table.insert(footer, { " │ ", "m_cp_border" })
  table.insert(footer, { current_char, "m_cp_current" })
  table.insert(footer, { " " .. output.name .. " ", "m_cp_title" })

  return footer
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
  if not self._bufnr or not vim.api.nvim_buf_is_valid(self._bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(self._bufnr, self._ns_id, 0, -1)

  local input = self._color:input()
  local bar_name_len = #input.bar_name[1]
  local value = self._color:get()

  local row = 0
  for i = 1, #value do
    local max_val = input.max[i]
    local point_idx = self:__adjust_to_bar__(value[i], max_val)

    vim.hl.range(self._bufnr, self._ns_id, "m_cp_bar_name", { row, 0 }, { row, bar_name_len })
    vim.hl.range(self._bufnr, self._ns_id, "m_cp_bar_value", { row, bar_name_len + 3 }, { row, bar_name_len + 7 })

    local start_col = bar_name_len + 8
    for j = 1, self._bar_len do
      local char_len = (j == point_idx) and #self._point_char or #self._bar_char
      local end_col = start_col + char_len

      local new_value = convert.round((j - 0.5) / self._bar_len * max_val)
      local hex = self._color:hex_at(i, new_value)
      local hl = { fg = hex }

      if j == point_idx then
        hl = { fg = contrast_color(hex), bg = hex }
      end

      local hl_name = string.format("m_cp_bar_%d_%d", i, j)
      vim.api.nvim_set_hl(self._ns_id, hl_name, hl)
      vim.hl.range(self._bufnr, self._ns_id, hl_name, { row, start_col }, { row, end_col })

      start_col = end_col
    end
    row = row + 1
  end

  local alpha = self._color:get_alpha()
  if alpha then
    local point_idx = self:__adjust_to_bar__(alpha, 100)

    vim.hl.range(self._bufnr, self._ns_id, "m_cp_bar_name", { row, 0 }, { row, bar_name_len })
    vim.hl.range(self._bufnr, self._ns_id, "m_cp_bar_value", { row, bar_name_len + 3 }, { row, bar_name_len + 7 })

    local start_col = bar_name_len + 8
    local r, g, b = self._color:get_rgb()
    for i = 1, self._bar_len do
      local char_len = (i == point_idx) and #self._point_char or #self._bar_char
      local end_col = start_col + char_len

      local alpha_ratio = (i - 0.5) / self._bar_len
      local ar = convert.round(r * alpha_ratio)
      local ag = convert.round(g * alpha_ratio)
      local ab = convert.round(b * alpha_ratio)
      local hex = string.format("#%02x%02x%02x", ar, ag, ab)
      local hl = { fg = hex }

      if i == point_idx then
        hl = { fg = contrast_color(hex), bg = hex }
      end

      local hl_name = string.format("m_cp_alpha_%d", i)
      vim.api.nvim_set_hl(self._ns_id, hl_name, hl)
      vim.hl.range(self._bufnr, self._ns_id, hl_name, { row, start_col }, { row, end_col })

      start_col = end_col
    end
  end
end

return M
