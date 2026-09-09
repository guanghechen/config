---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.protocol" ---@type string

local util = require("era.m.cmp.source.util")

local COMMAND = "era.cmp.execute"
local string_fields = { "detail", "filterText", "insertText", "sortText", "textEditText" }
local number_fields = { "kind", "insertTextFormat", "insertTextMode" }
local boolean_fields = { "deprecated", "preselect" }
local label_fields = { "detail", "description" }
local encoded_cursors = setmetatable({}, { __mode = "k" }) ---@type table<era.m.cmp.IContext, table<string, integer>>

---@param context                       era.m.cmp.IContext
---@param encoding                      string
---@return integer
local function encoded_cursor(context, encoding)
  if encoding == "utf-8" then
    return context.col
  end
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

---@param item                          lsp.CompletionItem
---@param defaults                      lsp.CompletionItemDefaults|nil
---@return nil
local function apply_defaults(item, defaults)
  if defaults == nil then
    return
  end
  if item.insertTextFormat == nil then
    item.insertTextFormat = defaults.insertTextFormat
  end
  if item.insertTextMode == nil then
    item.insertTextMode = defaults.insertTextMode
  end
  if item.data == nil then
    item.data = defaults.data
  end
  if item.commitCharacters == nil then
    item.commitCharacters = defaults.commitCharacters
  end
  if defaults.editRange ~= nil and item.textEdit == nil then
    local edit = { newText = item.textEditText or item.insertText or item.label }
    if defaults.editRange.start ~= nil then
      edit.range = defaults.editRange
    else
      edit.insert = defaults.editRange.insert
      edit.replace = defaults.editRange.replace
    end
    item.textEdit = edit
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
---@return nil
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
---@return nil
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
---@return nil
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
---@return nil
local function validate_item(item)
  if type(item.label) ~= "string" then
    error("invalid label", 0)
  end
  for _, name in ipairs(string_fields) do
    if item[name] ~= nil and type(item[name]) ~= "string" then
      error("invalid " .. name, 0)
    end
  end
  for _, name in ipairs(number_fields) do
    if item[name] ~= nil and type(item[name]) ~= "number" then
      error("invalid " .. name, 0)
    end
  end
  for _, name in ipairs(boolean_fields) do
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
    for _, name in ipairs(label_fields) do
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

---@param bufnr                         integer
---@param position                      lsp.Position
---@param encoding                      string
---@param context                       era.m.cmp.IContext|nil
---@param text_snapshot?                string[]
---@param source_context?               era.m.cmp.IContext
---@return integer|nil
local function position_byte_index(bufnr, position, encoding, context, text_snapshot, source_context)
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
  if encoding == "utf-8" then
    return math.min(character, #line)
  end
  local ok, byte_col = pcall(vim.str_byteindex, line, encoding, character, false)
  if not ok then
    return nil
  end
  return byte_col
end

---@param bufnr                         integer
---@param range                         lsp.Range
---@param encoding                      string
---@param context                       era.m.cmp.IContext|nil
---@param text_snapshot?                string[]
---@param source_context?               era.m.cmp.IContext
---@return lsp.Range|nil
local function range_to_utf8(bufnr, range, encoding, context, text_snapshot, source_context)
  local start = position_byte_index(bufnr, range.start, encoding, context, text_snapshot, source_context)
  local finish = position_byte_index(bufnr, range["end"], encoding, context, text_snapshot, source_context)
  if start == nil or finish == nil then
    return nil
  end
  return {
    start = { line = range.start.line, character = start },
    ["end"] = { line = range["end"].line, character = finish },
  }
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
  local byte_col = position_byte_index(context.bufnr, range.start, encoding, context, nil, source_context)
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
  local text_edit = item.textEdit
  local range = text_edit and (text_edit.range or text_edit.insert) or nil
  if range == nil then
    return 0
  end
  if range["end"].line ~= context.row then
    return nil
  end
  local end_col = position_byte_index(context.bufnr, range["end"], encoding, context, nil, source_context)
  if end_col == nil or end_col < context.col then
    return nil
  end
  return end_col - context.col
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
---@return nil
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
  ---@param position                    lsp.Position
  ---@param source                      era.m.cmp.IContext
  ---@param target                      era.m.cmp.IContext
  ---@return integer
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
---@param candidate                     ?era.m.cmp.protocol.ICandidate
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
  source_context,
  candidate
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
  normalized.filterText = prefix .. (item.filterText or item.label)
  normalized.textEdit = {
    newText = normalized_text,
    range = util.range(context, target_start_col),
  }
  normalized.insertText = nil
  normalized.textEditText = nil
  normalized._era_cmp_suffix_bytes = suffix_bytes
  normalized._era_cmp_cursor_offset = nil

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
      candidate = candidate,
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

---@class era.m.cmp.protocol.IResponse
---@field public client                 vim.lsp.Client
---@field public items                  era.m.cmp.protocol.ICandidate[]
---@field public is_incomplete          boolean

---@class era.m.cmp.protocol.ICandidate
---@field public item                   lsp.CompletionItem
---@field public context                era.m.cmp.IContext

---@param raw                           any
---@param defaults                      lsp.CompletionItemDefaults|nil
---@return lsp.CompletionItem|nil
---@return any
local function prepare(raw, defaults)
  if type(raw) ~= "table" then
    return nil, "completion item is not a table"
  end
  local item = raw
  if defaults ~= nil then
    if type(defaults) ~= "table" then
      return nil, "completion defaults are not a table"
    end
    item = {}
    for key, value in pairs(raw) do
      item[key] = value
    end
    local ok, err = pcall(apply_defaults, item, defaults)
    if not ok then
      return nil, err
    end
  end
  local ok, err = pcall(validate_item, item)
  if not ok then
    return nil, err
  end
  return item, nil
end

---@class era.m.cmp.protocol
local M = {
  COMMAND = COMMAND,
  prepare = prepare,
  validate = validate_item,
  start_col = item_start_col,
  suffix_bytes = item_suffix_bytes,
  equal = equal_response_items,
  usage_key = lsp_usage_key,
  normalize = normalize_item,
}

return M
