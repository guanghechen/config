local ReplaceState = require("kyokuya.replace.state")
local ReplaceView = require("kyokuya.replace.view")
local util_observable = require("guanghechen.util.observable")

---@class kyokuya.replace.IReplacerOptions
---@field public  data   kyokuya.replace.IReplaceStateData|guanghechen.observable.Observable
---@field public  nsnr   integer
---@field public  winnr  integer
---@field public  reuse? boolean

---@class kyokuya.replace.Replacer
---@field private state  kyokuya.replace.ReplaceState
---@field private view   kyokuya.replace.ReplaceView
---@field private winnr  integer
---@field private nsnr   integer
---@field private reuse  boolean
---@field private batch_disposable fml.types.collection.IBatchDisposable
local M = {}
M.__index = M

---@param opts kyokuya.replace.IReplacerOptions
---@return kyokuya.replace.Replacer
function M.new(opts)
  local self = setmetatable({}, M)

  local nsnr = opts.nsnr ---@type integer
  local winnr = opts.winnr ~= nil and opts.winnr or 0 ---@type integer
  local reuse = not not opts.reuse ---@type boolean
  local batch_disposable = fml.collection.BatchDisposable.new()

  local state ---@type kyokuya.replace.ReplaceState
  if util_observable.is_observable(opts.data) then
    local observable = opts.data
    ---@cast observable  guanghechen.observable.Observable
    state = ReplaceState.new({
      initial_data = observable:get_snapshot(),
      on_changed = function()
        local next_data = state:get_data()
        observable:next(next_data)
        self:replace()
      end,
    })

    local subscriber = fml.collection.Subscriber.new({
      on_next = function(next_data)
        state:set_data(next_data)
      end,
    })
    local unsubscribable = observable:subscribe(subscriber)
    batch_disposable:add_disposable(fml.collection.Disposable.new({
      on_dispose = function()
        unsubscribable:unsubscribe()
      end
    }))
  else
    local data = opts.data
    ---@cast data kyokuya.replace.IReplaceStateData
    state = ReplaceState.new({
      initial_data = data,
      on_changed = function()
        self:replace()
      end,
    })
  end

  local view = ReplaceView.new({ state = state, nsnr = nsnr })

  self.state = state
  self.view = view
  self.nsnr = nsnr
  self.winnr = winnr
  self.reuse = reuse
  self.batch_disposable = batch_disposable

  return self
end

function M:is_disposed()
  return self.batch_disposable:is_disposed()
end

function M:dispose()
  if not self:is_disposed() then
    self.batch_disposable:dispose()
  end
end

---@return integer|nil
function M:get_bufnr()
  return self.view:get_bufnr()
end

---@param opts ?{ force?: boolean }
---@return nil
function M:replace(opts)
  opts = opts or {}
  local force = not not opts.force ---@type boolean
  self.view:render({ winnr = self.winnr, force = force, reuse = self.reuse })
end

return M
