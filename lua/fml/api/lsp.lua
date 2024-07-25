local state = require("fml.api.state")
local lsp = require("fml.std.lsp")
local reporter = require("fml.std.reporter")

local locating = {} ---@type table<integer, boolean>
local dirty = {} ---@type table<integer, boolean>

--- Check if cursor is within range
---@param cursor                      fml.api.state.ILspSymbolPos
---@param range                       { start: fml.api.state.ILspSymbolPos, end: fml.api.state.ILspSymbolPos }
---@return boolean
local function is_within_range(cursor, range)
  local start = range.start ---@type fml.api.state.ILspSymbolPos
  local finish = range["end"] ---@type fml.api.state.ILspSymbolPos
  return (cursor.line > start.line or (cursor.line == start.line and cursor.character >= start.character))
    and (cursor.line < finish.line or (cursor.line == finish.line and cursor.character <= finish.character))
end

---! Find the symbol path recursively
---@param cursor                      fml.api.state.ILspSymbolPos
---@param symbols                     any[]
local function find_symbol_path(cursor, symbols)
  for _, symbol in ipairs(symbols) do
    if symbol.location then
      local range = symbol.location.range
      if is_within_range(cursor, range) then
        return { symbol }
      end
    elseif symbol.range then
      local range = symbol.range
      if is_within_range(cursor, range) then
        local path = { symbol }
        if symbol.children then
          local child_path = find_symbol_path(cursor, symbol.children)
          if child_path then
            for _, child_symbol in ipairs(child_path) do
              table.insert(path, child_symbol)
            end
          end
        end
        return path
      end
    end
  end
  return nil
end

---@param winnr                         integer
local function locate_symbols(winnr)
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local win_cursor = vim.api.nvim_win_get_cursor(winnr) ---@type integer[]
  local row = win_cursor[1] ---@type integer
  local col = win_cursor[2] ---@type integer

  -- Callback function to handle the response
  ---@param err                         any|nil
  ---@param symbols                     any[]
  ---@return nil
  local function handler(err, symbols)
    locating[winnr] = nil

    if err then
      reporter.error({
        from = "fml.api.lsp",
        subject = "locate_symbols",
        message = "Failed to request document symbols",
        details = { err = err, result = symbols, bufnr = bufnr, winnr = winnr },
      })
    else
      local win = state.wins[winnr] ---@type fml.api.state.IWinItem|nil
      if win ~= nil and type(symbols) == "table" then
        local pieces = win.lsp_symbols ---@type fml.api.state.ILspSymbol[]
        local N = #pieces ---@type integer
        local cursor_pos = { line = row - 1, character = col }
        local symbol_path = find_symbol_path(cursor_pos, symbols)

        local k = 0
        if symbol_path then
          for _, symbol in ipairs(symbol_path) do
            local kind = vim.lsp.protocol.SymbolKind[symbol.kind]
            local name = symbol.name
            local position = symbol.range and symbol.range.start or symbol.location.range.start
            ---@type fml.api.state.ILspSymbol
            local piece = {
              kind = kind,
              name = name,
              row = position.line + 1,
              col = position.character + 1,
            }

            k = k + 1
            pieces[k] = piece
          end
        end
        for i = k + 1, N, 1 do
          pieces[i] = nil
        end

        state.winline_dirty_ticker:tick()
      end
    end

    if dirty[winnr] then
      locate_symbols(winnr)
    end
  end

  ---! Make the request to the LSP server
  if lsp.has_support_method(bufnr, "textDocument/documentSymbol") then
    vim.lsp.buf_request(bufnr, "textDocument/documentSymbol", {
      textDocument = vim.lsp.util.make_text_document_params(),
    }, handler)
  end
end

---@class fml.api.lsp
local M = {}

---@param winnr                         integer
---@return nil
function M.locate_symbols(winnr)
  if locating[winnr] then
    dirty[winnr] = true
    return
  end

  dirty[winnr] = false
  pcall(locate_symbols, winnr)
end

return M
