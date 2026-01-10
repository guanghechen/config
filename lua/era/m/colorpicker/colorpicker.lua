local S = era.m.colorpicker

local WIN_HIGHLIGHT = "FloatBorder:m_cp_border,Normal:m_cp_normal,EndOfBuffer:m_cp_normal"

---@class era.m.colorpicker.IProps : era.m.colorpicker.ui.IProps

---@class era.m.colorpicker.ColorPicker : dot.t.IWidget
---@field public name                   string
---@field protected _ui                 era.m.colorpicker.UI
---@field protected _color              era.m.colorpicker.Color
---@field protected _range              integer[]|nil
---@field protected _source_bufnr       integer|nil
---@field protected _history_index      integer
---@field protected _saved_color        era.m.colorpicker.Color|nil
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---@field protected _keymaps            stl.t.IKeymap[]
local M = {}
M.__index = M

---@param props                         era.m.colorpicker.IProps|nil
---@return era.m.colorpicker.ColorPicker
function M.new(props)
  local self = setmetatable({}, M)
  self.name = "colorpicker"
  self._ui = era.m.colorpicker.UI.new(props)
  self._color = era.m.colorpicker.Color.new()
  self._range = nil
  self._source_bufnr = nil
  self._history_index = 0
  self._saved_color = nil
  self._bufnr = nil
  self._winnr = nil
  self._keymaps = self:__build_keymaps__()
  return self
end

---@type era.m.colorpicker.ColorPicker|nil
local _instance = nil

---@return era.m.colorpicker.ColorPicker
function M.instance()
  if _instance == nil then
    _instance = M.new()
  end
  return _instance
end

---@return nil
function M:pick()
  local ok, err = pcall(function()
    local result = S.picker.pick()
    local winnr = vim.api.nvim_get_current_win()
    local row, col = unpack(vim.api.nvim_win_get_cursor(winnr))
    self._source_bufnr = vim.api.nvim_win_get_buf(winnr)
    self._history_index = 0
    self._ui:set_history_index(0)

    if result then
      self._range = { row, result.start_col - 1, row, result.end_col }
      self:__apply_color__(result.r, result.g, result.b, result.alpha)
    else
      self._range = { row, col, row, col }
      local last = dot.context.colorpicker.get_last_color()
      if last then
        local r, g, b = S.convert.hex_parse(last.hex)
        if r and g and b then
          self:__apply_color__(r, g, b, last.alpha)
        else
          self._color:reset()
        end
      else
        self._color:reset()
      end
    end

    local bufnr = self:__create_buf_as_needed__()
    self:__create_win_as_needed__(bufnr)
    self._ui:render(self._color, bufnr, self._winnr)
    vim.api.nvim_win_set_cursor(self._winnr, { 1, 0 })
  end)

  if not ok then
    stl.reporter.error({
      from = "era.colorpicker",
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
---@param r                             integer
---@param g                             integer
---@param b                             integer
---@param alpha                         integer|nil
---@return nil
function M:__apply_color__(r, g, b, alpha)
  self._color:set_rgb(r, g, b)
  if alpha then
    self._color:set_alpha(alpha)
    self._color:show_alpha()
  else
    self._color:hide_alpha()
  end
end

----------------------------------------------------------------------------------------------------

---@protected
---@param source                        era.m.colorpicker.Color
---@return nil
function M:__restore_from__(source)
  local r, g, b = source:get_rgb()
  self._color:set_rgb(r, g, b)
  if source:is_alpha_visible() then
    self._color:set_alpha(source:get_alpha() or 100)
    self._color:show_alpha()
  else
    self._color:hide_alpha()
  end
end

---@protected
---@return nil
function M:__reset_to_current__()
  if self._history_index ~= 0 then
    self._history_index = 0
    self._ui:set_history_index(0)
  end
end

---@protected
---@param d                             integer
---@return nil
function M:__apply_delta__(d)
  local point = self._ui:point_at()

  if point.type == "color" and point.index then
    local value = self._color:get()
    self._color:set_component(point.index, value[point.index] + d)
    self:__reset_to_current__()
  elseif point.type == "alpha" then
    local alpha = self._color:get_alpha()
    if alpha then
      self._color:set_alpha(alpha + d)
      self:__reset_to_current__()
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

  local augroup = vim.api.nvim_create_augroup("dot-colorpicker-" .. self._winnr, { clear = true })
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
---@return stl.t.IKeymap[]
function M:__build_keymaps__()
  ---@type stl.t.IKeymap[]
  return {
    {
      modes = { "n" },
      key = "w",
      aliases = { "W", "t", "T", "f", "F" },
      desc = "colorpicker: noop",
      callback = function() end,
    },
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
      desc = "colorpicker: set value",
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
      key = "I",
      desc = "colorpicker: cycle input mode reverse",
      callback = function()
        self._color:cycle_input_reverse()
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
      key = "O",
      desc = "colorpicker: cycle output mode reverse",
      callback = function()
        self._color:cycle_output_reverse()
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
      desc = "colorpicker: reset to initial",
      callback = function()
        local before = self._ui:get_before_color()
        if before then
          self:__restore_from__(before)
        end
        self:__reset_to_current__()
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
        self:__on_scroll__(1)
      end,
    },
    {
      modes = { "n" },
      key = "<ScrollWheelDown>",
      desc = "colorpicker: scroll down",
      callback = function()
        self:__on_scroll__(-1)
      end,
    },
  }
end

---@protected
---@return nil
function M:__complete__()
  self:close()

  if self._range and self._source_bufnr and vim.api.nvim_buf_is_valid(self._source_bufnr) then
    local hex = self._color:hex()
    local alpha = self._color:get_alpha()
    dot.context.colorpicker.push(hex, alpha)
    dot.context.colorpicker.set_last_color(hex, alpha)

    local text = self._color:str()
    local start_row, start_col, end_row, end_col =
      self._range[1] - 1, self._range[2], self._range[3] - 1, self._range[4]
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

  vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", "colorpicker", { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })

  stl.nvim.fn.bindkeys(self._keymaps, { bufnr = bufnr, nowait = true, noremap = true, silent = true })

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
  win_opts.zindex = dot.win.resolve_zindex()
  local winnr = vim.api.nvim_open_win(bufnr, true, win_opts)
  self._winnr = winnr

  vim.api.nvim_set_option_value("signcolumn", "yes:1", { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winhighlight", WIN_HIGHLIGHT, { win = winnr, scope = "local" })

  self._ui:set_winnr(winnr)
  self:__attach_autocmds__()

  return winnr
end

---@protected
---@return nil
function M:__goto_next_history__()
  if self._history_index <= 0 then
    return
  end

  if self._history_index == 1 then
    self._history_index = 0
    self._ui:set_history_index(0)
    if self._saved_color then
      self:__restore_from__(self._saved_color)
    end
    self._ui:update()
  else
    self._history_index = self._history_index - 1
    self._ui:set_history_index(self._history_index)
    self:__load_history_item__(self._history_index)
  end
end

---@protected
---@return nil
function M:__goto_prev_history__()
  local size = dot.context.colorpicker.size()
  if size == 0 then
    return
  end

  if self._history_index == 0 then
    self._saved_color = self._color:copy()
    self._history_index = 1
  elseif self._history_index < size then
    self._history_index = self._history_index + 1
  end

  self._ui:set_history_index(self._history_index)
  self:__load_history_item__(self._history_index)
end

---@protected
---@param index                         integer
---@return nil
function M:__load_history_item__(index)
  local item = dot.context.colorpicker.get(index)
  if not item then
    return
  end

  local r, g, b = S.convert.hex_parse(item.hex)
  if r and g and b then
    self:__apply_color__(r, g, b, item.alpha)
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
    local offset = S.convert.clamp(col - bar_start_col, 0, bar_width)
    local ratio = S.convert.clamp(offset / bar_width, 0, 1)
    local max_val = input.max[row]
    self._color:set_component(row, S.convert.round(max_val * ratio))
    self:__reset_to_current__()
    self._ui:update()
  elseif self._color:is_alpha_visible() and row == #input.bar_name + 1 then
    local alpha = self._color:get_alpha() or 0
    local alpha_bar_name = "A" .. string.rep(" ", #input.bar_name[1] - 1)
    local prefix = string.format("%s : %5d%% ", alpha_bar_name, alpha)
    local bar_start_col = vim.api.nvim_strwidth(prefix) + 1
    local offset = S.convert.clamp(col - bar_start_col, 0, bar_width)
    local ratio = S.convert.clamp(offset / bar_width, 0, 1)
    self._color:set_alpha(S.convert.round(100 * ratio))
    self:__reset_to_current__()
    self._ui:update()
  end
end

---@protected
---@param d                             integer
---@return nil
function M:__on_scroll__(d)
  if not self._winnr then
    return
  end

  local mouse = vim.fn.getmousepos()
  if mouse.winid ~= self._winnr then
    return
  end

  local row = mouse.line
  local input = self._color:input()

  if row >= 1 and row <= #input.bar_name then
    local value = self._color:get()
    self._color:set_component(row, value[row] + d)
    self:__reset_to_current__()
    self._ui:update()
  elseif self._color:is_alpha_visible() and row == #input.bar_name + 1 then
    local alpha = self._color:get_alpha()
    if alpha then
      self._color:set_alpha(alpha + d)
      self:__reset_to_current__()
      self._ui:update()
    end
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
    self._color:set_component(point.index, S.convert.round(max_val * percent / 100))
  elseif point.type == "alpha" then
    self._color:set_alpha(percent)
  end

  self._ui:update()
end

---@protected
---@param value                         integer
---@param point                         era.m.colorpicker.IPoint
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
