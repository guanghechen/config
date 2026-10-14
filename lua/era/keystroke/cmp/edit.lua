---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.edit" ---@type string

local Context = require("era.keystroke.cmp.context")
local Item = require("era.keystroke.cmp.item")
local M = {}
local anchor_namespace = vim.api.nvim_create_namespace(__module_name__)

---@param text                          string
---@return string|nil
---@return boolean|nil single_line_text
function M.snippet_text(text)
  local ok, parsed = pcall(vim.lsp._snippet_grammar.parse, text)
  if not ok then
    return nil
  end
  local placeholders = {}
  local final_tabstop = false
  for _, child in ipairs(parsed.data.children) do
    if child.data.tabstop == 0 then
      if final_tabstop then
        return nil
      end
      final_tabstop = true
    end
    if child.type == vim.lsp._snippet_grammar.NodeType.Placeholder then
      local index = child.data.tabstop
      local value = tostring(child.data.value)
      if placeholders[index] ~= nil and placeholders[index] ~= value then
        return nil
      end
      placeholders[index] = value
    end
  end
  local rendered = tostring(parsed)
  local children = parsed.data.children
  return rendered,
    #children == 1 and children[1].type == vim.lsp._snippet_grammar.NodeType.Text and not rendered:find("\n", 1, true)
end

---@param left                          lsp.Position
---@param right                         lsp.Position
---@return boolean
local function before(left, right)
  return left.line < right.line or (left.line == right.line and left.character < right.character)
end

---@param item                          era.keystroke.cmp.IItem
---@param context                       era.keystroke.cmp.IContext
---@param position                      lsp.Position
---@param affinity                      "start"|"end"|"additional"
---@return lsp.Position|nil
local function position_in_current_input(item, context, position, affinity)
  local line_count = vim.api.nvim_buf_line_count(context.bufnr)
  if position.line < 0 or position.character < 0 or position.line > line_count then
    return nil
  end
  if position.line == line_count then
    -- Neovim includes the final newline in LSP text, exposing an empty EOF line.
    if position.character == 0 and vim.api.nvim_get_option_value("endofline", { buf = context.bufnr }) then
      return { line = line_count, character = 0 }
    end
    return nil
  end
  local origin = item.context
  local line = position.line == origin.row and origin.line
    or vim.api.nvim_buf_get_lines(context.bufnr, position.line, position.line + 1, false)[1]
  local col = Item.byte_col(line, position.character, item.encoding)
  if
    position.line == origin.row
    and col >= origin.col
    and (affinity == "end" or (affinity == "additional" and col > item.start_col))
  then
    col = col + context.col - origin.col
  end
  return { line = position.line, character = col }
end

---@param item                          era.keystroke.cmp.IItem
---@param context                       era.keystroke.cmp.IContext
---@param raw                           ?lsp.CompletionItem
---@return era.keystroke.cmp.IEditPlan|nil
function M.plan(item, context, raw)
  if not Context.compatible(item.context, context, item.start_col) then
    return nil
  end
  raw = raw or item.resolved or item.raw
  local main = Item.optional(raw.textEdit)
  local body = Item.insert_text(raw)
  local text = body
  if item.expansion ~= nil and item.expansion.body == body and Context.same_input(item.expansion.context, context) then
    text = item.expansion.text
  end
  if text == nil then
    return nil
  end
  local range = main and (Item.optional(main.range) or main.insert)
  if range ~= nil then
    if range == vim.NIL then
      return nil
    end
    local start = position_in_current_input(item, context, range.start, "start")
    local finish = position_in_current_input(item, context, range["end"], "end")
    if
      start == nil
      or finish == nil
      or before(finish, start)
      or start.line ~= context.row
      or finish.line ~= context.row
    then
      return nil
    end
    main = { newText = text, range = { start = start, ["end"] = finish } }
  else
    main = Item.text_edit(context, item.start_col, text)
  end

  local additional = {} ---@type lsp.TextEdit[]
  for _, edit in ipairs(Item.optional(raw.additionalTextEdits) or {}) do
    if type(edit.newText) ~= "string" then
      return nil
    end
    local start = position_in_current_input(item, context, edit.range.start, "additional")
    local finish = position_in_current_input(item, context, edit.range["end"], "additional")
    if start == nil or finish == nil or before(finish, start) then
      return nil
    end
    additional[#additional + 1] = { newText = edit.newText, range = { start = start, ["end"] = finish } }
  end
  local all = vim.list_extend({ main }, additional)
  table.sort(all, function(a, b)
    if a.range.start.line == b.range.start.line and a.range.start.character == b.range.start.character then
      return before(a.range["end"], b.range["end"])
    end
    return before(a.range.start, b.range.start)
  end)
  for index = 2, #all do
    if before(all[index].range.start, all[index - 1].range["end"]) then
      return nil
    end
  end
  local snippet = raw.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet
  local create_undo_point = not snippet
  if snippet then
    local rendered, single_line_text = M.snippet_text(text)
    if rendered == nil then
      return nil
    end
    -- Resolving a variable must not erase the original snippet's cursor semantics.
    if single_line_text and text == body and raw.kind ~= vim.lsp.protocol.CompletionItemKind.Snippet then
      main.newText = rendered
      snippet = false
    end
  end
  return {
    main = main,
    additional = additional,
    snippet = snippet,
    create_undo_point = create_undo_point,
    cursor_offset = 0,
    semantic_brackets = false,
  }
end

---@param context                       era.keystroke.cmp.IContext
---@return boolean
function M.is_current(context)
  local current = Context.capture()
  return Context.same_input(context, current) and context.changedtick == vim.api.nvim_buf_get_changedtick(context.bufnr)
end

---@return nil
local function join_undo()
  -- Preview and its reversal belong to the same change. E790 is expected before the first edit.
  local ok, err = pcall(vim.cmd.undojoin)
  if not ok and not tostring(err):find("E790", 1, true) then
    error(err)
  end
end

---@param context                       era.keystroke.cmp.IContext
---@param plan                          era.keystroke.cmp.IEditPlan
---@return boolean
function M.apply(context, plan)
  if not M.is_current(context) then
    return false
  end
  local main = plan.main
  local bufnr = context.bufnr
  -- Follow the main edit's end, including any insertion at its original start.
  -- A snippet's empty main edit leaves the anchor at its expansion point.
  local anchor = vim.api.nvim_buf_set_extmark(
    bufnr,
    anchor_namespace,
    main.range.start.line,
    main.range.start.character,
    { right_gravity = true }
  )
  local edits = vim.list_extend({}, plan.additional)
  edits[#edits + 1] = { range = main.range, newText = plan.snippet and "" or main.newText }
  if plan.create_undo_point then
    vim.api.nvim_set_option_value(
      "undolevels",
      vim.api.nvim_get_option_value("undolevels", { buf = bufnr }),
      { buf = bufnr }
    )
  end
  vim.lsp.util.apply_text_edits(edits, bufnr, "utf-8")
  local position = vim.api.nvim_buf_get_extmark_by_id(bufnr, anchor_namespace, anchor, {})
  vim.api.nvim_buf_del_extmark(bufnr, anchor_namespace, anchor)
  vim.api.nvim_win_set_cursor(context.winnr, { position[1] + 1, position[2] })
  if plan.snippet then
    vim.snippet.expand(main.newText)
  end
  return true
end

---@param context                       era.keystroke.cmp.IContext
---@param opening                       string
---@param closing                       string
---@return boolean
function M.insert_brackets(context, opening, closing)
  if not M.is_current(context) or context.line:sub(context.col + 1, context.col + #opening) == opening then
    return false
  end
  join_undo()
  vim.api.nvim_buf_set_text(context.bufnr, context.row, context.col, context.row, context.col, { opening .. closing })
  vim.api.nvim_win_set_cursor(context.winnr, { context.row + 1, context.col + #opening })
  return true
end

return M
