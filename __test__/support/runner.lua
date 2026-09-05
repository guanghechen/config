---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.runner" ---@type string

local M = {}

local source = assert(vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))) ---@type string
local ROOT = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source))) ---@type string
local DEFAULT_TIMEOUT_MS = 30000 ---@type integer

---@class __test__.support.runner.IOptions
---@field public root                   ?string
---@field public filter                 ?string
---@field public timeout_ms             ?integer
---@field public list                   ?boolean
---@field public help                   ?boolean

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

---@param output                        ?string
---@return nil
local function write_output(output)
  if output ~= nil and output ~= "" then
    io.write(output)
    if output:sub(-1) ~= "\n" then
      io.write("\n")
    end
  end
end

---@param opts                          ?__test__.support.runner.IOptions
---@return integer failed_suites
function M.run_all(opts)
  opts = opts or {}
  local timeout_ms = opts.timeout_ms or DEFAULT_TIMEOUT_MS ---@type integer
  if type(timeout_ms) ~= "number" or timeout_ms <= 0 or timeout_ms % 1 ~= 0 then
    error("suite timeout must be a positive integer in milliseconds", 0)
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

  local failed = 0 ---@type integer
  for _, suite in ipairs(suites) do
    local name = display_path(suite) ---@type string
    io.write("== " .. name .. "\n")
    io.flush()
    local ok, result = pcall(function()
      return vim
        .system({
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
        }, { cwd = ROOT, text = true, timeout = timeout_ms })
        :wait()
    end)
    if not ok then
      failed = failed + 1
      io.write("FAIL " .. name .. ": " .. tostring(result) .. "\n")
    else
      write_output(result.stdout)
      write_output(result.stderr)
      if result.code ~= 0 or result.signal ~= 0 then
        failed = failed + 1
        local reason = result.code == 124 and ("timeout after " .. timeout_ms .. " ms")
          or string.format("exit %s, signal %s", result.code, result.signal)
        io.write("FAIL " .. name .. ": " .. reason .. "\n")
      end
    end
    io.flush()
  end

  io.write(string.format("\n%d suite(s), %d failed\n", #suites, failed))
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
      io.write("Usage: nvim -l __test__/run.lua [--list] [--timeout ms] [path-filter]\n")
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
