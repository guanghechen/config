---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.explorer.metrics" ---@type string

local M = {}
local ffi
if vim.uv.os_uname().sysname == "Darwin" then
  ffi = require("ffi")
  ffi.cdef([[
    void *pthread_self(void);
    unsigned int pthread_mach_thread_np(void *thread);
    int thread_info(unsigned int thread, int flavor, int *info, unsigned int *count);
  ]])
end

---@return table
function M.usage()
  local usage = vim.uv.getrusage()
  local result = {
    cpu_us = (usage.utime.sec + usage.stime.sec) * 1000000 + usage.utime.usec + usage.stime.usec,
  }
  if ffi then
    local info, count = ffi.new("int[10]"), ffi.new("unsigned int[1]", 10)
    assert(ffi.C.thread_info(ffi.C.pthread_mach_thread_np(ffi.C.pthread_self()), 3, info, count) == 0)
    result.main_us = (tonumber(info[0]) + tonumber(info[2])) * 1000000 + tonumber(info[1]) + tonumber(info[3])
  end
  return result
end

---@return table
function M.memory_description()
  local system = vim.uv.os_uname().sysname
  local kind = "rss"
  if system == "Darwin" then
    -- Darwin's libuv API reports phys_footprint in 1.53; older builds need their own provenance.
    kind = vim.uv.version() >= 0x013500 and "physical_footprint" or "libuv_resident_set_memory"
  end
  return {
    kind = kind,
    unit = "bytes",
    api = "uv_resident_set_memory",
    libuv = vim.uv.version_string(),
    system = system,
  }
end

---@return table
function M.memory()
  return {
    process_memory_bytes = vim.uv.resident_set_memory(),
    process_memory_kind = M.memory_description().kind,
    lua_heap_kib = collectgarbage("count"),
    libuv_version = vim.uv.version_string(),
  }
end

return M
