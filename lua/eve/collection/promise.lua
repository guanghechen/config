local reporter = require("eve.std.reporter")

---@class eve.collection.Promise: t.eve.collection.IPromise
---@protected _callbacks                t.eve.collection.promise.ICallback[]
---@protected _settled                  t.eve.collection.promise.ISettled|nil
---@protected _reason                   unknown|nil
---@protected _result                   unknown|nil
local M = {}
M.__index = M

---@param fn                            fun(resolve: t.eve.collection.promise.IResolve, reject: t.eve.collection.promise.IReject): nil
---@return eve.collection.Promise
function M.new(fn)
  local self = setmetatable({}, M)

  local callbacks = {} ---@type t.eve.collection.promise.ICallback[]

  ---@param value                       unknown
  ---@return nil
  local function resolve(value)
    if self._settled ~= nil then
      reporter.error({
        from = "eve.collection.promise",
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
        from = "eve.collection.promise",
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
        from = "eve.collection.promise",
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
---@return eve.collection.Promise
function M.resolve(value)
  return M.new(function(resolve)
    resolve(value)
  end)
end

---@param reason                        unknown
---@return eve.collection.Promise
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

---@param on_fulfilled                  t.eve.collection.promise.IOnFulfilled
---@return eve.collection.Promise
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

  local _resolve ---@type t.eve.collection.promise.IResolve
  local _reject ---@type t.eve.collection.promise.IReject
  local promise = M.new(function(resolve, reject)
    _resolve = resolve
    _reject = reject
  end)

  ---@type t.eve.collection.promise.ICallback
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

---@param on_rejected                  t.eve.collection.promise.IOnRejected
---@return eve.collection.Promise
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

  local _resolve ---@type t.eve.collection.promise.IResolve
  local promise = M.new(function(resolve)
    _resolve = resolve
  end)

  ---@type t.eve.collection.promise.ICallback
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

---@param on_finally                  t.eve.collection.promise.IOnFinally
---@return eve.collection.Promise
function M:xfinally(on_finally)
  if self._settled ~= nil then
    return M.new(function(resolve)
      resolve(on_finally(self._result, self._reason))
    end)
  end

  local _resolve ---@type t.eve.collection.promise.IResolve
  local promise = M.new(function(resolve)
    _resolve = resolve
  end)
  ---@type t.eve.collection.promise.ICallback
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
