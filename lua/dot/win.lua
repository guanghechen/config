---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.win" ---@type string

local vim_win = require("stl.nvim.win")

---@class dot.win.IFilepathHistoryItem
---@field public bufnr                  ?integer
---@field public filepath               ?string

---@class dot.win.IWinline
---@field public bufnr                  integer
---@field public locate_token           ?stl.c.CancellationToken
---@field public locate_scheduler       ?stl.c.Scheduler
---@field public lsp_symbols            ?dot.t.ILspSymbol[]
---@field public nvimbar                era.m.nvimbar.Nvimbar

---@class dot.win.IMeta
---@field public history                ?stl.c.History
---@field public winline                ?dot.win.IWinline
---@field public wintype                ?stl.nvim.win.TypeEnum

local wintype_attrs = {
  focusable = {
    [vim_win.Types.BOARD] = true,
    [vim_win.Types.EXPLORER] = true,
    [vim_win.Types.INPUT] = true,
    [vim_win.Types.NOTIFY] = true,
    [vim_win.Types.PICKER_FINDER] = true,
    [vim_win.Types.PICKER_PREVIEW] = true,
    [vim_win.Types.PICKER_RESULT] = true,
    [vim_win.Types.POPUPMENU] = true,
    [vim_win.Types.SEARCHER_FINDER] = true,
    [vim_win.Types.SEARCHER_PREVIEW] = true,
    [vim_win.Types.SEARCHER_RESULT] = true,
    [vim_win.Types.SELECT] = true,
    [vim_win.Types.TERMINAL] = true,
    [vim_win.Types.TEXTAREA] = true,
  },
  projectable = {},
  sourcefile = {},
  swappable = {},
}

local meta_map = {} ---@type table<integer, dot.win.IMeta|nil>

---@param encoding                      ?string
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
---@param encoding                      ?string
---@return integer
local function byte_col_to_client_character(bufnr, row, byte_col, encoding)
  local normalized = normalize_encoding(encoding)
  if normalized == "utf-8" then
    return byte_col
  end

  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] ---@type string|nil
  if line == nil then
    return byte_col
  end

  local ok, character = pcall(vim.str_utfindex, line, normalized, byte_col)
  if ok and type(character) == "number" then
    return character
  end

  return byte_col
end

---@param bufnr                         integer
---@param position                      lsp.Position
---@param encoding                      ?string
---@return integer
local function position_to_byte_col(bufnr, position, encoding)
  local normalized = normalize_encoding(encoding) ---@type string
  local ok, col = pcall(vim.lsp.util._get_line_byte_from_position, bufnr, position, normalized) ---@type boolean, integer
  if ok and type(col) == "number" then
    return col
  end
  return position.character or 0
end

---@class dot.win
local M = {}

----------------------------------------------------------------------------------------------------

---@param tabnr                         integer
---@param filetype                      ?string
---@return integer|nil
function M.find_fixed_by_filetype(tabnr, filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local c_filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
    if filetype == c_filetype and vim_win.is_fixed(winnr) then
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
    if vim.api.nvim_get_option_value("filetype", { buf = bufnr }) == filetype and vim_win.is_float(winnr) then
      return winnr
    end
  end
  return nil
end

---@param tabnr                         integer
---@param filetype                      ?string
---@return integer|nil
function M.find_sourcefile_by_filetype(tabnr, filetype)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in pairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local c_filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
    if c_filetype == filetype and M.is_sourcefile(winnr) then
      return winnr
    end
  end
  return nil
end

----------------------------------------------------------------------------------------------------

---@param winnr                         integer
---@return boolean
function M.is_focusable(winnr)
  local meta = M.resolve(winnr, false) ---@type dot.win.IMeta|nil
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
  local meta = M.resolve(winnr, false) ---@type dot.win.IMeta|nil
  if meta == nil then
    return false
  end

  if meta.wintype ~= nil then
    return wintype_attrs.projectable[meta.wintype] == true
  end

  if vim.api.nvim_get_option_value("winfixbuf", { win = winnr }) or vim_win.is_float(winnr) then
    return false
  end

  return true
end

---@param winnr                         integer
---@return boolean
function M.is_sourcefile(winnr)
  local meta = M.resolve(winnr, false) ---@type dot.win.IMeta|nil
  if meta == nil then
    return false
  end

  if meta.wintype ~= nil then
    return wintype_attrs.sourcefile[meta.wintype] == true
  end

  if vim.api.nvim_get_option_value("winfixbuf", { win = winnr }) or vim_win.is_float(winnr) then
    return false
  end

  return true
end

---@param winnr                         integer
---@return boolean
function M.is_swappable(winnr)
  local meta = M.resolve(winnr, false) ---@type dot.win.IMeta|nil
  if meta == nil then
    return false
  end

  if meta.wintype ~= nil then
    return wintype_attrs.swappable[meta.wintype] == true
  end

  if vim_win.is_float(winnr) then
    return false
  end

  return true
end

---@param winnr                         ?integer
---@return integer
function M.resolve_zindex(winnr)
  winnr = winnr or vim.api.nvim_get_current_win() ---@type integer
  local wincfg = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  local base_zindex = wincfg.zindex or 50 ---@type integer
  local meta = M.resolve(winnr, false) ---@type dot.win.IMeta|nil
  local wintype = meta and meta.wintype or nil ---@type stl.nvim.win.TypeEnum|nil
  if wintype == vim_win.Types.CMDLINE or wintype == vim_win.Types.NOTIFY then
    return base_zindex - 1
  end
  return base_zindex + 1
end

----------------------------------------------------------------------------------------------------

---@param winnr_candidate               ?integer
---@return integer|nil
function M.pick_focusable(winnr_candidate)
  return era.fn.pick_win(M.is_focusable, winnr_candidate, false)
end

---@param winnr_candidate               ?integer
---@return integer|nil
function M.pick_projectable(winnr_candidate)
  return era.fn.pick_win(M.is_projectable, winnr_candidate, false)
end

---@param winnr_candidate               ?integer
---@return integer|nil
function M.pick_sourcefile(winnr_candidate)
  if winnr_candidate ~= nil and vim_win.is_valid(winnr_candidate) and M.is_sourcefile(winnr_candidate) then
    return winnr_candidate
  end
  return era.fn.pick_win(M.is_sourcefile, winnr_candidate, true)
end

---@param winnr_candidate               ?integer
---@return integer|nil
function M.pick_swappable(winnr_candidate)
  return era.fn.pick_win(M.is_swappable, winnr_candidate, false)
end

----------------------------------------------------------------------------------------------------

---@param winnr_source                  integer
---@param winnr_target                  integer
---@return dot.win.IMeta|nil
function M.fork(winnr_source, winnr_target)
  if
    winnr_source < 1
    or winnr_target < 1
    or not vim.api.nvim_win_is_valid(winnr_source)
    or not vim.api.nvim_win_is_valid(winnr_target)
  then
    return nil
  end

  local meta_source = M.resolve(winnr_source, false) ---@type dot.win.IMeta|nil
  if meta_source == nil then
    return nil
  end

  local meta_target = meta_map[winnr_target] or {} ---@type dot.win.IMeta
  meta_map[winnr_target] = meta_target

  if meta_source.wintype ~= nil then
    M.set_type(winnr_target, meta_source.wintype)
  end

  if meta_source.history ~= nil then
    if meta_target.history ~= nil then
      meta_target.history:clear()
    end
    local history_forked = meta_source.history:fork({ name = "win_filepath" }) ---@type stl.c.History
    meta_target.history = history_forked
  end

  return meta_target
end

---@param winnr                         ?integer
---@param force                         boolean
---@return dot.win.IMeta|nil
function M.resolve(winnr, force)
  if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return nil
  end

  local meta = meta_map[winnr] ---@type dot.win.IMeta|nil
  if meta ~= nil and not force then
    return meta
  end

  meta = meta or {} ---@type dot.win.IMeta
  meta_map[winnr] = meta

  meta.wintype = vim.w[winnr].eve_type ---@type stl.nvim.win.TypeEnum|nil
  if meta.wintype ~= nil or vim_win.is_float(winnr) then
    return meta
  end

  if meta.history == nil then
    meta.history = stl.c.History.new({
      name = "win#bufs",
      capacity = dot.var.WIN_BUF_HISTORY_CAPACITY,
      ---@param x                       dot.win.IFilepathHistoryItem
      ---@param y                       dot.win.IFilepathHistoryItem
      equals = function(x, y)
        return x == y or (x.bufnr == y.bufnr and x.filepath == y.filepath)
      end,
    })
  end
  return meta
end

---@param winnr                         integer
---@param wintype                       ?stl.nvim.win.TypeEnum
---@return nil
function M.set_type(winnr, wintype)
  vim.w[winnr].eve_type = wintype
  vim.schedule(function()
    local meta = M.resolve(winnr, false) ---@type dot.win.IMeta|nil
    if meta ~= nil then
      meta.wintype = wintype
    end
  end)
end

----------------------------------------------------------------------------------------------------

---@param winnr                         ?integer
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with { ok: boolean, symbols: ?dot.t.ILspSymbol[] }
function M.locate_symbols(winnr, token)
  return stl.c.Future.new(function(resolve)
    local cancel_lsp = stl.fn.noop ---@type fun(): nil
    local settled = false ---@type boolean

    local function do_resolve(ok, symbols)
      if settled then
        return
      end
      settled = true
      cancel_lsp = stl.fn.noop
      resolve({ ok = ok, symbols = symbols })
    end

    if token and token:is_cancelled() then
      do_resolve(false, nil)
      return
    end

    if winnr == nil or not vim_win.is_valid(winnr) then
      do_resolve(false, nil)
      return
    end

    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local support_documentSymbol = vim.b[bufnr].support_documentSymbol or 0 ---@type integer
    if vim.b[bufnr][dot.var.N_WINLINE_DISABLED] or support_documentSymbol < 1 then
      do_resolve(false, nil)
      return
    end

    local cmp = package.loaded["blink.cmp"]
    if type(cmp) == "table" and type(cmp.is_visible) == "function" then
      local ok, visible = pcall(cmp.is_visible)
      if ok and visible then
        do_resolve(false, nil)
        return
      end
    end

    local textDocument = vim.lsp.util.make_text_document_params(bufnr) ---@type lsp.TextDocumentIdentifier

    ---@param err                         ?any
    ---@param symbols                     any[]
    ---@param ctx                         ?lsp.HandlerContext
    ---@return nil
    local function handler(err, symbols, ctx)
      if settled then
        return
      end

      if token and token:is_cancelled() then
        return
      end

      if not vim.api.nvim_win_is_valid(winnr) then
        do_resolve(false, nil)
        return
      end

      if err then
        if type(err) == "table" then
          if err.message == "Content modified." then
            do_resolve(false, nil)
            return
          end

          if err.message == "trying to get AST for non-added document" then
            if vim.api.nvim_buf_is_valid(bufnr) then
              vim.b[bufnr][dot.var.N_WINLINE_DISABLED] = true
            end
            do_resolve(false, nil)
            return
          end
        end

        if dot.state.status.suppress_warning:snapshot() then
          do_resolve(false, nil)
          return
        end

        stl.reporter.error({
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
        do_resolve(false, nil)
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
      local symbol_path = era.m.lsp.fn.find_symbol_path(cursor_pos, symbols)
      local lsp_symbols = {} ---@type dot.t.ILspSymbol[]

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
            ---@type dot.t.ILspSymbol
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
      do_resolve(true, lsp_symbols)
    end

    local requests
    requests, cancel_lsp =
      vim.lsp.buf_request(bufnr, "textDocument/documentSymbol", { textDocument = textDocument }, handler)
    cancel_lsp = cancel_lsp or stl.fn.noop
    if requests == nil or next(requests) == nil then
      do_resolve(false, nil)
      return
    end

    if token then
      token:on_cancel(function()
        pcall(cancel_lsp)
      end)
    end
  end)
end

---@param winnr_source                  ?integer
---@param filepath                      string
---@param lnum                          ?integer
---@param col                           ?integer
---@return boolean
function M.open_filepath(winnr_source, filepath, lnum, col)
  local bufnr = dot.buf.loadfile(filepath) ---@type integer|nil
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

---@param winnr_source                  ?integer
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
    or era.fn.pick_win(M.is_sourcefile, winnr_source, true)

  if winnr == nil then
    return
  end

  local tabnr = vim.api.nvim_win_get_tabpage(winnr) ---@type integer
  local last_bufnr ---@type integer|nil
  for _, fp in ipairs(filepaths) do
    local bufnr = dot.buf.loadfile(fp) ---@type integer|nil
    if bufnr ~= nil then
      last_bufnr = bufnr
      M.on_buf_enter(winnr, bufnr)
      dot.tab.on_buf_enter(tabnr, bufnr)
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

---@param winnr                         ?integer
---@return nil
function M.on_close(winnr)
  if winnr == nil then
    return
  end

  local meta = meta_map[winnr] ---@type dot.win.IMeta|nil
  if meta == nil then
    return
  end

  meta_map[winnr] = nil

  if meta.history ~= nil then
    meta.history:clear()
  end

  if meta.winline ~= nil then
    if meta.winline.locate_token ~= nil then
      meta.winline.locate_token:cancel()
      meta.winline.locate_token = nil
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
  local meta_win = M.resolve(winnr, false) ---@type dot.win.IMeta|nil
  if meta_win == nil or meta_win.history == nil then
    return
  end

  local meta_buf = dot.buf.resolve(bufnr, false) ---@type dot.buf.IMeta|nil
  if meta_buf == nil then
    return
  end

  if meta_win.winline ~= nil and meta_win.winline.lsp_symbols ~= nil then
    if meta_win.winline.bufnr ~= bufnr then
      meta_win.winline.bufnr = bufnr
      meta_win.winline.lsp_symbols = {}
    end
  end

  local fp = meta_buf.filepath ---@type string
  local history = meta_win.history ---@type stl.c.History
  local item = { bufnr = bufnr, filepath = fp } ---@type dot.win.IFilepathHistoryItem
  history:push(item)
end

return M
