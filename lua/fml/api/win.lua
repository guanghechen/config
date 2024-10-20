local locating_set = {} ---@type table<integer, boolean>
local dirty_set = {} ---@type table<integer, boolean>

---@class fml.api.win
local M = {}

---@type fun(direction: "p"|"n"|"h"|"j"|"k"|"l"): nil
M.navigate = vim.env.TMUX and require("fml.api.internal.navigate_tmux") or require("fml.api.internal.navigate_vim")

---@param winnr                         integer
---@return t.eve.context.state.win.IItem|nil
function M.get(winnr)
  if eve.context.state.wins[winnr] == nil then
    M.refresh(winnr)
  end

  local win = eve.context.state.wins[winnr] ---@type t.eve.context.state.win.IItem|nil
  if win == nil then
    eve.reporter.error({
      from = "fml.api.win",
      subject = "get_win",
      message = "Cannot find win from the state",
      details = { winnr = winnr },
    })
  end
  return win
end

---@param winnr                         integer
---@param force                         ?boolean
function M.locate_symbols(winnr, force)
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
  if not eve.lsp.has_support_method(bufnr, "textDocument/documentSymbol") then
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
      eve.reporter.error({
        from = "fml.api.lsp",
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

    local win = eve.context.state.wins[winnr] ---@type t.eve.context.state.win.IItem|nil
    if win ~= nil and type(symbols) == "table" then
      local cursor_pos = { line = row - 1, character = col }
      local symbol_path = eve.lsp.find_symbol_path(cursor_pos, symbols)

      local pieces = win.lsp_symbols ---@type t.eve.context.state.lsp.ISymbol[]
      local N = #pieces ---@type integer
      local k = 0 ---@type integer
      if symbol_path then
        for _, symbol in ipairs(symbol_path) do
          local kind = vim.lsp.protocol.SymbolKind[symbol.kind]
          local name = symbol.name
          local position = symbol.range and symbol.range.start or symbol.location.range.start
          ---@type t.eve.context.state.lsp.ISymbol
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
      eve.context.state.winline_dirty_nr:next(winnr)
    end

    if dirty_set[winnr] then
      M.locate_symbols(winnr, false)
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

---@param winnr                         integer|nil
---@return t.eve.context.state.win.IItem|nil
function M.refresh(winnr)
  if winnr == nil or type(winnr) ~= "number" then
    return
  end

  if not eve.win.is_valid(winnr) then
    eve.context.state.wins[winnr] = nil
    return
  end

  local win = eve.context.state.wins[winnr] ---@type t.eve.context.state.win.IItem|nil
  if win == nil then
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local filepath_history = eve.c.AdvanceHistory.new({
      name = "win#bufs",
      capacity = eve.constants.WIN_BUF_HISTORY_CAPACITY,
      validate = eve.buf.is_valid_filepath,
    })
    filepath_history:push(filepath)

    ---@type t.eve.context.state.win.IItem
    win = { filepath_history = filepath_history, lsp_symbols = {} }
    eve.context.state.wins[winnr] = win
  end
  return win
end

---@return nil
function M.refresh_all()
  local winnrs = vim.api.nvim_list_wins() ---@type integer[]
  local wins = {} ---@type table<integer, t.eve.context.state.win.IItem>
  for _, winnr in ipairs(winnrs) do
    local win = M.refresh(winnr) ---@type t.eve.context.state.win.IItem|nil
    if win ~= nil then
      wins[winnr] = win
    end
  end
  eve.context.state.wins = wins
end

---@param tabnr                         integer
---@return nil
function M.refresh_tabpage_wins(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    M.refresh(winnr)
  end
end

---@type fun(): nil
M.schedule_refresh_all = eve.scheduler.schedule("fml.api.win.refresh_all", M.refresh_all, 16)

return M
