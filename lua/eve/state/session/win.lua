local __module_name__ = "eve.state.session.win"

local setting = require("eve.constant.setting")
local editor = require("eve.module.editor")
local state_status = require("eve.state.session.status")

---@class eve.t.state.win.meta.data
---@field public winnr                  integer
---@field public filepath_history       eve.collection.history.ISerializedData

---@class eve.t.state.win.meta.state
---@field public filepath_history       eve.collection.IAdvanceHistory
---@field public lsp_symbols            eve.t.state.buf.lsp.ISymbol[]
---@field public winline                fml.ux.INvimbar|nil
---@field public winline_bufnr          integer

---@class eve.state.win.data
---@field public list                   eve.t.state.win.meta.data[]

---@class eve.state.win.state
---@field public __meta_map__           table<integer, eve.t.state.win.meta.state>
---@field public get                    fun(winnr: integer|nil): eve.t.state.win.meta.state|nil
---@field public set                    fun(winnr: integer|nil, meta: eve.t.state.win.meta.state): eve.t.state.win.meta.state|nil
---@field public del                    fun(winnr: integer|nil): nil
---@field public fork                   fun(winnr: integer|nil): eve.t.state.win.meta.state|nil
---@field public resolve                fun(winnr: integer|nil): eve.t.state.win.meta.state|nil
---@field public refresh                fun(winnr: integer|nil): nil
---@field public refresh_all            fun(): nil
---@field public refresh_tabpage_wins   fun(tabnr: integer|nil): nil
---
---@field public on_buf_enter           fun(winnr: integer, bufnr: integer): nil
---
---@field public locate_symbols         fun(winnr: integer|nil, callback: fun(err: string|false|nil): nil): nil
local S = {}

---@class eve.state.win
---@field public defaults               fun(): eve.state.win.data
---@field public dump                   fun(): eve.state.win.data
---@field public load                   fun(data: unknown): eve.state.win.state
---@field public normalize              fun(data: unknown): eve.state.win.data
local M = {}

---@type eve.state.win.state
S = {
  __meta_map__ = {}, ---@type table<integer, eve.t.state.win.meta.state>
  get = function(winnr)
    if winnr ~= nil and eve.std.nvim.is_win_valid(winnr) then
      return S.__meta_map__[winnr]
    end
  end,
  set = function(winnr, meta)
    if winnr ~= nil and eve.std.nvim.is_win_valid(winnr) then
      S.__meta_map__[winnr] = meta
      return meta
    end
  end,
  del = function(winnr)
    local meta = winnr ~= nil and S.__meta_map__[winnr] or nil ---@type eve.t.state.win.meta.state|nil
    if winnr ~= nil and meta ~= nil then
      S.__meta_map__[winnr] = nil
      meta.filepath_history:clear()
      if meta.winline ~= nil then
        meta.winline:dispose()
      end
    end
  end,
  fork = function(winnr)
    local meta = S.resolve(winnr) ---@type eve.t.state.win.meta.state|nil
    if meta ~= nil then
      ---@type eve.t.state.win.meta.state
      local meta_forked = {
        filepath_history = meta.filepath_history:fork({ name = "win_filepath" }),
        lsp_symbols = vim.list_slice(meta.lsp_symbols),
        winline = nil,
        winline_bufnr = meta.winline_bufnr,
      }
      return meta_forked
    end
  end,
  resolve = function(winnr)
    if winnr == nil or not eve.std.nvim.is_win_valid(winnr) or not editor.is_win_sourcefile(winnr) then
      return nil
    end

    local meta = S.__meta_map__[winnr] ---@type eve.t.state.win.meta.state|nil
    if meta ~= nil then
      return meta
    end

    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if not editor.is_buf_sourcefile(bufnr) then
      return nil
    end

    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local filepath_history = eve.col.AdvanceHistory.new({
      name = "win#bufs",
      capacity = setting.WIN_BUF_HISTORY_CAPACITY,
      validate = editor.is_valid_filepath,
    })
    filepath_history:push(filepath)

    ---@type eve.t.state.win.meta.state
    meta = {
      filepath_history = filepath_history,
      lsp_symbols = {},
      winline = nil,
      winline_bufnr = 0,
    }
    S.__meta_map__[winnr] = meta
    return meta
  end,
  refresh = function(winnr)
    if S.resolve(winnr) then
      state_status.load({}).dirty_winline_nr:next(winnr)
    end
  end,
  refresh_all = function()
    local winnrs = vim.api.nvim_list_wins() ---@type integer[]
    for _, winnr in ipairs(winnrs) do
      S.refresh(winnr)
    end

    local invalid_winnrs = {} ---@type integer[]
    for winnr in pairs(S.__meta_map__) do
      if not vim.api.nvim_win_is_valid(winnr) then
        table.insert(invalid_winnrs, winnr)
      end
    end
    for _, winnr in ipairs(invalid_winnrs) do
      S.del(winnr)
    end
  end,
  refresh_tabpage_wins = function(tabnr)
    if tabnr ~= nil and vim.api.nvim_tabpage_is_valid(tabnr) then
      local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
      for _, winnr in ipairs(winnrs) do
        S.refresh(winnr)
      end
    end
  end,
  locate_symbols = function(winnr, callback)
    if winnr == nil or not eve.std.nvim.is_win_valid(winnr) then
      callback(false)
      return
    end

    ---! Make the request to the LSP server
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if
      vim.b[bufnr][setting.vars.WINLINE_DISABLED] or not eve.lsp.has_support_method(bufnr, "textDocument/documentSymbol")
    then
      callback(false)
      return
    end

    local ok, cmp = pcall(require, "cmp")
    ---@diagnostic disable-next-line: undefined-field
    if ok and cmp.visible() then
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
      if not vim.api.nvim_win_is_valid(winnr) then
        safe_callback(false)
        return
      end

      if err then
        if type(err) == "table" then
          if err.message == "Content modified." then
            safe_callback(false)
            return
          end

          if err.message == "trying to get AST for non-added document" then
            if vim.api.nvim_buf_is_valid(bufnr) then
              vim.b[bufnr][setting.vars.WINLINE_DISABLED] = true
            end
          end
        end
        if state_status.load({}).suppress_warning:snapshot() then
          safe_callback(false)
          return
        end

        eve.reporter.error({
          from = __module_name__,
          subject = "locate_symbols",
          message = "Failed to request document symbols",
          details = { err = err, result = symbols, bufnr = bufnr, winnr = winnr },
        })
        safe_callback(err.message or "Failed to request document symbols")
        return
      end

      local meta = S.resolve(winnr) ---@type eve.t.state.win.meta.state|nil
      if meta == nil or type(symbols) ~= "table" then
        safe_callback(false)
        return
      end

      local cursor_pos = { line = row - 1, character = col }
      local symbol_path = eve.lsp.find_symbol_path(cursor_pos, symbols)

      local pieces = meta.lsp_symbols ---@type eve.t.state.buf.lsp.ISymbol[]
      local N = #pieces ---@type integer
      local k = 0 ---@type integer
      if symbol_path then
        for _, symbol in ipairs(symbol_path) do
          local kind = vim.lsp.protocol.SymbolKind[symbol.kind]
          local name = symbol.name
          local position = symbol.range and symbol.range.start or symbol.location.range.start
          ---@type eve.t.state.buf.lsp.ISymbol
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
  end,
  on_buf_enter = function(winnr, bufnr)
    if not eve.std.nvim.is_buf_valid(bufnr) or not editor.is_buf_sourcefile(bufnr) then
      return
    end

    if not eve.std.nvim.is_win_valid(winnr) or not editor.is_win_sourcefile(winnr) then
      return
    end

    local meta = S.get(winnr) ---@type eve.t.state.win.meta.state|nil
    if meta ~= nil then
      local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
      meta.filepath_history:push(filepath)
    end
  end,
}

---@return eve.state.win.data
function M.defaults()
  ---@type eve.state.win.data
  return {
    list = {},
  }
end

---@param data                        any
---@return eve.state.win.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.win.data

  ---@diagnostic disable-next-line: empty-block
  if type(data) == "table" then
    --- handle data
  end

  ---@type eve.state.win.data
  return resolved
end

---@return eve.state.win.data
function M.dump()
  ---@type eve.state.win.data
  return {
    list = {},
  }
end

---@param raw_data                      any
---@return eve.state.win.state
function M.load(raw_data)
  ---@diagnostic disable-next-line: unused-local
  local data = M.normalize(raw_data) ---@type eve.state.win.data
  return S
end

return M
