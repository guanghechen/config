local convert = require("eve.ux.widget.colorpicker.convert")

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

---@class eve.ux.widget.colorpicker.ui.IProps
---@field public bar_char                string|nil
---@field public bar_len                 integer|nil
---@field public point_char              string|nil
---@field public history_char            string|nil
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
  return vim.tbl_extend("force", self._win_opts, { height = 5, width = 50 })
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

  local title = self:__build_title__()
  local winbar = self:__build_winbar__()
  local footer_left, footer_right = self:__build_footer__()

  local win_config = {
    height = #buffer + 1,
    width = width + 4,
    title = title,
    title_pos = "center",
  }
  if #footer_left > 0 then
    win_config.footer = footer_left
    win_config.footer_pos = "left"
  end

  vim.api.nvim_win_set_config(self._winnr, win_config)
  vim.api.nvim_win_set_config(self._winnr, { footer = footer_right, footer_pos = "right" })
  vim.wo[self._winnr].winbar = winbar
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
  local output = self._color:output()
  local before_hex = self._before_color:hex()
  local after_hex = self._color:hex()

  local r1, g1, b1 = self._before_color:get_rgb()
  local r2, g2, b2 = self._color:get_rgb()
  local before_str = output.str(r1, g1, b1, nil):gsub("%%", "%%%%")
  local after_str = output.str(r2, g2, b2, nil):gsub("%%", "%%%%")

  vim.api.nvim_set_hl(self._ns_id, "f_cp_preview_before_icon", { fg = before_hex })
  vim.api.nvim_set_hl(self._ns_id, "f_cp_preview_after_icon", { fg = after_hex })

  return string.format(
    "%%=%%#f_cp_preview_before_icon#%s %%#f_cp_bar_name#%s%%#f_cp_normal# -> %%#f_cp_preview_after_icon#%s %%#f_cp_bar_name#%s%%=",
    self._history_char,
    before_str,
    self._history_char,
    after_str
  )
end

---@protected
---@return { [1]: string, [2]: string }[]
function M:__build_title__()
  local input = self._color:input()
  return { { string.format(" Color Picker (%s) ", input.name), "f_cp_title" } }
end

---@protected
---@return { [1]: string, [2]: string }[], { [1]: string, [2]: string }[]
function M:__build_footer__()
  local history = eve.context.colorpicker.history:snapshot()
  local output = self._color:output()

  ---@type { [1]: string, [2]: string }[]
  local footer_left = {}
  if #history > 0 then
    table.insert(footer_left, { " ", "f_cp_normal" })
    for i, item in ipairs(history) do
      local hl_name = string.format("f_cp_history_%d", i)
      vim.api.nvim_set_hl(self._ns_id, hl_name, { fg = item.hex })
      table.insert(footer_left, { self._history_char, hl_name })
      if i < #history then
        table.insert(footer_left, { " ", "f_cp_normal" })
      end
    end
    table.insert(footer_left, { " ", "f_cp_normal" })
  end

  ---@type { [1]: string, [2]: string }[]
  local footer_right = { { " " .. output.name .. " ", "f_cp_title" } }

  return footer_left, footer_right
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
        local fg = contrast_color(hex)
        hl = { fg = fg, bg = hex }
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
        local fg = contrast_color(hex)
        hl = { fg = fg, bg = hex }
      end

      local hl_name = string.format("f_cp_alpha_%d", i)
      vim.api.nvim_set_hl(self._ns_id, hl_name, hl)
      vim.hl.range(self._bufnr, self._ns_id, hl_name, { row, start_col }, { row, end_col })

      start_col = end_col
    end
  end
end

return M
