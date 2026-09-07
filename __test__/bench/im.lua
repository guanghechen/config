--- Run with: nvim --headless -u NONE -i NONE -n -l __test__/bench/im.lua [native-library]
--- Measures capture + restore to the same macOS source; aborts if the source changes externally.
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.im" ---@type string

assert(vim.uv.os_uname().sysname == "Darwin", "This benchmark requires the macOS IM backend.")
local source = assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2)))
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source)))
local library = arg[1] and vim.fs.abspath(arg[1]) or (root .. "/lua/yoz.so")
local native = assert(package.loadlib(library, "luaopen_yoz"))()
local im = assert(native.im)
local snapshot, err = im.capture()
assert(snapshot, err)

local captures, restores, cycles = {}, {}, {}
for i = 1, 100 do
  vim.uv.sleep(5)
  local started = vim.uv.hrtime()
  local current, capture_err = im.capture()
  local captured_at = vim.uv.hrtime()
  assert(current, capture_err)
  assert(current == snapshot, "Input source changed externally; stopping the benchmark.")
  local restored, restore_err = im.restore(snapshot)
  local finished = vim.uv.hrtime()
  assert(restored, restore_err)
  captures[i] = (captured_at - started) / 1000
  restores[i] = (finished - captured_at) / 1000
  cycles[i] = (finished - started) / 1000
end
assert(im.capture() == snapshot, "Input source changed during the benchmark.")

---@return { p50_us: number, p95_us: number, p99_us: number, max_us: number }
local function summarize(samples)
  table.sort(samples)
  return {
    p50_us = samples[50],
    p95_us = samples[95],
    p99_us = samples[99],
    max_us = samples[100],
  }
end

io.write(vim.json.encode({
  library = library,
  samples = #cycles,
  idle_ms = 5,
  capture = summarize(captures),
  restore = summarize(restores),
  capture_and_restore = summarize(cycles),
}) .. "\n")
