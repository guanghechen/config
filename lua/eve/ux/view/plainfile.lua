---@class eve.ux.view.IPlainfileProps
---@field public name                   string
---@field public nsnr                   ?integer

---@class eve.ux.view.Plainfile : eve.ux.view.IView
---@field protected _disposed           boolean
---@field protected _filename           string|nil
---@field protected _filetype           string|nil
---@field protected _lines              string[]
---@field protected _max_width          integer
local M = {}
M.__index = M

local NSNR_DEFAULT = vim.api.nvim_create_namespace("ux_view_plainfile") ---@type integer

---@param props                         eve.ux.view.IPlainfileProps
---@return eve.ux.view.Plainfile
function M.new(props)
  local name = props.name ---@type string
  local nsnr = props.nsnr or NSNR_DEFAULT ---@type integer

  local self = setmetatable({}, M)

  self.name = name
  self.nsnr = nsnr
  self._disposed = false
  self._filename = nil
  self._filetype = nil
  self._lines = nil
  self._max_width = 0
  return self
end

---@return eve.ux.view.Plainfile
function M:clear()
  self:health()

  self._filename = nil
  self._filetype = nil
  self._lines = nil
  self._max_width = 0
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end

  self._disposed = true
  self._filename = nil
  self._filetype = nil
  self._lines = nil
  self._max_width = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return nil
function M:health()
  if self._disposed then
    local message = string.format("Plainfile (%s) has been disposed.", self.name) ---@type string
    error(message)
  end
end

---@return integer
---@return integer
function M:measure()
  self:health()

  local height = #self._lines ---@type integer
  local max_width = self._max_width ---@type integer
  return height, max_width
end

---@param bufnr                         integer
---@return eve.ux.view.Plainfile
function M:render(bufnr)
  self:health()

  local lines = self._lines ---@type string[]
  local filetype = self._filetype ---@type string
  local nsnr = self.nsnr ---@type integer

  vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  require("nvim-treesitter") --- load nvim-treesitter if not loaded
  if filetype ~= nil and vim.treesitter ~= nil and vim.treesitter.language ~= nil then
    local lang = vim.treesitter.language.get_lang(filetype) or filetype
    local loaded = vim.treesitter.language.add(lang)
    if loaded then
      vim.treesitter.start(bufnr, lang)
    end
  end

  return self
end

----------------------------------------------------------------------------------------------------

---@param filename                      string
---@param filetype                      string
---@param lines                         string[]
---@return eve.ux.view.Plainfile
function M:attach(filename, filetype, lines)
  self:health()

  local max_width = 0 ---@type integer
  for _, line in ipairs(lines) do
    local width = vim.api.nvim_strwidth(line) ---@type integer
    max_width = max_width < width and width or max_width ---@type integer
  end

  self._filename = filename
  self._filetype = filetype
  self._lines = lines
  self._max_width = max_width
  return self
end

return M
