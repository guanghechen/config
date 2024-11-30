local __module_name__ = "fml.fn.locate_symbols" ---@type string

local constant = require("eve.builtin.constant")
local reporter = require("eve.lib.reporter")
local state = require("eve.state")

local locating_set = {} ---@type table<integer, boolean>
local dirty_set = {} ---@type table<integer, boolean>

---@param winnr                         integer
---@param force                         ?boolean
local function locate_symbols(winnr, force)
  dirty_set[winnr] = dirty_set[winnr] or force
  if locating_set[winnr] or not dirty_set[winnr] then
    return
  end

  if not vim.api.nvim_win_is_valid(winnr) then
    dirty_set[winnr] = nil
    locating_set[winnr] = nil
    return
  end

  ---! Make the request to the LSP server
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  if
    vim.b[bufnr][constant.V_WINLINE_DISABLED]
    or not eve.lsp.has_support_method(bufnr, "textDocument/documentSymbol")
  then
    return
  end

  locating_set[winnr] = true
  dirty_set[winnr] = nil

  local cursor = vim.api.nvim_win_get_cursor(winnr) or { 1, 1 } ---@type integer[]
  local row = cursor[1] or 1 ---@type integer
  local col = cursor[2] or 1 ---@type integer

  -- Callback function to handle the response
  ---@param err                         any|nil
  ---@param symbols                     any[]
  ---@return nil
  local function handler(err, symbols)
    locating_set[winnr] = nil

    if err then
      if type(err) == "table" then
        if err.message == "trying to get AST for non-added document" then
          vim.b[bufnr][constant.V_WINLINE_DISABLED] = true
          return
        end
      end

      reporter.error({
        from = __module_name__,
        subject = "locate_symbols",
        message = "Failed to request document symbols",
        details = { err = err, result = symbols, bufnr = bufnr, winnr = winnr },
      })
      return
    end

    ---! Check if the window still valid.
    if not vim.api.nvim_win_is_valid(winnr) then
      return
    end

    local meta = eve.win.get_meta(winnr) ---@type eve.t.state.state.win.IMeta|nil
    if meta ~= nil and type(symbols) == "table" then
      local cursor_pos = { line = row - 1, character = col }
      local symbol_path = eve.lsp.find_symbol_path(cursor_pos, symbols)

      local pieces = meta.lsp_symbols ---@type eve.t.state.state.lsp.ISymbol[]
      local N = #pieces ---@type integer
      local k = 0 ---@type integer
      if symbol_path then
        for _, symbol in ipairs(symbol_path) do
          local kind = vim.lsp.protocol.SymbolKind[symbol.kind]
          local name = symbol.name
          local position = symbol.range and symbol.range.start or symbol.location.range.start
          ---@type eve.t.state.state.lsp.ISymbol
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
      state.state.status.winline_dirty_nr:next(winnr)
    end

    if dirty_set[winnr] then
      locate_symbols(winnr, false)
    end
  end

  ---! Make the request to the LSP server
  vim.lsp.buf_request(
    bufnr,
    "textDocument/documentSymbol",
    { textDocument = vim.lsp.util.make_text_document_params() },
    handler
  )
end

return locate_symbols
