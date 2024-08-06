---@class fml.ui.search.Preview : fml.types.ui.search.IPreview
---@field protected _bufnr              integer|nil
---@field protected _render             fun(): fml.ui.search.preview.IRenderData
---@field protected _update             fun(data: fml.ui.search.preview.IRenderData): fml.ui.search.preview.IRenderData
local M = {}
M.__index = M

---@class fml.ui.search.preview.IProps
---@field public state                  fml.types.ui.search.IState
---@field public render                 fun(bufnr: integer): nil
---@field public update                 ?fun(bufnr: integer): nil

---@param props                         fml.ui.search.preview.IProps
---@return fml.ui.search.Preview
function M.new(props)
  local self = setmetatable({}, M)

  local state = props.state ---@type fml.types.ui.search.IState
  local render = props.render ---@type fun(bufnr: integer): nil
  local update = props.update or render ---@type fun(bufnr: integer): nil

  self.state = state
  self._render = render
  self._update = update

  return self
end

---@return nil
function M:create_buf_as_needed()
  if self._bufnr ~= nil and vim.api.nvim_buf_is_valid(self._bufnr) then
    return self._bufnr
  end

  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._bufnr = bufnr

  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nowrite"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
end

---@return nil
function M:destroy()
  local bufnr = self._bufnr ---@type integer|nil
  self._bufnr = nil

  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
end

---@param force                         ?boolean
---@return nil
function M:render(force)
  local state = self.state ---@type fml.types.ui.search.IState

  if force then
    state.dirty_preview:next(true)
  end

  if self._bufnr == nil or not vim.api.nvim_buf_is_valid(self._bufnr) then
    self._bufnr = nil
    state.dirty_preview:next(true)
  end
end

return M
