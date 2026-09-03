---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.insert" ---@type string

local keymap = require("era.m.cmp.keymap")
local accept = require("era.m.cmp.accept")
local bridge = require("era.m.cmp.bridge")
local label_highlight = require("era.m.cmp.label")
local list = require("era.m.cmp.list")
local popupmenu = require("era.m.ui_attach.popupmenu")
local source = require("era.m.cmp.source")
local trigger = require("era.m.cmp.trigger")

---@class era.m.cmp.insert
local M = {}

local timers = {} ---@type table<integer, uv.uv_timer_t>
local generations = {} ---@type table<integer, integer>
local pending_chars = {} ---@type table<integer, { char: string, incomplete: boolean }>
local pending_backspaces = {} ---@type table<integer, integer>
local sessions = {} ---@type table<integer, era.m.cmp.IInsertSession>
local documentation_requests = {} ---@type table<integer, { cancel: fun()|nil }>
local usage_filepath = dot.path.join(vim.fn.stdpath("state"), "era/cmp/frecency.json")
local dressed = false ---@type boolean
local INSERT_OWNER = "era-cmp-insert"
local cancel_documentation ---@type fun(bufnr: integer): nil
local resolve_documentation ---@type fun(bufnr: integer, selected: integer, completed: table): nil
local trigger_after_accept ---@type fun(bufnr: integer): nil
local bracket_kinds = { Function = true, Method = true } ---@type table<string, boolean>
local bracket_blocked_filetypes = {
  applescript = true,
  clojure = true,
  cpp = true,
  elixir = true,
  elm = true,
  fennel = true,
  janet = true,
  javascriptreact = true,
  lisp = true,
  ["objective-c"] = true,
  objc = true,
  objcpp = true,
  nu = true,
  perl = true,
  prolog = true,
  ps1 = true,
  racket = true,
  ruby = true,
  rust = true,
  scheme = true,
  smalltalk = true,
  sql = true,
  typescriptreact = true,
  vb = true,
  vue = true,
} ---@type table<string, boolean>
local round_brackets = { "(", ")" } ---@type string[]
local space_brackets = { " ", "" } ---@type string[]
local square_brackets = { "[", "]" } ---@type string[]
local curly_brackets = { "{", "}" } ---@type string[]
local bracket_shapes = {
  bash = space_brackets,
  context = square_brackets,
  erlang = space_brackets,
  fish = space_brackets,
  fsharp = space_brackets,
  haskell = space_brackets,
  helm = space_brackets,
  lean = space_brackets,
  make = space_brackets,
  mathematica = square_brackets,
  mma = square_brackets,
  nix = space_brackets,
  ocaml = space_brackets,
  plaintex = curly_brackets,
  powershell = space_brackets,
  sh = space_brackets,
  shell = space_brackets,
  tcl = space_brackets,
  tex = curly_brackets,
  wl = square_brackets,
  wolfram = square_brackets,
  zsh = space_brackets,
} ---@type table<string, string[]>
local kind_hlgroups = {
  Text = "String",
  Method = "Function",
  Function = "Function",
  Constructor = "Special",
  Field = "Identifier",
  Variable = "Identifier",
  Class = "Type",
  Interface = "Type",
  Module = "Include",
  Property = "Identifier",
  Unit = "Constant",
  Value = "Constant",
  Enum = "Type",
  Keyword = "Keyword",
  Snippet = "Special",
  File = "Directory",
  Reference = "Identifier",
  Folder = "Directory",
  EnumMember = "Constant",
  Constant = "Constant",
  Struct = "Type",
  Event = "Special",
  Operator = "Operator",
  TypeParameter = "Type",
} ---@type table<string, string>
local source_hlgroups = {
  buffer = "String",
  dict = "Constant",
  path = "Directory",
  path_at = "Directory",
  slash = "Keyword",
  snippets = "Special",
} ---@type table<string, string>

---@param item                          era.m.cmp.ICompletionItem
---@param meta                          era.m.cmp.IMeta|nil
---@return string
local function source_hlgroup(item, meta)
  if item._era_cmp_origin ~= nil then
    return "Function"
  end
  return source_hlgroups[meta and meta.source or ""] or "Type"
end

---@param context                       era.m.cmp.IContext|nil
---@return boolean
local function can_auto_bracket(context)
  if context == nil then
    return true
  end
  local filetype = context.filetype ---@type string
  if bracket_blocked_filetypes[filetype] then
    return false
  end

  local line = context.line ---@type string
  if filetype == "python" then
    return line:find("^%s*import%s") == nil and line:find("^%s*from%s") == nil and line:find("^%s*except%s") == nil
  end
  if filetype == "css" or filetype == "scss" or filetype == "less" or filetype == "html" then
    return line:sub(1, context.col):find("[%w_-]*::?[%w-]*$") == nil
  end
  if
    filetype == "javascript"
    or filetype == "javascriptreact"
    or filetype == "typescript"
    or filetype == "typescriptreact"
    or filetype == "svelte"
  then
    return line:find("^%s*import%s") == nil
  end
  return true
end

---@param snippet                       string
---@return integer
local function next_snippet_placeholder(snippet)
  local highest = 0 ---@type integer
  for number in snippet:gmatch("%${(%d+)") do
    highest = math.max(highest, tonumber(number) or 0)
  end
  for number in snippet:gmatch("%$(%d+)") do
    highest = math.max(highest, tonumber(number) or 0)
  end
  return highest + 1
end

---@param snippet                       string
---@return string
local function snippet_preview(snippet)
  local ok, parsed = pcall(vim.lsp._snippet_grammar.parse, snippet)
  return ok and tostring(parsed) or snippet
end

local preview_stop_chars = "'\"=$()[]<>{} \t\r\n" ---@type string
local preview_stops = {} ---@type table<integer, boolean>
for index = 1, #preview_stop_chars do
  preview_stops[preview_stop_chars:byte(index)] = true
end
local preview_closing_pairs = {
  [string.byte("(")] = string.byte(")"),
  [string.byte("[")] = string.byte("]"),
  [string.byte("{")] = string.byte("}"),
  [string.byte("<")] = string.byte(">"),
  [string.byte('"')] = string.byte('"'),
  [string.byte("'")] = string.byte("'"),
} ---@type table<integer, integer>

---@param text                          string
---@return string
local function snippet_preview_prefix(text)
  local closing_pairs = {} ---@type integer[]
  local has_alphanumeric = false ---@type boolean
  for index = 1, #text do
    local byte = text:byte(index) ---@type integer
    if not preview_stops[byte] then
      if (byte >= 0x30 and byte <= 0x39) or (byte >= 0x41 and byte <= 0x5A) or (byte >= 0x61 and byte <= 0x7A) then
        has_alphanumeric = true
      end
    elseif not has_alphanumeric or #closing_pairs > 0 then
      if closing_pairs[#closing_pairs] == byte then
        closing_pairs[#closing_pairs] = nil
      elseif preview_closing_pairs[byte] ~= nil then
        closing_pairs[#closing_pairs + 1] = preview_closing_pairs[byte]
      end
      if has_alphanumeric and #closing_pairs == 0 then
        return text:sub(1, index)
      end
    else
      return text:sub(1, index - 1)
    end
  end
  return text
end

---@param item                          lsp.CompletionItem
---@return string
local function preview_word(item)
  local text = item.textEdit and item.textEdit.newText or item.insertText or item.label ---@type string|nil
  if type(text) ~= "string" then
    return ""
  end
  text = text:gsub("\r\n?", "\n")
  if item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet then
    text = snippet_preview_prefix(snippet_preview(text))
  end
  return text:match("([^\n]*)") or ""
end

---@param item                          lsp.CompletionItem
---@return string
local function documentation(item)
  if type(item.documentation) == "string" then
    return item.documentation --[[@as string]]
  end
  if type(item.documentation) == "table" and type(item.documentation.value) == "string" then
    return item.documentation.value
  end
  return ""
end

---@param item                          lsp.CompletionItem
---@return string|nil
local function color_hlgroup(item)
  if item.kind ~= vim.lsp.protocol.CompletionItemKind.Color then
    return nil
  end
  local value = documentation(item) ---@type string
  local red, green, blue = value:match("rgb%((%d+)%s*,?%s*(%d+)%s*,?%s*(%d+)%)")
  local hex = red and string.format("%02x%02x%02x", tonumber(red), tonumber(green), tonumber(blue))
    or value:match("#?([%da-fA-F]+)") ---@type string|nil
  if hex == nil then
    return nil
  end
  if #hex == 3 then
    hex = hex:gsub(".", "%1%1")
  end
  if #hex ~= 6 then
    return nil
  end
  hex = hex:lower()
  local group = "@lsp.color." .. hex ---@type string
  if vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = group })) then
    vim.api.nvim_set_hl(0, group, { fg = "#" .. hex })
  end
  return group
end

---@param item                          lsp.CompletionItem
---@return string
local function item_description(item)
  local docs = documentation(item) ---@type string
  local detail = type(item.detail) == "string" and item.detail or "" ---@type string
  if detail == "" or docs:find(detail, 1, true) then
    return docs
  end
  return docs == "" and detail or detail .. dot.var.CMP_DOCUMENTATION_SEPARATOR .. docs
end

---@param item                          lsp.CompletionItem
---@return string|nil
local function snippet_info(item)
  if item.insertTextFormat ~= vim.lsp.protocol.InsertTextFormat.Snippet then
    return nil
  end

  local new_text = item.textEdit and item.textEdit.newText or item.insertText or item.label ---@type string|nil
  if type(new_text) ~= "string" or new_text == "" then
    return nil
  end

  local preview = snippet_preview(new_text) ---@type string
  local description = item_description(item) ---@type string
  return dot.var.CMP_DOCUMENTATION_PREVIEW
    .. preview
    .. (description == "" and "" or dot.var.CMP_DOCUMENTATION_SEPARATOR .. description)
end

---@param item                          era.m.cmp.ICompletionItem
---@return string
local function display_info(item)
  return snippet_info(item) or item_description(item)
end

local function item_meta(item)
  local lsp_item = vim.tbl_get(item, "user_data", "era_cmp", "item") ---@type table|nil
  local data = type(lsp_item) == "table" and lsp_item.data or nil ---@type table|nil
  local meta = type(lsp_item) == "table" and lsp_item._era_cmp_meta or nil ---@type table|nil
  meta = meta or (type(data) == "table" and data.era_cmp or nil)
  return lsp_item, meta
end

---@class era.m.cmp.IInsertSession
---@field public generation             integer
---@field public bufnr                  integer
---@field public row                    integer 0-indexed
---@field public base_line              string
---@field public base_col               integer 0-indexed
---@field public start_col              integer 0-indexed
---@field public items                  era.m.cmp.ICompletionItem[]
---@field public completed              table[]
---@field public rows                   string[][]
---@field public selected               integer 0-indexed, -1 means base text
---@field public preview_line           string|nil
---@field public preview_col            integer|nil

---@param value                         era.m.cmp.IInsertSession
---@return boolean
local function owns_session(value)
  return sessions[value.bufnr] == value
    and generations[value.bufnr] == value.generation
    and vim.api.nvim_buf_is_valid(value.bufnr)
    and vim.api.nvim_get_current_buf() == value.bufnr
end

---@param value                         era.m.cmp.IInsertSession
---@return boolean
local function is_session_current(value)
  return owns_session(value) and vim.api.nvim_get_mode().mode:match("^[iR]") ~= nil
end

---@param value                         era.m.cmp.IInsertSession
---@return boolean
local function owns_preview(value)
  if value.preview_line == nil or not owns_session(value) then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(0) ---@type integer[]
  return cursor[1] - 1 == value.row and vim.api.nvim_get_current_line() == value.preview_line
end

---@param value                         era.m.cmp.IInsertSession
---@return boolean
local function restore_preview(value)
  if not owns_preview(value) then
    return false
  end
  vim.api.nvim_buf_set_lines(value.bufnr, value.row, value.row + 1, false, { value.base_line })
  vim.api.nvim_win_set_cursor(0, { value.row + 1, value.base_col })
  value.preview_line = nil
  value.preview_col = nil
  return true
end

---@param value                         era.m.cmp.IInsertSession
---@param target                        integer
---@return boolean
local function apply_preview(value, target)
  if not is_session_current(value) then
    return false
  end
  if target < 0 then
    if value.preview_line ~= nil and not restore_preview(value) then
      return false
    end
    value.selected = target
    popupmenu.select_owned(INSERT_OWNER, value.generation, target)
    cancel_documentation(value.bufnr)
    return true
  end
  if value.preview_line ~= nil and not owns_preview(value) then
    return false
  end

  local item = value.items[target + 1] ---@type era.m.cmp.ICompletionItem|nil
  local completed = value.completed[target + 1] ---@type table|nil
  if item == nil or completed == nil then
    return false
  end
  value.selected = target
  local suffix_bytes = math.max(0, item._era_cmp_suffix_bytes or 0) ---@type integer
  local end_col = math.min(value.base_col + suffix_bytes, #value.base_line) ---@type integer
  local preview = completed.word or "" ---@type string
  local line = value.base_line:sub(1, value.start_col) .. preview .. value.base_line:sub(end_col + 1) ---@type string
  local col = value.start_col + #preview ---@type integer
  vim.api.nvim_buf_set_lines(value.bufnr, value.row, value.row + 1, false, { line })
  vim.api.nvim_win_set_cursor(0, { value.row + 1, col })
  value.preview_line = line
  value.preview_col = col
  popupmenu.select_owned(INSERT_OWNER, value.generation, target)
  resolve_documentation(value.bufnr, target, completed)
  return true
end

---@param item                          table
---@return string|nil
local function completion_identity(item)
  local lsp_item = item_meta(item) ---@type era.m.cmp.ICompletionItem|nil
  local origin = type(lsp_item) == "table" and lsp_item._era_cmp_origin or nil ---@type era.m.cmp.IOrigin|nil
  if type(lsp_item) ~= "table" or origin == nil then
    return nil
  end
  local text_edit = lsp_item.textEdit ---@type table|nil
  local new_text = type(text_edit) == "table" and text_edit.newText or "" ---@type string
  return table.concat({
    origin.client_id,
    lsp_item.label or "",
    lsp_item.kind or 0,
    lsp_item.filterText or "",
    lsp_item.sortText or "",
    new_text,
  }, "\0")
end

local function usage_key(item)
  local lsp_item, meta = item_meta(item)
  if lsp_item == nil then
    return nil
  end
  local key = bridge.get_usage_key(lsp_item)
  if key ~= nil then
    return key
  end
  local source_name = meta and meta.source or "lsp" ---@type string
  return source_name .. "\0" .. (lsp_item.label or item.abbr or item.word or "")
end

local function convert(item)
  local kind = vim.lsp.protocol.CompletionItemKind[item.kind] ---@type string|nil
  local data = type(item.data) == "table" and item.data.era_cmp or nil ---@type table|nil
  local meta = type(item._era_cmp_meta) == "table" and item._era_cmp_meta or data ---@type table|nil

  if bracket_kinds[kind] == true then
    local new_text = item.textEdit and item.textEdit.newText or item.insertText or item.label ---@type string
    local origin = item._era_cmp_origin ---@type era.m.cmp.IOrigin|nil
    local context = origin and origin.context or nil ---@type era.m.cmp.IContext|nil
    local brackets = context and bracket_shapes[context.filetype] or nil ---@type string[]|nil
    local opening, closing = unpack(brackets or round_brackets) ---@type string, string
    local followed_by_bracket = false ---@type boolean
    if context ~= nil then
      local range_end = context.col + (origin and origin.suffix_bytes or 0) ---@type integer
      local trailing = context.line:sub(range_end + 1) ---@type string
      followed_by_bracket = opening == " " and trailing:match("^%s") ~= nil
        or trailing:match("^%s*" .. vim.pesc(opening)) ~= nil
    end
    if type(new_text) == "string" then
      local bracket = new_text:find(opening, 1, true) ---@type integer|nil
      local has_final_tabstop = item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet
        and (new_text:find("$0", 1, true) ~= nil or new_text:find("${0", 1, true) ~= nil) ---@type boolean
      if followed_by_bracket and bracket ~= nil and opening ~= " " then
        new_text = new_text:sub(1, bracket - 1)
      elseif not followed_by_bracket and bracket == nil and not has_final_tabstop and can_auto_bracket(context) then
        if item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet then
          new_text = new_text .. opening .. "$" .. next_snippet_placeholder(new_text) .. closing
        elseif closing == "" then
          new_text = new_text .. opening
        else
          new_text = new_text:gsub("\\", "\\\\"):gsub("%$", "\\$"):gsub("}", "\\}") .. opening .. "$0" .. closing
          item.insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet
        end
      end
      if item.textEdit ~= nil then
        item.textEdit.newText = new_text
      else
        item.insertText = new_text
      end
    end
  end

  return {
    equal = 1,
    kind = kind and (stl.icon.kind[kind] or kind) or "",
    menu = meta and string.format("[%s]", meta.source) or nil,
    source_hlgroup = source_hlgroup(item, meta),
    info = snippet_info(item) or (item._era_cmp_origin == nil and item_description(item) or nil),
    word = preview_word(item),
  }
end

---@param item                          era.m.cmp.ICompletionItem
---@param display_label                 string|nil
---@return table
local function to_complete_item(item, display_label)
  local converted = convert(item) ---@type table
  display_label = display_label or label_highlight.display(item.label)
  local raw_detail = vim.tbl_get(item, "labelDetails", "detail") ---@type string|nil
  local raw_description = vim.tbl_get(item, "labelDetails", "description") ---@type string|nil
  local label_detail = raw_detail and label_highlight.display(raw_detail) or nil ---@type string|nil
  local label_description = raw_description and label_highlight.display(raw_description) or nil ---@type string|nil
  local kind = vim.lsp.protocol.CompletionItemKind[item.kind] ---@type string|nil
  local deprecated = label_highlight.is_deprecated(item) ---@type boolean
  return vim.tbl_extend("keep", converted, {
    abbr = display_label .. (label_detail or ""),
    label_description = label_description,
    icase = 1,
    dup = 1,
    empty = 1,
    abbr_hlgroup = deprecated and "DiagnosticDeprecated" or "",
    kind_hlgroup = color_hlgroup(item) or kind_hlgroups[kind or ""] or "Function",
    user_data = { era_cmp = { item = item } },
  })
end

---@param bufnr                         integer
---@param params                        lsp.CompletionParams
---@param result                        lsp.CompletionList
---@param generation                    integer
local function publish_completion(bufnr, params, result, generation)
  if
    generations[bufnr] ~= generation
    or vim.api.nvim_get_current_buf() ~= bufnr
    or not vim.api.nvim_get_mode().mode:match("^[iR]")
    or vim.api.nvim_win_get_cursor(0)[1] - 1 ~= params.position.line
  then
    return
  end

  local cursor_col = vim.api.nvim_win_get_cursor(0)[2] ---@type integer
  if cursor_col ~= params.position.character then
    return
  end
  local line = vim.api.nvim_get_current_line() ---@type string
  local start_col = yoz.cmp.keyword_range(line, cursor_col, true) ---@type integer
  local items = type(result) == "table" and result.items or nil ---@type era.m.cmp.ICompletionItem[]|nil
  items = type(items) == "table" and items or {}
  if #items == 0 then
    sessions[bufnr] = nil
    cancel_documentation(bufnr)
    popupmenu.dismiss(INSERT_OWNER, generation)
    return
  end
  local first = items[1]
  local range = first and first.textEdit and first.textEdit.range or nil ---@type lsp.Range|nil
  if range ~= nil and range.start.line == params.position.line then
    start_col = range.start.character
  end

  local previous = sessions[bufnr]
  if previous ~= nil and previous.generation == generation then
    restore_preview(previous)
  end
  local completed = {} ---@type table[]
  local rows = {} ---@type string[][]
  local labels = {} ---@type string[]
  for index, item in ipairs(items) do
    local display_label = label_highlight.display(item.label) ---@type string
    local value = to_complete_item(item, display_label)
    completed[index] = value
    labels[index] = display_label
    rows[index] = {
      value.abbr or value.word or "",
      value.kind or "",
      value.menu or "",
      value.info or "",
      value.label_description or "",
      value.kind_hlgroup or "Function",
      nil,
      value.source_hlgroup or "NonText",
    }
  end
  local query = line:sub(start_col + 1, cursor_col) ---@type string
  local matched_ranges = yoz.cmp.matched_ranges(query, labels) ---@type integer[][]
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  local highlights, resolve_highlights = label_highlight.project(filetype, items, matched_ranges, labels)
  for index = 1, #items do
    rows[index][7] = highlights[index]
  end
  local position = vim.fn.screenpos(0, params.position.line + 1, start_col + 1) ---@type table
  local anchor_row = math.max(0, (position.row or 1) - 1) ---@type integer
  local anchor_col = math.max(0, (position.col or start_col + 1) - 1) ---@type integer
  local value = {
    generation = generation,
    bufnr = bufnr,
    row = params.position.line,
    base_line = line,
    base_col = cursor_col,
    start_col = start_col,
    items = items,
    completed = completed,
    rows = rows,
    selected = 0,
    preview_line = nil,
    preview_col = nil,
  } ---@type era.m.cmp.IInsertSession
  sessions[bufnr] = value
  cancel_documentation(bufnr)
  popupmenu.present(INSERT_OWNER, generation, rows, 0, anchor_row, anchor_col, 0, resolve_highlights)
  resolve_documentation(bufnr, 0, completed[1])
end

---@param bufnr                         integer
---@param ctx                           lsp.CompletionContext|nil
---@return lsp.CompletionParams|nil
local function completion_params(bufnr, ctx)
  if vim.api.nvim_get_current_buf() ~= bufnr then
    return nil
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0)) ---@type integer, integer
  return {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = row - 1, character = col },
    context = ctx or { triggerKind = vim.lsp.protocol.CompletionTriggerKind.Invoked },
  }
end

---@param bufnr                         integer
---@param ctx                           lsp.CompletionContext|nil
---@return boolean
local function request_completion(bufnr, ctx)
  local params = completion_params(bufnr, ctx)
  if params == nil then
    return false
  end
  local generation = generations[bufnr] or next_generation(bufnr) ---@type integer
  local ok, err = xpcall(function()
    bridge.complete(params, function(response_err, result)
      if response_err ~= nil then
        stl.reporter.error({
          from = __module_name__,
          subject = "request",
          message = "Completion request failed.",
          details = response_err,
        })
      elseif type(result) == "table" then
        local published, publish_err = xpcall(publish_completion, debug.traceback, bufnr, params, result, generation)
        if not published then
          stl.reporter.error({
            from = __module_name__,
            subject = "publish",
            message = "Failed to publish completion results.",
            details = publish_err,
          })
        end
      end
    end, bufnr)
  end, debug.traceback)
  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "request",
      message = "Failed to start completion request.",
      details = err,
    })
  end
  return ok
end

---@param completed                     table
local function record_usage(completed)
  local key = usage_key(completed)
  if key ~= nil then
    bridge.record_history(key, os.time())
  end
end

---@param bufnr                         integer
---@return boolean
local function visible(bufnr)
  local value = sessions[bufnr]
  return value ~= nil and is_session_current(value) and popupmenu.visible(INSERT_OWNER, value.generation)
end

local function in_cmdwin()
  return vim.fn.win_gettype() == "command"
end

---@param bufnr                         integer
---@param direction                     -1|1
---@return boolean
local function move_completion(bufnr, direction)
  local value = sessions[bufnr]
  if value == nil or not is_session_current(value) or #value.items == 0 then
    return false
  end
  local target = #value.items == 1 and value.selected == 0 and value.preview_line == nil and 0
    or list.move(value.selected, #value.items, direction) ---@type integer
  return apply_preview(value, target)
end

---@param bufnr                         integer
---@param index?                        integer 1-indexed
---@return boolean
local function accept_completion(bufnr, index)
  local value = sessions[bufnr]
  if value == nil or not is_session_current(value) or #value.items == 0 then
    return false
  end
  local selected = index and list.resolve(index, #value.items) or value.selected
  if selected == nil then
    return false
  end
  if selected < 0 then
    selected = 0
  end
  if value.selected ~= selected or value.preview_line == nil then
    if not apply_preview(value, selected) then
      return false
    end
  end
  local completed = value.completed[selected + 1] ---@type table|nil
  if completed == nil then
    return false
  end

  sessions[bufnr] = nil
  cancel_documentation(bufnr)
  popupmenu.dismiss(INSERT_OWNER, value.generation)
  bridge.clear(bufnr)
  if accept.apply(completed, record_usage, true) then
    trigger_after_accept(bufnr)
  end
  return true
end

---@param bufnr                         integer
local function commit_preview(bufnr)
  local value = sessions[bufnr]
  if value == nil or value.preview_line == nil then
    return
  end
  local generation = value.generation
  sessions[bufnr] = nil
  cancel_documentation(bufnr)
  -- InsertCharPre is textlocked, so detach controller state now and dispose
  -- the generation-owned windows on the next event-loop tick.
  vim.schedule(function()
    popupmenu.dismiss(INSERT_OWNER, generation)
  end)
end

---@param bufnr                         integer
local function attach(bufnr)
  if not source.is_enabled(bufnr) or vim.g.vscode or vim.g.yozvim then
    local value = sessions[bufnr]
    if value ~= nil then
      restore_preview(value)
      sessions[bufnr] = nil
      popupmenu.dismiss(INSERT_OWNER, value.generation)
    end
    keymap.unbind(bufnr)
    bridge.clear(bufnr)
    return
  end

  keymap.bind(bufnr)
end

local function stop_timer(bufnr)
  local timer = timers[bufnr]
  if timer ~= nil then
    timer:stop()
  end
end

---@param bufnr                         integer
---@return integer
local function next_generation(bufnr)
  local generation = (generations[bufnr] or 0) + 1 ---@type integer
  generations[bufnr] = generation
  return generation
end

---@param bufnr                         integer
cancel_documentation = function(bufnr)
  local request = documentation_requests[bufnr]
  documentation_requests[bufnr] = nil
  if request ~= nil and type(request.cancel) == "function" then
    request.cancel()
  end
end

---@param bufnr                         integer
---@param selected                      integer
---@param identity                      string
---@return boolean
local function is_documentation_current(bufnr, selected, identity)
  local value = sessions[bufnr]
  if value == nil or not is_session_current(value) or value.selected ~= selected then
    return false
  end
  local current = value.completed[selected + 1] ---@type table|nil
  return type(current) == "table" and completion_identity(current) == identity
end

---@param bufnr                         integer
---@param selected                      integer
---@param completed                     table
resolve_documentation = function(bufnr, selected, completed)
  cancel_documentation(bufnr)
  local lsp_item = item_meta(completed) ---@type era.m.cmp.ICompletionItem|nil
  local word = completed.abbr or completed.word ---@type string|nil
  local identity = completion_identity(completed) ---@type string|nil
  if type(lsp_item) ~= "table" or identity == nil or type(word) ~= "string" or word == "" then
    return
  end

  local request = { cancel = nil } ---@type { cancel: fun()|nil }
  documentation_requests[bufnr] = request
  vim.schedule(function()
    if documentation_requests[bufnr] ~= request then
      return
    end
    if not is_documentation_current(bufnr, selected, identity) then
      cancel_documentation(bufnr)
      return
    end

    request.cancel = bridge.resolve(lsp_item, function(err, resolved)
      if documentation_requests[bufnr] ~= request then
        return
      end
      documentation_requests[bufnr] = nil
      if err ~= nil or type(resolved) ~= "table" or not is_documentation_current(bufnr, selected, identity) then
        return
      end
      local documented = vim.deepcopy(lsp_item) ---@type era.m.cmp.ICompletionItem
      if resolved.documentation ~= nil then
        documented.documentation = resolved.documentation
      end
      if resolved.detail ~= nil then
        documented.detail = resolved.detail
      end
      local text = display_info(documented) ---@type string
      if text ~= "" then
        local value = sessions[bufnr]
        if value ~= nil then
          popupmenu.update_owned_documentation(INSERT_OWNER, value.generation, selected, word, text)
        end
      end
    end)
  end)
end

---@param bufnr                         integer
---@param ctx                           lsp.CompletionContext|nil
local function schedule_completion(bufnr, ctx)
  if not source.is_enabled(bufnr) then
    return
  end
  local generation = next_generation(bufnr) ---@type integer
  local timer = timers[bufnr]
  if timer == nil then
    timer = assert(vim.uv.new_timer())
    timers[bufnr] = timer
  end
  timer:stop()
  timer:start(
    0,
    0,
    vim.schedule_wrap(function()
      if
        generations[bufnr] == generation
        and vim.api.nvim_get_current_buf() == bufnr
        and vim.api.nvim_get_mode().mode:match("^[iR]")
        and source.is_enabled(bufnr)
      then
        request_completion(bufnr, ctx)
      end
    end)
  )
end

local function hide_completion(bufnr)
  local value = sessions[bufnr]
  if value ~= nil then
    restore_preview(value)
    sessions[bufnr] = nil
    popupmenu.dismiss(INSERT_OWNER, value.generation)
  else
    popupmenu.dismiss(INSERT_OWNER)
  end
  next_generation(bufnr)
  stop_timer(bufnr)
  pending_chars[bufnr] = nil
  pending_backspaces[bufnr] = nil
  cancel_documentation(bufnr)
  bridge.clear(bufnr)
end

---@param bufnr                         integer
---@param char                          string
---@param incomplete                    boolean
local function handle_char(bufnr, char, incomplete)
  local kind = trigger.classify(char, function()
    return trigger.characters(bufnr)
  end)
  if kind == nil then
    hide_completion(bufnr)
    return
  end

  local ctx = nil ---@type lsp.CompletionContext|nil
  if kind == "trigger_character" then
    ctx = {
      triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter,
      triggerCharacter = char,
    }
  elseif incomplete then
    ctx = {
      triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerForIncompleteCompletions,
    }
  end
  schedule_completion(bufnr, ctx)
end

---@param bufnr                         integer
---@return string
---@return integer[]
---@return string
local function character_before_cursor(bufnr)
  if vim.api.nvim_get_current_buf() ~= bufnr then
    return "", {}, ""
  end
  local cursor = vim.api.nvim_win_get_cursor(0) ---@type integer[]
  local line = vim.api.nvim_get_current_line() ---@type string
  local prefix = line:sub(1, cursor[2]) ---@type string
  local chars = vim.fn.strchars(prefix) ---@type integer
  local char = chars > 0 and vim.fn.strcharpart(prefix, chars - 1, 1) or "" ---@type string
  return char, cursor, line
end

---@param bufnr                         integer
trigger_after_accept = function(bufnr)
  local char, cursor, line = character_before_cursor(bufnr)
  local kind = trigger.classify(char, function()
    return trigger.characters(bufnr)
  end)
  if kind ~= "trigger_character" then
    return
  end

  ---@type lsp.CompletionContext
  local ctx = {
    triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter,
    triggerCharacter = char,
  }
  local generation = next_generation(bufnr) ---@type integer
  vim.schedule(function()
    if
      generations[bufnr] == generation
      and vim.api.nvim_get_current_buf() == bufnr
      and vim.api.nvim_get_mode().mode:match("^[iR]")
      and vim.deep_equal(vim.api.nvim_win_get_cursor(0), cursor)
      and vim.api.nvim_get_current_line() == line
    then
      schedule_completion(bufnr, ctx)
    end
  end)
end

function M.show()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if source.is_enabled(bufnr) then
    local value = sessions[bufnr]
    if value ~= nil then
      restore_preview(value)
      sessions[bufnr] = nil
      popupmenu.dismiss(INSERT_OWNER, value.generation)
    end
    next_generation(bufnr)
    stop_timer(bufnr)
    pending_chars[bufnr] = nil
    bridge.cancel(bufnr)
    request_completion(bufnr, nil)
  end
end

function M.hide()
  hide_completion(vim.api.nvim_get_current_buf())
end

---@param bufnr                         integer
---@param index?                        integer
---@return boolean
function M.accept(bufnr, index)
  return accept_completion(bufnr, index)
end

---@param bufnr                         integer
---@return boolean
function M.cancel(bufnr)
  if not visible(bufnr) then
    return false
  end
  hide_completion(bufnr)
  return true
end

---@param bufnr                         integer
---@param direction                     -1|1
---@return boolean
function M.move(bufnr, direction)
  return move_completion(bufnr, direction)
end

---@param bufnr                         integer
---@return boolean
function M.visible(bufnr)
  return visible(bufnr)
end

function M.backspace()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local value = sessions[bufnr]
  if value ~= nil then
    restore_preview(value)
    sessions[bufnr] = nil
    popupmenu.dismiss(INSERT_OWNER, value.generation)
  end
  local generation = next_generation(bufnr) ---@type integer
  bridge.cancel(bufnr)
  pending_backspaces[bufnr] = generation
end

---@param show_signature                fun(bufnr: integer): boolean
function M.dressing(show_signature)
  if dressed then
    return
  end
  dressed = true

  local persisted_usage = stl.fs.read_json({
    filepath = usage_filepath,
    silent_on_bad_json = true,
    silent_on_bad_path = true,
  }) or {}
  bridge.set_history(persisted_usage)
  bridge.set_refresh(function(bufnr)
    if
      vim.api.nvim_get_current_buf() == bufnr
      and vim.api.nvim_get_mode().mode:match("^[iR]")
      and source.is_enabled(bufnr)
    then
      return request_completion(bufnr, {
        triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerForIncompleteCompletions,
      })
    end
    return false
  end)
  bridge.register_commands(M.show, show_signature)

  local augroup = stl.nvim.fn.augroup(__module_name__ .. ".dressing")
  vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
    group = augroup,
    callback = function(args)
      attach(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd("InsertCharPre", {
    group = augroup,
    callback = function(args)
      if in_cmdwin() then
        return
      end
      local incomplete = visible(args.buf)
      commit_preview(args.buf)
      pending_chars[args.buf] = { char = vim.v.char, incomplete = incomplete }
    end,
  })
  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
    group = augroup,
    callback = function(args)
      if in_cmdwin() then
        return
      end
      local pending = pending_chars[args.buf] ---@type { char: string, incomplete: boolean }|nil
      pending_chars[args.buf] = nil
      if pending ~= nil then
        handle_char(args.buf, pending.char, pending.incomplete)
        return
      end
      local generation = pending_backspaces[args.buf] ---@type integer|nil
      pending_backspaces[args.buf] = nil
      if
        generation ~= nil
        and generations[args.buf] == generation
        and vim.api.nvim_get_current_buf() == args.buf
        and vim.api.nvim_get_mode().mode:match("^[iR]")
        and source.is_enabled(args.buf)
      then
        local char = character_before_cursor(args.buf)
        local kind = trigger.classify(char, function()
          return trigger.characters(args.buf)
        end)
        if kind == nil then
          hide_completion(args.buf)
        else
          local ctx = kind == "trigger_character"
              and {
                triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter,
                triggerCharacter = char,
              }
            or nil ---@type lsp.CompletionContext|nil
          schedule_completion(args.buf, ctx)
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = augroup,
    callback = function(args)
      local value = sessions[args.buf]
      if value ~= nil then
        restore_preview(value)
        sessions[args.buf] = nil
        popupmenu.dismiss(INSERT_OWNER, value.generation)
      end
      next_generation(args.buf)
      stop_timer(args.buf)
      pending_chars[args.buf] = nil
      pending_backspaces[args.buf] = nil
      cancel_documentation(args.buf)
      bridge.clear(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = augroup,
    callback = function(args)
      local timer = timers[args.buf]
      timers[args.buf] = nil
      generations[args.buf] = nil
      pending_chars[args.buf] = nil
      pending_backspaces[args.buf] = nil
      sessions[args.buf] = nil
      cancel_documentation(args.buf)
      bridge.clear(args.buf)
      source.clear_buffer(args.buf)
      keymap.release(args.buf)
      if timer ~= nil then
        timer:stop()
        timer:close()
      end
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      stl.fs.write_json(usage_filepath, bridge.snapshot_history(os.time()), false)
    end,
  })
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      attach(bufnr)
    end
  end
end

M._to_completed_item = to_complete_item

return M
