local __module_name__ = "eve.lib.collection.promise" ---@type string

local reporter = require("eve.lib.reporter")

---@class eve.lib.collection.IPromise
---@field public resolve                fun(value: unknown): eve.lib.collection.IPromise
---@field public reject                 fun(reason: unknown): eve.lib.collection.IPromise
---@field public settled                fun(self: eve.lib.collection.IPromise): boolean
---@field public snapshot               fun(self: eve.lib.collection.IPromise): unknown, unknown
---@field public xthen                  fun(self: eve.lib.collection.IPromise, on_fulfilled: eve.lib.collection.promise.IOnFulfilled): eve.lib.collection.IPromise
---@field public xcatch                 fun(self: eve.lib.collection.IPromise, on_rejected: eve.lib.collection.promise.IOnRejected): eve.lib.collection.IPromise
---@field public xfinally               fun(self: eve.lib.collection.IPromise, on_finally: eve.lib.collection.promise.IOnFinally): eve.lib.collection.IPromise

---@alias eve.lib.collection.promise.ISettled
---| 'fulfilled'
---|'rejected'

---@alias eve.lib.collection.promise.IOnFulfilled
---| fun(value: unknown): unknown

---@alias eve.lib.collection.promise.IOnRejected
---| fun(reason: unknown): unknown

---@alias eve.lib.collection.promise.IOnFinally
---| fun(settled: eve.lib.collection.promise.ISettled, value: unknown|nil, reason: unknown|nil): nil

---@alias eve.lib.collection.promise.IResolve
---| fun(value: unknown): nil

---@alias eve.lib.collection.promise.IReject
---| fun(reason: unknown): nil

---@class eve.lib.collection.promise.ICallback
---@field public type                   'fulfilled'|'rejected'|'finally'
---@field public callback               fun(): nil

---@class eve.lib.collection.Promise: eve.lib.collection.IPromise
---@protected _callbacks                eve.lib.collection.promise.ICallback[]
---@protected _settled                  eve.lib.collection.promise.ISettled|nil
---@protected _reason                   unknown|nil
---@protected _result                   unknown|nil
local M = {}
M.__index = M

---@param fn                            fun(resolve: eve.lib.collection.promise.IResolve, reject: eve.lib.collection.promise.IReject): nil
---@return eve.lib.collection.Promise
function M.new(fn)
  local self = setmetatable({}, M)

  local callbacks = {} ---@type eve.lib.collection.promise.ICallback[]

  ---@param value                       unknown
  ---@return nil
  local function resolve(value)
    if self._settled ~= nil then
      reporter.error({
        from = __module_name__,
        subject = "new#resolve",
        message = "Promise is already settled.",
        details = { value = value },
      })
      return
    end

    self._settled = "fulfilled"
    self._result = value

    for _, callback in ipairs(callbacks) do
      if callback.type == "fulfilled" or callback.type == "finally" then
        callback.callback()
      end
    end
  end

  ---@param reason                      unknown
  ---@return nil
  local function reject(reason)
    if self._settled ~= nil then
      reporter.error({
        from = __module_name__,
        subject = "new#reject",
        message = "Promise is already settled.",
        details = { reason = reason },
      })
      return
    end

    self._settled = "rejected"
    self._reason = reason

    local has_catched = false ---@type boolean
    for _, callback in ipairs(callbacks) do
      if callback.type == "rejected" or callback.type == "finally" then
        has_catched = true
        callback.callback()
      end
    end

    if not has_catched then
      reporter.error({
        from = __module_name__,
        subject = "new#reject",
        message = "Uncatched promise rejection.",
        details = { reason = reason },
      })
    end
  end

  self._callbacks = callbacks
  self._settled = nil

  fn(resolve, reject)

  return self
end

---@param value                         unknown
---@return eve.lib.collection.Promise
function M.resolve(value)
  return M.new(function(resolve)
    resolve(value)
  end)
end

---@param reason                        unknown
---@return eve.lib.collection.Promise
function M.reject(reason)
  return M.new(function(_, reject)
    reject(reason)
  end)
end

---@return boolean
function M:settled()
  return self._settled ~= nil
end

---@return unknown
---@return unknown
function M:snapshot()
  return self._result, self._reason
end

---@param on_fulfilled                  eve.lib.collection.promise.IOnFulfilled
---@return eve.lib.collection.Promise
function M:xthen(on_fulfilled)
  if self._settled ~= nil then
    return M.new(function(resolve, reject)
      if self._settled == "fulfilled" then
        resolve(on_fulfilled(self._result))
      elseif self._settled == "rejected" then
        reject(self._reason)
      end
    end)
  end

  local _resolve ---@type eve.lib.collection.promise.IResolve
  local _reject ---@type eve.lib.collection.promise.IReject
  local promise = M.new(function(resolve, reject)
    _resolve = resolve
    _reject = reject
  end)

  ---@type eve.lib.collection.promise.ICallback
  local callback = {
    type = "fulfilled",
    callback = function()
      if self._settled == "fulfilled" then
        _resolve(on_fulfilled(self._result))
      elseif self._settled == "rejected" then
        _reject(self._reason)
      end
    end,
  }
  self._callbacks[#self._callbacks + 1] = callback
  return promise
end

---@param on_rejected                  eve.lib.collection.promise.IOnRejected
---@return eve.lib.collection.Promise
function M:xcatch(on_rejected)
  if self._settled ~= nil then
    return M.new(function(resolve)
      if self._settled == "fulfilled" then
        resolve(self._result)
      elseif self._settled == "rejected" then
        resolve(on_rejected(self._reason))
      end
    end)
  end

  local _resolve ---@type eve.lib.collection.promise.IResolve
  local promise = M.new(function(resolve)
    _resolve = resolve
  end)

  ---@type eve.lib.collection.promise.ICallback
  local callback = {
    type = "rejected",
    callback = function()
      if self._settled == "fulfilled" then
        _resolve(self._result)
      elseif self._settled == "rejected" then
        _resolve(on_rejected(self._reason))
      end
    end,
  }
  self._callbacks[#self._callbacks + 1] = callback
  return promise
end

---@param on_finally                  eve.lib.collection.promise.IOnFinally
---@return eve.lib.collection.Promise
function M:xfinally(on_finally)
  if self._settled ~= nil then
    return M.new(function(resolve)
      resolve(on_finally(self._result, self._reason))
    end)
  end

  local _resolve ---@type eve.lib.collection.promise.IResolve
  local promise = M.new(function(resolve)
    _resolve = resolve
  end)
  ---@type eve.lib.collection.promise.ICallback
  local callback = {
    type = "finally",
    callback = function()
      _resolve(on_finally(self._settled, self._result, self._reason))
    end,
  }
  self._callbacks[#self._callbacks + 1] = callback
  return promise
end

return M
