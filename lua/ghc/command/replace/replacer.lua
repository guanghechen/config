local BatchDisposable = fml.collection.BatchDisposable
local ReplaceState = require("ghc.command.replace.state")
local ReplaceViewer = require("ghc.command.replace.viewer")

---@class ghc.command.replace.Replacer
---@field public  state                 ghc.command.replace.State
---@field private view                  ghc.command.replace.Viewer
---@field private winnr                 integer
---@field private reuse                 boolean
---@field private batch_disposable      fml.types.collection.IBatchDisposable
local M = {}
M.__index = M

---@class ghc.command.replace.replacer.IProps
---@field public data                   ghc.types.command.replace.IStateData
---@field public winnr                  integer
---@field public reuse                  ?boolean
---@field public on_changed             ?fun(ghc.command.replace.State): nil

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
  local on_changed = props.on_changed

  ---@type ghc.command.replace.State
  local state = ReplaceState.new({
    initial_data = props.data,
    on_changed = function(s)
      self:open({ mode = s:get_value("mode") })
      if on_changed then
        on_changed(s)
      end
    end,
  })

  local view = ReplaceViewer.new({ state = state })

  self.state = state
  self.view = view
  self.winnr = winnr
  self.reuse = reuse
  self.batch_disposable = batch_disposable

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
  local mode = params.mode ---@type ghc.enums.command.replace.Mode
  local winnr = params.winnr or self.winnr ---@type integer
  local reuse = not not params.reuse ---@type boolean
  local force = not not params.force ---@type boolean

  self.state:set_value("mode", mode)
  self.view:render({ winnr = winnr, force = force, reuse = reuse })
end

return M
