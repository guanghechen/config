---@diagnostic disable: invisible
---@diagnostic disable-next-line: unused-local
local __module_name__ = "stl.c.future" ---@type string

---@alias stl.c.future.State
---| "pending"
---| "resolved"
---| "rejected"
---| "cancelled"

---@alias stl.c.future.Executor fun(resolve: fun(result: any): nil, reject: fun(err: string): nil): nil

---@class stl.c.future.IProps
---@field public token                  ?stl.c.CancellationToken

---@class stl.c.Future : stl.c.IDisposable
---@field protected _state              stl.c.future.State
---@field protected _result             any
---@field protected _error              ?string
---@field protected _listeners          fun(ok: boolean, result: any)[]
---@field protected _token              ?stl.c.CancellationToken
---@field protected _cancel_sub         ?stl.c.IUnsubscribable
local M = {}
M.__index = M

---Create a new Future.
---ES Promise-compatible: new(executor) where executor receives (resolve, reject)
---Also supports: new(props) for backward compatibility
---@overload fun(executor: stl.c.future.Executor): stl.c.Future
---@overload fun(props: stl.c.future.IProps): stl.c.Future
---@param executor_or_props             ?stl.c.future.Executor|stl.c.future.IProps
---@return stl.c.Future
function M.new(executor_or_props)
  local self = setmetatable({}, M)
  self._state = "pending"
  self._result = nil
  self._error = nil
  self._listeners = {}

  local executor ---@type stl.c.future.Executor|nil
  local props ---@type stl.c.future.IProps|nil

  if type(executor_or_props) == "function" then
    executor = executor_or_props
  elseif type(executor_or_props) == "table" then
    props = executor_or_props
  end

  self._token = props and props.token or nil

  if self._token then
    self._cancel_sub = self._token:on_cancel(function()
      self:__cancel__() ---@diagnostic disable-line: invisible
    end)
  end

  if executor then
    local function resolve(result)
      self:__resolve__(result) ---@diagnostic disable-line: invisible
    end
    local function reject(err)
      self:__reject__(err) ---@diagnostic disable-line: invisible
    end
    local ok, err = pcall(executor, resolve, reject)
    if not ok then
      self:__reject__(err or "Unknown error") ---@diagnostic disable-line: invisible
    end
  end

  return self
end

---Create a new Future with resolver function for external resolution.
---@param props                         ?stl.c.future.IProps
---@return stl.c.Future
---@return fun(result: any): nil resolver
function M.new_with_resolver(props)
  local self = M.new(props)
  local function resolver(result)
    self:__resolve__(result) ---@diagnostic disable-line: invisible
  end
  return self, resolver
end

---Create a resolved Future with the given result.
---@param result                        any
---@return stl.c.Future
function M.resolve(result)
  local future = M.new()
  future:__resolve__(result)
  return future
end

---Create a rejected Future with the given error.
---@param err                           string
---@return stl.c.Future
function M.reject(err)
  local future = M.new()
  future:__reject__(err)
  return future
end

---Check if the future is done (resolved, rejected, or cancelled).
---@return boolean
function M:is_done()
  return self._state ~= "pending"
end

---Check if the future was cancelled.
---@return boolean
function M:is_cancelled()
  return self._state == "cancelled"
end

---Check if the future failed (rejected or cancelled).
---@return boolean
function M:is_failed()
  return self._state == "rejected" or self._state == "cancelled"
end

---Check if the future resolved successfully.
---@return boolean
function M:is_resolved()
  return self._state == "resolved"
end

---Get the result if resolved, nil otherwise.
---@return any
function M:get_result()
  return self._result
end

---Get the error if rejected/cancelled, nil otherwise.
---@return string|nil
function M:get_error()
  return self._error
end

---Register a callback to be called when the future settles.
---@param callback                      fun(ok: boolean, result: any): nil
---@return nil
function M:finally(callback)
  if self:is_done() then
    -- Branch on the state rather than falling back with `or`: a future resolved with `false` or
    -- `nil` would otherwise hand the callback the error slot, so the same future delivered
    -- different values depending on whether the callback subscribed before or after it settled.
    if self._state == "resolved" then
      pcall(callback, true, self._result)
    else
      pcall(callback, false, self._error)
    end
  else
    self._listeners[#self._listeners + 1] = callback
  end
end

---Await the future result. Must be called from an async context.
---@async
---@return any
function M:await()
  if self:is_done() then
    if self._state == "resolved" then
      return self._result
    else
      error(self._error or "Future rejected", 0)
    end
  end

  -- Yield and wait for resolution via stl.async.await
  -- Note: stl.async.await wraps the callback to add nil prefix automatically,
  -- so we should call callback(result) for success or error(err) for errors.
  return stl.async.await(function(callback)
    self:finally(function(ok, result)
      if ok then
        callback(result)
      else
        error(result or "Future rejected", 0)
      end
    end)
  end)
end

---IDisposable implementation: check if disposed.
---@return boolean
function M:isdisposed()
  return self:is_done()
end

---IDisposable implementation: dispose by cancelling.
---@return boolean
function M:dispose()
  if self._token then
    self._token:cancel()
    return true
  end
  return false
end

---Chain a callback to be called when this future settles.
---Returns a new Future that resolves with the callback's return value.
---@param on_resolved                   ?fun(result: any): any
---@param on_rejected                   ?fun(error: string): any
---@return stl.c.Future
function M:then_(on_resolved, on_rejected)
  local next_future = M.new()

  self:finally(function(ok, result)
    local handler ---@type (fun(x: any): any)|nil
    if ok then
      handler = on_resolved
    else
      handler = on_rejected
    end

    if not handler then
      if ok then
        next_future:__resolve__(result)
      else
        next_future:__reject__(result)
      end
      return
    end

    local success, value = pcall(handler, result)
    if not success then
      next_future:__reject__(value)
      return
    end

    if type(value) == "table" and value.__index == M then
      ---@cast value stl.c.Future
      value:finally(function(inner_ok, inner_result)
        if inner_ok then
          next_future:__resolve__(inner_result)
        else
          next_future:__reject__(inner_result)
        end
      end)
    else
      next_future:__resolve__(value)
    end
  end)

  return next_future
end

---Catch errors from this future.
---Equivalent to then_(nil, on_rejected).
---@param on_rejected                   fun(error: string): any
---@return stl.c.Future
function M:catch(on_rejected)
  return self:then_(nil, on_rejected)
end

---Map the result of this future.
---Equivalent to then_(fn, nil).
---@param fn                            fun(result: any): any
---@return stl.c.Future
function M:map(fn)
  return self:then_(fn, nil)
end

---Wait for all futures to resolve.
---Returns a Future that resolves with an array of results.
---Rejects immediately if any future rejects.
---@param futures                       stl.c.Future[]
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future
function M.all(futures, token)
  local result_future = M.new({ token = token })
  local count = #futures

  if count == 0 then
    result_future:__resolve__({})
    return result_future
  end

  local results = {} ---@type any[]
  local pending = count
  local settled = false

  for i, future in ipairs(futures) do
    future:finally(function(ok, result)
      if settled then
        return
      end

      if not ok then
        settled = true
        result_future:__reject__(result)
        return
      end

      results[i] = result
      pending = pending - 1

      if pending == 0 then
        settled = true
        result_future:__resolve__(results)
      end
    end)
  end

  return result_future
end

---Return the result of the first future to settle.
---@param futures                       stl.c.Future[]
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future
function M.race(futures, token)
  local result_future = M.new({ token = token })
  local count = #futures

  if count == 0 then
    return result_future
  end

  local settled = false

  for _, future in ipairs(futures) do
    future:finally(function(ok, result)
      if settled then
        return
      end
      settled = true

      if ok then
        result_future:__resolve__(result)
      else
        result_future:__reject__(result)
      end
    end)
  end

  return result_future
end

---Return the result of the first future to resolve successfully.
---Rejects with "All futures rejected" if all futures reject.
---@param futures                       stl.c.Future[]
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future
function M.any(futures, token)
  local result_future = M.new({ token = token })
  local count = #futures

  if count == 0 then
    result_future:__reject__("All futures rejected")
    return result_future
  end

  local pending = count
  local settled = false

  for _, future in ipairs(futures) do
    future:finally(function(ok, result)
      if settled then
        return
      end

      if ok then
        settled = true
        result_future:__resolve__(result)
        return
      end

      pending = pending - 1
      if pending == 0 then
        settled = true
        result_future:__reject__("All futures rejected")
      end
    end)
  end

  return result_future
end

---@class stl.c.future.ISettledResult
---@field public status                 "fulfilled"|"rejected"
---@field public value                  ?any
---@field public reason                 ?string

---Wait for all futures to settle (resolve or reject).
---Returns a Future that resolves with an array of results, never rejects.
---Each result has { status = "fulfilled", value = ... } or { status = "rejected", reason = ... }
---@param futures                       stl.c.Future[]
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future
function M.allSettled(futures, token)
  local result_future = M.new({ token = token })
  local count = #futures

  if count == 0 then
    result_future:__resolve__({})
    return result_future
  end

  local results = {} ---@type stl.c.future.ISettledResult[]
  local pending = count

  for i, future in ipairs(futures) do
    future:finally(function(ok, result)
      if ok then
        results[i] = { status = "fulfilled", value = result }
      else
        results[i] = { status = "rejected", reason = result }
      end

      pending = pending - 1
      if pending == 0 then
        result_future:__resolve__(results)
      end
    end)
  end

  return result_future
end

----------------------------------------------------------------------------------------------------

---Resolve the future with a result. Internal use only.
---@protected
---@param result                        any
---@return nil
function M:__resolve__(result)
  if self._state ~= "pending" then
    return
  end
  self._state = "resolved"
  self._result = result
  self:__cleanup__()
  self:__notify_listeners__(true, result)
end

---Reject the future with an error. Internal use only.
---@protected
---@param err                           string
---@return nil
function M:__reject__(err)
  if self._state ~= "pending" then
    return
  end
  self._state = "rejected"
  self._error = err
  self:__cleanup__()
  self:__notify_listeners__(false, err)
end

---Cancel the future. Internal use only.
---@protected
---@return nil
function M:__cancel__()
  if self._state ~= "pending" then
    return
  end
  self._state = "cancelled"
  self._error = "Operation cancelled"
  self:__cleanup__()
  self:__notify_listeners__(false, self._error)
end

---Cleanup token subscription. Internal use only.
---@protected
---@return nil
function M:__cleanup__()
  if self._cancel_sub then
    self._cancel_sub:unsubscribe()
    self._cancel_sub = nil
  end
end

---Notify all listeners. Internal use only.
---@protected
---@param ok                            boolean
---@param result                        any
---@return nil
function M:__notify_listeners__(ok, result)
  for _, listener in ipairs(self._listeners) do
    pcall(listener, ok, result)
  end
  self._listeners = {}
end

return M
