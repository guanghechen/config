---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.item" ---@type string

local M = {}
local offsets =
  { lsp = 180, path = 200, path_at = 210, snippets = 160, buffer = 100, dict = 95, slash = 220, cmdline = 0 }

---@generic T
---@param value                         T
---@return T|nil
function M.optional(value)
  if value == vim.NIL then
    return nil
  end
  return value
end

---@param line                          string
---@param character                     integer
---@param encoding                      string
---@return integer
function M.byte_col(line, character, encoding)
  if character == 0 then
    return 0
  end
  if encoding == "utf-8" then
    return math.min(#line, math.max(0, character))
  end
  return vim.str_byteindex(line, encoding, math.max(0, character), false)
end

---@param raw                           lsp.CompletionItem
---@return string|nil
function M.insert_text(raw)
  local edit = M.optional(raw.textEdit)
  if edit ~= nil then
    -- newText is required; malformed edits must not insert an unrelated fallback.
    local text = edit.newText
    return type(text) == "string" and text or nil
  end
  return M.optional(raw.insertText) or raw.label
end

---@param context                       era.keystroke.cmp.IContext
---@param source                        string
---@param raw                           lsp.CompletionItem
---@param client                        ?vim.lsp.Client
---@param id                            ?string
---@return era.keystroke.cmp.IItem
function M.new(context, source, raw, client, id)
  local encoding = client and client.offset_encoding or "utf-8"
  local client_id = client and client.id or nil
  local edit = M.optional(raw.textEdit)
  local range = edit and (M.optional(edit.range) or edit.insert)
  local start_col = range and M.byte_col(context.line, range.start.character, encoding) or context.start_col
  local filter_start_col = source == "lsp" and context.start_col or nil
  if filter_start_col ~= nil and start_col < filter_start_col then
    local prefix = context.line:sub(start_col + 1, filter_start_col)
    -- A compound filter includes the input before the final keyword.
    if vim.startswith(M.optional(raw.filterText) or raw.label, prefix) then
      filter_start_col = start_col
    end
  end
  local details = M.optional(raw.labelDetails)
  local description = details and M.optional(details.description) or ""
  local detail = M.optional(raw.detail) or ""
  local text = M.optional(edit and edit.newText or raw.insertText) or ""
  -- Client names keep history stable across restarts; positional IDs distinguish live LSP alternatives.
  local frecency_key = source
    .. "\0"
    .. (client and client.name or "")
    .. "\0"
    .. raw.label
    .. "\0"
    .. description
    .. "\0"
    .. detail
    .. "\0"
    .. text
  return {
    raw = raw,
    context = context,
    source = source,
    id = id
      or (
        client_id == nil and frecency_key
        or source .. "\0" .. client_id .. "\0" .. raw.label .. "\0" .. description .. "\0" .. detail .. "\0" .. text
      ),
    frecency_key = frecency_key,
    start_col = start_col,
    filter_start_col = filter_start_col,
    encoding = encoding,
    client_id = client_id,
    score_offset = offsets[source] or 0,
  }
end

---@param context                       era.keystroke.cmp.IContext
---@param start_col                     integer
---@param text                          string
---@param end_col                       ?integer
---@return lsp.TextEdit
function M.text_edit(context, start_col, text, end_col)
  return {
    newText = text,
    range = {
      start = { line = context.row, character = start_col },
      ["end"] = { line = context.row, character = end_col or context.col },
    },
  }
end

return M
