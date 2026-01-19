---@diagnostic disable-next-line: unused-local
local __module_name__ = "init-debug-lsp" ---@type string

---@type string|nil
TARGET_DIR = TARGET_DIR
---@type string|nil
OUTPUT_FILE = OUTPUT_FILE
---@type string[]|nil
FILE_PATTERNS = FILE_PATTERNS
---@type string[]|nil
EXCLUDE_PATTERNS = EXCLUDE_PATTERNS
---@type string|nil
MIN_SEVERITY = MIN_SEVERITY
---@type string[]|nil
FILE_PATHS = FILE_PATHS

--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

---@class LspCollectorConfig
---@field target_dir                    string
---@field output_file                   string
---@field file_paths                    string[]|nil
---@field file_patterns                 string[]
---@field exclude_patterns              string[]
---@field min_severity                  integer
---@field timeout_ms                    integer
---@field poll_interval_ms              integer
---@field stable_count_required         integer
---@field min_wait_after_open_ms        integer
---@field min_analysis_time_ms          integer

---@class LspCollectorState
---@field config                        LspCollectorConfig
---@field start_time                    integer
---@field stable_count                  integer
---@field busy_stable_count             integer
---@field last_diagnostic_count         integer
---@field opened_files                  string[]
---@field failed_files                  string[]
---@field is_quick_mode                 boolean

---@class FormattedDiagnostic
---@field file                          string
---@field lnum                          integer
---@field col                           integer
---@field end_lnum                      integer|nil
---@field end_col                       integer|nil
---@field severity                      string
---@field message                       string
---@field source                        string|nil
---@field code                          string|number|nil

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local SEVERITY_MAP = {
  ERROR = vim.diagnostic.severity.ERROR,
  WARN = vim.diagnostic.severity.WARN,
  HINT = vim.diagnostic.severity.HINT,
  INFO = vim.diagnostic.severity.INFO,
}

local SEVERITY_NAME = {
  [vim.diagnostic.severity.ERROR] = "ERROR",
  [vim.diagnostic.severity.WARN] = "WARN",
  [vim.diagnostic.severity.HINT] = "HINT",
  [vim.diagnostic.severity.INFO] = "INFO",
}

---@type LspCollectorConfig
local DEFAULT_CONFIG = {
  target_dir = vim.fn.getcwd(),
  output_file = "",
  file_paths = nil,
  file_patterns = { "**/*.lua" },
  exclude_patterns = { "/lazy/", "/pack/", "%.spec%.lua$" },
  min_severity = vim.diagnostic.severity.HINT,
  timeout_ms = 10 * 60 * 1000,
  poll_interval_ms = 15000,
  stable_count_required = 3,
  min_wait_after_open_ms = 3000,
  min_analysis_time_ms = 2 * 60 * 1000,
}

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

---@param msg                           string
---@return nil
local function log(msg)
  io.stdout:write(msg .. "\n")
  io.stdout:flush()
end

---@param overrides                     table<string, any>|nil
---@return LspCollectorConfig
local function create_config(overrides)
  local config = vim.tbl_deep_extend("force", {}, DEFAULT_CONFIG, overrides or {})
  config.target_dir = vim.fn.expand(config.target_dir)
  config.output_file = vim.fn.expand(config.output_file)
  return config
end

---@param target_dir                    string
---@param patterns                      string[]
---@param exclude_patterns              string[]
---@return string[] files, string[] skipped
local function collect_files(target_dir, patterns, exclude_patterns)
  local files = {} ---@type string[]
  local skipped = {} ---@type string[]
  local seen = {} ---@type table<string, boolean>

  for _, pattern in ipairs(patterns) do
    local matches = vim.fn.globpath(target_dir, pattern, false, true)
    for _, filepath in ipairs(matches) do
      local normalized = filepath:gsub("\\", "/")
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

---@param filepath                      string
---@return boolean success, string|nil error
local function safe_edit(filepath)
  local ok, err = pcall(vim.cmd.edit, vim.fn.fnameescape(filepath))
  if not ok then
    return false, tostring(err)
  end
  return true, nil
end

---@param min_severity                  integer
---@return vim.Diagnostic[]
local function get_all_diagnostics(min_severity)
  return vim.tbl_filter(function(d)
    return d.severity <= min_severity
  end, vim.diagnostic.get(nil))
end

---@param diagnostics                   vim.Diagnostic[]
---@return FormattedDiagnostic[]
local function format_diagnostics(diagnostics)
  local results = {} ---@type FormattedDiagnostic[]

  for _, d in ipairs(diagnostics) do
    local bufname = vim.api.nvim_buf_get_name(d.bufnr)
    if bufname ~= "" then
      table.insert(results, {
        file = bufname,
        lnum = d.lnum + 1,
        col = d.col + 1,
        end_lnum = d.end_lnum and (d.end_lnum + 1) or nil,
        end_col = d.end_col and (d.end_col + 1) or nil,
        severity = SEVERITY_NAME[d.severity] or "UNKNOWN",
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

---@param expected_count                integer
---@return boolean ready, integer attached_count, integer total_listed
local function check_lsp_attach_status(expected_count)
  if expected_count == 0 then
    return true, 0, 0
  end

  local attached_count = 0
  local total_listed = 0

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_get_option_value("buflisted", { buf = bufnr }) then
      total_listed = total_listed + 1
      if #vim.lsp.get_clients({ bufnr = bufnr }) > 0 then
        attached_count = attached_count + 1
      end
    end
  end

  local min_required = math.max(1, math.ceil(expected_count * 0.9))
  return attached_count >= min_required, attached_count, total_listed
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
  return ok and status and status ~= ""
end

--------------------------------------------------------------------------------
-- Core Logic
--------------------------------------------------------------------------------

---@param state                         LspCollectorState
---@return integer
local function collect_and_output(state)
  local diagnostics = get_all_diagnostics(state.config.min_severity)
  local results = format_diagnostics(diagnostics)
  local elapsed_ms = vim.uv.now() - state.start_time

  ---@type table
  local meta = {
    target_dir = state.config.target_dir,
    total_files = #state.opened_files,
    failed_files = state.failed_files,
    total_diagnostics = #results,
    min_severity = SEVERITY_NAME[state.config.min_severity],
    elapsed_ms = elapsed_ms,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }

  if state.is_quick_mode then
    meta.file_paths = state.config.file_paths
  end

  ---@type table
  local output = {
    meta = meta,
    diagnostics = results,
  }

  local ok_encode, json = pcall(vim.fn.json_encode, output)
  if not ok_encode then
    log(string.format("[%s] ERROR: JSON encode failed", __module_name__))
    vim.cmd("cq!")
    return #results
  end

  if vim.fn.writefile({ json }, state.config.output_file) == -1 then
    log(string.format("[%s] ERROR: Failed to write to %s", __module_name__, state.config.output_file))
  end

  log(string.format("\n=== Found %d diagnostics ===", #results))
  for _, d in ipairs(results) do
    log(string.format("%s:%d:%d: [%s] %s", d.file, d.lnum, d.col, d.severity, d.message))
  end
  log(string.format("\nJSON output: %s", state.config.output_file))

  return #results
end

---@param state                         LspCollectorState
---@return nil
local function poll(state)
  local elapsed = vim.uv.now() - state.start_time
  local config = state.config
  local expected_attach_count = #state.opened_files

  if elapsed > config.timeout_ms then
    log(string.format("[%s] WARNING: Timeout reached!", __module_name__))
    local diag_count = collect_and_output(state)
    vim.cmd(diag_count > 0 and "cq!" or "qa!")
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
    end, config.poll_interval_ms)
    return
  end

  local busy = lsp_is_busy()
  local current_count = #get_all_diagnostics(config.min_severity)
  local past_min_analysis_time = elapsed >= config.min_analysis_time_ms
  local elapsed_s = math.floor(elapsed / 1000)
  local progress_pct = math.min(99, math.floor(elapsed / config.timeout_ms * 100))

  if past_min_analysis_time and current_count == state.last_diagnostic_count then
    if busy then
      state.busy_stable_count = state.busy_stable_count + 1
    else
      state.stable_count = state.stable_count + 1
      state.busy_stable_count = 0
    end
  else
    state.stable_count = 0
    state.busy_stable_count = 0
  end

  state.last_diagnostic_count = current_count

  if busy then
    log(string.format(
      "[%s] [%ds] [%d%%] LSP busy (attached=%d/%d), diagnostics=%d",
      __module_name__,
      elapsed_s,
      progress_pct,
      attached_count,
      expected_attach_count,
      current_count
    ))
  else
    log(string.format(
      "[%s] [%ds] [%d%%] LSP idle (attached=%d/%d), diagnostics=%d, stable=%d/%d",
      __module_name__,
      elapsed_s,
      progress_pct,
      attached_count,
      expected_attach_count,
      current_count,
      state.stable_count,
      config.stable_count_required
    ))
  end

  local busy_stable_threshold = config.stable_count_required * 3
  if state.stable_count >= config.stable_count_required then
    log(string.format("[%s] LSP analysis complete!", __module_name__))
    local diag_count = collect_and_output(state)
    vim.cmd(diag_count > 0 and "cq!" or "qa!")
    return
  elseif state.busy_stable_count >= busy_stable_threshold then
    log(string.format("[%s] LSP still busy but diagnostics stable for %d cycles, completing...", __module_name__, state.busy_stable_count))
    local diag_count = collect_and_output(state)
    vim.cmd(diag_count > 0 and "cq!" or "qa!")
    return
  end

  vim.defer_fn(function()
    poll(state)
  end, config.poll_interval_ms)
end

---@return nil
local function main()
  require("ark.bootstrap").setup()

  local default_storage = dot.get_default_storage() ---@type dot.context.storage
  dot.setup_context({
    editor = default_storage.editor,
    workspace = default_storage.workspace,
  })

  require("era.plugin")

  local severity_value = MIN_SEVERITY and SEVERITY_MAP[MIN_SEVERITY] or nil
  local config = create_config({
    target_dir = TARGET_DIR,
    output_file = OUTPUT_FILE,
    file_paths = FILE_PATHS,
    file_patterns = FILE_PATTERNS,
    exclude_patterns = EXCLUDE_PATTERNS,
    min_severity = severity_value,
  })

  if config.output_file == "" then
    log(string.format("[%s] ERROR: OUTPUT_FILE is required but not specified", __module_name__))
    log(string.format("[%s] Usage: nvim --headless -c \"lua OUTPUT_FILE='/path/to/output.json'\" -c \"luafile %s\"", __module_name__, debug.getinfo(1, "S").source:sub(2)))
    vim.cmd("cq!")
    return
  end

  local output_dir = vim.fn.fnamemodify(config.output_file, ":h")
  if vim.fn.isdirectory(output_dir) == 0 then
    vim.fn.mkdir(output_dir, "p")
    log(string.format("[%s] Created output directory: %s", __module_name__, output_dir))
  end

  log(string.format("[%s] Target: %s", __module_name__, config.target_dir))
  log(string.format("[%s] Output: %s", __module_name__, config.output_file))

  local files ---@type string[]
  local skipped = {} ---@type string[]
  local is_quick_mode = (config.file_paths and #config.file_paths > 0) == true ---@type boolean

  if is_quick_mode then
    files = {}
    for _, path in ipairs(config.file_paths) do
      local expanded = vim.fn.expand(path) ---@type string
      if vim.fn.filereadable(expanded) == 1 then
        table.insert(files, expanded)
      else
        log(string.format("[%s] WARN: File not readable: %s", __module_name__, expanded))
      end
    end
    log(string.format("[%s] Using explicit file paths: %d files (quick mode)", __module_name__, #files))
    config.min_analysis_time_ms = 45 * 1000
  else
    files, skipped = collect_files(config.target_dir, config.file_patterns, config.exclude_patterns)
    log(string.format("[%s] Found %d files (skipped %d)", __module_name__, #files, #skipped))
  end

  if #files == 0 then
    log(string.format("[%s] No files to check, exiting.", __module_name__))
    local json = vim.fn.json_encode({
      meta = {
        target_dir = config.target_dir,
        total_files = 0,
        failed_files = {},
        total_diagnostics = 0,
        elapsed_ms = 0,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      },
      diagnostics = {},
    })
    vim.fn.writefile({ json }, config.output_file)
    vim.cmd("qa!")
    return
  end

  local opened_files = {} ---@type string[]
  local failed_files = {} ---@type string[]
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

  ---@type LspCollectorState
  local state = {
    config = config,
    start_time = vim.uv.now(),
    stable_count = 0,
    busy_stable_count = 0,
    last_diagnostic_count = -1,
    opened_files = opened_files,
    failed_files = failed_files,
    is_quick_mode = is_quick_mode,
  }

  vim.defer_fn(function()
    poll(state)
  end, config.min_wait_after_open_ms)
end

--------------------------------------------------------------------------------
-- Entry Point
--------------------------------------------------------------------------------

vim.schedule(main)
