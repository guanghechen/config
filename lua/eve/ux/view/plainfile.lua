local __module_name__ = "eve.ux.view.plainfile" ---@type string

---@class eve.ux.view.plainfile.IData
---@field public filepath               string
---@field public filetype               string
---@field public lines                  string[]

---@class eve.ux.view.IPlainfileProps
---@field public name                   string
---@field public nsnr                   ?integer

---@class eve.ux.view.Plainfile : eve.ux.view.IView
---@field protected _disposed           boolean
---@field protected _last_bufnr         integer|nil
---@field protected _last_data          eve.ux.view.plainfile.IData|nil
local M = {}
M.__index = M

local NSNR_DEFAULT = eve.var.nsnr.view_plainfile ---@type integer

---@param props                         eve.ux.view.IPlainfileProps
---@return eve.ux.view.Plainfile
function M.new(props)
  local name = props.name ---@type string
  local nsnr = props.nsnr or NSNR_DEFAULT ---@type integer

  local self = setmetatable({}, M)

  self.name = name
  self.nsnr = nsnr
  self._disposed = false
  self._last_bufnr = nil
  self._last_data = nil
  return self
end

---@return eve.ux.view.Plainfile
function M:clear()
  self:__health__()

  self._last_bufnr = nil
  self._last_data = nil
  return self
end

---@return nil
function M:dispose()
  if self._disposed then
    return nil
  end
  self._disposed = true

  self._last_bufnr = nil
  self._last_data = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@param bufnr                         integer
---@param filepath                      string
---@param force                         boolean
---@return eve.ux.view.Plainfile
function M:render(bufnr, filepath, force)
  self:__health__()

  local data = self._last_data ---@type eve.ux.view.plainfile.IData|nil
  if force or data == nil or data.filepath ~= filepath then
    local lines = std.fs.read_file_as_lines({ filepath = filepath, silent = true }) ---@type string[]
    local filename = std.path.basename(filepath) ---@type string
    local filetype = vim.filetype.match({ filename = filename }) or "text" ---@type string

    ---@type eve.ux.view.plainfile.IData
    data = {
      filepath = filepath,
      filetype = filetype,
      lines = lines,
    }
    self._last_data = data

    force = true
  end

  if force or self._last_bufnr ~= bufnr then
    self._last_bufnr = bufnr
    local nsnr = self.nsnr ---@type integer
    local lines = data.lines ---@type string[]
    local filetype = data.filetype ---@type string

    vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

    if filetype ~= nil and vim.treesitter ~= nil and vim.treesitter.language ~= nil then
      local lang = vim.treesitter.language.get_lang(filetype) or filetype
      local loaded = vim.treesitter.language.add(lang)
      if loaded then
        vim.treesitter.stop(bufnr)
        vim.treesitter.start(bufnr, lang)
      end
    end
  end

  return self
end

----------------------------------------------------------------------------------------------------

---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("%s (%s) has been disposed.", __module_name__, self.name) ---@type string
    error(message)
  end
end

return M
