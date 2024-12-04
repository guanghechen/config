local __module_name__ = "eve.builtin.win"

local fs = require("eve.lib.fs")
local path = require("eve.lib.path")
local reporter = require("eve.lib.reporter")
local AdvanceHistory = require("eve.lib.collection.history_advance")
local checks = require("eve.builtin.checks")
local constant = require("eve.builtin.constant")
local lsp = require("eve.builtin.lsp")
local status = require("eve.builtin.status")

local meta_map = {} ---@type table<integer, eve.t.state.state.win.IMeta>

---@class eve.builtin.win
local M = {}

---@param winnr                         integer|nil
---@return eve.t.state.state.win.IMeta|nil
function M.get_meta(winnr)
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    return meta_map[winnr]
  end
end

---@param winnr                         integer|nil
---@param meta                          eve.t.state.state.win.IMeta
---@return eve.t.state.state.win.IMeta|nil
function M.set_meta(winnr, meta)
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    meta_map[winnr] = meta
    return meta
  end
end

---@param winnr                         integer|nil
---@return nil
function M.del_meta(winnr)
  if winnr == nil or meta_map[winnr] == nil then
    return
  end

  local meta = meta_map[winnr] ---@type eve.t.state.state.win.IMeta
  meta_map[winnr] = nil
  meta.filepath_history:clear()
  if meta.winline ~= nil then
    meta.winline:dispose()
  end
end

---@param winnr                         integer|nil
---@return eve.t.state.state.win.IMeta|nil
function M.fork_meta(winnr)
  local meta = M.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
  if meta ~= nil then
    ---@type eve.t.state.state.win.IMeta
    local meta_forked = {
      filepath_history = meta.filepath_history:fork({ name = "win_filepath" }),
      lsp_symbols = vim.list_slice(meta.lsp_symbols),
      winline = nil,
    }
    return meta_forked
  end
end

---@param winnr                         integer|nil
---@return eve.t.state.state.win.IMeta|nil
function M.resolve(winnr)
  if winnr == nil or not checks.is_win_valid(winnr) then
    return nil
  end

  local meta = M.get_meta(winnr) ---@type eve.t.state.state.win.IMeta|nil
  if meta ~= nil then
    return meta
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  if not checks.is_buf_valid(bufnr) then
    return nil
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filepath_history = AdvanceHistory.new({
    name = "win#bufs",
    capacity = constant.WIN_BUF_HISTORY_CAPACITY,
    validate = checks.is_valid_filepath,
  })
  filepath_history:push(filepath)

  ---@type eve.t.state.state.win.IMeta
  meta = {
    filepath_history = filepath_history,
    lsp_symbols = {},
    winline = nil,
  }
  M.set_meta(winnr, meta)
  return meta
end

---@param winnr                         integer|nil
---@return nil
function M.refresh(winnr)
  if winnr == nil then
    return
  end

  local meta = M.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
  if meta ~= nil then
    status.winline_dirty_nr:next(winnr)
  end
end

---@return nil
function M.refresh_all()
  local winnrs = vim.api.nvim_list_wins() ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    M.refresh(winnr)
  end

  local invalid_winnrs = {} ---@type integer[]
  for winnr in pairs(meta_map) do
    if not vim.api.nvim_win_is_valid(winnr) then
      table.insert(invalid_winnrs, winnr)
    end
  end
  for _, winnr in ipairs(invalid_winnrs) do
    M.del_meta(winnr)
  end
end

---@param tabnr                         integer
---@return nil
function M.refresh_tabpage_wins(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    M.refresh(winnr)
  end
end

---@param bufnr                         integer
---@return nil
function M.on_buf_enter(bufnr)
  if bufnr == nil or not checks.is_buf_valid(bufnr) then
    return
  end

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local meta = M.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
  if meta == nil then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  meta.filepath_history:push(filepath)
end

----------------------------------------------------------------------------------------------------

---@class eve.builtin.win.IDetails
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public filepath               string|nil
---@field public dirpath                string|nil

---@param winnr                         integer|nil
---@return eve.builtin.win.IDetails|nil
function M.get_details(winnr)
  if winnr == nil or not checks.is_win_valid(winnr) then
    return nil
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filetype = fs.is_file_or_dir(filepath) ---@type eve.e.FileType|nil
  if filetype == "file" or filetype == "directory" then
    local dirpath = filetype == "file" and path.dirname(filepath) or filepath ---@type string
    dirpath = path.normalize(dirpath)
    return { winnr = winnr, bufnr = bufnr, filepath = filepath, dirpath = dirpath }
  end
  return { winnr = winnr, bufnr = bufnr }
end

---@param winnr                         integer
---@param callback                      function(err: string|false|nil): nil
---@return nil
function M.locate_symbols(winnr, callback)
  if winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    callback(false)
    return
  end

  ---! Make the request to the LSP server
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  if vim.b[bufnr][constant.V_WINLINE_DISABLED] or not lsp.has_support_method(bufnr, "textDocument/documentSymbol") then
    callback(false)
    return
  end

  local callback_called = false ---@type boolean

  ---@param err                         string|false|nil
  ---@return nil
  local function safe_callback(err)
    if not callback_called then
      callback_called = true
      callback(err)
      return
    end
  end

  local cursor = vim.api.nvim_win_get_cursor(winnr) or { 1, 1 } ---@type integer[]
  local row = cursor[1] or 1 ---@type integer
  local col = cursor[2] or 1 ---@type integer

  -- Handle the lsp request response.
  ---@param err                         any|nil
  ---@param symbols                     any[]
  ---@return nil
  local function handler(err, symbols)
    if winnr < 1 or not vim.api.nvim_win_is_valid(winnr) or callback_called then
      return
    end

    if err then
      if type(err) == "table" and err.message == "trying to get AST for non-added document" then
        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.b[bufnr][constant.V_WINLINE_DISABLED] = true
        end
      end

      reporter.error({
        from = __module_name__,
        subject = "locate_symbols",
        message = "Failed to request document symbols",
        details = { err = err, result = symbols, bufnr = bufnr, winnr = winnr },
      })
      safe_callback("Failed to request document symbols")
      return
    end

    local meta = M.resolve(winnr) ---@type eve.t.state.state.win.IMeta|nil
    if meta ~= nil and type(symbols) == "table" then
      local cursor_pos = { line = row - 1, character = col }
      local symbol_path = lsp.find_symbol_path(cursor_pos, symbols)

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
    end
    safe_callback()
  end

  vim.defer_fn(function()
    safe_callback("Request document symbols timeout")
  end, 10000)

  ---! Make the request to the LSP server
  vim.lsp.buf_request(
    bufnr,
    "textDocument/documentSymbol",
    { textDocument = vim.lsp.util.make_text_document_params() },
    handler
  )
end

return M
