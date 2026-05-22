---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.harness" ---@type string

---@class __test__.harness.ICase
---@field public name                   string
---@field public callback               fun()

---@class __test__.harness.IResult
---@field public name                   string
---@field public passed                 integer
---@field public failed                 integer
---@field public failures               string[]

---@class __test__.Harness
---@field public name                   string
---@field private _cases                __test__.harness.ICase[]
---@field private _case_cleanups        fun()[]|nil
---@field private _suite_cleanups       fun()[]
local Harness = {}
Harness.__index = Harness

local M = {}

---@param value                         any
---@return string
local function format_value(value)
  if type(value) == "string" then
    return string.format("%q", value)
  end
  return tostring(value)
end

---@param cleanups                      fun()[]
---@return string[]
local function run_cleanups(cleanups)
  local failures = {} ---@type string[]
  for i = #cleanups, 1, -1 do
    local ok, err = pcall(cleanups[i])
    if not ok then
      failures[#failures + 1] = tostring(err)
    end
  end
  return failures
end

---@param name                          string
---@return __test__.Harness
function M.new(name)
  ---@type __test__.Harness
  local harness = {
    name = name,
    _cases = {},
    _case_cleanups = nil,
    _suite_cleanups = {},
  }
  return setmetatable(harness, Harness)
end

---@param name                          string
---@param callback                      fun()
---@return nil
function Harness:test(name, callback)
  if type(name) ~= "string" or name == "" then
    error("test name must be a non-empty string", 2)
  end

  if type(callback) ~= "function" then
    error("test callback must be a function", 2)
  end

  self._cases[#self._cases + 1] = { name = name, callback = callback }
end

---@param expected                      any
---@param actual                        any
---@param msg                           ?string
---@return nil
function Harness.assert_eq(expected, actual, msg)
  if expected ~= actual then
    error(
      string.format("%s: expected %s, got %s", msg or "assertion failed", format_value(expected), format_value(actual)),
      2
    )
  end
end

---@param actual                        any
---@param msg                           ?string
---@return nil
function Harness.assert_true(actual, msg)
  if not actual then
    error(string.format("%s: expected true, got %s", msg or "assertion failed", format_value(actual)), 2)
  end
end

---@param actual                        any
---@param msg                           ?string
---@return nil
function Harness.assert_false(actual, msg)
  if actual then
    error(string.format("%s: expected false, got %s", msg or "assertion failed", format_value(actual)), 2)
  end
end

---@param actual                        any
---@param msg                           ?string
---@return nil
function Harness.assert_nil(actual, msg)
  if actual ~= nil then
    error(string.format("%s: expected nil, got %s", msg or "assertion failed", format_value(actual)), 2)
  end
end

---@private
---@param cleanup                       fun()
---@return fun()
function Harness:_register_cleanup(cleanup)
  local disposed = false ---@type boolean

  local function wrapped()
    if disposed then
      return
    end
    disposed = true
    cleanup()
  end

  local target = self._case_cleanups or self._suite_cleanups ---@type fun()[]
  target[#target + 1] = wrapped
  return wrapped
end

---@param name                          string
---@param value                         any
---@return fun()
function Harness:patch_global(name, value)
  local existed = rawget(_G, name) ~= nil ---@type boolean
  local previous = rawget(_G, name) ---@type any
  rawset(_G, name, value)

  return self:_register_cleanup(function()
    if existed then
      rawset(_G, name, previous)
    else
      rawset(_G, name, nil)
    end
  end)
end

---@param target                        table
---@param key                           any
---@param value                         any
---@return fun()
function Harness:patch_table(target, key, value)
  local previous = rawget(target, key) ---@type any
  local existed = previous ~= nil ---@type boolean
  rawset(target, key, value)

  return self:_register_cleanup(function()
    if existed then
      rawset(target, key, previous)
    else
      rawset(target, key, nil)
    end
  end)
end

---@param predicate                     fun(): boolean
---@param timeout_ms                    integer
---@param msg                           ?string
---@return nil
function Harness.wait_until(predicate, timeout_ms, msg)
  local ok = vim.wait(timeout_ms, predicate) ---@type boolean
  if not ok then
    error(msg or string.format("condition was not met within %d ms", timeout_ms), 2)
  end
end

---@param opts                          ?{ exit: boolean, quiet: boolean }
---@return __test__.harness.IResult
function Harness:run(opts)
  opts = opts or {}
  local quiet = opts.quiet == true ---@type boolean

  ---@param line                         string
  local function emit(line)
    if quiet then
      return
    end

    print(line)
    io.flush()
  end

  local passed = 0 ---@type integer
  local failed = 0 ---@type integer
  local failures = {} ---@type string[]

  for _, case in ipairs(self._cases) do
    self._case_cleanups = {}
    local ok, err = pcall(case.callback)
    local cleanup_failures = run_cleanups(self._case_cleanups)
    self._case_cleanups = nil

    if ok and #cleanup_failures == 0 then
      passed = passed + 1
      emit("PASS " .. case.name)
    else
      failed = failed + 1
      emit("FAIL " .. case.name)
      if not ok then
        local message = tostring(err)
        failures[#failures + 1] = case.name .. ": " .. message
        emit("  Error: " .. message)
      end
      for _, cleanup_err in ipairs(cleanup_failures) do
        local message = "cleanup failed: " .. cleanup_err
        failures[#failures + 1] = case.name .. ": " .. message
        emit("  Error: " .. message)
      end
    end
  end

  local suite_cleanup_failures = run_cleanups(self._suite_cleanups)
  for _, cleanup_err in ipairs(suite_cleanup_failures) do
    failed = failed + 1
    local message = "suite cleanup failed: " .. cleanup_err
    failures[#failures + 1] = message
    emit("FAIL " .. message)
  end

  emit(string.format("\n%d passed, %d failed", passed, failed))

  local result = {
    name = self.name,
    passed = passed,
    failed = failed,
    failures = failures,
  } ---@type __test__.harness.IResult

  if opts.exit ~= false then
    os.exit(failed > 0 and 1 or 0)
  end

  return result
end

return M
