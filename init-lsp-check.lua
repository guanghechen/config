---@diagnostic disable-next-line: unused-local
local __module_name__ = "init-lsp-check"

-- External config variables (injected via -c "lua VAR=value")
---@type string|nil
TARGET_DIR = TARGET_DIR
---@type string|nil
OUTPUT_FILE = OUTPUT_FILE
---@type string[]|nil
FILE_PATTERNS = FILE_PATTERNS
---@type string[]|nil
EXCLUDE_PATTERNS = EXCLUDE_PATTERNS

-- Usage:
-- nvim --headless -c "luafile ~/.config/nvim/init-lsp-check.lua"
--
-- With config overrides:
-- nvim --headless \
--   -c "lua TARGET_DIR='~/my-project'" \
--   -c "lua OUTPUT_FILE='/tmp/my-diagnostics.json'" \
--   -c "luafile ~/.config/nvim/init-lsp-check.lua"

--------------------------------------------------------------------------------
-- Headless Output Helper
--------------------------------------------------------------------------------

---@param msg string
local function log(msg)
  io.stdout:write(msg .. "\n")
  io.stdout:flush()
end

--------------------------------------------------------------------------------
-- Bootstrap
--------------------------------------------------------------------------------

require("ark.bootstrap").setup()

local default_storage = dot.get_default_storage() ---@type dot.context.storage
local storage = { editor = default_storage.editor, workspace = default_storage.workspace } ---@type dot.context.storage
dot.setup_context(storage)

require("era.plugin")

--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

---@class LspCollectorConfig
---@field target_dir string
---@field output_file string
---@field file_patterns string[]
---@field exclude_patterns string[]
---@field timeout_ms number
---@field poll_interval_ms number
---@field stable_count_required number
---@field min_wait_after_open_ms number
---@field min_analysis_time_ms number

---@class LspCollectorState
---@field config LspCollectorConfig
---@field start_time number
---@field stable_count number
---@field busy_stable_count number
---@field last_diagnostic_count number
---@field opened_files string[]
---@field failed_files string[]

---@class FormattedDiagnostic
---@field file string
---@field lnum number
---@field col number
---@field end_lnum number|nil
---@field end_col number|nil
---@field severity string
---@field message string
---@field source string|nil
---@field code string|number|nil

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

---@type LspCollectorConfig
local DEFAULT_CONFIG = {
  target_dir = vim.fn.getcwd(),
  output_file = "/tmp/nvim-diagnostics.json",
  file_patterns = { "**/*.lua" },
  exclude_patterns = {
    "/lazy/",
    "/pack/",
    "%.spec%.lua$",
  },
  timeout_ms = 10 * 60 * 1000,
  poll_interval_ms = 15000,
  stable_count_required = 3,
  min_wait_after_open_ms = 3000,
  min_analysis_time_ms = 2 * 60 * 1000, -- Wait at least 2 minutes for LSP analysis
}

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

---@param default LspCollectorConfig
---@param overrides table<string, any>|nil
---@return LspCollectorConfig
local function merge_config(default, overrides)
  local config = vim.tbl_deep_extend("force", {}, default)
  if overrides then
    for key, value in pairs(overrides) do
      if value ~= nil then
        config[key] = value
      end
    end
  end
  config.target_dir = vim.fn.expand(config.target_dir)
  config.output_file = vim.fn.expand(config.output_file)
  return config
end

---@param filepath string
---@return string
local function normalize_path(filepath)
  return (filepath:gsub("\\", "/"))
end

---@param target_dir string
---@param patterns string[]
---@param exclude_patterns string[]
---@return string[] files
---@return string[] skipped
local function collect_files(target_dir, patterns, exclude_patterns)
  local files = {}
  local skipped = {}
  local seen = {}

  for _, pattern in ipairs(patterns) do
    local matches = vim.fn.globpath(target_dir, pattern, false, true)
    for _, filepath in ipairs(matches) do
      local normalized = normalize_path(filepath)
      if not seen[normalized] then
        seen[normalized] = true
        local excluded = false
        for _, exclude in ipairs(exclude_patterns) do
          if normalized:match(exclude) then
            excluded = true
            table.insert(skipped, filepath)
            break
          end
        end
        if not excluded then
          table.insert(files, filepath)
        end
      end
    end
  end

  return files, skipped
end

---@param filepath string
---@return boolean success
---@return string|nil error
local function safe_edit(filepath)
  local ok, err = pcall(function()
    vim.cmd.edit(vim.fn.fnameescape(filepath))
  end)
  if not ok then
    return false, tostring(err)
  end
  return true, nil
end

---@return vim.Diagnostic[]
local function get_all_diagnostics()
  return vim.diagnostic.get(nil)
end

---@param diagnostics vim.Diagnostic[]
---@return FormattedDiagnostic[]
local function format_diagnostics(diagnostics)
  local severity_map = {
    [vim.diagnostic.severity.ERROR] = "ERROR",
    [vim.diagnostic.severity.WARN] = "WARN",
    [vim.diagnostic.severity.INFO] = "INFO",
    [vim.diagnostic.severity.HINT] = "HINT",
  }

  local results = {}
  for _, d in ipairs(diagnostics) do
    local bufname = vim.api.nvim_buf_get_name(d.bufnr)
    if bufname ~= "" then
      table.insert(results, {
        file = bufname,
        lnum = d.lnum + 1,
        col = d.col + 1,
        end_lnum = d.end_lnum and (d.end_lnum + 1) or nil,
        end_col = d.end_col and (d.end_col + 1) or nil,
        severity = severity_map[d.severity] or "UNKNOWN",
        message = d.message,
        source = d.source,
        code = d.code,
      })
    end
  end

  table.sort(results, function(a, b)
    if a.file ~= b.file then
      return a.file < b.file
    end
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    return a.col < b.col
  end)

  return results
end

---@param diagnostics FormattedDiagnostic[]
---@param output_file string
local function print_human_readable(diagnostics, output_file)
  log(string.format("\n=== Found %d diagnostics ===", #diagnostics))
  for _, d in ipairs(diagnostics) do
    log(string.format("%s:%d:%d: [%s] %s", d.file, d.lnum, d.col, d.severity, d.message))
  end
  log(string.format("\nJSON output: %s", output_file))
end

---@param elapsed_ms number
---@param busy boolean
---@param count number
---@param stable number
---@param required number
---@param attached_count number
---@param expected_count number
local function print_progress(elapsed_ms, busy, count, stable, required, attached_count, expected_count)
  local elapsed_s = math.floor(elapsed_ms / 1000)
  if busy then
    log(string.format(
      "[%s] [%ds] LSP busy (attached=%d/%d), diagnostics=%d",
      __module_name__,
      elapsed_s,
      attached_count,
      expected_count,
      count
    ))
  else
    log(string.format(
      "[%s] [%ds] LSP idle (attached=%d/%d), diagnostics=%d, stable=%d/%d",
      __module_name__,
      elapsed_s,
      attached_count,
      expected_count,
      count,
      stable,
      required
    ))
  end
end

---@param expected_count number
---@return boolean ready
---@return number attached_count
---@return number total_listed
local function check_lsp_attach_status(expected_count)
  if expected_count == 0 then
    return true, 0, 0
  end

  local attached_count = 0
  local total_listed = 0

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted then
      total_listed = total_listed + 1
      local clients = vim.lsp.get_clients({ bufnr = bufnr })
      if #clients > 0 then
        attached_count = attached_count + 1
      end
    end
  end

  local threshold = 0.9
  local min_required = math.max(1, math.ceil(expected_count * threshold))
  local ready = attached_count >= min_required

  return ready, attached_count, total_listed
end

---@return boolean
local function lsp_is_busy()
  for _, client in pairs(vim.lsp.get_clients()) do
    if client.requests then
      for _, req in pairs(client.requests) do
        if req then
          return true
        end
      end
    end
  end

  local ok, status = pcall(vim.lsp.status)
  if ok and status and status ~= "" then
    return true
  end

  return false
end

--------------------------------------------------------------------------------
-- Core Logic
--------------------------------------------------------------------------------

---@param state LspCollectorState
local function collect_and_output(state)
  local diagnostics = get_all_diagnostics()
  local results = format_diagnostics(diagnostics)

  local output = {
    meta = {
      target_dir = state.config.target_dir,
      total_files = #state.opened_files,
      failed_files = state.failed_files,
      total_diagnostics = #results,
      elapsed_ms = vim.uv.now() - state.start_time,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    },
    diagnostics = results,
  }

  local ok_encode, json = pcall(vim.fn.json_encode, output)
  if not ok_encode then
    log(string.format("[%s] ERROR: JSON encode failed, falling back to text output", __module_name__))
    print_human_readable(results, state.config.output_file)
    vim.cmd("cq!")
    return
  end

  local write_result = vim.fn.writefile({ json }, state.config.output_file)
  if write_result == -1 then
    log(string.format("[%s] ERROR: Failed to write to %s", __module_name__, state.config.output_file))
  end

  print_human_readable(results, state.config.output_file)
end

local poll ---@type fun(state: LspCollectorState): nil

---@param state LspCollectorState
poll = function(state)
  local elapsed = vim.uv.now() - state.start_time
  local expected_attach_count = #state.opened_files

  if elapsed > state.config.timeout_ms then
    log(string.format("[%s] WARNING: Timeout reached!", __module_name__))
    collect_and_output(state)
    vim.cmd("qa!")
    return
  end

  local attach_ready, attached_count, total_listed = check_lsp_attach_status(expected_attach_count)
  if not attach_ready then
    state.stable_count = 0
    log(string.format(
      "[%s] [%ds] Waiting for LSP to attach... (attached=%d/%d, expected=%d)",
      __module_name__,
      math.floor(elapsed / 1000),
      attached_count,
      total_listed,
      expected_attach_count
    ))
    vim.defer_fn(function()
      poll(state)
    end, state.config.poll_interval_ms)
    return
  end

  local busy = lsp_is_busy()
  local current_count = #get_all_diagnostics()

  -- Stability check:
  -- 1. Must wait for min_analysis_time before counting stability
  -- 2. LSP idle + diagnostics stable → stable_count++
  -- 3. LSP busy + diagnostics stable → busy_stable_count++ (requires longer stable period)
  local past_min_analysis_time = elapsed >= state.config.min_analysis_time_ms

  if past_min_analysis_time and current_count == state.last_diagnostic_count then
    if not busy then
      state.stable_count = state.stable_count + 1
      state.busy_stable_count = 0
    else
      state.busy_stable_count = state.busy_stable_count + 1
    end
  else
    state.stable_count = 0
    state.busy_stable_count = 0
  end

  state.last_diagnostic_count = current_count

  print_progress(
    elapsed,
    busy,
    current_count,
    state.stable_count,
    state.config.stable_count_required,
    attached_count,
    expected_attach_count
  )

  -- Completion conditions:
  -- 1. LSP idle and diagnostics stable for required cycles
  -- 2. LSP busy but diagnostics stable for 3x required cycles (give LSP more time)
  local busy_stable_threshold = state.config.stable_count_required * 3
  if state.stable_count >= state.config.stable_count_required then
    log(string.format("[%s] LSP analysis complete!", __module_name__))
    collect_and_output(state)
    vim.cmd("qa!")
    return
  elseif state.busy_stable_count >= busy_stable_threshold then
    log(string.format("[%s] LSP still busy but diagnostics stable for %d cycles, completing...", __module_name__, state.busy_stable_count))
    collect_and_output(state)
    vim.cmd("qa!")
    return
  end

  vim.defer_fn(function()
    poll(state)
  end, state.config.poll_interval_ms)
end

---@param config LspCollectorConfig
---@param opened_files string[]
---@param failed_files string[]
local function start_polling(config, opened_files, failed_files)
  local state = {
    config = config,
    start_time = vim.uv.now(),
    stable_count = 0,
    busy_stable_count = 0,
    last_diagnostic_count = -1,
    opened_files = opened_files,
    failed_files = failed_files,
  }
  poll(state)
end

local function main()
  ---@type string|nil, string|nil, string[]|nil, string[]|nil
  local target_dir, output_file, file_patterns, exclude_patterns = TARGET_DIR, OUTPUT_FILE, FILE_PATTERNS, EXCLUDE_PATTERNS
  local config = merge_config(DEFAULT_CONFIG, {
    target_dir = target_dir,
    output_file = output_file,
    file_patterns = file_patterns,
    exclude_patterns = exclude_patterns,
  })

  log(string.format("[%s] Target: %s", __module_name__, config.target_dir))
  log(string.format("[%s] Output: %s", __module_name__, config.output_file))

  local files, skipped = collect_files(config.target_dir, config.file_patterns, config.exclude_patterns)
  log(string.format("[%s] Found %d files (skipped %d)", __module_name__, #files, #skipped))

  if #files == 0 then
    log(string.format("[%s] No files to check, exiting.", __module_name__))
    local output = {
      meta = {
        target_dir = config.target_dir,
        total_files = 0,
        failed_files = {},
        total_diagnostics = 0,
        elapsed_ms = 0,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      },
      diagnostics = {},
    }
    local json = vim.fn.json_encode(output)
    vim.fn.writefile({ json }, config.output_file)
    vim.cmd("qa!")
    return
  end

  local opened_files = {}
  local failed_files = {}
  for i, file in ipairs(files) do
    local ok, err = safe_edit(file)
    if ok then
      table.insert(opened_files, file)
    else
      table.insert(failed_files, file)
      log(string.format("[%s] WARN: Failed to open %s: %s", __module_name__, file, err))
    end
    if i % 20 == 0 then
      log(string.format("[%s] Opened %d/%d files...", __module_name__, i, #files))
    end
  end
  log(string.format("[%s] Opened %d/%d files", __module_name__, #opened_files, #files))

  vim.defer_fn(function()
    start_polling(config, opened_files, failed_files)
  end, config.min_wait_after_open_ms)
end

--------------------------------------------------------------------------------
-- Entry Point
--------------------------------------------------------------------------------

vim.schedule(function()
  main()
end)
