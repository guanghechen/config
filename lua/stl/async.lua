---@class stl.async
---@field public scheduler              async fun()
local M = {}

local yield_marker = {}

----------------------------------------------------------------------------------------------------

---@param thread                      thread
---@param ...                         any
local function resume(thread, ...)
  ---@type [boolean, {}, string|fun(callback: fun(...))]
  local ret = { coroutine.resume(thread, ...) }
  local stat = ret[1]

  if not stat then
    error(debug.traceback(thread, ret[2]), 0)
  elseif coroutine.status(thread) == "dead" then
    return
  end

  local marker, fn = ret[2], ret[3]

  assert(type(fn) == "function", "type error :: expected func")

  if marker ~= yield_marker or not vim.is_callable(fn) then
    return error("Unexpected coroutine.yield")
  end

  local ok, perr = pcall(fn, function(...)
    resume(thread, ...)
  end)
  if not ok then
    resume(thread, perr)
  end
end

---@param err                         any
---@param ...                         any
---@return any ...
local function check(err, ...)
  if err then
    error(err, 0)
  end
  return ...
end

----------------------------------------------------------------------------------------------------

---Executes a future with a callback when it is done.
---@param async_fn                    async fun()
---@param ...                         any
function M.run(async_fn, ...)
  resume(coroutine.create(async_fn), ...)
end

---@async
---@param argc                        integer|function
---@param func                        ?function
---@param ...                         any
---@return any ...
function M.await(argc, func, ...)
  if type(argc) == "function" then
    func = argc
    argc = 1
  end
  local nargs, args = select("#", ...), { ... }
  return check(coroutine.yield(yield_marker, function(callback)
    args[argc] = function(...)
      callback(nil, ...)
    end
    nargs = math.max(nargs, argc)
    return func(unpack(args, 1, nargs)) ---@diagnostic disable-line: need-check-nil
  end))
end

---Creates an async function with a callback style function.
---@param argc                        integer|function The number of arguments of func. Must be included.
---@param func                        ?function A callback style function to be converted. The last argument must be the callback.
---@return async fun(...): any
---@overload fun(func: function): async fun()
function M.wrap(argc, func)
  if type(argc) == "function" then
    func = argc
    argc = 1
  end
  assert(type(argc) == "number")
  assert(type(func) == "function")
  ---@async
  return function(...)
    return M.await(argc, func, ...)
  end
end

---An async function that when called will yield to the Neovim scheduler to be
---able to call the API.
M.scheduler = M.wrap(vim.schedule)

----------------------------------------------------------------------------------------------------
-- Future utilities
----------------------------------------------------------------------------------------------------

---Await all futures in parallel and return their results.
---All futures must complete successfully, or the first error is propagated.
---@async
---@param futures                       stl.c.Future[]
---@return any[]
function M.await_all(futures)
  local results = {} ---@type any[]
  for i, future in ipairs(futures) do
    results[i] = future:await()
  end
  return results
end

---Await any future and return the first result with its index.
---@async
---@param futures                       stl.c.Future[]
---@return any result                   Result from first completed future
---@return integer index                Index of completed future
function M.await_any(futures)
  return M.await(function(callback)
    local resolved = false
    for i, future in ipairs(futures) do
      future:finally(function(ok, result)
        if resolved then
          return
        end
        resolved = true
        if ok then
          callback(nil, result, i)
        else
          callback(result)
        end
      end)
    end
  end)
end

---Convert a callback-style async function to a Future-returning function.
---The async function must have signature: (args..., callback) -> cancel_fn|nil
---The returned function has signature: (args..., token?) -> Future
---
---Example:
---  -- For a callback-style function: some_async_fn(arg1, arg2, callback) -> cancel_fn
---  local some_fn = stl.async.futurify(some_async_fn)
---  local future = some_fn(arg1, arg2, token)
---
---@generic T
---@param async_fn                       fun(...: any, callback: fun(result: T)): (fun())|nil
---@return fun(...: any, token: stl.c.CancellationToken|nil): stl.c.Future
function M.futurify(async_fn)
  return function(...) ---@return stl.c.Future
    local args = { ... }
    local nargs = select("#", ...)

    -- Detect if the last argument is a CancellationToken
    local token = args[nargs] ---@type stl.c.CancellationToken|nil
    if token and type(token) == "table" and type(token.is_cancelled) == "function" then
      nargs = nargs - 1
    else
      token = nil
    end

    local future = stl.c.Future.new({ token = token })
    if token and token:is_cancelled() then
      return future
    end

    -- Insert callback at the end
    args[nargs + 1] = function(result)
      future:__resolve__(result) ---@diagnostic disable-line: invisible
    end

    ---@diagnostic disable-next-line: need-check-nil
    local cancel_fn = async_fn(unpack(args, 1, nargs + 1)) ---@type (fun())|nil
    if cancel_fn ~= nil and token then
      token:on_cancel(cancel_fn)
    end

    return future
  end
end

---Convert a callback-style async function with multiple callback arguments to a Future.
---The callback receives multiple values which are packed into a table.
---
---Example:
---  -- For: some_async_fn(cwd, callback) where callback(result1, result2)
---  local some_fn = stl.async.futurify_multi(2, some_async_fn)
---  local future = some_fn(cwd, token)
---  -- future resolves with { result1, result2 }
---
---@param callback_argc                   integer Number of arguments the callback receives
---@param async_fn                        function
---@return fun(...: any, token: stl.c.CancellationToken|nil): stl.c.Future
function M.futurify_multi(callback_argc, async_fn)
  return function(...) ---@return stl.c.Future
    local args = { ... }
    local nargs = select("#", ...)

    -- Detect if the last argument is a CancellationToken
    local token = args[nargs] ---@type stl.c.CancellationToken|nil
    if token and type(token) == "table" and type(token.is_cancelled) == "function" then
      nargs = nargs - 1
    else
      token = nil
    end

    local future = stl.c.Future.new({ token = token })
    if token and token:is_cancelled() then
      return future
    end

    -- Insert callback at the end that packs multiple args
    args[nargs + 1] = function(...)
      local result = { ... }
      -- Truncate to expected argc to avoid trailing nils
      for i = callback_argc + 1, #result do
        result[i] = nil
      end
      future:__resolve__(result) ---@diagnostic disable-line: invisible
    end

    local cancel_fn = async_fn(unpack(args, 1, nargs + 1))
    if cancel_fn and token then
      token:on_cancel(cancel_fn)
    end

    return future
  end
end

---Create a Future from a callback-style function that returns a cancel_fn.
---The returned function creates a new Future each time it's called.
---@deprecated Use futurify() or futurify_multi() instead
---@param argc                          integer
---@param func                          function
---@return fun(...): stl.c.Future
function M.to_future(argc, func)
  ---@return stl.c.Future
  return function(...)
    local future, resolver = stl.c.Future.new_with_resolver()
    local args = { ... }
    local nargs = select("#", ...)

    args[argc] = function(...)
      resolver({ ... })
    end
    nargs = math.max(nargs, argc)

    local cancel_fn = func(unpack(args, 1, nargs))
    if cancel_fn then
      -- Store cancel_fn for potential cleanup
      rawset(future, "_external_cancel", cancel_fn)
    end

    return future
  end
end

---Create a Future from a callback-style function with CancellationToken support.
---@param argc                          integer
---@param func                          function
---@param token                         ?stl.c.CancellationToken
---@return fun(...): stl.c.Future
function M.to_future_cancellable(argc, func, token)
  ---@return stl.c.Future
  return function(...)
    local future, resolver = stl.c.Future.new_with_resolver({ token = token })
    if token and token:is_cancelled() then
      return future -- Already cancelled
    end

    local args = { ... }
    local nargs = select("#", ...)

    args[argc] = function(...)
      resolver({ ... })
    end
    nargs = math.max(nargs, argc)

    local cancel_fn = func(unpack(args, 1, nargs))
    if cancel_fn and token then
      token:on_cancel(function()
        cancel_fn()
      end)
    end

    return future
  end
end

----------------------------------------------------------------------------------------------------

local TARGET_MIN_FPS = 120
local TARGET_FRAME_TIME_NS = 10 ^ 9 / TARGET_MIN_FPS

local AUTO_ITER_THRESHOLD = 100

---Automatically yield an async thread after a certain amount of time.
---@async
---@param start_time                  integer
---@return integer new_start_time
function M.event_control(start_time)
  local duration = vim.uv.hrtime() - start_time
  if duration > TARGET_FRAME_TIME_NS then
    M.scheduler()
    return vim.uv.hrtime()
  end
  return start_time
end

---Async version of `ipairs` which internally calls async.event_control between
---iterations.
---@async
---@generic T
---@param a                           T[]
---@return fun(): integer, T
---@return any
---@return integer
function M.ipairs(a)
  local start_time = vim.uv.hrtime()

  ---@async
  ---@param i                         integer
  ---@return integer|nil
  ---@return any
  local function iter(_, i)
    start_time = M.event_control(start_time)
    i = i + 1
    local v = a[i]
    if v then
      return i, v
    end
  end

  return iter, a, 0
end

---Async version of `pairs` which internally calls async.event_control between
---iterations.
---@async
---@generic K, V
---@param t                           table<K, V>
---@return fun(): K, V
---@return any
---@return K|nil
function M.pairs(t)
  local start_time = vim.uv.hrtime()

  ---@async
  local function iter(_, k)
    start_time = M.event_control(start_time)
    return next(t, k)
  end

  return iter, t, nil
end

---Auto-selecting version of `ipairs`. Uses async iteration for large arrays
---(size > threshold), otherwise uses native `ipairs`.
---@async
---@generic T
---@param a                           T[]
---@param threshold                   ?integer
---@return fun(): integer, T
---@return any
---@return integer
function M.auto_ipairs(a, threshold)
  threshold = threshold or AUTO_ITER_THRESHOLD
  if #a > threshold then
    return M.ipairs(a)
  end
  return ipairs(a)
end

return M
