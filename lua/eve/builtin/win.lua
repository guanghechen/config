local __module_name__ = "eve.builtin.win"

local Methods = vim.lsp.protocol.Methods

---@alias eve.builtin.win.TypeEnum
---| "ux:board"
---| "ux:chatbox"
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
---@field public locate_scheduler       std.collection.Scheduler|nil
---@field public lsp_symbols            std.t.ILspSymbol[]|nil
---@field public nvimbar                eve.ux.nvimbar.Nvimbar

---@class eve.builtin.win.IMeta
---@field public history                std.collection.IHistory|nil
---@field public winline                eve.builtin.win.IWinline|nil
---@field public wintype                eve.builtin.win.TypeEnum|nil

---@class eve.builtin.win.Types
local Types = {
  -- stylua: ignore start
  BOARD             = "ux:board",
  CHATBOX           = "ux:chatbox",
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

---@param winnr                       integer
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

---@param winnr                       integer
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

---@param winnr                       integer
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
      capacity = eve.setting.WIN_BUF_HISTORY_CAPACITY,
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
---@return nil
function M.locate_symbols(winnr, callback)
  if winnr == nil or not eve.win.is_valid(winnr) then
    callback(false)
    return
  end

  ---! Make the request to the LSP server
  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local support_documentSymbol = vim.b[bufnr].support_documentSymbol or 0 ---@type integer
  if vim.b[bufnr][eve.var.Names.WINLINE_DISABLED] or support_documentSymbol < 1 then
    callback(false)
    return
  end

  local ok, cmp = pcall(require, "blink.cmp")
  if ok and cmp.is_visible() then
    callback(false)
    return
  end

  local row, col = unpack(vim.api.nvim_win_get_cursor(winnr)) ---@type integer, integer
  local textDocument = vim.lsp.util.make_text_document_params(bufnr) ---@type lsp.TextDocumentIdentifier

  -- Handle the lsp request response.
  ---@param err                         any|nil
  ---@param symbols                     any[]
  ---@return nil
  local function handler(err, symbols)
    if not vim.api.nvim_win_is_valid(winnr) then
      callback(false)
      return
    end

    if err then
      if type(err) == "table" then
        if err.message == "Content modified." then
          callback(false)
          return
        end

        if err.message == "trying to get AST for non-added document" then
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.b[bufnr][eve.var.Names.WINLINE_DISABLED] = true
          end
          callback(false)
          return
        end
      end

      if eve.status.suppress_warning:snapshot() then
        callback(false)
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
      callback(false)
      return
    end

    local cursor_pos = { line = row - 1, character = col }
    local symbol_path = eve.lsp.find_symbol_path(cursor_pos, symbols)
    local lsp_symbols = {} ---@type std.t.ILspSymbol[]

    local k = 1 ---@type integer
    if symbol_path then
      for _, symbol in ipairs(symbol_path) do
        local kind = vim.lsp.protocol.SymbolKind[symbol.kind]
        local name = symbol.name
        local pos = symbol.range and symbol.range.start or symbol.location.range.start
        ---@type std.t.ILspSymbol
        local lsp_symbol = {
          kind = kind,
          name = name,
          row = pos.line + 1,
          col = pos.character + 1,
        }

        lsp_symbols[k] = lsp_symbol
        k = k + 1
      end
    end
    callback(true, lsp_symbols)
  end

  ---! Make the request to the LSP server
  vim.lsp.buf_request(bufnr, Methods.textDocument_documentSymbol, { textDocument = textDocument }, handler)
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

  for _, filepath in ipairs(filepaths) do
    local bufnr = eve.buf.loadfile(filepath) ---@type integer|nil
    if bufnr ~= nil then
      vim.api.nvim_win_set_buf(winnr, bufnr)
    end
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
