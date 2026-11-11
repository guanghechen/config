---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.harness" ---@type string

---@class __test__.support.harness.ICase
---@field public name                   string
---@field public callback               fun()

---@class __test__.support.harness.IResult
---@field public name                   string
---@field public passed                 integer
---@field public failed                 integer
---@field public skipped                integer
---@field public failures               string[]

---@class __test__.support.harness.ISkip
---@field public reason                 string

---@class __test__.support.Harness
---@field public name                   string
---@field private _cases                __test__.support.harness.ICase[]
---@field private _case_cleanups        fun()[]|nil
---@field private _suite_cleanups       fun()[]
local Harness = {}
Harness.__index = Harness

local M = {}

-- Metatable of the error skip() raises, so run() tells a skip from a failure.
local Skip = {} ---@type table

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

---Names the suite after its script path, as the runner lists it.
---@return __test__.support.Harness
function M.new()
  local script = _G.arg and _G.arg[0] or "suite" ---@type string
  ---@type __test__.support.Harness
  local harness = {
    name = vim.fs.relpath(assert(vim.uv.cwd()), vim.fs.abspath(script)) or script,
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

---Compares values as vim.deep_equal does and shows both sides on failure.
---@param expected                      any
---@param actual                        any
---@param msg                           ?string
---@return nil
function Harness.assert_same(expected, actual, msg)
  if not vim.deep_equal(expected, actual) then
    error(
      string.format("%s: expected %s, got %s", msg or "assertion failed", vim.inspect(expected), vim.inspect(actual)),
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

---Calls `callback`, which must raise an error whose message contains `fragment`, and returns that message.
---@param callback                      fun(): any
---@param fragment                      string
---@param msg                           ?string
---@return string
function Harness.assert_error(callback, fragment, msg)
  local ok, err = pcall(callback)
  if ok then
    error(string.format("%s: expected an error containing %q", msg or "assertion failed", fragment), 2)
  end
  local message = tostring(err) ---@type string
  if not message:find(fragment, 1, true) then
    error(string.format("%s: expected an error containing %q, got %q", msg or "assertion failed", fragment, message), 2)
  end
  return message
end

--- Ends the current case as skipped when the environment cannot exercise it.
---@param reason                        string
---@return nil
function Harness.skip(reason)
  error(setmetatable({ reason = reason }, Skip), 0)
end

---@param cleanup                       fun()
---@return fun()
function Harness:defer(cleanup)
  if type(cleanup) ~= "function" then
    error("cleanup must be a function", 2)
  end
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

  return self:defer(function()
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

  return self:defer(function()
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

---Runs the callbacks `vim.schedule` queued before this call.
---@return nil
function Harness.drain()
  local drained = false ---@type boolean
  vim.schedule(function()
    drained = true
  end)
  if not vim.wait(10000, function()
    return drained
  end) then
    error("scheduled callbacks did not run within 10000 ms", 2)
  end
end

---Raises at the caller of the waiting function when `future` does not settle within `timeout_ms`.
---@param future                        stl.c.Future
---@param timeout_ms                    integer
---@return nil
local function wait_settled(future, timeout_ms)
  local done = vim.wait(timeout_ms, function()
    return future:is_done()
  end, 1)
  if not done then
    error(string.format("future did not settle within %d ms", timeout_ms), 3)
  end
end

---Waits for a Future to settle and returns its result; a failed Future fails the case.
---@param future                        stl.c.Future
---@param timeout_ms                    ?integer
---@return any
function Harness.await(future, timeout_ms)
  wait_settled(future, timeout_ms or 10000)
  if future:is_failed() then
    error("future failed: " .. tostring(future:get_error()), 2)
  end
  return future:get_result()
end

---Waits for a Future to settle, failed or not: returns whether it resolved, and its result or error.
---@param future                        stl.c.Future
---@param timeout_ms                    ?integer
---@return boolean
---@return any
function Harness.settle(future, timeout_ms)
  wait_settled(future, timeout_ms or 10000)
  if future:is_failed() then
    return false, future:get_error()
  end
  return true, future:get_result()
end

-- Support modules wait without a suite instance.
M.wait_until = Harness.wait_until
M.await = Harness.await
M.settle = Harness.settle

---Creates a directory under the system temporary directory, removed when the case (or the suite, outside a
---case) ends.
---@return string
function Harness:tempdir()
  local path = assert(vim.uv.fs_mkdtemp(vim.fs.joinpath(vim.uv.os_tmpdir(), "nvim-test-XXXXXX"))) ---@type string
  self:defer(function()
    vim.fn.delete(path, "rf")
  end)
  return assert(vim.uv.fs_realpath(path))
end

---@class __test__.support.harness.IBufferOptions
---@field filetype                      ?string
---@field name                          ?string Buffer name, such as a file path.
---@field listed                        ?boolean Listed; false by default.
---@field scratch                       ?boolean A scratch buffer (`buftype=nofile`); by default an unlisted one is.
---@field current                       ?boolean Shown in the current window, which gets its buffer back first.

---Creates a buffer holding `lines`, deleted when the case (or the suite, outside a case) ends.
---@param lines                         ?string[]
---@param options                       ?__test__.support.harness.IBufferOptions
---@return integer
function Harness:buffer(lines, options)
  options = options or {}
  local listed = options.listed == true ---@type boolean
  local scratch = options.scratch == nil and not listed or options.scratch == true ---@type boolean
  local bufnr = vim.api.nvim_create_buf(listed, scratch) ---@type integer
  self:defer(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)
  if options.name then
    vim.api.nvim_buf_set_name(bufnr, options.name)
  end
  if lines then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
  end
  if options.filetype then
    vim.api.nvim_set_option_value("filetype", options.filetype, { buf = bufnr })
  end
  if options.current then
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local previous = vim.api.nvim_win_get_buf(winnr) ---@type integer
    self:defer(function()
      if vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_buf_is_valid(previous) then
        vim.api.nvim_win_set_buf(winnr, previous)
      end
    end)
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end
  return bufnr
end

---Opens a window on `bufnr` with `nvim_open_win`, closed when the case (or the suite, outside a case) ends. An entered
---window gives the focus back to the window that had it.
---@param bufnr                         integer
---@param config                        vim.api.keyset.win_config
---@param enter                         ?boolean
---@return integer
function Harness:window(bufnr, config, enter)
  local previous = vim.api.nvim_get_current_win() ---@type integer
  local winnr = vim.api.nvim_open_win(bufnr, enter == true, config) ---@type integer
  self:defer(function()
    if enter and vim.api.nvim_win_is_valid(previous) then
      vim.api.nvim_set_current_win(previous)
    end
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end)
  return winnr
end

---@param opts                          ?{ exit: boolean, quiet: boolean }
---@return __test__.support.harness.IResult
function Harness:run(opts)
  opts = opts or {}
  local quiet = opts.quiet == true ---@type boolean

  ---@param line                         string
  local function emit(line)
    if quiet then
      return
    end

    io.write(line .. "\n")
    io.flush()
  end

  local passed = 0 ---@type integer
  local failed = 0 ---@type integer
  local skipped = 0 ---@type integer
  local failures = {} ---@type string[]

  if #self._cases == 0 then
    failed = 1
    failures[1] = "suite has no test cases: " .. self.name
    emit("FAIL " .. failures[1])
  end

  for _, case in ipairs(self._cases) do
    self._case_cleanups = {}
    local ok, err = pcall(case.callback)
    local cleanup_failures = run_cleanups(self._case_cleanups)
    self._case_cleanups = nil
    local skip = not ok and getmetatable(err) == Skip and err or nil ---@type __test__.support.harness.ISkip|nil

    if skip ~= nil and #cleanup_failures == 0 then
      skipped = skipped + 1
      emit("SKIP " .. case.name .. ": " .. skip.reason)
    elseif ok and #cleanup_failures == 0 then
      passed = passed + 1
      emit("PASS " .. case.name)
    else
      failed = failed + 1
      emit("FAIL " .. case.name)
      if not ok and skip == nil then
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

  local summary = string.format("\n%d passed, %d failed", passed, failed) ---@type string
  emit(skipped > 0 and string.format("%s, %d skipped", summary, skipped) or summary)

  local result = {
    name = self.name,
    passed = passed,
    failed = failed,
    skipped = skipped,
    failures = failures,
  } ---@type __test__.support.harness.IResult

  if opts.exit ~= false then
    -- Unlike os.exit, quitting runs Neovim's exit cleanup, which removes its server socket directory.
    vim.cmd(failed > 0 and "cquit 1" or "qall!")
  end

  return result
end

return M
