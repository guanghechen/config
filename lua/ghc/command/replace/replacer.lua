local Disposable = fml.collection.Disposable
local BatchDisposable = fml.collection.BatchDisposable
local ReplaceViewer = require("ghc.command.replace.viewer")
local state = require("ghc.command.replace.state")

---@class ghc.command.replace.Replacer
---@field private view                  ghc.command.replace.Viewer
---@field private winnr                 integer
---@field private reuse                 boolean
---@field private batch_disposable      fml.types.collection.IBatchDisposable
local M = {}
M.__index = M

---@class ghc.command.replace.replacer.IProps
---@field public winnr                  integer
---@field public reuse                  ?boolean

---@class ghc.command.replace.replacer.IOpenParams
---@field public mode                   ?ghc.enums.command.replace.Mode
---@field public winnr                  ?integer
---@field public reuse                  ?boolean
---@field public force                  ?boolean

---@param props                          ghc.command.replace.replacer.IProps
---@return ghc.command.replace.Replacer
function M.new(props)
  local self = setmetatable({}, M)

  local winnr = props.winnr ~= nil and props.winnr or 0 ---@type integer
  local reuse = not not props.reuse ---@type boolean
  local batch_disposable = BatchDisposable.new()
  local view = ReplaceViewer.new()

  self.view = view
  self.winnr = winnr
  self.reuse = reuse
  self.batch_disposable = batch_disposable

  ---@type fml.types.collection.IUnsubscribable
  local unsubscribable_1 = state.watch_search_changes(function()
    local bufnr = self:get_bufnr()
    if bufnr and fml.api.buf.is_visible(bufnr) then
      self:open()
    end
  end)
  batch_disposable:add_disposable(Disposable.from_unsubscribable(unsubscribable_1))

  ---@type fml.types.collection.IUnsubscribable
  local unsubscribable_2 = state.watch_replace_changes(function()
    local bufnr = self:get_bufnr()
    if bufnr and fml.api.buf.is_visible(bufnr) then
      self:open()
    end
  end)
  batch_disposable:add_disposable(Disposable.from_unsubscribable(unsubscribable_2))

  return self
end

---@return integer|nil
function M:get_bufnr()
  return self.view:get_bufnr()
end

---@param params                        ?ghc.command.replace.replacer.IOpenParams
---@return nil
function M:open(params)
  params = params or {}
  local mode = params.mode ---@type ghc.enums.command.replace.Mode|nil
  local winnr = params.winnr or self.winnr ---@type integer
  local reuse = not not params.reuse ---@type boolean
  local force = not not params.force ---@type boolean

  state.set_mode(mode)
  self.view:render({ winnr = winnr, force = force, reuse = reuse })
end

return M
