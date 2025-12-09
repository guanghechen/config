local __module_name__ = "eve.builtin.win"

local Methods = vim.lsp.protocol.Methods

---@alias eve.builtin.win.TypeEnum
---| "ux:board"
---| "ux:cmdline"
---| "ux:input"
---| "ux:picker-finder"
---| "ux:picker-preview"
---| "ux:picker-result"
---| "ux:notify"
---| "ux:popupmenu"
---| "ux:search-input"
---| "ux:search-main"
---| "ux:search-preview"
---| "ux:select"
---| "ux:terminal"
---| "ux:textarea"
---| "ux:winpicker"
---| "ux:winsep"
---
---| "plugin:neotree"

---@class eve.builtin.win.IFilepathHistoryItem
---@field public bufnr                  integer|nil
---@field public filepath               string|nil

---@class eve.builtin.win.IWinline
---@field public bufnr                  integer
---@field public locate_cancel          (fun(): nil)|nil
---@field public locate_scheduler       std.collection.Scheduler|nil
---@field public lsp_symbols            std.t.ILspSymbol[]|nil
---@field public nvimbar                ux.nvimbar.Nvimbar

---@class eve.builtin.win.IMeta
---@field public history                std.collection.IHistory|nil
---@field public winline                eve.builtin.win.IWinline|nil
---@field public wintype                eve.builtin.win.TypeEnum|nil

---@class eve.builtin.win.Types
local Types = {
  -- stylua: ignore start
  BOARD             = "ux:board",
  CMDLINE           = "ux:cmdline",
  INPUT             = "ux:input",
  NOTIFY            = "ux:notify",
  PICKER_FINDER     = "ux:picker-finder",
  PICKER_PREVIEW    = "ux:picker-preview",
  PICKER_RESULT     = "ux:picker-result",
  POPUPMENU         = "ux:popupmenu",
  SEARCHER_FINDER   = "ux:searcher-finder",
  SEARCHER_PREVIEW  = "ux:searcher-preview",
  SEARCHER_RESULT   = "ux:searcher-result",
  SELECT            = "ux:select",
  TERMINAL          = "ux:terminal",
  TEXTAREA          = "ux:textarea",
  WINPICKER         = "ux:winpicker",
  WINSEP            = "ux:winsep",

  NEOTREE           = "plugin:neotree",
  -- stylua: ignore end
}

local wintype_attrs = {
  focusable = {
    [Types.BOARD] = true,
    [Types.INPUT] = true,
    [Types.NOTIFY] = true,
    [Types.PICKER_FINDER] = true,
    [Types.PICKER_PREVIEW] = true,
    [Types.PICKER_RESULT] = true,
    [Types.POPUPMENU] = true,
    [Types.SEARCHER_FINDER] = true,
    [Types.SEARCHER_PREVIEW] = true,
    [Types.SEARCHER_RESULT] = true,
    [Types.SELECT] = true,
    [Types.TERMINAL] = true,
    [Types.TEXTAREA] = true,

    [Types.NEOTREE] = true,
  },
  projectable = {},
  sourcefile = {},
  swappable = {},
}

local meta_map = {} ---@type table<integer, eve.builtin.win.IMeta|nil>

---@param encoding                      string|nil
---@return string
local function normalize_encoding(encoding)
  if type(encoding) == "string" and encoding ~= "" then
    return string.lower(encoding)
  end
  return "utf-16"
end

---@param bufnr                         integer
---@param row                           integer
---@param byte_col                      integer
---@param encoding                      string|nil
---@return integer
local function byte_col_to_client_character(bufnr, row, byte_col, encoding)
  local normalized = normalize_encoding(encoding)
  if normalized == "utf-8" then
    return byte_col
  end

  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  if line == nil then
    return byte_col
  end

  local use_utf16 = normalized == "utf-16"
  local ok, character = pcall(vim.str_utfindex, line, byte_col, use_utf16)
  if ok and type(character) == "number" then
    return character
  end

  if normalized == "utf-32" then
    local fallback_ok, fallback_character = pcall(vim.str_utfindex, line, byte_col)
    if fallback_ok and type(fallback_character) == "number" then
      return fallback_character
    end
  end

  return byte_col
end

---@param bufnr                         integer
---@param position                      lsp.Position
---@param encoding                      string|nil
---@return integer
local function position_to_byte_col(bufnr, position, encoding)
  local normalized = normalize_encoding(encoding)
  local ok, col = pcall(vim.lsp.util._get_line_byte_from_position, bufnr, position, normalized)
  if ok and type(col) == "number" then
    return col
  end
  return position.character or 0
end

---@class eve.builtin.win
local M = {}

M.Types = vim.deepcopy(Types)

---@param winnr                         integer|nil
---@return nil
function M.close(winnr)
  if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return
  end
  vim.api.nvim_win_close(winnr, true)
end

---@param tabnr                         integer
---@param filetype                      string
---@return integer|nil
function M.find_by_filetype(tabnr, filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.bo[bufnr].filetype == filetype then
      return winnr
    end
  end
  return nil
end

---@param tabnr                         integer
---@param filetype                      string|nil
---@return integer|nil
function M.find_fixed_by_filetype(tabnr, filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if (filetype == nil or vim.bo[bufnr].filetype == filetype) and M.is_fixed(winnr) then
      return winnr
    end
  end
  return nil
end

---@param tabnr                         integer
---@param filetype                      string
---@return integer|nil
function M.find_floating_by_filetype(tabnr, filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if vim.bo[bufnr].filetype == filetype and M.is_float(winnr) then
      return winnr
    end
  end
  return nil
end

---@param filetype                      string|nil
---@return integer|nil
function M.find_sourcefile_by_filetype(tabnr, filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    if (filetype == nil or vim.bo[bufnr].filetype == filetype) and M.is_sourcefile(winnr) then
      return winnr
    end
  end
  return nil
end

----------------------------------------------------------------------------------------------------

---@param winnr                         integer
---@return boolean
function M.is_fixed(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config == nil or config.relative == ""
end

---@param winnr                         integer
---@return boolean
function M.is_float(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config.relative ~= nil and config.relative ~= ""
end

---@param winnr                         integer
---@return boolean
function M.is_focusable(winnr)
  local meta = M.resolve(winnr, false) ---@type eve.builtin.win.IMeta|nil
  if meta == nil then
    return false
  end

  if meta.wintype ~= nil then
    return wintype_attrs.focusable[meta.wintype] == true
  end

  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config.focusable == true
end

---@param winnr                         integer
---@return boolean
function M.is_projectable(winnr)
  local meta = M.resolve(winnr, false) ---@type eve.builtin.win.IMeta|nil
  if meta == nil then
    return false
  end

  if meta.wintype ~= nil then
    return wintype_attrs.projectable[meta.wintype] == true
  end

  if vim.wo[winnr].winfixbuf or M.is_float(winnr) then
    return false
  end

  return true
end

---@param winnr                         integer
---@return boolean
function M.is_sourcefile(winnr)
  local meta = M.resolve(winnr, false) ---@type eve.builtin.win.IMeta|nil
  if meta == nil then
    return false
  end

  if meta.wintype ~= nil then
    return wintype_attrs.sourcefile[meta.wintype] == true
  end

  if vim.wo[winnr].winfixbuf or M.is_float(winnr) then
    return false
  end

  return true
end

---@param winnr                         integer
---@return boolean
function M.is_swappable(winnr)
  local meta = M.resolve(winnr, false) ---@type eve.builtin.win.IMeta|nil
  if meta == nil then
    return false
  end

  if meta.wintype ~= nil then
    return wintype_attrs.swappable[meta.wintype] == true
  end

  if M.is_float(winnr) then
    return false
  end

  return true
end

---@param winnr                         integer
---@return boolean
function M.is_valid(winnr)
  return winnr > 0 and vim.api.nvim_win_is_valid(winnr)
end

---@param winnr                         integer|nil
---@return integer
function M.resolve_zindex(winnr)
  winnr = winnr or vim.api.nvim_get_current_win()
  local wincfg = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  local base_zindex = wincfg.zindex or 50 ---@type integer
  local meta = M.resolve(winnr, false) ---@type eve.builtin.win.IMeta|nil
  local wintype = meta and meta.wintype or nil ---@type eve.builtin.win.TypeEnum|nil
  if wintype == Types.CMDLINE or wintype == Types.NOTIFY then
    return base_zindex - 1
  end
  return base_zindex + 1
end

----------------------------------------------------------------------------------------------------

---@param winnr_candidate               integer|nil
---@return integer|nil
function M.pick_focusable(winnr_candidate)
  return eve.winpicker.pick_window(M.is_focusable, winnr_candidate, false) ---@type integer|nil
end

---@param winnr_candidate               integer|nil
---@return integer|nil
function M.pick_projectable(winnr_candidate)
  return eve.winpicker.pick_window(M.is_projectable, winnr_candidate, false) ---@type integer|nil
end

---@param winnr_candidate               integer|nil
---@return integer|nil
function M.pick_sourcefile(winnr_candidate)
  if winnr_candidate ~= nil and M.is_valid(winnr_candidate) and M.is_sourcefile(winnr_candidate) then
    return winnr_candidate
  end
  return eve.winpicker.pick_window(M.is_sourcefile, winnr_candidate, true) ---@type integer|nil
end

---@param winnr_candidate               integer|nil
---@return integer|nil
function M.pick_swappable(winnr_candidate)
  return eve.winpicker.pick_window(M.is_swappable, winnr_candidate, false) ---@type integer|nil
end

----------------------------------------------------------------------------------------------------

---@param winnr_source                  integer
---@param winnr_target                  integer
---@return eve.builtin.win.IMeta|nil
function M.fork(winnr_source, winnr_target)
  if
    winnr_source < 1
    or winnr_target < 1
    or not vim.api.nvim_win_is_valid(winnr_source)
    or not vim.api.nvim_win_is_valid(winnr_target)
  then
    return nil
  end

  local meta_source = M.resolve(winnr_source, false) ---@type eve.builtin.win.IMeta|nil
  if meta_source == nil then
    return nil
  end

  local meta_target = meta_map[winnr_target] or {} ---@type eve.builtin.win.IMeta
  meta_map[winnr_target] = meta_target

  if meta_source.wintype ~= nil then
    M.set_type(winnr_target, meta_source.wintype)
  end

  if meta_source.history ~= nil then
    if meta_target.history ~= nil then
      meta_target.history:clear()
    end
    local history_forked = meta_source.history:fork({ name = "win_filepath" }) ---@type std.collection.IHistory
    meta_target.history = history_forked
  end

  return meta_target
end

---@param winnr                         integer|nil
---@param force                         boolean
---@return eve.builtin.win.IMeta|nil
function M.resolve(winnr, force)
  if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return nil
  end

  local meta = meta_map[winnr] ---@type eve.builtin.win.IMeta|nil
  if meta ~= nil and not force then
    return meta
  end

  meta = meta or {} ---@type eve.builtin.win.IMeta
  meta_map[winnr] = meta

  meta.wintype = vim.w[winnr].eve_type ---@type eve.builtin.win.TypeEnum|nil
  if meta.wintype ~= nil or M.is_float(winnr) then
    return meta
  end

  if meta.history == nil then
    meta.history = std.History.new({
      name = "win#bufs",
      capacity = dot.var.WIN_BUF_HISTORY_CAPACITY,
      ---@param x                       eve.builtin.win.IFilepathHistoryItem
      ---@param y                       eve.builtin.win.IFilepathHistoryItem
      equals = function(x, y)
        return x == y or (x.bufnr == y.bufnr and x.filepath == y.filepath)
      end,
    })
  end
  return meta
end

---@param winnr                         integer
---@param wintype                       eve.builtin.win.TypeEnum|nil
---@return nil
function M.set_type(winnr, wintype)
  vim.w[winnr].eve_type = wintype
  vim.schedule(function()
    local meta = M.resolve(winnr, false) ---@type eve.builtin.win.IMeta|nil
    if meta ~= nil then
      meta.wintype = wintype
    end
  end)
end

----------------------------------------------------------------------------------------------------

---@param winnr                         integer|nil
---@param callback                      fun(ok: boolean, symbols: std.t.ILspSymbol[]|nil): nil
---@return fun(): nil
function M.locate_symbols(winnr, callback)
  local cancel_lsp = std.fn.noop ---@type fun(): nil
  local settled = false ---@type boolean

  local function settle(ok, symbols)
    if settled then
      return
    end
    settled = true
    cancel_lsp = std.fn.noop
    callback(ok, symbols)
  end

  local function cancel_request()
    if settled then
      return
    end
    pcall(cancel_lsp)
    settle(false)
  end

  local function abort()
    settle(false)
    return cancel_request
  end

  if winnr == nil or not eve.win.is_valid(winnr) then
    return abort()
  end

  ---! Make the request to the LSP server
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local support_documentSymbol = vim.b[bufnr].support_documentSymbol or 0 ---@type integer
  if vim.b[bufnr][dot.var.N_WINLINE_DISABLED] or support_documentSymbol < 1 then
    return abort()
  end

  local cmp = package.loaded["blink.cmp"]
  if type(cmp) == "table" and type(cmp.is_visible) == "function" then
    local ok, visible = pcall(cmp.is_visible)
    if ok and visible then
      return abort()
    end
  end

  local textDocument = vim.lsp.util.make_text_document_params(bufnr) ---@type lsp.TextDocumentIdentifier

  -- Handle the lsp request response.
  ---@param err                         any|nil
  ---@param symbols                     any[]
  ---@param ctx                         lsp.HandlerContext|nil
  ---@return nil
  local function handler(err, symbols, ctx)
    if settled then
      return
    end

    if not vim.api.nvim_win_is_valid(winnr) then
      settle(false)
      return
    end

    if err then
      if type(err) == "table" then
        if err.message == "Content modified." then
          settle(false)
          return
        end

        if err.message == "trying to get AST for non-added document" then
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.b[bufnr][dot.var.N_WINLINE_DISABLED] = true
          end
          settle(false)
          return
        end
      end

      if std.status.suppress_warning:snapshot() then
        settle(false)
        return
      end

      std.reporter.error({
        from = __module_name__,
        subject = "locate_symbols",
        message = "Failed to request document symbols",
        details = {
          err = err,
          result = symbols,
          bufnr = bufnr,
          winnr = winnr,
          textDocument = textDocument,
        },
      })
      settle(false)
      return
    end

    local encoding ---@type string|nil
    if ctx ~= nil and ctx.client_id ~= nil then
      local client = vim.lsp.get_client_by_id(ctx.client_id) ---@type vim.lsp.Client|nil
      if client ~= nil then
        encoding = client.offset_encoding
      end
    end

    local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(winnr)) ---@type integer, integer
    local cursor_line = cursor_row - 1 ---@type integer
    local cursor_character = byte_col_to_client_character(bufnr, cursor_line, cursor_col, encoding) ---@type integer
    local cursor_pos = { line = cursor_line, character = cursor_character }
    local symbol_path = eve.lsp.find_symbol_path(cursor_pos, symbols)
    local lsp_symbols = {} ---@type std.t.ILspSymbol[]

    local k = 1 ---@type integer
    if symbol_path then
      for _, symbol in ipairs(symbol_path) do
        local kind = vim.lsp.protocol.SymbolKind[symbol.kind]
        local name = symbol.name
        local location = symbol.location
        local range = symbol.range or (location and location.range) ---@type lsp.Range|nil
        local pos = range and range.start or nil ---@type lsp.Position|nil
        if pos ~= nil then
          local byte_col = position_to_byte_col(bufnr, pos, encoding) ---@type integer
          ---@type std.t.ILspSymbol
          local lsp_symbol = {
            kind = kind,
            name = name,
            row = pos.line + 1,
            col = byte_col + 1,
          }

          lsp_symbols[k] = lsp_symbol
          k = k + 1
        end
      end
    end
    settle(true, lsp_symbols)
  end

  ---! Make the request to the LSP server
  local requests
  requests, cancel_lsp = vim.lsp.buf_request(bufnr, Methods.textDocument_documentSymbol, { textDocument = textDocument }, handler)
  cancel_lsp = cancel_lsp or std.fn.noop
  if requests == nil or next(requests) == nil then
    return abort()
  end

  return cancel_request
end

---@param winnr_source                  integer|nil
---@param filepath                      string
---@param lnum                          ?integer
---@param col                           ?integer
---@return boolean
function M.open_filepath(winnr_source, filepath, lnum, col)
  local bufnr = eve.buf.loadfile(filepath) ---@type integer|nil
  if bufnr == nil then
    return false
  end

  local winnr = M.pick_sourcefile(winnr_source) ---@type integer|nil
  if winnr == nil then
    return false
  end

  vim.api.nvim_win_set_buf(winnr, bufnr)
  vim.api.nvim_exec_autocmds("BufRead", { buffer = bufnr, modeline = false })
  vim.schedule(function()
    vim.cmd("stopinsert")

    if lnum ~= nil and col ~= nil and vim.api.nvim_win_is_valid(winnr) then
      pcall(vim.api.nvim_win_set_cursor, winnr, { lnum, col })
    end
  end)
  return true
end

---@param winnr_source                  integer|nil
---@param filepaths                     string[]
---@param lnum                          ?integer
---@param col                           ?integer
---@return nil
function M.open_filepaths(winnr_source, filepaths, lnum, col)
  if #filepaths < 1 then
    return
  end

  ---@type integer|nil
  local winnr = (
    winnr_source ~= nil
    and winnr_source > 0
    and vim.api.nvim_win_is_valid(winnr_source)
    and M.is_sourcefile(winnr_source)
  )
      and winnr_source
    or eve.winpicker.pick_window(M.is_sourcefile, winnr_source, true)

  if winnr == nil then
    return
  end

  local tabnr = vim.api.nvim_win_get_tabpage(winnr) ---@type integer
  local last_bufnr ---@type integer|nil
  for _, filepath in ipairs(filepaths) do
    local bufnr = eve.buf.loadfile(filepath) ---@type integer|nil
    if bufnr ~= nil then
      last_bufnr = bufnr
      M.on_buf_enter(winnr, bufnr)
      eve.tab.on_buf_enter(tabnr, bufnr)
    end
  end

  if last_bufnr then
    vim.api.nvim_win_set_buf(winnr, last_bufnr)
    vim.api.nvim_exec_autocmds("BufRead", { buffer = last_bufnr, modeline = false })
  end

  vim.schedule(function()
    vim.cmd("stopinsert")

    if lnum ~= nil and col ~= nil and vim.api.nvim_win_is_valid(winnr) then
      pcall(vim.api.nvim_win_set_cursor, winnr, { lnum, col })
    end
  end)
end

----------------------------------------------------------------------------------------------------

---@param winnr                         integer|nil
---@return nil
function M.on_close(winnr)
  if winnr == nil then
    return
  end

  local meta = meta_map[winnr] ---@type eve.builtin.win.IMeta|nil
  if meta == nil then
    return
  end

  meta_map[winnr] = nil

  if meta.history ~= nil then
    meta.history:clear()
  end

  if meta.winline ~= nil then
    if meta.winline.locate_cancel ~= nil then
      pcall(meta.winline.locate_cancel)
      meta.winline.locate_cancel = nil
    end

    if meta.winline.nvimbar ~= nil then
      meta.winline.nvimbar:dispose()
    end

    if meta.winline.locate_scheduler ~= nil then
      meta.winline.locate_scheduler:dispose()
      meta.winline.locate_scheduler = nil
    end
  end
end

---@param winnr                         integer
---@param bufnr                         integer
---@return nil
function M.on_buf_enter(winnr, bufnr)
  local meta_win = M.resolve(winnr, false) ---@type eve.builtin.win.IMeta|nil
  if meta_win == nil or meta_win.history == nil then
    return
  end

  local meta_buf = eve.buf.resolve(bufnr, false) ---@type eve.builtin.buf.IMeta|nil
  if meta_buf == nil then
    return
  end

  if meta_win.winline ~= nil and meta_win.winline.lsp_symbols ~= nil then
    if meta_win.winline.bufnr ~= bufnr then
      meta_win.winline.bufnr = bufnr
      meta_win.winline.lsp_symbols = {}
    end
  end

  local filepath = meta_buf.filepath ---@type string
  local history = meta_win.history ---@type std.collection.IHistory
  local item = { bufnr = bufnr, filepath = filepath } ---@type eve.builtin.win.IFilepathHistoryItem
  history:push(item)
end

return M
