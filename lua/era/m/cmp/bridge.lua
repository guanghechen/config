---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.bridge" ---@type string

local source = require("era.m.cmp.source")
local util = require("era.m.cmp.source.util")

local M = {}

local COMMAND = "era.cmp.execute"
local INITIAL_PUBLISH_DELAY = 40 ---@type integer
local MAX_ITEMS = 200 ---@type integer
local MAX_SUPERSEDED_SESSIONS = 8 ---@type integer
local REQUEST_TIMEOUT = 2000 ---@type integer
local TRIGGER_PARAMETER_HINTS = "editor.action.triggerParameterHints"
local TRIGGER_SUGGEST = "editor.action.triggerSuggest"
local failed_clients = {} ---@type table<integer, boolean>
local failed_items = {} ---@type table<string, boolean>
local encoded_cursors = setmetatable({}, { __mode = "k" }) ---@type table<era.m.cmp.IContext, table<string, integer>>
local history = yoz.cmp.usage({}) ---@type yoz.cmp.IUsage
local history_labels = {} ---@type table<string, table<string, boolean>>
local history_keys = {} ---@type table<string, boolean>
local refresh = nil ---@type (fun(bufnr: integer): boolean)|nil
local completion_cache = {} ---@type table<integer, { context: era.m.cmp.IContext, responses: table<integer, era.m.cmp.bridge.IResponse>, snapshot: era.m.cmp.bridge.IRankSnapshot|nil }>

---@param context                       era.m.cmp.IContext
---@return string[]|nil
local function nearby_words(context)
  local line_count = vim.api.nvim_buf_line_count(context.bufnr) ---@type integer
  local start_row = math.max(0, context.row - 30) ---@type integer
  local end_row = math.min(line_count, context.row + 31) ---@type integer
  local text = table.concat(vim.api.nvim_buf_get_lines(context.bufnr, start_row, end_row, false), "\n") ---@type string
  if #text >= 10000 then
    return nil
  end
  return yoz.cmp.words(text, math.max(#text, 1))
end

---@param context                       era.m.cmp.IContext
---@param encoding                      string
---@return integer
local function encoded_cursor(context, encoding)
  local values = encoded_cursors[context]
  if values == nil then
    values = {}
    encoded_cursors[context] = values
  end
  local value = values[encoding]
  if value == nil then
    value = vim.str_utfindex(context.line, encoding, context.col, false)
    values[encoding] = value
  end
  return value
end

---@param timer                         uv.uv_timer_t|nil
local function close_timer(timer)
  if timer ~= nil and not timer:is_closing() then
    timer:stop()
    timer:close()
  end
end

---@param item                          lsp.CompletionItem
---@param defaults                      lsp.CompletionItemDefaults|nil
local function apply_defaults(item, defaults)
  if defaults == nil then
    return
  end

  item.insertTextFormat = item.insertTextFormat or defaults.insertTextFormat
  item.insertTextMode = item.insertTextMode or defaults.insertTextMode
  item.data = item.data or defaults.data
  if defaults.editRange ~= nil then
    local text_edit = item.textEdit or {} ---@type table
    item.textEdit = text_edit
    text_edit.newText = text_edit.newText or item.textEditText or item.insertText or item.label
    if defaults.editRange.start ~= nil then
      text_edit.range = text_edit.range or vim.deepcopy(defaults.editRange)
    elseif defaults.editRange.insert ~= nil then
      text_edit.insert = text_edit.insert or vim.deepcopy(defaults.editRange.insert)
      text_edit.replace = text_edit.replace or vim.deepcopy(defaults.editRange.replace)
    end
  end
end

---@param value                         any
---@return boolean
local function is_position(value)
  return type(value) == "table"
    and type(value.line) == "number"
    and value.line >= 0
    and value.line % 1 == 0
    and type(value.character) == "number"
    and value.character >= 0
    and value.character % 1 == 0
end

---@param value                         any
---@return boolean
local function is_range(value)
  return type(value) == "table" and is_position(value.start) and is_position(value["end"])
end

---@param edit                          any
local function validate_text_edit(edit)
  if type(edit) ~= "table" or type(edit.newText) ~= "string" or not is_range(edit.range) then
    error("invalid text edit", 0)
  end
end

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

---@param primary                       lsp.Range
---@param edits                         lsp.TextEdit[]|nil
local function validate_additional_edits(primary, edits)
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

---@param value                         any
---@param name                          string
local function validate_string_list(value, name)
  if type(value) ~= "table" or not vim.islist(value) then
    error("invalid " .. name, 0)
  end
  for _, item in ipairs(value) do
    if type(item) ~= "string" then
      error("invalid " .. name, 0)
    end
  end
end

---@param item                          lsp.CompletionItem
local function validate_item(item)
  if type(item.label) ~= "string" then
    error("invalid label", 0)
  end
  for _, name in ipairs({ "detail", "filterText", "insertText", "sortText", "textEditText" }) do
    if item[name] ~= nil and type(item[name]) ~= "string" then
      error("invalid " .. name, 0)
    end
  end
  for _, name in ipairs({ "kind", "insertTextFormat", "insertTextMode" }) do
    if item[name] ~= nil and type(item[name]) ~= "number" then
      error("invalid " .. name, 0)
    end
  end
  for _, name in ipairs({ "deprecated", "preselect" }) do
    if item[name] ~= nil and type(item[name]) ~= "boolean" then
      error("invalid " .. name, 0)
    end
  end

  if item.tags ~= nil then
    if type(item.tags) ~= "table" or not vim.islist(item.tags) then
      error("invalid tags", 0)
    end
    for _, tag in ipairs(item.tags) do
      if type(tag) ~= "number" then
        error("invalid tags", 0)
      end
    end
  end
  if item.commitCharacters ~= nil then
    validate_string_list(item.commitCharacters, "commitCharacters")
  end
  if item.labelDetails ~= nil then
    if type(item.labelDetails) ~= "table" then
      error("invalid labelDetails", 0)
    end
    for _, name in ipairs({ "detail", "description" }) do
      if item.labelDetails[name] ~= nil and type(item.labelDetails[name]) ~= "string" then
        error("invalid labelDetails." .. name, 0)
      end
    end
  end
  if item.documentation ~= nil then
    if type(item.documentation) == "table" then
      if type(item.documentation.value) ~= "string" then
        error("invalid documentation", 0)
      end
    elseif type(item.documentation) ~= "string" then
      error("invalid documentation", 0)
    end
  end
  if item.command ~= nil then
    if type(item.command) ~= "table" or type(item.command.command) ~= "string" then
      error("invalid command", 0)
    end
  end
  if item.textEdit ~= nil then
    if type(item.textEdit) ~= "table" or type(item.textEdit.newText) ~= "string" then
      error("invalid textEdit", 0)
    end
    if item.textEdit.range ~= nil then
      if not is_range(item.textEdit.range) then
        error("invalid textEdit.range", 0)
      end
    elseif not is_range(item.textEdit.insert) or not is_range(item.textEdit.replace) then
      error("invalid textEdit ranges", 0)
    end
  end
  if item.additionalTextEdits ~= nil then
    if type(item.additionalTextEdits) ~= "table" or not vim.islist(item.additionalTextEdits) then
      error("invalid additionalTextEdits", 0)
    end
    for _, edit in ipairs(item.additionalTextEdits) do
      validate_text_edit(edit)
    end
  end
end

---@param bufnr                        integer
---@param position                     lsp.Position
---@param encoding                     string
---@param context                      era.m.cmp.IContext|nil
---@param text_snapshot?                string[]
---@param source_context?               era.m.cmp.IContext
---@return lsp.Position|nil
local function position_to_utf8(bufnr, position, encoding, context, text_snapshot, source_context)
  local character = position.character ---@type integer
  if
    context ~= nil
    and source_context ~= nil
    and source_context ~= context
    and source_context.bufnr == context.bufnr
    and source_context.row == context.row
    and source_context.start_col == context.start_col
    and position.line == source_context.row
  then
    local old_cursor = encoded_cursor(source_context, encoding) ---@type integer
    if character >= old_cursor then
      local new_cursor = encoded_cursor(context, encoding) ---@type integer
      character = character + new_cursor - old_cursor
    end
  end
  local line ---@type string|nil
  if text_snapshot ~= nil then
    line = text_snapshot[position.line + 1]
  elseif context ~= nil and position.line == context.row then
    line = context.line
  else
    line = vim.api.nvim_buf_get_lines(bufnr, position.line, position.line + 1, false)[1]
  end
  if line == nil then
    return nil
  end
  local ok, byte_col = pcall(vim.str_byteindex, line, encoding, character, false)
  if not ok then
    return nil
  end
  return { line = position.line, character = byte_col }
end

---@param bufnr                        integer
---@param range                        lsp.Range
---@param encoding                     string
---@param context                      era.m.cmp.IContext|nil
---@param text_snapshot?                string[]
---@param source_context?               era.m.cmp.IContext
---@return lsp.Range|nil
local function range_to_utf8(bufnr, range, encoding, context, text_snapshot, source_context)
  local start = position_to_utf8(bufnr, range.start, encoding, context, text_snapshot, source_context)
  local finish = position_to_utf8(bufnr, range["end"], encoding, context, text_snapshot, source_context)
  if start == nil or finish == nil then
    return nil
  end
  return { start = start, ["end"] = finish }
end

---@param edits                         lsp.TextEdit[]|nil
---@param bufnr                         integer
---@param encoding                      string
---@param context                       era.m.cmp.IContext|nil
---@param text_snapshot?                string[]
---@param source_context?               era.m.cmp.IContext
---@return lsp.TextEdit[]|nil
local function text_edits_to_utf8(edits, bufnr, encoding, context, text_snapshot, source_context)
  if edits == nil then
    return nil
  end

  local output = {} ---@type lsp.TextEdit[]
  for _, edit in ipairs(edits) do
    validate_text_edit(edit)
    local range = range_to_utf8(bufnr, edit.range, encoding, context, text_snapshot, source_context)
    if range == nil then
      error("text edit range cannot be converted to UTF-8", 0)
    end
    local converted = vim.deepcopy(edit) ---@type lsp.TextEdit
    converted.range = range
    output[#output + 1] = converted
  end
  return output
end

---@param item                          lsp.CompletionItem
---@param context                       era.m.cmp.IContext
---@param encoding                      string
---@param source_context?               era.m.cmp.IContext
---@return integer|nil
local function item_start_col(item, context, encoding, source_context)
  local text_edit = item.textEdit
  local range = text_edit and (text_edit.range or text_edit.insert) or nil
  if range == nil then
    return context.start_col
  end
  if range.start.line ~= context.row then
    return nil
  end
  local position = position_to_utf8(context.bufnr, range.start, encoding, context, nil, source_context)
  local byte_col = position and position.character or nil ---@type integer|nil
  if byte_col == nil or byte_col < 0 or byte_col > context.col then
    return nil
  end
  return byte_col
end

---@param item                          lsp.CompletionItem
---@param context                       era.m.cmp.IContext
---@param encoding                      string
---@param source_context?               era.m.cmp.IContext
---@return integer|nil
local function item_suffix_bytes(item, context, encoding, source_context)
  local keyword_suffix_bytes = math.max(0, context.end_col - context.col) ---@type integer
  local text_edit = item.textEdit
  local range = text_edit and (text_edit.replace or text_edit.range or text_edit.insert) or nil
  if range == nil then
    return keyword_suffix_bytes
  end
  if range["end"].line ~= context.row then
    return nil
  end
  local position = position_to_utf8(context.bufnr, range["end"], encoding, context, nil, source_context)
  local end_col = position and position.character or nil ---@type integer|nil
  if end_col == nil or end_col < context.col then
    return nil
  end
  return math.max(keyword_suffix_bytes, end_col - context.col)
end

---@param client_id                     integer
---@param command                       lsp.Command|nil
---@return lsp.Command|nil
local function wrap_command(client_id, command)
  if command == nil then
    return nil
  end
  return {
    command = COMMAND,
    arguments = { { client_id = client_id, command = command } },
  }
end

---@param value                         string
---@return string
local function escape_snippet_literal(value)
  return (value:gsub("\\", "\\\\"):gsub("%$", "\\$"):gsub("}", "\\}"))
end

---@param value                         string
local function validate_snippet(value)
  local ok, err = pcall(vim.lsp._snippet_grammar.parse, value)
  if not ok then
    error("invalid snippet: " .. tostring(err), 0)
  end
end

---@param value                         any
---@param seen?                         table<table, boolean>
---@param depth?                        integer
---@return string
local function canonical_value(value, seen, depth)
  if value == nil or value == vim.NIL then
    return "n"
  end
  local value_type = type(value)
  if value_type == "boolean" then
    return value and "b1" or "b0"
  end
  if value_type == "number" then
    if value ~= value then
      return "d:nan"
    end
    if value == math.huge then
      return "d:inf"
    end
    if value == -math.huge then
      return "d:-inf"
    end
    return value == 0 and "d:0" or "d:" .. string.format("%.17g", value)
  end
  if value_type == "string" then
    return "s:" .. #value .. ":" .. value
  end
  if value_type ~= "table" then
    return "x:" .. value_type
  end

  seen = seen or {}
  depth = depth or 0
  if depth >= 32 then
    return "x:depth"
  end
  if seen[value] then
    return "x:cycle"
  end
  seen[value] = true

  local parts = {} ---@type string[]
  if vim.islist(value) then
    parts[1] = "a:" .. #value .. ":"
    for index = 1, #value do
      parts[#parts + 1] = canonical_value(value[index], seen, depth + 1)
    end
  else
    local entries = {} ---@type { key: any, encoded: string }[]
    for key in pairs(value) do
      entries[#entries + 1] = { key = key, encoded = canonical_value(key, seen, depth + 1) }
    end
    table.sort(entries, function(left, right)
      return left.encoded < right.encoded
    end)
    parts[1] = "m:" .. #entries .. ":"
    for _, entry in ipairs(entries) do
      parts[#parts + 1] = entry.encoded
      parts[#parts + 1] = canonical_value(value[entry.key], seen, depth + 1)
    end
  end
  seen[value] = nil
  return table.concat(parts)
end

---@param edits                         lsp.TextEdit[]
---@return lsp.TextEdit[]
local function sorted_text_edits(edits)
  edits = vim.list_slice(edits)
  table.sort(edits, function(left, right)
    local compared = compare_position(left.range.start, right.range.start)
    if compared ~= 0 then
      return compared < 0
    end
    compared = compare_position(left.range["end"], right.range["end"])
    if compared ~= 0 then
      return compared < 0
    end
    return left.newText < right.newText
  end)
  return edits
end

---@param item                          lsp.CompletionItem
---@return string
local function lsp_semantic_projection(item)
  local label = item.label or "" ---@type string
  local text_edit = item.textEdit ---@type table|nil
  local new_text = type(text_edit) == "table" and text_edit.newText or item.textEditText or item.insertText or label ---@type string
  local label_details = type(item.labelDetails) == "table" and item.labelDetails or {} ---@type table
  local command = nil ---@type table|nil
  if type(item.command) == "table" then
    command = {
      command = item.command.command,
      arguments = item.command.arguments or {},
    }
  end
  local additional_edits = sorted_text_edits(item.additionalTextEdits or {}) ---@type lsp.TextEdit[]
  local additional_texts = {} ---@type string[]
  for index, edit in ipairs(additional_edits) do
    additional_texts[index] = edit.newText
  end
  local deprecated = item.deprecated == true
    or vim.list_contains(item.tags or {}, vim.lsp.protocol.CompletionTag.Deprecated) ---@type boolean

  return table.concat({
    label,
    item.kind or 0,
    item.filterText or label,
    item.sortText or label,
    item.detail or "",
    label_details.detail or "",
    label_details.description or "",
    deprecated and 1 or 0,
    item.insertTextFormat or vim.lsp.protocol.InsertTextFormat.PlainText,
    new_text,
    canonical_value(command),
    canonical_value(additional_texts),
  }, "\0")
end

---@param left                          lsp.CompletionItem
---@param right                         lsp.CompletionItem
---@return boolean
local function equal_commands(left, right)
  local left_command = left.command
  local right_command = right.command
  if left_command == nil or right_command == nil then
    return left_command == right_command
  end
  return left_command.command == right_command.command
    and vim.deep_equal(left_command.arguments or {}, right_command.arguments or {})
end

---@param left                          lsp.Position|nil
---@param right                         lsp.Position|nil
---@param left_context                  era.m.cmp.IContext
---@param right_context                 era.m.cmp.IContext
---@param encoding                      string
---@return boolean
local function equal_position(left, right, left_context, right_context, encoding)
  if left == nil or right == nil or left.line ~= right.line then
    return left == right
  end
  local function character(position, source, target)
    if
      source ~= target
      and source.bufnr == target.bufnr
      and source.row == target.row
      and source.start_col == target.start_col
      and position.line == source.row
    then
      local old_cursor = encoded_cursor(source, encoding) ---@type integer
      if position.character >= old_cursor then
        local new_cursor = encoded_cursor(target, encoding) ---@type integer
        return position.character + new_cursor - old_cursor
      end
    end
    return position.character
  end
  return character(left, left_context, right_context) == right.character
end

---@param left                          lsp.Range|nil
---@param right                         lsp.Range|nil
---@param left_context                  era.m.cmp.IContext
---@param right_context                 era.m.cmp.IContext
---@param encoding                      string
---@return boolean
local function equal_range(left, right, left_context, right_context, encoding)
  if left == nil or right == nil then
    return left == right
  end
  return equal_position(left.start, right.start, left_context, right_context, encoding)
    and equal_position(left["end"], right["end"], left_context, right_context, encoding)
end

---@param left                          lsp.CompletionItem
---@param right                         lsp.CompletionItem
---@param left_context                  era.m.cmp.IContext
---@param right_context                 era.m.cmp.IContext
---@param encoding                      string
---@return boolean
local function equal_primary_ranges(left, right, left_context, right_context, encoding)
  local left_edit = left.textEdit
  local right_edit = right.textEdit
  if left_edit == nil or right_edit == nil then
    return left_edit == right_edit
  end
  return equal_range(left_edit.range, right_edit.range, left_context, right_context, encoding)
    and equal_range(left_edit.insert, right_edit.insert, left_context, right_context, encoding)
    and equal_range(left_edit.replace, right_edit.replace, left_context, right_context, encoding)
end

---@param left                          lsp.TextEdit[]|nil
---@param right                         lsp.TextEdit[]|nil
---@param left_context                  era.m.cmp.IContext
---@param right_context                 era.m.cmp.IContext
---@param encoding                      string
---@return boolean
local function equal_additional_edits(left, right, left_context, right_context, encoding)
  local left_count = left and #left or 0 ---@type integer
  local right_count = right and #right or 0 ---@type integer
  if left_count ~= right_count then
    return false
  end
  if left_count == 0 then
    return true
  end
  local left_sorted = sorted_text_edits(assert(left))
  local right_sorted = sorted_text_edits(assert(right))
  for index, left_edit in ipairs(left_sorted) do
    local right_edit = right_sorted[index]
    if
      left_edit.newText ~= right_edit.newText
      or not equal_range(left_edit.range, right_edit.range, left_context, right_context, encoding)
    then
      return false
    end
  end
  return true
end

---@param left                          string[]|nil
---@param right                         string[]|nil
---@return boolean
local function equal_commit_characters(left, right)
  local left_count = left and #left or 0 ---@type integer
  local right_count = right and #right or 0 ---@type integer
  if left_count ~= right_count then
    return false
  end
  if left_count == 0 then
    return true
  end
  if vim.deep_equal(left, right) then
    return true
  end
  local left_sorted = vim.list_slice(assert(left)) ---@type string[]
  local right_sorted = vim.list_slice(assert(right)) ---@type string[]
  table.sort(left_sorted)
  table.sort(right_sorted)
  return vim.deep_equal(left_sorted, right_sorted)
end

---@param left                          lsp.CompletionItem
---@param right                         lsp.CompletionItem
---@param left_context                  era.m.cmp.IContext
---@param right_context                 era.m.cmp.IContext
---@param encoding                      string
---@return boolean
local function equal_response_items(left, right, left_context, right_context, encoding)
  local left_label = left.label or "" ---@type string
  local right_label = right.label or "" ---@type string
  local left_details = type(left.labelDetails) == "table" and left.labelDetails or nil ---@type table|nil
  local right_details = type(right.labelDetails) == "table" and right.labelDetails or nil ---@type table|nil
  local left_edit = left.textEdit ---@type table|nil
  local right_edit = right.textEdit ---@type table|nil
  local left_text = type(left_edit) == "table" and left_edit.newText
    or left.textEditText
    or left.insertText
    or left_label ---@type string
  local right_text = type(right_edit) == "table" and right_edit.newText
    or right.textEditText
    or right.insertText
    or right_label ---@type string
  local left_deprecated = left.deprecated == true
    or (left.tags ~= nil and vim.list_contains(left.tags, vim.lsp.protocol.CompletionTag.Deprecated)) ---@type boolean
  local right_deprecated = right.deprecated == true
    or (right.tags ~= nil and vim.list_contains(right.tags, vim.lsp.protocol.CompletionTag.Deprecated)) ---@type boolean

  return (left.filterText or left_label) == (right.filterText or right_label)
    and (left.sortText or left_label) == (right.sortText or right_label)
    and (left.detail or "") == (right.detail or "")
    and (left_details and left_details.detail or "") == (right_details and right_details.detail or "")
    and (left_details and left_details.description or "") == (right_details and right_details.description or "")
    and left_deprecated == right_deprecated
    and (left.insertTextFormat or vim.lsp.protocol.InsertTextFormat.PlainText) == (right.insertTextFormat or vim.lsp.protocol.InsertTextFormat.PlainText)
    and (left.insertTextMode or 1) == (right.insertTextMode or 1)
    and (left.preselect == true) == (right.preselect == true)
    and left_text == right_text
    and equal_commands(left, right)
    and equal_primary_ranges(left, right, left_context, right_context, encoding)
    and equal_additional_edits(
      left.additionalTextEdits,
      right.additionalTextEdits,
      left_context,
      right_context,
      encoding
    )
    and equal_commit_characters(left.commitCharacters, right.commitCharacters)
end

---@param source                        string
---@param item                          lsp.CompletionItem
---@return string
local function lsp_usage_key(source, item)
  local label = item.label or "" ---@type string
  return util.usage_key(source, {
    label = label,
    kind = item.kind,
    filterText = item.filterText or label,
    sortText = item.sortText or label,
  }, nil, yoz.fn.md5(lsp_semantic_projection(item)))
end

---@param labels                        table<string, table<string, boolean>>
---@param key                           string
local function add_history_label(labels, key)
  local source, label = key:match("^([^%z]*)%z[^%z]*%z([^%z]*)%z")
  if source == nil then
    source, label = key:match("^([^%z]*)%z(.*)$")
  end
  if source == nil or label == nil then
    return
  end
  local source_labels = labels[source] or {} ---@type table<string, boolean>
  source_labels[label] = true
  labels[source] = source_labels
end

---@param values                        table<string, any>
---@return table<string, table<string, boolean>>, table<string, boolean>
local function collect_history_indexes(values)
  local labels = {} ---@type table<string, table<string, boolean>>
  local keys = {} ---@type table<string, boolean>
  for key in pairs(values) do
    add_history_label(labels, key)
    keys[key] = true
  end
  return labels, keys
end

---@param item                          era.m.cmp.ICompletionItem
---@param context                       era.m.cmp.IContext
---@param start_col                     integer
---@param target_start_col              integer
---@param suffix_bytes                  integer
---@param usage_key                     string|nil
---@param client                        vim.lsp.Client|nil
---@param preserved_edits               lsp.TextEdit[]|nil
---@param text_snapshot?                string[]
---@param source_context?               era.m.cmp.IContext
---@return era.m.cmp.ICompletionItem|nil
local function normalize_item(
  item,
  context,
  start_col,
  target_start_col,
  suffix_bytes,
  usage_key,
  client,
  preserved_edits,
  text_snapshot,
  source_context
)
  -- Local items are validated during collection; upstream and resolved items
  -- are validated once at their ingress boundary.
  local new_text = item.textEdit and item.textEdit.newText or item.textEditText or item.insertText or item.label
  if type(new_text) ~= "string" then
    return nil
  end

  local prefix = context.line:sub(target_start_col + 1, start_col)
  local insertion_prefix = item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet
      and escape_snippet_literal(prefix)
    or prefix
  local normalized_text = insertion_prefix .. new_text ---@type string
  if item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet then
    validate_snippet(normalized_text)
  end
  local normalized = vim.deepcopy(item) ---@type era.m.cmp.ICompletionItem
  normalized._era_cmp_source_context = nil
  normalized.filterText = prefix .. (item.filterText or item.label)
  normalized.textEdit = {
    newText = normalized_text,
    range = util.range(context, target_start_col),
  }
  normalized.insertText = nil
  normalized.textEditText = nil
  normalized._era_cmp_suffix_bytes = suffix_bytes

  if client ~= nil then
    local encoding = client.offset_encoding or "utf-16"
    normalized.additionalTextEdits = preserved_edits ~= nil and vim.deepcopy(preserved_edits)
      or text_edits_to_utf8(item.additionalTextEdits, context.bufnr, encoding, context, text_snapshot, source_context)
    normalized.command = wrap_command(client.id, item.command)
    normalized._era_cmp_meta = {
      source = client.name,
      priority = 180,
      score = 180,
      exact = false,
      usage_key = usage_key,
    }
    normalized._era_cmp_origin = {
      client_id = client.id,
      context = context,
      item = item,
      start_col = start_col,
      suffix_bytes = suffix_bytes,
      target_start_col = target_start_col,
      source_context = source_context or context,
    }
  end
  local effective_range = vim.deepcopy(normalized.textEdit.range) ---@type lsp.Range
  effective_range["end"].character = effective_range["end"].character + suffix_bytes
  validate_additional_edits(effective_range, normalized.additionalTextEdits)
  return normalized
end

---@param params                         lsp.CompletionParams
---@param client                         vim.lsp.Client
---@param context                        era.m.cmp.IContext
---@return lsp.CompletionParams
local function client_params(params, client, context)
  local forwarded = vim.deepcopy(params) ---@type lsp.CompletionParams
  forwarded.position.character = vim.str_utfindex(context.line, client.offset_encoding or "utf-16", context.col, false)
  local forwarded_context = forwarded.context
  if
    forwarded_context ~= nil
    and forwarded_context.triggerKind == vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter
  then
    local characters = vim.tbl_get(client.server_capabilities or {}, "completionProvider", "triggerCharacters") or {}
    if not vim.list_contains(characters, forwarded_context.triggerCharacter) then
      forwarded.context = { triggerKind = vim.lsp.protocol.CompletionTriggerKind.Invoked }
    end
  end
  return forwarded
end

---@param owner                         string
---@param err                           any
local function report_invalid_item(owner, err)
  if failed_items[owner] then
    return
  end
  failed_items[owner] = true
  stl.reporter.warn({
    from = __module_name__,
    subject = owner,
    message = "Skipped invalid completion item.",
    details = err,
  })
end

---@param previous                      era.m.cmp.IContext
---@param current                       era.m.cmp.IContext
---@return boolean
local function extends_context(previous, current)
  return previous.bufnr == current.bufnr
    and previous.row == current.row
    and previous.start_col == current.start_col
    and previous.col <= current.col
    and previous.line:sub(1, previous.col) == current.line:sub(1, previous.col)
    and previous.line:sub(previous.col + 1) == current.line:sub(current.col + 1)
end

---@param result                        vim.lsp.CompletionResult
---@param owner                         string
---@param context                       era.m.cmp.IContext
---@return lsp.CompletionItem[]
local function response_items(result, owner, context)
  local raw_items = type(result) == "table" and (result.items or result) or nil
  if type(raw_items) ~= "table" then
    return {}
  end

  local defaults = result.items and result.itemDefaults or nil
  local items = {} ---@type lsp.CompletionItem[]
  for _, raw_item in ipairs(raw_items) do
    local ok, item = xpcall(function()
      if type(raw_item) ~= "table" then
        error("completion item is not a table", 0)
      end
      local item = vim.deepcopy(raw_item) ---@type lsp.CompletionItem
      apply_defaults(item, defaults)
      validate_item(item)
      item._era_cmp_source_context = context
      return item
    end, debug.traceback)
    if ok then
      items[#items + 1] = item
    else
      report_invalid_item(owner, item)
    end
  end
  return items
end

---@param result                        vim.lsp.CompletionResult
---@return boolean
local function response_is_incomplete(result)
  return type(result) == "table" and result.isIncomplete == true
end

---@param preferred                     lsp.CompletionItem[]
---@param fallback                      lsp.CompletionItem[]|nil
---@param encoding                      string
---@return lsp.CompletionItem[]
local function merge_response_items(preferred, fallback, encoding)
  local output = {} ---@type lsp.CompletionItem[]
  local buckets = {} ---@type table<string, lsp.CompletionItem[]>
  for _, items in ipairs({ preferred, fallback or {} }) do
    for _, item in ipairs(items) do
      local bucket_key = table.concat({ item.label or "", item.kind or 0 }, "\0") ---@type string
      local bucket = buckets[bucket_key] or {} ---@type lsp.CompletionItem[]
      local duplicate = vim.iter(bucket):any(function(candidate)
        return equal_response_items(
          candidate,
          item,
          candidate._era_cmp_source_context,
          item._era_cmp_source_context,
          encoding
        )
      end)
      if not duplicate then
        bucket[#bucket + 1] = item
        buckets[bucket_key] = bucket
        output[#output + 1] = item
      end
    end
  end
  return output
end

---@class era.m.cmp.bridge.IResponse
---@field public client                 vim.lsp.Client
---@field public items                  lsp.CompletionItem[]
---@field public is_incomplete          boolean

---@param context                       era.m.cmp.IContext
---@return boolean
local function is_context_current(context)
  if not vim.api.nvim_buf_is_valid(context.bufnr) or vim.api.nvim_get_current_buf() ~= context.bufnr then
    return false
  end

  if vim.api.nvim_get_current_line() ~= context.line then
    return false
  end
  if not vim.api.nvim_get_mode().mode:match("^[iR]") then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(0) ---@type integer[]
  return cursor[1] - 1 == context.row and cursor[2] == context.col
end

---@param context                        era.m.cmp.IContext
---@param local_result                   lsp.CompletionList
---@param responses                      table<integer, era.m.cmp.bridge.IResponse>
---@return lsp.CompletionList
---@class era.m.cmp.bridge.IRankEntry
---@field public item                   era.m.cmp.ICompletionItem
---@field public client                 vim.lsp.Client|nil
---@field public start_col              integer
---@field public suffix_bytes           integer
---@field public usage_key              string|nil
---@field public source_context         era.m.cmp.IContext|nil

---@class era.m.cmp.bridge.IRankSnapshot
---@field public context                era.m.cmp.IContext
---@field public entries                era.m.cmp.bridge.IRankEntry[]
---@field public target_start_col       integer
---@field public index                  yoz.cmp.IIndex

---@param context                       era.m.cmp.IContext
---@param local_result                  lsp.CompletionList
---@param responses                     table<integer, era.m.cmp.bridge.IResponse>
---@return lsp.CompletionList
---@return era.m.cmp.bridge.IRankSnapshot
local function merge(context, local_result, responses)
  local entries = {} ---@type { item: era.m.cmp.ICompletionItem, client: vim.lsp.Client|nil, start_col: integer, suffix_bytes: integer, usage_key: string|nil, source_context: era.m.cmp.IContext|nil }[]
  local target_start_col = context.start_col ---@type integer

  local function collect(item, client, used_labels, source_context)
    local owner = client and client.name or "local" ---@type string
    local encoding = client and (client.offset_encoding or "utf-16") or "utf-8" ---@type string
    local ok, entry = pcall(function()
      if type(item) ~= "table" then
        error("completion item is not a table", 0)
      end
      if client == nil then
        validate_item(item)
      end
      local start_col = item_start_col(item, context, encoding, source_context)
      local suffix_bytes = item_suffix_bytes(item, context, encoding, source_context)
      if start_col == nil or suffix_bytes == nil then
        return nil
      end
      local meta = client == nil and util.meta(item) or nil ---@type era.m.cmp.IMeta|nil
      local usage_key = nil ---@type string|nil
      if client ~= nil then
        if used_labels ~= nil and used_labels[item.label] then
          local key = lsp_usage_key(client.name, item)
          usage_key = history_keys[key] and key or nil
        end
      else
        local key = assert(meta).usage_key or util.usage_key(meta.source, item)
        usage_key = history_keys[key] and key or nil
      end
      return {
        item = item,
        client = client,
        start_col = start_col,
        suffix_bytes = suffix_bytes,
        usage_key = usage_key,
        source_context = source_context,
      }
    end)
    if not ok then
      report_invalid_item(owner, entry)
      return
    end
    if entry ~= nil then
      failed_items[owner] = nil
      target_start_col = math.min(target_start_col, entry.start_col)
      entries[#entries + 1] = entry
    end
  end

  local local_items = type(local_result) == "table" and local_result.items or nil
  if type(local_items) == "table" then
    for _, item in ipairs(local_items) do
      collect(item, nil, nil, context)
    end
  end

  for _, response in pairs(responses) do
    local used_labels = history_labels[response.client.name]
    for _, raw_item in ipairs(response.items) do
      collect(raw_item, response.client, used_labels, raw_item._era_cmp_source_context)
    end
  end

  local query = context.line:sub(target_start_col + 1, context.col) ---@type string
  local texts = {} ---@type string[]
  local score_offsets = nil ---@type integer|integer[]|nil
  local usage_keys = next(history_keys) ~= nil and {} or nil ---@type (string|nil)[]|nil
  local sort_texts = true ---@type string[]|true
  local proximity_keys = {} ---@type string[]
  for index, entry in ipairs(entries) do
    local item = entry.item ---@type era.m.cmp.ICompletionItem
    local meta = entry.client == nil and util.meta(item) or nil ---@type era.m.cmp.IMeta|nil
    texts[index] = context.line:sub(target_start_col + 1, entry.start_col) .. (item.filterText or item.label)
    proximity_keys[index] = item.label
    local score_offset = entry.client and 180 or (meta and meta.priority or 0) ---@type integer
    if score_offsets == nil then
      score_offsets = score_offset
    elseif type(score_offsets) == "number" then
      if score_offsets ~= score_offset then
        local previous_score_offset = score_offsets
        score_offsets = {}
        for previous = 1, index - 1 do
          score_offsets[previous] = previous_score_offset
        end
        score_offsets[index] = score_offset
      end
    else
      score_offsets[index] = score_offset
    end
    if usage_keys ~= nil then
      usage_keys[index] = entry.usage_key
    end
    local sort_text = item.sortText or item.label ---@type string
    if sort_texts == true then
      if sort_text ~= texts[index] then
        sort_texts = {} ---@type string[]
        for previous = 1, index - 1 do
          sort_texts[previous] = texts[previous]
        end
        sort_texts[index] = sort_text
      end
    else
      sort_texts[index] = sort_text
    end
  end

  local rank_index = yoz.cmp.index(texts, score_offsets, usage_keys, sort_texts, proximity_keys) ---@type yoz.cmp.IIndex
  local matched = rank_index:rank(query, history, os.time(), MAX_ITEMS, nearby_words(context)) ---@type integer[]
  local items = {} ---@type era.m.cmp.ICompletionItem[]
  for _, entry_index in ipairs(matched) do
    local entry = entries[entry_index] ---@type { item: era.m.cmp.ICompletionItem, client: vim.lsp.Client|nil, start_col: integer, suffix_bytes: integer, usage_key: string|nil, source_context: era.m.cmp.IContext|nil }|nil
    if entry ~= nil then
      local owner = entry.client and entry.client.name or "local" ---@type string
      local usage_key = entry.client ~= nil and entry.usage_key or nil
      local ok, item = pcall(function()
        return normalize_item(
          entry.item,
          context,
          entry.start_col,
          target_start_col,
          entry.suffix_bytes,
          usage_key,
          entry.client,
          nil,
          nil,
          entry.source_context
        )
      end)
      if ok then
        if item ~= nil then
          items[#items + 1] = item
        end
      else
        report_invalid_item(owner, item)
      end
    end
  end

  return { isIncomplete = true, items = items }, {
    context = context,
    entries = entries,
    target_start_col = target_start_col,
    index = rank_index,
  }
end

---@param context                       era.m.cmp.IContext
---@param snapshot                      era.m.cmp.bridge.IRankSnapshot
---@return lsp.CompletionList
local function rank_snapshot(context, snapshot)
  local target_start_col = snapshot.target_start_col ---@type integer
  if target_start_col >= snapshot.context.col then
    target_start_col = target_start_col + context.col - snapshot.context.col
  end
  local query = context.line:sub(target_start_col + 1, context.col) ---@type string
  local matched = snapshot.index:rank(query, history, os.time(), MAX_ITEMS, nearby_words(context)) ---@type integer[]
  local items = {} ---@type era.m.cmp.ICompletionItem[]
  for _, entry_index in ipairs(matched) do
    local entry = snapshot.entries[entry_index]
    if entry ~= nil then
      local encoding = entry.client and (entry.client.offset_encoding or "utf-16") or "utf-8" ---@type string
      local start_col = item_start_col(entry.item, context, encoding, entry.source_context)
      local suffix_bytes = item_suffix_bytes(entry.item, context, encoding, entry.source_context)
      if start_col ~= nil and suffix_bytes ~= nil then
        local owner = entry.client and entry.client.name or "local" ---@type string
        local ok, item = pcall(
          normalize_item,
          entry.item,
          context,
          start_col,
          target_start_col,
          suffix_bytes,
          entry.client and entry.usage_key or nil,
          entry.client,
          nil,
          nil,
          entry.source_context
        )
        if ok then
          if item ~= nil then
            items[#items + 1] = item
          end
        else
          report_invalid_item(owner, item)
        end
      end
    end
  end
  return { isIncomplete = true, items = items }
end

---@class era.m.cmp.bridge.ISession
---@field public context                era.m.cmp.IContext
---@field public key                    string
---@field public local_done             boolean
---@field public local_cancel           fun()|nil
---@field public local_snapshot         (fun(): lsp.CompletionList)|nil
---@field public local_result           lsp.CompletionList
---@field public requests               table<integer, { done: boolean, request_id: integer|nil }>
---@field public responses              table<integer, era.m.cmp.bridge.IResponse>
---@field public pending                integer
---@field public initial_published      boolean
---@field public refresh_pending        boolean
---@field public finished               boolean
---@field public cancelled              boolean
---@field public initial_timer          uv.uv_timer_t|nil
---@field public publish_initial        fun(): nil
---@field public superseded             boolean
---@field public timer                  uv.uv_timer_t|nil
---@field public cached_snapshot        era.m.cmp.bridge.IRankSnapshot|nil

local sessions = {} ---@type table<integer, era.m.cmp.bridge.ISession>
local superseded_sessions = {} ---@type table<integer, era.m.cmp.bridge.ISession[]>

---@param context                       era.m.cmp.IContext
---@return string
local function context_key(context)
  return table.concat({ context.bufnr, context.row, context.col, context.line }, "\0")
end

---@param session                       era.m.cmp.bridge.ISession
local function cancel_outstanding(session)
  if not session.local_done and type(session.local_cancel) == "function" then
    pcall(session.local_cancel)
  end
  for client_id, request in pairs(session.requests) do
    if not request.done and request.request_id ~= nil then
      local client = vim.lsp.get_client_by_id(client_id)
      if client ~= nil then
        pcall(client.cancel_request, client, request.request_id)
      end
    end
  end
end

---@param session                       era.m.cmp.bridge.ISession
local function remove_superseded(session)
  local bufnr = session.context.bufnr ---@type integer
  local entries = superseded_sessions[bufnr]
  if entries == nil then
    return
  end
  for index, candidate in ipairs(entries) do
    if candidate == session then
      table.remove(entries, index)
      break
    end
  end
  if #entries == 0 then
    superseded_sessions[bufnr] = nil
  end
end

---@param session                       era.m.cmp.bridge.ISession
local function dispose_session(session)
  if session.cancelled then
    return
  end
  session.cancelled = true
  close_timer(session.initial_timer)
  close_timer(session.timer)
  cancel_outstanding(session)
  remove_superseded(session)
  if sessions[session.context.bufnr] == session then
    sessions[session.context.bufnr] = nil
  end
end

---@param session                       era.m.cmp.bridge.ISession
local function supersede_session(session)
  if session.cancelled or session.superseded then
    return
  end
  session.superseded = true
  close_timer(session.initial_timer)
  if not session.local_done then
    if type(session.local_cancel) == "function" then
      pcall(session.local_cancel)
    end
    session.local_done = true
    session.pending = session.pending - 1
  end
  if sessions[session.context.bufnr] == session then
    sessions[session.context.bufnr] = nil
  end
  if session.pending <= 0 then
    session.finished = true
    close_timer(session.timer)
    session.timer = nil
    return
  end
  local entries = superseded_sessions[session.context.bufnr] or {}
  while #entries >= MAX_SUPERSEDED_SESSIONS do
    dispose_session(entries[1])
  end
  entries[#entries + 1] = session
  superseded_sessions[session.context.bufnr] = entries
end

---@param session                       era.m.cmp.bridge.ISession
local function update_local_snapshot(session)
  if session.local_done or session.local_snapshot == nil then
    return
  end
  local ok, result = xpcall(session.local_snapshot, debug.traceback)
  if ok then
    session.local_result = result
  else
    session.local_snapshot = nil
    stl.reporter.error({
      from = __module_name__,
      subject = "local",
      message = "Failed to snapshot local completion results.",
      details = result,
    })
  end
end

---@param session                       era.m.cmp.bridge.ISession
---@param callback                      fun(err: lsp.ResponseError|nil, result: lsp.CompletionList|nil): nil
---@return boolean
local function publish_session(session, callback)
  if not is_context_current(session.context) then
    callback(nil, { isIncomplete = false, items = {} })
    return true
  end

  local ok, result, snapshot = xpcall(function()
    if session.cached_snapshot ~= nil then
      local cached_snapshot = session.cached_snapshot
      session.cached_snapshot = nil
      return rank_snapshot(session.context, cached_snapshot), nil
    end
    update_local_snapshot(session)
    return merge(session.context, session.local_result, session.responses)
  end, debug.traceback)
  if ok then
    if snapshot ~= nil then
      local cached = completion_cache[session.context.bufnr]
      if cached ~= nil and context_key(cached.context) == context_key(session.context) then
        cached.snapshot = snapshot
      end
    end
    callback(nil, result)
    return true
  end

  stl.reporter.error({
    from = __module_name__,
    subject = "merge",
    message = "Failed to merge completion responses.",
    details = result,
  })
  callback({ code = vim.lsp.protocol.ErrorCodes.InternalError, message = "Completion merge failed" }, nil)
  return false
end

---@param session                       era.m.cmp.bridge.ISession
local function schedule_refresh(session)
  if session.cancelled or session.superseded or not session.initial_published or session.refresh_pending then
    return
  end
  session.refresh_pending = true
  vim.schedule(function()
    if session.cancelled or sessions[session.context.bufnr] ~= session then
      return
    end
    if not is_context_current(session.context) then
      dispose_session(session)
      return
    end
    if refresh == nil then
      dispose_session(session)
      return
    end
    local ok, started = xpcall(refresh, debug.traceback, session.context.bufnr)
    if not ok then
      stl.reporter.error({
        from = __module_name__,
        subject = "refresh",
        message = "Failed to refresh completion results.",
        details = started,
      })
      dispose_session(session)
    elseif not started then
      dispose_session(session)
    end
  end)
end

---@param session                       era.m.cmp.bridge.ISession
local function finish_background(session)
  if session.pending ~= 0 or session.finished then
    return
  end
  session.finished = true
  close_timer(session.timer)
  if session.initial_published then
    schedule_refresh(session)
  else
    session.publish_initial()
  end
end

---@param params                         lsp.CompletionParams
---@param callback                       fun(err: lsp.ResponseError|nil, result: lsp.CompletionList|nil): nil
---@param bufnr?                         integer
---@return fun()
function M.complete(params, callback, bufnr)
  local context = util.context(params, bufnr)
  if context == nil then
    callback(nil, { isIncomplete = false, items = {} })
    return function() end
  end
  if not is_context_current(context) then
    callback(nil, { isIncomplete = false, items = {} })
    return function() end
  end

  local key = context_key(context)
  local existing = sessions[context.bufnr]
  if existing ~= nil then
    if not existing.cancelled and existing.key == key then
      existing.refresh_pending = false
      local published = publish_session(existing, callback)
      if not published then
        dispose_session(existing)
      elseif existing.finished then
        sessions[context.bufnr] = nil
      end
      return function() end
    end
    if extends_context(existing.context, context) then
      supersede_session(existing)
    else
      dispose_session(existing)
    end
  end

  local clients = vim.lsp.get_clients({ bufnr = context.bufnr, method = "textDocument/completion" })
  local responses = {} ---@type table<integer, era.m.cmp.bridge.IResponse>
  local request_clients = {} ---@type vim.lsp.Client[]
  local cached = completion_cache[context.bufnr]
  local extends_cached = cached ~= nil and extends_context(cached.context, context) ---@type boolean
  local incomplete_refresh = params.context ~= nil
    and params.context.triggerKind == vim.lsp.protocol.CompletionTriggerKind.TriggerForIncompleteCompletions ---@type boolean
  local publish_cached_immediately = extends_cached and incomplete_refresh ---@type boolean
  if extends_cached then
    for _, client in ipairs(clients) do
      local response = cached.responses[client.id]
      if response ~= nil then
        responses[client.id] = response
      end
      if response == nil or not incomplete_refresh or response.is_incomplete then
        request_clients[#request_clients + 1] = client
      end
    end
  else
    request_clients = clients
  end
  local session = {
    context = context,
    key = key,
    local_done = false,
    local_cancel = nil,
    local_snapshot = nil,
    local_result = { isIncomplete = true, items = {} },
    requests = {},
    responses = responses,
    pending = #request_clients + 1,
    initial_published = false,
    refresh_pending = false,
    finished = false,
    cancelled = false,
    superseded = false,
    initial_timer = nil,
    publish_initial = function() end,
    timer = nil,
    cached_snapshot = publish_cached_immediately and cached.snapshot or nil,
  } ---@type era.m.cmp.bridge.ISession
  sessions[context.bufnr] = session
  completion_cache[context.bufnr] = { context = vim.deepcopy(context), responses = responses, snapshot = nil }

  session.publish_initial = function()
    if session.cancelled or session.initial_published or sessions[context.bufnr] ~= session then
      return
    end
    close_timer(session.initial_timer)
    session.initial_timer = nil
    session.initial_published = true
    local published = publish_session(session, callback)
    if not published or session.finished then
      sessions[context.bufnr] = nil
    end
  end
  if not publish_cached_immediately then
    session.initial_timer = vim.defer_fn(session.publish_initial, INITIAL_PUBLISH_DELAY)
  elseif session.cached_snapshot ~= nil then
    session.publish_initial()
  end

  session.timer = vim.defer_fn(function()
    if session.cancelled or session.finished then
      return
    end
    if session.superseded then
      dispose_session(session)
      return
    end
    if sessions[context.bufnr] ~= session then
      return
    end
    update_local_snapshot(session)
    cancel_outstanding(session)
    session.pending = 0
    session.finished = true
    schedule_refresh(session)
  end, REQUEST_TIMEOUT)

  local local_ok, cancel_or_error, snapshot = xpcall(function()
    return source.complete(params, history, function(result)
      if session.cancelled or session.finished or session.local_done then
        return
      end
      session.local_done = true
      session.local_result = result
      session.pending = session.pending - 1
      schedule_refresh(session)
      finish_background(session)
    end, context.bufnr)
  end, debug.traceback)
  if local_ok then
    session.local_cancel = cancel_or_error
    session.local_snapshot = snapshot
  else
    session.local_done = true
    session.pending = session.pending - 1
    stl.reporter.error({
      from = __module_name__,
      subject = "local",
      message = "Local completion request failed.",
      details = cancel_or_error,
    })
  end

  for _, client in ipairs(request_clients) do
    local upstream = client ---@type vim.lsp.Client
    local request = { done = false, request_id = nil } ---@type { done: boolean, request_id: integer|nil }
    session.requests[upstream.id] = request
    local invoked, request_ok, request_id = xpcall(function()
      return upstream:request("textDocument/completion", client_params(params, upstream, context), function(err, result)
        if session.cancelled or request.done then
          return
        end
        request.done = true
        if session.superseded then
          session.pending = session.pending - 1
          local cached_response = completion_cache[context.bufnr]
          if err == nil and cached_response ~= nil and extends_context(context, cached_response.context) then
            local response = {
              client = upstream,
              items = response_items(result, upstream.name, context),
              is_incomplete = response_is_incomplete(result),
            }
            local previous = cached_response.responses[upstream.id]
            response.items = merge_response_items(
              previous and previous.items or {},
              response.items,
              upstream.offset_encoding or "utf-16"
            )
            if previous ~= nil then
              response.is_incomplete = previous.is_incomplete
            end
            cached_response.responses[upstream.id] = response
            cached_response.snapshot = nil
            local current = sessions[context.bufnr]
            if current ~= nil and context_key(current.context) == context_key(cached_response.context) then
              current.responses[upstream.id] = response
              schedule_refresh(current)
            end
          end
          if session.pending <= 0 then
            session.finished = true
            close_timer(session.timer)
            session.timer = nil
            remove_superseded(session)
          end
          return
        end
        if session.finished then
          return
        end
        session.pending = session.pending - 1
        if err == nil then
          failed_clients[upstream.id] = nil
          local previous = session.responses[upstream.id]
          session.responses[upstream.id] = {
            client = upstream,
            items = merge_response_items(
              response_items(result, upstream.name, context),
              previous and previous.items or nil,
              upstream.offset_encoding or "utf-16"
            ),
            is_incomplete = response_is_incomplete(result),
          }
          completion_cache[context.bufnr] = {
            context = vim.deepcopy(context),
            responses = session.responses,
            snapshot = nil,
          }
        elseif
          type(err) == "table"
          and err.code ~= vim.lsp.protocol.ErrorCodes.RequestCancelled
          and not failed_clients[upstream.id]
        then
          failed_clients[upstream.id] = true
          stl.reporter.warn({
            from = __module_name__,
            subject = upstream.name,
            message = "LSP completion request failed.",
            details = err,
          })
        end
        schedule_refresh(session)
        finish_background(session)
      end, context.bufnr)
    end, debug.traceback)
    if invoked and request_ok and request_id ~= nil then
      request.request_id = request_id
    elseif not request.done then
      request.done = true
      session.pending = session.pending - 1
      if not invoked and not failed_clients[upstream.id] then
        failed_clients[upstream.id] = true
        stl.reporter.warn({
          from = __module_name__,
          subject = upstream.name,
          message = "Failed to start LSP completion request.",
          details = request_ok,
        })
      end
    end
  end

  if publish_cached_immediately and not session.initial_published then
    session.publish_initial()
  end
  finish_background(session)

  return function()
    dispose_session(session)
  end
end

---@param item                           era.m.cmp.ICompletionItem
---@param callback                       fun(err: lsp.ResponseError|nil, result: era.m.cmp.ICompletionItem|nil): nil
---@param text_snapshot?                 string[]
---@return fun()
function M.resolve(item, callback, text_snapshot)
  local origin = item._era_cmp_origin
  if origin == nil then
    callback(nil, item)
    return function() end
  end
  local client = vim.lsp.get_client_by_id(origin.client_id) ---@type vim.lsp.Client|nil
  if client == nil or not client:supports_method("completionItem/resolve") then
    callback(nil, item)
    return function() end
  end
  local usage_key = M.get_usage_key(item)

  local cancelled = false ---@type boolean
  local settled = false ---@type boolean
  local request_id ---@type integer|nil
  local timer ---@type uv.uv_timer_t|nil

  local function finish(err, result)
    if cancelled or settled then
      return
    end
    settled = true
    close_timer(timer)
    callback(err, result)
  end

  timer = vim.defer_fn(function()
    if request_id ~= nil then
      pcall(client.cancel_request, client, request_id)
    end
    finish(nil, item)
  end, REQUEST_TIMEOUT)

  local invoked, request_ok, started_id = xpcall(function()
    local resolve_item = vim.deepcopy(origin.item) ---@type era.m.cmp.ICompletionItem
    resolve_item._era_cmp_source_context = nil
    return client:request("completionItem/resolve", resolve_item, function(err, result)
      if cancelled or settled then
        return
      end
      if err ~= nil or type(result) ~= "table" then
        finish(err, item)
        return
      end

      local ok, normalized = xpcall(function()
        local resolved = vim.tbl_extend("force", vim.deepcopy(resolve_item), result) ---@type era.m.cmp.ICompletionItem
        validate_item(resolved)
        local preserved_edits = type(item.additionalTextEdits) == "table"
            and next(item.additionalTextEdits) ~= nil
            and item.additionalTextEdits
          or nil
        return normalize_item(
          resolved,
          origin.context,
          origin.start_col,
          origin.target_start_col,
          origin.suffix_bytes,
          usage_key,
          client,
          preserved_edits,
          text_snapshot,
          origin.source_context
        )
      end, debug.traceback)
      if ok then
        finish(nil, normalized or item)
      else
        stl.reporter.error({
          from = __module_name__,
          subject = "resolve",
          message = "Failed to normalize resolved completion item.",
          details = normalized,
        })
        finish({ code = vim.lsp.protocol.ErrorCodes.InternalError, message = "Completion resolve failed" }, item)
      end
    end, origin.context.bufnr)
  end, debug.traceback)

  if invoked and request_ok and started_id ~= nil then
    request_id = started_id
  else
    if not invoked then
      stl.reporter.warn({
        from = __module_name__,
        subject = client.name,
        message = "Failed to start completion resolve request.",
        details = request_ok,
      })
    end
    finish(nil, item)
  end

  return function()
    if cancelled or settled then
      return
    end
    cancelled = true
    close_timer(timer)
    if request_id ~= nil then
      pcall(client.cancel_request, client, request_id)
    end
  end
end

---@param command                        lsp.Command
---@param context                        table
function M.execute_command(command, context)
  local payload = type(command.arguments) == "table" and command.arguments[1] or nil
  if type(payload) ~= "table" or type(payload.client_id) ~= "number" or type(payload.command) ~= "table" then
    return
  end
  local client = vim.lsp.get_client_by_id(payload.client_id) ---@type vim.lsp.Client|nil
  if client ~= nil then
    client:exec_cmd(payload.command, { bufnr = context.bufnr })
  end
end

---@param show                           fun(): nil
---@param show_signature                 fun(bufnr: integer): boolean
function M.register_commands(show, show_signature)
  vim.lsp.commands[TRIGGER_PARAMETER_HINTS] = vim.lsp.commands[TRIGGER_PARAMETER_HINTS]
    or function(_, context)
      local bufnr = context.bufnr ---@type integer|nil
      vim.schedule(function()
        if
          type(bufnr) == "number"
          and vim.api.nvim_buf_is_valid(bufnr)
          and vim.api.nvim_get_current_buf() == bufnr
          and vim.api.nvim_get_mode().mode:match("^[iR]")
        then
          show_signature(bufnr)
        end
      end)
    end
  vim.lsp.commands[TRIGGER_SUGGEST] = vim.lsp.commands[TRIGGER_SUGGEST]
    or function(_, context)
      local bufnr = context.bufnr ---@type integer|nil
      vim.schedule(function()
        if
          type(bufnr) == "number"
          and vim.api.nvim_buf_is_valid(bufnr)
          and vim.api.nvim_get_current_buf() == bufnr
          and vim.api.nvim_get_mode().mode:match("^[iR]")
        then
          show()
        end
      end)
    end
end

---@param item                           era.m.cmp.ICompletionItem
---@return string|nil
function M.get_usage_key(item)
  local meta = util.meta(item)
  if meta == nil then
    return nil
  end
  if type(meta.usage_key) == "string" then
    return meta.usage_key
  end
  local origin = item._era_cmp_origin
  if origin == nil then
    return nil
  end
  local key = lsp_usage_key(meta.source, origin.item)
  meta.usage_key = key
  return key
end

---@param value                          table<string, integer|{ count: integer, last_used: integer }|yoz.cmp.IUsageRecord>
function M.set_history(value)
  history = yoz.cmp.usage(value)
  history_labels, history_keys = collect_history_indexes(value)
end

---@param key                            string
---@param now                            integer
function M.record_history(key, now)
  history:record(key, now)
  add_history_label(history_labels, key)
  history_keys[key] = true
end

---@param now                            integer
---@return table<string, yoz.cmp.IUsageRecord>
function M.snapshot_history(now)
  local snapshot = history:snapshot(now)
  history_labels, history_keys = collect_history_indexes(snapshot)
  return snapshot
end

---@param callback                      fun(bufnr: integer): boolean
function M.set_refresh(callback)
  refresh = callback
end

---@param bufnr                         integer
function M.cancel(bufnr)
  local session = sessions[bufnr]
  if session ~= nil then
    dispose_session(session)
  end
end

---@param bufnr                         integer
function M.clear(bufnr)
  M.cancel(bufnr)
  local entries = superseded_sessions[bufnr]
  while entries ~= nil and entries[1] ~= nil do
    dispose_session(entries[1])
  end
  superseded_sessions[bufnr] = nil
  completion_cache[bufnr] = nil
end

return M
