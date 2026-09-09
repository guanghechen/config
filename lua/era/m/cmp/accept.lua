---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.accept" ---@type string

local bridge = require("era.m.cmp.bridge")
local editor = require("era.m.cmp.editor")
local brackets = require("era.m.cmp.brackets")

local M = {}
local RESOLVE_WAIT_MS = 100

---@param item                          era.m.cmp.ICompletionItem
---@return lsp.Range
local function effective_range(item)
  local range = vim.deepcopy(item.textEdit.range) ---@type lsp.Range
  range["end"].character = range["end"].character + (item._era_cmp_suffix_bytes or 0)
  return range
end

---@param item                          era.m.cmp.ICompletionItem
---@return table|nil
local function meta(item)
  if type(item._era_cmp_meta) == "table" then
    return item._era_cmp_meta
  end
  return type(item.data) == "table" and item.data.era_cmp or nil
end

---@param edits                         ?lsp.TextEdit[]
---@param bufnr                         integer
---@return nil
local function apply_text_edits(edits, bufnr)
  if edits ~= nil and next(edits) ~= nil then
    vim.lsp.util.apply_text_edits(edits, bufnr, "utf-8")
  end
end

---@param command                       ?lsp.Command
---@param bufnr                         integer
---@return nil
local function execute_command(command, bufnr)
  if command == nil then
    return
  end
  local ok, err = xpcall(function()
    bridge.execute_command(command, { bufnr = bufnr })
  end, debug.traceback)
  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "command",
      message = "Failed to execute completion command.",
      details = err,
    })
  end
end

---@return boolean
local function is_accept_mode()
  local mode = vim.api.nvim_get_mode().mode ---@type string
  return mode:match("^[iR]") ~= nil or mode == "s" or mode == "S" or mode == string.char(19)
end

---@class era.m.cmp.accept.IPending
---@field public cancel                 ?fun(): nil
---@field public tracker                ?era.m.cmp.editor.ITracker
---@field public snapshot               ?string[]
---@field public result                 ?era.m.cmp.ICompletionItem
---@field public ready                  boolean
---@field public committed              boolean
---@field public consumed               boolean
---@field public changedtick            ?integer
---@field public cursor                 ?integer[]

local pending = {} ---@type table<integer, era.m.cmp.accept.IPending>

---@param bufnr                         integer
---@return nil
local function cancel_resolve(bufnr)
  local state = pending[bufnr]
  if state == nil then
    return
  end
  pending[bufnr] = nil
  state.snapshot = nil
  state.result = nil
  if state.tracker ~= nil then
    state.tracker.close()
    state.tracker = nil
  end
  local cancel = state.cancel
  state.cancel = nil
  if type(cancel) == "function" then
    local ok, err = pcall(cancel)
    if not ok then
      stl.reporter.warn({
        from = __module_name__,
        subject = "cancel",
        message = "Failed to cancel completion acceptance.",
        details = err,
      })
    end
  end
end

---@param bufnr                         integer
---@return nil
function M.cancel(bufnr)
  brackets.cancel(bufnr)
  cancel_resolve(bufnr)
end

---@param completed                     table
---@param record                        fun(item: table): nil
---@param base                          ?era.m.cmp.editor.IBase
---@param on_brackets                   ?fun(): nil
---@return boolean
function M.apply(completed, record, base, on_brackets)
  local item = type(completed) == "table" and vim.tbl_get(completed, "user_data", "era_cmp", "item") or nil
  local edit = item and item.textEdit
  if
    type(item) ~= "table"
    or meta(item) == nil
    or type(edit) ~= "table"
    or type(edit.newText) ~= "string"
    or type(edit.range) ~= "table"
  then
    return false
  end
  local bufnr = vim.api.nvim_get_current_buf()
  local winnr = vim.api.nvim_get_current_win()
  if base ~= nil and base.bufnr ~= bufnr then
    return false
  end
  if base == nil then
    local cursor = vim.api.nvim_win_get_cursor(0)
    base = { bufnr = bufnr, row = cursor[1] - 1, col = cursor[2], line = vim.api.nvim_get_current_line() }
  end
  local text = edit.newText:gsub("\r\n?", "\n")
  local snippet = item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet
  local primary = effective_range(item)
  local initial_edits = item.additionalTextEdits
  local initial_command = item.command
  local has_initial_edits = type(initial_edits) == "table" and next(initial_edits) ~= nil
  local has_initial_command = type(initial_command) == "table"
  local valid, validation_error = xpcall(function()
    if snippet then
      vim.lsp._snippet_grammar.parse(text)
    end
    editor.validate(initial_edits, primary)
  end, debug.traceback)
  if not valid then
    stl.reporter.error({
      from = __module_name__,
      subject = "preflight",
      message = "Rejected invalid completion item.",
      details = validation_error,
    })
    return false
  end

  M.cancel(bufnr)
  editor.restore(base)
  local state = { ready = false, committed = false, consumed = false } ---@type era.m.cmp.accept.IPending
  pending[bufnr] = state
  local applied = nil ---@type era.m.cmp.editor.IApplied|nil
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local mode = vim.api.nvim_get_mode().mode
  ---@return boolean
  local function current_input()
    return pending[bufnr] == state
      and vim.api.nvim_buf_is_valid(bufnr)
      and vim.api.nvim_get_current_buf() == bufnr
      and vim.api.nvim_get_current_win() == winnr
      and vim.api.nvim_get_mode().mode == mode
      and vim.api.nvim_buf_get_changedtick(bufnr) == changedtick
      and vim.deep_equal(vim.api.nvim_win_get_cursor(0), cursor)
  end
  ---@return boolean
  local function same_owner()
    return vim.api.nvim_buf_is_valid(bufnr)
      and vim.api.nvim_get_current_buf() == bufnr
      and vim.api.nvim_get_current_win() == winnr
      and is_accept_mode()
  end
  ---@return nil
  local function finish()
    if pending[bufnr] ~= state or not state.ready or not state.committed then
      return
    end
    if state.consumed or type(state.result) ~= "table" or not same_owner() then
      cancel_resolve(bufnr)
      return
    end
    local stable = vim.api.nvim_buf_get_changedtick(bufnr) == state.changedtick
      and vim.deep_equal(vim.api.nvim_win_get_cursor(0), state.cursor)
    local command = stable and not has_initial_command and state.result.command or nil
    local edits = nil ---@type lsp.TextEdit[]|nil
    local planned, plan_error = xpcall(function()
      if not has_initial_edits and state.tracker ~= nil and type(state.result.additionalTextEdits) == "table" then
        editor.validate(state.result.additionalTextEdits, primary)
        edits = state.tracker.rebase(editor.transform(state.result.additionalTextEdits, primary, applied.finish))
      end
    end, debug.traceback)
    cancel_resolve(bufnr)
    if not planned then
      stl.reporter.error({
        from = __module_name__,
        subject = "resolved",
        message = "Rejected resolved completion side effects.",
        details = plan_error,
      })
      return
    end
    local ok, err = xpcall(function()
      apply_text_edits(edits, bufnr)
      execute_command(command, bufnr)
    end, debug.traceback)
    if not ok then
      stl.reporter.error({
        from = __module_name__,
        subject = "resolved",
        message = "Failed to apply resolved completion side effects.",
        details = err,
      })
    end
  end

  state.cancel = bridge.resolve(item, function(err, result)
    if pending[bufnr] ~= state or state.ready then
      return
    end
    state.ready = true
    state.result = result
    if err ~= nil then
      stl.reporter.warn({
        from = __module_name__,
        subject = "resolve",
        message = "Failed to resolve accepted completion item.",
        details = err,
      })
    end
    finish()
  end, function()
    return state.snapshot
  end)

  local interrupted = false
  if not state.ready and current_input() then
    local waited, wait_error = vim.wait(RESOLVE_WAIT_MS, function()
      return state.ready or not current_input()
    end, 1)
    interrupted = not waited and wait_error == -2
  end
  if not current_input() or interrupted then
    if pending[bufnr] == state then
      M.cancel(bufnr)
    end
    return false
  end

  local ready = state.ready
  if not ready and not has_initial_edits then
    state.snapshot = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local origin = item._era_cmp_origin
    if origin ~= nil then
      state.snapshot[origin.context.row + 1] = origin.context.line
    end
  end
  local ok, apply_error = xpcall(function()
    if ready and type(state.result) == "table" then
      if not has_initial_edits then
        initial_edits = state.result.additionalTextEdits
      end
      if not has_initial_command then
        initial_command = state.result.command
      end
      editor.validate(initial_edits, primary)
    end
    editor.undo_point(bufnr)
    applied =
      editor.apply(base, edit.range.start, item._era_cmp_suffix_bytes or 0, text, snippet, item._era_cmp_cursor_offset)
    if not ready and not has_initial_edits then
      local cursor = vim.api.nvim_win_get_cursor(0)
      local finish_position = { line = cursor[1] - 1, character = cursor[2] }
      if finish_position.line == edit.range.start.line and finish_position.character == edit.range.start.character then
        finish_position = applied.finish
      end
      state.tracker = editor.track(bufnr, { start = edit.range.start, ["end"] = finish_position })
    end
    apply_text_edits(editor.transform(initial_edits, primary, applied.finish), bufnr)
    execute_command(initial_command, bufnr)
  end, debug.traceback)
  if not ok then
    if pending[bufnr] == state then
      M.cancel(bufnr)
    end
    stl.reporter.error({
      from = __module_name__,
      subject = "apply",
      message = "Failed to apply completion item.",
      details = apply_error,
    })
    return false
  end

  state.consumed = ready
  if same_owner() then
    state.changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
    state.cursor = vim.api.nvim_win_get_cursor(0)
  end
  local sanitized = vim.deepcopy(completed)
  sanitized.user_data.era_cmp = nil
  vim.api.nvim_set_vvar("completed_item", sanitized)
  state.committed = true
  finish()
  local invoked, repeated, repeat_error = xpcall(editor.record, debug.traceback, applied, sanitized)
  if not invoked or not repeated and repeat_error ~= nil then
    stl.reporter.warn({
      from = __module_name__,
      subject = "repeat",
      message = "Failed to record completion repeat.",
      details = invoked and repeat_error or repeated,
    })
  end
  local requested, request_error = xpcall(brackets.request, debug.traceback, item, applied, sanitized, on_brackets)
  if not requested then
    brackets.cancel(bufnr)
    stl.reporter.warn({
      from = __module_name__,
      subject = "brackets",
      message = "Failed to prepare semantic completion brackets.",
      details = request_error,
    })
  end
  local recorded, record_error = xpcall(record, debug.traceback, completed)
  if not recorded then
    stl.reporter.warn({
      from = __module_name__,
      subject = "record",
      message = "Failed to record completion usage.",
      details = record_error,
    })
  end
  return true
end

return M
