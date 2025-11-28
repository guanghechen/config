local convert = require("eve.ux.widget.colorpicker.convert")
local Color = require("eve.ux.widget.colorpicker.color")
local UI = require("eve.ux.widget.colorpicker.ui")
local picker = require("eve.ux.widget.colorpicker.picker")

local WIN_HIGHLIGHT = "FloatBorder:f_cp_border,Normal:f_cp_normal,EndOfBuffer:f_cp_normal"

---@class eve.ux.widget.colorpicker.IProps : eve.ux.widget.colorpicker.ui.IProps

---@class eve.ux.widget.colorpicker.ColorPicker : std.t.ux.IWidget
---@field public name                    string
---@field private _ui                    eve.ux.widget.colorpicker.UI
---@field private _color                 eve.ux.widget.colorpicker.Color
---@field private _range                 integer[]|nil
---@field private _source_bufnr          integer|nil
---@field private _history_index         integer
---@field private _bufnr                 integer|nil
---@field private _winnr                 integer|nil
---@field private _keymaps               std.t.IKeymap[]
local M = {}
M.__index = M

---@param props                         eve.ux.widget.colorpicker.IProps|nil
---@return eve.ux.widget.colorpicker.ColorPicker
function M.new(props)
  local self = setmetatable({}, M)
  self.name = "colorpicker"
  self._ui = UI.new(props)
  self._color = Color.new()
  self._range = nil
  self._source_bufnr = nil
  self._history_index = 0
  self._bufnr = nil
  self._winnr = nil
  self._keymaps = self:__build_keymaps__()
  self._ui.on_quit_callback = function() end
  return self
end

---@return nil
function M:pick()
  local ok, err = pcall(function()
    local result = picker.pick()
    local winnr = vim.api.nvim_get_current_win()
    local row, col = unpack(vim.api.nvim_win_get_cursor(winnr))
    self._source_bufnr = vim.api.nvim_win_get_buf(winnr)
    self._history_index = 0

    if result then
      self._range = { row, result.start_col - 1, row, result.end_col }
      if result.input_mode then
        self._color:set_input_mode(result.input_mode)
      end
      if result.output_mode then
        self._color:set_output_mode(result.output_mode)
      end
      self._color:set_rgb(result.r, result.g, result.b)
      if result.alpha then
        self._color:set_alpha(result.alpha)
        self._color:show_alpha()
      else
        self._color:hide_alpha()
      end
    else
      self._range = { row, col, row, col }
      self._color:reset()
    end

    local bufnr = self:__create_buf_as_needed__()
    self:__create_win_as_needed__(bufnr)
    self._ui:render(self._color, bufnr, self._winnr)
    vim.api.nvim_win_set_cursor(self._winnr, { 1, 0 })
  end)

  if not ok then
    std.reporter.error({
      from = "eve.ux.widget.colorpicker",
      subject = "pick",
      message = tostring(err),
    })
  end
end

---@return nil
function M:focus()
  self:pick()
end

---@return nil
function M:show()
  self:pick()
end

---@return nil
function M:hide()
  self:close()
end

---@return nil
function M:close()
  local bufnr = self._bufnr
  local winnr = self._winnr
  self._bufnr = nil
  self._winnr = nil

  if winnr and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
  end
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  self._ui:on_close()
end

---@return boolean
function M:isvisible()
  return self._winnr ~= nil and vim.api.nvim_win_is_valid(self._winnr)
end

---@return boolean
function M:isfocused()
  return self._winnr ~= nil and vim.api.nvim_get_current_win() == self._winnr
end

---@return nil
function M:resize()
  self._ui:update()
end

---@return boolean
function M:isdisposed()
  return false
end

----------------------------------------------------------------------------------------------------

---@protected
---@param d                             integer
---@return nil
function M:__apply_delta__(d)
  local point = self._ui:point_at()

  if point.type == "color" and point.index then
    local value = self._color:get()
    self._color:set_component(point.index, value[point.index] + d)
  elseif point.type == "alpha" then
    local alpha = self._color:get_alpha()
    if alpha then
      self._color:set_alpha(alpha + d)
    end
  end

  self._ui:update()
end

---@protected
---@return nil
function M:__attach_autocmds__()
  if not self._winnr then
    return
  end

  local augroup = vim.api.nvim_create_augroup("eve-colorpicker-" .. self._winnr, { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(self._winnr),
    group = augroup,
    callback = function()
      self:__on_close__()
    end,
    once = true,
  })
end

---@protected
---@return std.t.IKeymap[]
function M:__build_keymaps__()
  ---@type std.t.IKeymap[]
  return {
    {
      modes = { "n" },
      key = "<CR>",
      desc = "colorpicker: confirm",
      callback = function()
        self:__complete__()
      end,
    },
    {
      modes = { "n" },
      key = "q",
      desc = "colorpicker: quit",
      callback = function()
        self:close()
      end,
    },
    {
      modes = { "n" },
      key = "h",
      desc = "colorpicker: decrease",
      callback = function()
        local point = self._ui:point_at()
        if point.type == "color" or point.type == "alpha" then
          self:__apply_delta__(-vim.v.count1)
        else
          vim.api.nvim_feedkeys("h", "n", false)
        end
      end,
    },
    {
      modes = { "n" },
      key = "l",
      desc = "colorpicker: increase",
      callback = function()
        local point = self._ui:point_at()
        if point.type == "color" or point.type == "alpha" then
          self:__apply_delta__(vim.v.count1)
        else
          vim.api.nvim_feedkeys("l", "n", false)
        end
      end,
    },
    {
      modes = { "n" },
      key = "m",
      desc = "colorpicker: jump to position",
      callback = function()
        local point = self._ui:point_at()
        if point.type == "color" or point.type == "alpha" then
          self:__set_value__(vim.v.count1, point)
        else
          vim.api.nvim_feedkeys("m", "n", false)
        end
      end,
    },
    {
      modes = { "n" },
      key = "0",
      desc = "colorpicker: set min",
      callback = function()
        self:__set_percent__(0)
      end,
    },
    {
      modes = { "n" },
      key = "$",
      desc = "colorpicker: set max",
      callback = function()
        self:__set_percent__(100)
      end,
    },
    {
      modes = { "n" },
      key = "H",
      desc = "colorpicker: set 0%",
      callback = function()
        self:__set_percent__(0)
      end,
    },
    {
      modes = { "n" },
      key = "M",
      desc = "colorpicker: set 50%",
      callback = function()
        self:__set_percent__(50)
      end,
    },
    {
      modes = { "n" },
      key = "L",
      desc = "colorpicker: set 100%",
      callback = function()
        self:__set_percent__(100)
      end,
    },
    {
      modes = { "n" },
      key = "i",
      desc = "colorpicker: cycle input mode",
      callback = function()
        self._color:cycle_input()
        self._ui:update()
      end,
    },
    {
      modes = { "n" },
      key = "o",
      desc = "colorpicker: cycle output mode",
      callback = function()
        self._color:cycle_output()
        self._ui:update()
      end,
    },
    {
      modes = { "n" },
      key = "a",
      desc = "colorpicker: toggle alpha",
      callback = function()
        self._color:toggle_alpha()
        self._ui:update()
      end,
    },
    {
      modes = { "n" },
      key = "r",
      desc = "colorpicker: reset",
      callback = function()
        self._color:reset()
        self._ui:update()
      end,
    },
    {
      modes = { "n" },
      key = "<C-a>i",
      aliases = { "<D-i>", "<M-i>" },
      desc = "colorpicker: prev history",
      callback = function()
        self:__goto_prev_history__()
      end,
    },
    {
      modes = { "n" },
      key = "<C-a>o",
      aliases = { "<D-o>", "<M-o>" },
      desc = "colorpicker: next history",
      callback = function()
        self:__goto_next_history__()
      end,
    },
    {
      modes = { "n" },
      key = "<LeftMouse>",
      desc = "colorpicker: click",
      callback = function()
        self:__on_click__()
      end,
    },
    {
      modes = { "n" },
      key = "<ScrollWheelUp>",
      desc = "colorpicker: scroll up",
      callback = function()
        self:__apply_delta__(1)
      end,
    },
    {
      modes = { "n" },
      key = "<ScrollWheelDown>",
      desc = "colorpicker: scroll down",
      callback = function()
        self:__apply_delta__(-1)
      end,
    },
  }
end

---@protected
---@return nil
function M:__complete__()
  self._ui.is_quit = false
  self:close()

  if self._range and self._source_bufnr and vim.api.nvim_buf_is_valid(self._source_bufnr) then
    local hex = self._color:hex()
    local alpha = self._color:get_alpha()
    eve.context.colorpicker.push(hex, alpha)

    local text = self._color:str()
    local start_row, start_col, end_row, end_col = self._range[1] - 1, self._range[2], self._range[3] - 1, self._range[4]
    vim.api.nvim_buf_set_text(self._source_bufnr, start_row, start_col, end_row, end_col, { text })
  end
end

---@protected
---@return integer
function M:__create_buf_as_needed__()
  if self._bufnr and vim.api.nvim_buf_is_valid(self._bufnr) then
    return self._bufnr
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  self._bufnr = bufnr

  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = "colorpicker"
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].swapfile = false

  eve.nvim.bindkeys(self._keymaps, { bufnr = bufnr, nowait = true, noremap = true, silent = true })

  return bufnr
end

---@protected
---@param bufnr                         integer
---@return integer
function M:__create_win_as_needed__(bufnr)
  if self._winnr and vim.api.nvim_win_is_valid(self._winnr) then
    return self._winnr
  end

  local win_opts = self._ui:get_win_opts()
  local winnr = vim.api.nvim_open_win(bufnr, true, win_opts)
  self._winnr = winnr

  vim.wo[winnr].signcolumn = "yes:1"
  vim.wo[winnr].winhighlight = WIN_HIGHLIGHT

  self._ui:set_winnr(winnr)
  self:__attach_autocmds__()

  return winnr
end

---@protected
---@return nil
function M:__goto_next_history__()
  if self._history_index <= 1 then
    return
  end
  self._history_index = self._history_index - 1
  self:__load_history_item__(self._history_index)
end

---@protected
---@return nil
function M:__goto_prev_history__()
  local size = eve.context.colorpicker.size()
  if size == 0 then
    return
  end

  if self._history_index == 0 then
    self._history_index = 1
  elseif self._history_index < size then
    self._history_index = self._history_index + 1
  end

  self:__load_history_item__(self._history_index)
end

---@protected
---@param index                         integer
---@return nil
function M:__load_history_item__(index)
  local item = eve.context.colorpicker.get(index)
  if not item then
    return
  end

  local r, g, b = convert.hex_parse(item.hex)
  if r and g and b then
    self._color:set_rgb(r, g, b)
    if item.alpha then
      self._color:set_alpha(item.alpha)
      self._color:show_alpha()
    else
      self._color:hide_alpha()
    end
    self._ui:update()
  end
end

---@protected
---@return nil
function M:__on_click__()
  if not self._winnr then
    return
  end

  local mouse = vim.fn.getmousepos()
  if mouse.winid ~= self._winnr then
    return
  end

  local row = mouse.line
  local col = mouse.wincol
  local input = self._color:input()
  local values = self._color:get()
  local bar_len = self._ui:get_bar_len()
  local bar_char_width = self._ui:get_bar_char_width()
  local point_char_width = self._ui:get_point_char_width()

  if bar_len <= 0 or bar_char_width <= 0 or point_char_width <= 0 then
    return
  end
  local bar_width = (bar_len - 1) * bar_char_width + point_char_width

  if row >= 1 and row <= #input.bar_name then
    local bar_name = input.bar_name[row]
    local value = values[row] or 0
    local prefix = string.format("%s : %6d ", bar_name, value)
    local bar_start_col = vim.api.nvim_strwidth(prefix) + 1
    local offset = convert.clamp(col - bar_start_col, 0, bar_width)
    local ratio = convert.clamp(offset / bar_width, 0, 1)
    local max_val = input.max[row]
    self._color:set_component(row, convert.round(max_val * ratio))
    self._ui:update()
  elseif self._color:is_alpha_visible() and row == #input.bar_name + 1 then
    local alpha = self._color:get_alpha() or 0
    local alpha_bar_name = "A" .. string.rep(" ", #input.bar_name[1] - 1)
    local prefix = string.format("%s : %5d%% ", alpha_bar_name, alpha)
    local bar_start_col = vim.api.nvim_strwidth(prefix) + 1
    local offset = convert.clamp(col - bar_start_col, 0, bar_width)
    local ratio = convert.clamp(offset / bar_width, 0, 1)
    self._color:set_alpha(convert.round(100 * ratio))
    self._ui:update()
  end
end

---@protected
---@return nil
function M:__on_close__()
  self._bufnr = nil
  self._winnr = nil
  self._ui:on_close()
end

---@protected
---@param percent                       integer
---@return nil
function M:__set_percent__(percent)
  local point = self._ui:point_at()

  if point.type == "color" and point.index then
    local input = self._color:input()
    local max_val = input.max[point.index]
    self._color:set_component(point.index, convert.round(max_val * percent / 100))
  elseif point.type == "alpha" then
    self._color:set_alpha(percent)
  end

  self._ui:update()
end

---@protected
---@param value                         integer
---@param point                         eve.ux.widget.colorpicker.IPoint
---@return nil
function M:__set_value__(value, point)
  if point.type == "color" and point.index then
    self._color:set_component(point.index, value)
  elseif point.type == "alpha" then
    self._color:set_alpha(value)
  end

  self._ui:update()
end

return M
