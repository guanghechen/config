local BatchDisposable = fml.collection.BatchDisposable
local ReplaceState = require("ghc.command.replace.state")
local ReplaceViewer = require("ghc.command.replace.viewer")

---@class ghc.command.replace.Replacer
---@field private state                 ghc.command.replace.State
---@field private view                  ghc.command.replace.Viewer
---@field private winnr                 integer
---@field private nsnr                  integer
---@field private reuse                 boolean
---@field private batch_disposable      fml.types.collection.IBatchDisposable
local M = {}
M.__index = M

---@class ghc.command.replace.replacer.IProps
---@field public  data                  ghc.types.command.replace.IStateData
---@field public  nsnr                  integer
---@field public  winnr                 integer
---@field public  reuse                 ?boolean

---@param opts                          ghc.command.replace.replacer.IProps
---@return ghc.command.replace.Replacer
function M.new(opts)
  local self = setmetatable({}, M)

  local nsnr = opts.nsnr ---@type integer
  local winnr = opts.winnr ~= nil and opts.winnr or 0 ---@type integer
  local reuse = not not opts.reuse ---@type boolean
  local batch_disposable = BatchDisposable.new()

  local state ---@type ghc.command.replace.State
  state = ReplaceState.new({
    initial_data = opts.data,
    on_changed = function()
      self:replace()
    end,
  })

  local view = ReplaceViewer.new({ state = state, nsnr = nsnr })

  self.state = state
  self.view = view
  self.nsnr = nsnr
  self.winnr = winnr
  self.reuse = reuse
  self.batch_disposable = batch_disposable

  return self
end

---@return integer|nil
function M:get_bufnr()
  return self.view:get_bufnr()
end

---@param opts                          ?{ force?: boolean }
---@return nil
function M:replace(opts)
  opts = opts or {}
  local force = not not opts.force ---@type boolean
  self.view:render({ winnr = self.winnr, force = force, reuse = self.reuse })
end

return M
