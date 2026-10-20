---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.fuzzy.cpu" ---@type string

-- Benchmark processes ask macOS for performance cores and measure the core they got: on hosts with
-- performance and efficiency cores a default-QoS process can run two to three times slower.

local M = {}

-- QOS_CLASS_USER_INTERACTIVE from <sys/qos.h>.
local USER_INTERACTIVE = 0x21

---@return boolean
function M.prefer_performance_cores()
  if vim.uv.os_uname().sysname ~= "Darwin" then
    return false
  end
  local ffi = require("ffi")
  pcall(ffi.cdef, "int pthread_set_qos_class_self_np(unsigned int qos_class, int relative_priority);")
  return ffi.C.pthread_set_qos_class_self_np(USER_INTERACTIVE, 0) == 0
end

-- A fixed integer loop; its time tracks the speed of the core running this process.
---@return number milliseconds
function M.calibrate()
  local best = math.huge
  for _ = 1, 3 do
    local started = vim.uv.hrtime()
    local value = 0
    for index = 1, 20000000 do
      value = (value + index * 7) % 1000003
    end
    best = math.min(best, (vim.uv.hrtime() - started) / 1e6)
    assert(value >= 0)
  end
  return best
end

return M
