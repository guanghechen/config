---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.git_buffer" ---@type string

-- Specs of the Git modules run them over the globals they describe. The modules create and await the real `stl.c`
-- futures, and `era.m.git.buffer` creates a Ticker when it loads.

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local M = {}

---Exposes the real Future and CancellationToken in `stl.c` until the case or suite of `t` ends.
---@param t                             __test__.support.Harness
---@return nil
function M.with_futures(t)
  bootstrap.with_global(t, "stl", {
    c = { CancellationToken = require("stl.c.cancellation_token"), Future = require("stl.c.future") },
  })
end

---Loads a fresh `era.m.git.buffer`. Until the case or suite of `t` ends, `stl.c` holds the real futures and a Ticker
---stub, and the globals in `runtime` are merged in as `bootstrap.with_runtime` merges them.
---@param t                             __test__.support.Harness
---@param runtime                       table<string, table>
---@return era.m.git.buffer
function M.load(t, runtime)
  M.with_futures(t)
  bootstrap.with_global(t, "stl", {
    c = {
      Ticker = {
        new = function()
          return { tick = function() end }
        end,
      },
    },
  })
  bootstrap.with_runtime(t, runtime)
  return assert(loadfile("lua/era/m/git/buffer.lua"))()
end

---The cache entries that `buffer`, a loaded `era.m.git.buffer`, keeps by buffer number.
---@param buffer                        era.m.git.buffer
---@return table<integer, era.m.git.buffer.ICache>
function M.cache(buffer)
  for index = 1, 50 do
    local name, value = debug.getupvalue(buffer.reset_hunk, index)
    if not name then
      break
    end
    if name == "cache" then
      return value
    end
  end
  error("missing upvalue: cache")
end

---A `stl.timer` debounce or throttle stand-in: calling it calls `callback`, and it can be disposed.
---@param callback                      function
---@return table
function M.callable(callback)
  return setmetatable({ dispose = function() end }, {
    __call = function(_, ...)
      return callback(...)
    end,
  })
end

---Waits for a staging write of `era.m.git.buffer` and returns its outcome, a rejection as a failed one.
---@param future                        stl.c.Future
---@return { ok: boolean, err: string|nil }
function M.outcome(future)
  local resolved, result = harness.settle(future)
  return resolved and result or { ok = false, err = tostring(result) }
end

return M
