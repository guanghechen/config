---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git_files.input" ---@type string

local namespace = vim.api.nvim_create_namespace("era.git_files.input")

---@class era.m.git_files.Input
---@field keymaps                       stl.t.IKeymap[]
---@field _on_change                    fun(value: string): nil
---@field _value                        string
---@field _bufnr                        ?integer
---@field _winnr                        ?integer
---@field _disposed                     boolean
local M = {}
M.__index = M

---@param keymaps                       stl.t.IKeymap[]
---@param on_change                     fun(value: string): nil
---@return era.m.git_files.Input
function M.new(keymaps, on_change)
  return setmetatable({ keymaps = keymaps, _on_change = on_change, _value = "", _disposed = false }, M)
end

---@return integer|nil
function M:get_bufnr()
  return self._bufnr
end

---@return integer|nil
function M:get_winnr()
  return self._winnr
end

---@return boolean
function M:isvisible()
  return self._winnr ~= nil and vim.api.nvim_win_is_valid(self._winnr)
end

---@return boolean
function M:isfocused()
  return self._winnr == vim.api.nvim_get_current_win()
end

---@param value                         string
---@return nil
function M:set_content(value)
  if self._disposed then
    return
  end
  value = value:gsub("[\r\n]", " ")
  local changed = self._value ~= value
  self._value = value
  local bufnr = self._bufnr
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    if #lines ~= 1 or lines[1] ~= value then
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { value })
    end
    vim.api.nvim_buf_set_extmark(bufnr, namespace, 0, 0, {
      id = 1,
      sign_text = " ",
      sign_hl_group = "m_pk_finder_prompt",
    })
  end
  if changed then
    self._on_change(value)
  end
end

---@return nil
function M:sync()
  local bufnr = self._bufnr
  if not self._disposed and bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    self:set_content(table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), " "))
  end
end

---@param dimension                     dot.t.IWinDimension
---@param border                        string[]
---@return nil
function M:show(dimension, border)
  assert(not self._disposed, "Git Files input is disposed")
  local bufnr = self._bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
    self._bufnr = bufnr
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", stl.filetype.UX_PICKER_FINDER, { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
    stl.nvim.fn.bindkeys(self.keymaps, { bufnr = bufnr, nowait = true, noremap = true, silent = true })
    self:set_content(self._value)
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
      buffer = bufnr,
      callback = function()
        self:sync()
      end,
    })
  end
  local config = {
    relative = "editor",
    row = dimension.row,
    col = dimension.col,
    width = dimension.width,
    height = 1,
    border = border,
    title = " Git Files · filter ",
    title_pos = "left",
    style = "minimal",
    focusable = true,
    noautocmd = true,
    zindex = 50,
  }
  if self:isvisible() then
    vim.api.nvim_win_set_config(assert(self._winnr), {
      relative = "editor",
      row = dimension.row,
      col = dimension.col,
      width = dimension.width,
      height = 1,
      border = border,
    })
    return
  end
  local winnr = vim.api.nvim_open_win(bufnr, false, config)
  self._winnr = winnr
  vim.w[winnr].wintype = stl.e.WinTypeEnum.PICKER_FINDER
  vim.api.nvim_set_option_value("signcolumn", "yes:1", { win = winnr })
  vim.api.nvim_set_option_value("wrap", false, { win = winnr })
  vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr })
  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:m_pk_finder_normal,FloatBorder:FloatBorder,FloatTitle:m_pk_finder_title",
    { win = winnr }
  )
end

---@return nil
function M:focus()
  if self:isvisible() then
    vim.api.nvim_set_current_win(assert(self._winnr))
  end
end

---@return nil
function M:hide()
  local winnr = self._winnr
  self._winnr = nil
  if winnr and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
  end
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self:hide()
  self._disposed = true
  local bufnr = self._bufnr
  self._bufnr = nil
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

return M
