---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.pairs.context" ---@type string

-- Ported from blink.pairs v0.5.0 (`lua/blink/pairs/context`; MIT License, Copyright (c) 2025 Liam Dyer; see
-- LICENSE.blink). The command line reads as Vim script and never looks at the current buffer's syntax tree or pairs.

--- The text around the cursor when a pair key is typed. Fields that need a call are computed on first read.
---@class era.keystroke.pairs.Context
---@field public mode                   string
---@field public cmdline                boolean
---@field public bufnr                  integer
---@field public filetype               string The command line's is "vim".
---@field public row                    integer One-based.
---@field public col                    integer Byte column of the cursor.
---@field public line                   string
---@field public prev_non_ws_col        integer One-based column of the last non-blank character before the cursor.
---@field public is_escaped             boolean An odd run of backslashes ends before the cursor.
---@field public parser                 vim.treesitter.LanguageTree|false The buffer's syntax tree; false without one.
---@field public lang                   string|false Treesitter language at the cursor; false without a parser.
---@field public document               yoz.pairs.Document|false The buffer's `era.m.pairs` document; false without one.
---@field public in_string              boolean The document has the cursor inside a string.
local Context = {}

---@type table<string, fun(ctx: era.keystroke.pairs.Context): any>
local constructors = {
  prev_non_ws_col = function(ctx)
    for index = ctx.col, 1, -1 do
      if not ctx.line:sub(index, index):match("%s") then
        return index
      end
    end
    return 0
  end,
  is_escaped = function(ctx)
    local count, index = 0, ctx.col ---@type integer, integer
    while index > 0 and ctx.line:sub(index, index) == "\\" do
      count, index = count + 1, index - 1
    end
    return count % 2 == 1
  end,
  parser = function(ctx)
    return not ctx.cmdline and vim.treesitter.get_parser(ctx.bufnr, nil, { error = false }) or false
  end,
  lang = function(ctx)
    local parser = ctx.parser
    if not parser then
      return false
    end
    local row = ctx.row - 1 ---@type integer
    return parser:language_for_range({ row, ctx.col, row, ctx.col }):lang()
  end,
  document = function(ctx)
    return not ctx.cmdline and era.m.pairs.document(ctx.bufnr) or false
  end,
  in_string = function(ctx)
    local class = ctx.document and ctx.document:inside(ctx.row - 1, ctx.col) ---@type yoz.pairs.Class|false|nil
    return class == "string" or class == "block_string"
  end,
}

local metatable = {
  __index = function(ctx, key)
    if Context[key] ~= nil then
      return Context[key]
    end
    local constructor = constructors[key]
    if constructor then
      local value = constructor(ctx)
      rawset(ctx, key, value)
      return value
    end
  end,
}

---@param chars                         ?integer
---@return string
function Context:text_before_cursor(chars)
  return self.line:sub(chars and (self.col - chars + 1) or 1, self.col)
end

---@param chars                         ?integer
---@return string
function Context:text_after_cursor(chars)
  return self.line:sub(self.col + 1, chars and (self.col + chars) or nil)
end

---@param text                          string
---@return boolean
function Context:is_after_cursor(text)
  return self.line:sub(self.col + 1, self.col + #text) == text
end

---@param text                          string
---@return boolean
function Context:is_before_cursor(text)
  return self.line:sub(self.col - #text + 1, self.col) == text
end

--- Whether a capture of the `pairs_<query>` treesitter query named `<capture>.inside`, `.after` or `.inside_or_after`
--- holds the cursor, ends at the last non-blank character before it, or either; never without a parser.
---@param query_name                    string
---@param capture_name                  string
---@return boolean
function Context:captures(query_name, capture_name)
  local parser = self.parser
  if not parser then
    return false
  end
  local row, col = self.row - 1, self.col ---@type integer, integer
  local matches = false ---@type boolean
  parser:for_each_tree(function(tree, ltree)
    if matches then
      return
    end
    local root = tree:root()
    local first_row, _, last_row = root:range()
    if first_row > row or last_row < row then
      return
    end
    local query = vim.treesitter.query.get(ltree:lang(), "pairs_" .. query_name)
    if not query then
      return
    end
    for id, node in query:iter_captures(root, self.bufnr, row, row + 1) do
      local capture = query.captures[id] ---@type string
      local _, _, end_row, end_col = node:range()
      local inside = vim.treesitter.is_in_node_range(node, row, col)
      local after = end_row == row and end_col == self.prev_non_ws_col
      if
        (capture == capture_name .. ".inside" and inside)
        or (capture == capture_name .. ".inside_or_after" and (inside or after))
        or (capture == capture_name .. ".after" and after)
      then
        matches = true
        return
      end
    end
  end)
  return matches
end

---@class era.keystroke.pairs.context
local M = {}

--- The context of the key being typed, in Insert mode or on the command line.
---@return era.keystroke.pairs.Context
function M.new()
  local mode = vim.api.nvim_get_mode().mode ---@type string
  local cmdline = mode == "c" ---@type boolean
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local ctx = {
    mode = mode,
    cmdline = cmdline,
    bufnr = bufnr,
    filetype = cmdline and "vim" or vim.api.nvim_get_option_value("filetype", { buf = bufnr }),
  }
  if cmdline then
    ctx.row, ctx.col, ctx.line = 1, vim.fn.getcmdpos() - 1, vim.fn.getcmdline()
  else
    local cursor = vim.api.nvim_win_get_cursor(0) ---@type integer[]
    ctx.row, ctx.col, ctx.line = cursor[1], cursor[2], vim.api.nvim_get_current_line()
  end
  return setmetatable(ctx, metatable)
end

return M
