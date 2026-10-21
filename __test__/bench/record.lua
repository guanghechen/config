---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.record" ---@type string

-- Writes a benchmark run to __test__/bench/results/<bench>/<UTC>-<pid>.json (git-ignored): the environment it ran
-- in, the conditions the benchmark states and its results. Results report durations in milliseconds and memory in
-- bytes, and summarize distributions with `stats.summary`.

local Metrics = require("__test__.bench.metrics")

local source = assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))) ---@type string
local ROOT = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source))) ---@type string

local M = {}

---@param args                          string[]
---@return string|nil
local function git(args)
  local result = vim.system(vim.list_extend({ "git", "--no-optional-locks", "-C", ROOT }, args), { text = true }):wait()
  return result.code == 0 and vim.trim(result.stdout) or nil
end

---Neovim, LuaJIT, the host, this checkout's commit, and the installed native library's build receipt.
---@return table
function M.environment()
  local uname = vim.uv.os_uname()
  local cpus = vim.uv.cpu_info() or {}
  local version = vim.version()
  local library = uname.sysname == "Windows_NT" and "yoz.dll" or "yoz.so"
  local receipt_lines = vim.fn.filereadable(ROOT .. "/lua/" .. library .. ".build.json") == 1
      and vim.fn.readfile(ROOT .. "/lua/" .. library .. ".build.json")
    or nil
  local receipt = receipt_lines and vim.json.decode(table.concat(receipt_lines, "\n")) or nil
  return {
    nvim = { version = tostring(version), build = version.build or vim.NIL },
    luajit = jit and jit.version or vim.NIL,
    host = {
      system = uname.sysname,
      release = uname.release,
      machine = uname.machine,
      cpu = cpus[1] and cpus[1].model or vim.NIL,
      logical_cpus = #cpus,
      memory_bytes = vim.uv.get_total_memory(),
    },
    source = {
      commit = git({ "rev-parse", "HEAD" }) or vim.NIL,
      dirty = (git({ "status", "--porcelain", "--untracked-files=no" }) or "") ~= "",
    },
    native = receipt and {
      receipt = library .. ".build.json",
      artifact_sha256 = receipt.artifact_sha256,
      source_sha256 = receipt.source and receipt.source.sha256 or vim.NIL,
    } or { receipt = vim.NIL },
    process_memory = Metrics.memory_description(),
  }
end

---Writes `run` (its `conditions` and `results`, plus any other fields) with the environment, and returns the path.
---@param bench                         string
---@param run                           table
---@return string
function M.write(bench, run)
  local directory = ROOT .. "/__test__/bench/results/" .. bench
  vim.fn.mkdir(directory, "p")
  local path = string.format("%s/%s-%d.json", directory, os.date("!%Y%m%dT%H%M%SZ"), vim.uv.os_getpid())
  local record = vim.tbl_extend("keep", {
    schema = "bench-run/1",
    bench = bench,
    finished_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    environment = M.environment(),
  }, run)
  assert(vim.fn.writefile({ vim.json.encode(record) }, path) == 0, "cannot write " .. path)
  return path
end

return M
