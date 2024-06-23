local ReplaceState = require("kyokuya.replace.state")
local ReplaceView = require("kyokuya.replace.view")

---@class kyokuya.replace.IReplacerOptions
---@field public  data                  kyokuya.replace.IReplaceStateData
---@field public  nsnr                  integer
---@field public  winnr                 integer
---@field public  reuse                 ?boolean

---@class kyokuya.replace.Replacer
---@field private state                 kyokuya.replace.ReplaceState
---@field private view                  kyokuya.replace.ReplaceView
---@field private winnr                 integer
---@field private nsnr                  integer
---@field private reuse                 boolean
---@field private batch_disposable      fml.types.collection.IBatchDisposable
local M = {}
M.__index = M

---@param opts                          kyokuya.replace.IReplacerOptions
---@return kyokuya.replace.Replacer
function M.new(opts)
  local self = setmetatable({}, M)

  local nsnr = opts.nsnr ---@type integer
  local winnr = opts.winnr ~= nil and opts.winnr or 0 ---@type integer
  local reuse = not not opts.reuse ---@type boolean
  local batch_disposable = fml.collection.BatchDisposable.new()

  local state ---@type kyokuya.replace.ReplaceState
  state = ReplaceState.new({
    initial_data = opts.data,
    on_changed = function()
      self:replace()
    end,
  })

  local view = ReplaceView.new({ state = state, nsnr = nsnr })

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
