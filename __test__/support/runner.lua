---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.runner" ---@type string

local M = {}

local source = assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))) ---@type string
local ROOT = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source))) ---@type string
local DEFAULT_TIMEOUT_MS = 30000 ---@type integer
-- Suites run at once by default: half the hardware threads, at most eight. Suites start child processes and native
-- worker threads of their own, and timing-sensitive cases need headroom.
local DEFAULT_JOBS = math.max(1, math.min(8, math.floor(vim.uv.available_parallelism() / 2))) ---@type integer

---@class __test__.support.runner.IOptions
---@field public root                   ?string
---@field public filter                 ?string
---@field public timeout_ms             ?integer
---@field public jobs                   ?integer
---@field public list                   ?boolean
---@field public help                   ?boolean

---@class __test__.support.runner.IResult
---@field public output                 string
---@field public failed                 boolean
---@field public skipped                integer

---@param path                          string
---@return string
local function display_path(path)
  local prefix = ROOT .. "/" ---@type string
  return path:sub(1, #prefix) == prefix and path:sub(#prefix + 1) or path
end

---@param dirpath                       string
---@param result                        string[]
---@return nil
local function collect_specs(dirpath, result)
  local scanner, err = vim.uv.fs_scandir(dirpath)
  if scanner == nil then
    error("cannot read test directory " .. dirpath .. ": " .. tostring(err), 0)
  end
  while true do
    local name, kind = vim.uv.fs_scandir_next(scanner)
    if name == nil then
      break
    end
    local filepath = dirpath .. "/" .. name ---@type string
    if kind == nil or kind == "unknown" then
      local stat, stat_err = vim.uv.fs_lstat(filepath)
      if stat == nil then
        error("cannot inspect test path " .. filepath .. ": " .. tostring(stat_err), 0)
      end
      kind = stat.type
    end
    if kind == "directory" then
      collect_specs(filepath, result)
    elseif kind == "file" and name:match("_spec%.lua$") then
      result[#result + 1] = filepath
    end
  end
end

---@param root                          ?string
---@param filter                        ?string
---@return string[]
function M.discover(root, filter)
  root = vim.fs.abspath(root or (ROOT .. "/__test__/specs"))
  local stat = vim.uv.fs_stat(root)
  if stat == nil or stat.type ~= "directory" then
    error("test directory does not exist: " .. root, 0)
  end

  local suites = {} ---@type string[]
  collect_specs(root, suites)
  table.sort(suites)
  if filter == nil or filter == "" then
    return suites
  end

  local filtered = {} ---@type string[]
  for _, suite in ipairs(suites) do
    if suite:find(filter, 1, true) then
      filtered[#filtered + 1] = suite
    end
  end
  return filtered
end

-- A suite that needs longer than the shared limit declares it in a leading comment line such as
-- `--- Timeout: 120000`; the declaration only ever raises the limit.
---@param suite                         string
---@return integer|nil
local function declared_timeout_ms(suite)
  local file = io.open(suite, "r")
  if file == nil then
    return nil
  end
  local declared = nil ---@type integer|nil
  for line in file:lines() do
    if not line:match("^%-%-") then
      break
    end
    local value = line:match("^%-%-%-?%s*Timeout:%s*(%d+)%s*$")
    if value ~= nil then
      declared = tonumber(value)
      break
    end
  end
  file:close()
  return declared
end

---The environment of suite processes: the runner's own, without tmux. Children inherit it, so a regression in code
---that drives tmux panes cannot reach the user's real session.
---@return table<string, string>
local function suite_env()
  local env = vim.fn.environ() ---@type table<string, string>
  env.TMUX, env.TMUX_PANE = nil, nil
  return env
end

---Starts one suite process and calls `on_done` with its report once it exits.
---@param suite                         string
---@param timeout_ms                    integer
---@param env                           table<string, string>
---@param on_done                       fun(result: __test__.support.runner.IResult): nil
---@return nil
local function start_suite(suite, timeout_ms, env, on_done)
  local name = display_path(suite) ---@type string
  local suite_timeout_ms = math.max(timeout_ms, declared_timeout_ms(suite) or 0) ---@type integer
  vim.system({
    vim.v.progpath,
    "--headless",
    "-u",
    "NONE",
    "-i",
    "NONE",
    "-n",
    "-l",
    ROOT .. "/__test__/run.lua",
    "--suite",
    suite,
  }, { cwd = ROOT, text = true, timeout = suite_timeout_ms, env = env, clear_env = true }, function(result)
    local parts = {} ---@type string[]
    for _, output in ipairs({ result.stdout, result.stderr }) do
      if output ~= nil and output ~= "" then
        parts[#parts + 1] = output:sub(-1) == "\n" and output or output .. "\n"
      end
    end
    local skipped = 0 ---@type integer
    for _ in ("\n" .. (result.stdout or "")):gmatch("\nSKIP ") do
      skipped = skipped + 1
    end
    local failed = result.code ~= 0 or result.signal ~= 0 ---@type boolean
    if failed then
      local reason = result.code == 124 and ("timeout after " .. suite_timeout_ms .. " ms")
        or string.format("exit %s, signal %s", result.code, result.signal)
      parts[#parts + 1] = "FAIL " .. name .. ": " .. reason .. "\n"
    end
    on_done({ output = table.concat(parts), failed = failed, skipped = skipped })
  end)
end

---@param opts                          ?__test__.support.runner.IOptions
---@return integer failed_suites
function M.run_all(opts)
  opts = opts or {}
  local timeout_ms = opts.timeout_ms or DEFAULT_TIMEOUT_MS ---@type integer
  if type(timeout_ms) ~= "number" or timeout_ms <= 0 or timeout_ms % 1 ~= 0 then
    error("suite timeout must be a positive integer in milliseconds", 0)
  end
  local jobs = opts.jobs or DEFAULT_JOBS ---@type integer
  if type(jobs) ~= "number" or jobs <= 0 or jobs % 1 ~= 0 then
    error("jobs must be a positive integer", 0)
  end

  local suites = M.discover(opts.root, opts.filter) ---@type string[]
  if #suites == 0 then
    error("no test suites matched" .. (opts.filter and (": " .. opts.filter) or ""), 0)
  end
  if opts.list then
    for _, suite in ipairs(suites) do
      io.write(display_path(suite) .. "\n")
    end
    return 0
  end

  local results = {} ---@type table<integer, __test__.support.runner.IResult>
  local env = suite_env() ---@type table<string, string>
  local started, running, written = 0, 0, 0 ---@type integer, integer, integer
  local failed, skipped = 0, 0 ---@type integer, integer
  while written < #suites do
    while running < jobs and started < #suites do
      started = started + 1
      local index = started ---@type integer
      running = running + 1
      local ok, err = pcall(start_suite, suites[index], timeout_ms, env, function(result)
        results[index] = result
        running = running - 1
      end)
      if not ok then
        local name = display_path(suites[index]) ---@type string
        results[index] = { output = "FAIL " .. name .. ": " .. tostring(err) .. "\n", failed = true, skipped = 0 }
        running = running - 1
      end
    end
    vim.wait(DEFAULT_TIMEOUT_MS, function()
      return results[written + 1] ~= nil or (running < jobs and started < #suites)
    end, 10)
    -- Output follows discovery order, so a parallel run reads like a sequential one.
    while results[written + 1] ~= nil do
      written = written + 1
      local result = results[written] ---@type __test__.support.runner.IResult
      io.write("== " .. display_path(suites[written]) .. "\n" .. result.output)
      io.flush()
      failed = failed + (result.failed and 1 or 0)
      skipped = skipped + result.skipped
    end
  end

  local summary = string.format("\n%d suite(s), %d failed", #suites, failed) ---@type string
  io.write((skipped > 0 and string.format("%s, %d case(s) skipped", summary, skipped) or summary) .. "\n")
  return failed
end

---@param args                          string[]
---@return __test__.support.runner.IOptions
local function parse_args(args)
  local opts = {} ---@type __test__.support.runner.IOptions
  local index = 1 ---@type integer
  while index <= #args do
    local value = args[index] ---@type string
    if value == "--list" then
      opts.list = true
    elseif value == "--help" then
      opts.help = true
    elseif value == "--timeout" then
      index = index + 1
      opts.timeout_ms = tonumber(args[index])
      if opts.timeout_ms == nil then
        error("--timeout requires a positive integer in milliseconds", 0)
      end
    elseif value == "--jobs" then
      index = index + 1
      opts.jobs = tonumber(args[index])
      if opts.jobs == nil then
        error("--jobs requires a positive integer", 0)
      end
    elseif value:sub(1, 1) == "-" then
      error("unknown option: " .. value, 0)
    elseif opts.filter ~= nil then
      error("expected one literal path filter", 0)
    else
      opts.filter = value
    end
    index = index + 1
  end
  return opts
end

---@param args                          ?string[]
---@return nil
function M.main(args)
  local ok, failed = pcall(function()
    local opts = parse_args(args or {})
    if opts.help then
      io.write("Usage: nvim -l __test__/run.lua [--list] [--timeout ms] [--jobs n] [path-filter]\n")
      return 0
    end
    return M.run_all(opts)
  end)
  if not ok then
    io.stderr:write(tostring(failed) .. "\n")
  end
  os.exit(ok and failed == 0 and 0 or 1)
end

return M
