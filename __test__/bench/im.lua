-- Usage, from the repository root: nvim --headless -u NONE -i NONE -n -l __test__/bench/im.lua [native-library]
-- Measures capture + restore to the same macOS source; aborts if the source changes externally.
---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.im" ---@type string

assert(vim.uv.os_uname().sysname == "Darwin", "This benchmark requires the macOS IM backend.")
local source = assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2)))
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source)))
package.path = root .. "/?.lua;" .. package.path
local Record = require("__test__.bench.record")
local Stats = require("__test__.bench.stats")
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
  captures[i] = (captured_at - started) / 1e6
  restores[i] = (finished - captured_at) / 1e6
  cycles[i] = (finished - started) / 1e6
end
assert(im.capture() == snapshot, "Input source changed during the benchmark.")

---@param samples                     number[]
---@return table
local function summarize(samples)
  local summary = assert(Stats.summary(samples))
  summary.p99 = Stats.percentile(samples, 0.99)
  return summary
end

local results = {
  capture_ms = summarize(captures),
  restore_ms = summarize(restores),
  capture_and_restore_ms = summarize(cycles),
}
io.write(vim.json.encode(results), "\n")
local conditions = { library = library, iterations = #cycles, idle_ms = 5 }
io.write("results: ", Record.write("im", { conditions = conditions, results = results }), "\n")
