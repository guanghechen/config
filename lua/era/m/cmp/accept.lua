---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.accept" ---@type string

local bridge = require("era.m.cmp.bridge")

local M = {}
local namespace = vim.api.nvim_create_namespace(__module_name__)

---@param left                          lsp.Position
---@param right                         lsp.Position
---@return integer
local function compare_position(left, right)
  if left.line ~= right.line then
    return left.line < right.line and -1 or 1
  end
  if left.character == right.character then
    return 0
  end
  return left.character < right.character and -1 or 1
end

---@param position                      lsp.Position
---@param range                         lsp.Range
---@param final_end                     lsp.Position
---@return lsp.Position
local function transform_after(position, range, final_end)
  if position.line == range["end"].line then
    return {
      line = final_end.line,
      character = final_end.character + position.character - range["end"].character,
    }
  end
  return {
    line = position.line + final_end.line - range["end"].line,
    character = position.character,
  }
end

---@param edits                         lsp.TextEdit[]|nil
---@param range                         lsp.Range
---@param final_end                     lsp.Position
---@return lsp.TextEdit[]|nil
local function transform_text_edits(edits, range, final_end)
  if edits == nil then
    return nil
  end
  local transformed = {} ---@type lsp.TextEdit[]
  for index, edit in ipairs(edits) do
    local edit_range = edit.range
    local copied = vim.deepcopy(edit) ---@type lsp.TextEdit
    if compare_position(edit_range["end"], range.start) <= 0 then
      transformed[index] = copied
    elseif compare_position(edit_range.start, range["end"]) >= 0 then
      copied.range.start = transform_after(edit_range.start, range, final_end)
      copied.range["end"] = transform_after(edit_range["end"], range, final_end)
      transformed[index] = copied
    else
      error("additional text edit overlaps the primary completion edit", 0)
    end
  end
  return transformed
end

---@param edits                         lsp.TextEdit[]|nil
---@param primary                       lsp.Range
local function validate_text_edits(edits, primary)
  if edits == nil then
    return
  end
  local ranges = {} ---@type lsp.Range[]
  for _, edit in ipairs(edits) do
    local range = edit.range
    if compare_position(range.start, range["end"]) > 0 then
      error("invalid additional text edit range", 0)
    end
    if compare_position(range["end"], primary.start) > 0 and compare_position(range.start, primary["end"]) < 0 then
      error("additional text edit overlaps the primary completion edit", 0)
    end
    ranges[#ranges + 1] = range
  end
  table.sort(ranges, function(left, right)
    return compare_position(left.start, right.start) < 0
  end)
  for index = 2, #ranges do
    if compare_position(ranges[index - 1]["end"], ranges[index].start) > 0 then
      error("additional text edits overlap", 0)
    end
  end
end

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

---@param edits                         lsp.TextEdit[]|nil
---@param bufnr                         integer
local function apply_text_edits(edits, bufnr)
  if edits ~= nil and next(edits) ~= nil then
    vim.lsp.util.apply_text_edits(edits, bufnr, "utf-8")
  end
end

---@param command                       lsp.Command|nil
---@param bufnr                         integer
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

---@param completed                     table
---@param record                         fun(item: table): nil
---@param suffix_consumed?               boolean
---@return boolean
function M.apply(completed, record, suffix_consumed)
  if type(completed) ~= "table" or vim.tbl_isempty(completed) then
    return false
  end
  local lsp_item = vim.tbl_get(completed, "user_data", "era_cmp", "item") ---@type era.m.cmp.ICompletionItem|nil
  local text_edit = lsp_item and lsp_item.textEdit or nil ---@type table|nil
  if
    type(lsp_item) ~= "table"
    or meta(lsp_item) == nil
    or type(text_edit) ~= "table"
    or type(text_edit.newText) ~= "string"
    or type(text_edit.range) ~= "table"
  then
    return false
  end

  local sanitized = vim.deepcopy(completed) ---@type table
  sanitized.user_data.era_cmp = nil
  vim.api.nvim_set_vvar("completed_item", sanitized)

  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local row, col = unpack(vim.api.nvim_win_get_cursor(0)) ---@type integer, integer
  local suffix_bytes = lsp_item._era_cmp_suffix_bytes or 0 ---@type integer
  local pending_suffix_bytes = suffix_consumed and 0 or suffix_bytes ---@type integer
  local is_snippet = lsp_item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet
  local primary_text = text_edit.newText:gsub("\r\n?", "\n") ---@type string
  if is_snippet then
    local valid, parse_err = pcall(vim.lsp._snippet_grammar.parse, primary_text)
    if not valid then
      stl.reporter.error({
        from = __module_name__,
        subject = "snippet",
        message = "Rejected invalid completion snippet.",
        details = parse_err,
      })
      return false
    end
  end
  local primary_range = effective_range(lsp_item) ---@type lsp.Range
  local initial_edits = lsp_item.additionalTextEdits ---@type lsp.TextEdit[]|nil
  local initial_command = lsp_item.command ---@type lsp.Command|nil
  local has_initial_edits = type(initial_edits) == "table" and next(initial_edits) ~= nil ---@type boolean
  local has_initial_command = type(initial_command) == "table" ---@type boolean
  local tail_mark = nil ---@type integer|nil
  local final_end = nil ---@type lsp.Position|nil
  local preflight_ok, preflight_err = xpcall(function()
    validate_text_edits(initial_edits, primary_range)
  end, debug.traceback)
  if not preflight_ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "edits",
      message = "Rejected invalid completion text edits.",
      details = preflight_err,
    })
    return false
  end
  local origin = lsp_item._era_cmp_origin
  local text_snapshot = origin ~= nil
      and primary_text:find("\n", 1, true) ~= nil
      and vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    or nil ---@type string[]|nil
  if text_snapshot ~= nil then
    text_snapshot[origin.context.row + 1] = origin.context.line
  end
  local ok, err = xpcall(function()
    local line = vim.api.nvim_get_current_line() ---@type string
    local suffix_end_col = math.min(col + pending_suffix_bytes, #line) ---@type integer
    tail_mark = vim.api.nvim_buf_set_extmark(bufnr, namespace, row - 1, suffix_end_col, { right_gravity = true })
    if suffix_end_col > col then
      vim.api.nvim_buf_set_text(bufnr, row - 1, col, row - 1, suffix_end_col, {})
    end
    vim.api.nvim_buf_set_text(bufnr, text_edit.range.start.line, text_edit.range.start.character, row - 1, col, {})
    if is_snippet then
      vim.snippet.expand(primary_text)
    else
      local lines = vim.split(primary_text, "\n", { plain = true }) ---@type string[]
      if #lines == 0 then
        lines = { "" }
      end
      vim.api.nvim_buf_set_text(
        bufnr,
        text_edit.range.start.line,
        text_edit.range.start.character,
        text_edit.range.start.line,
        text_edit.range.start.character,
        lines
      )
    end
    local position = vim.api.nvim_buf_get_extmark_by_id(bufnr, namespace, tail_mark, {}) ---@type integer[]
    if #position ~= 2 then
      error("completion tail mark was lost", 0)
    end
    final_end = { line = position[1], character = position[2] }
    if not is_snippet then
      vim.api.nvim_win_set_cursor(0, { final_end.line + 1, final_end.character })
    end
    apply_text_edits(has_initial_edits and transform_text_edits(initial_edits, primary_range, final_end) or nil, bufnr)
    execute_command(has_initial_command and initial_command or nil, bufnr)
  end, debug.traceback)
  if tail_mark ~= nil then
    pcall(vim.api.nvim_buf_del_extmark, bufnr, namespace, tail_mark)
  end
  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "apply",
      message = "Failed to apply completion item.",
      details = err,
    })
    return false
  end
  local accepted_end = assert(final_end) ---@type lsp.Position

  local recorded, record_err = xpcall(record, debug.traceback, completed)
  if not recorded then
    stl.reporter.warn({
      from = __module_name__,
      subject = "record",
      message = "Failed to record completion usage.",
      details = record_err,
    })
  end

  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr) ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(0) ---@type integer[]
  bridge.resolve(lsp_item, function(resolve_err, resolved)
    if resolve_err ~= nil then
      stl.reporter.warn({
        from = __module_name__,
        subject = "resolve",
        message = "Failed to resolve accepted completion item.",
        details = resolve_err,
      })
    end
    if
      type(resolved) ~= "table"
      or not vim.api.nvim_buf_is_valid(bufnr)
      or vim.api.nvim_get_current_buf() ~= bufnr
      or not is_accept_mode()
      or vim.api.nvim_buf_get_changedtick(bufnr) ~= changedtick
      or not vim.deep_equal(vim.api.nvim_win_get_cursor(0), cursor)
    then
      return
    end

    local resolved_edits = not has_initial_edits and resolved.additionalTextEdits or nil ---@type lsp.TextEdit[]|nil
    local resolved_command = not has_initial_command and resolved.command or nil ---@type lsp.Command|nil
    local resolved_ok, resolved_err = xpcall(function()
      apply_text_edits(transform_text_edits(resolved_edits, primary_range, accepted_end), bufnr)
      execute_command(resolved_command, bufnr)
    end, debug.traceback)
    if not resolved_ok then
      stl.reporter.error({
        from = __module_name__,
        subject = "resolved",
        message = "Failed to apply resolved completion side effects.",
        details = resolved_err,
      })
    end
  end, text_snapshot)
  return true
end

return M
