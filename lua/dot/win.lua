---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.win" ---@type string

---@class dot.win.IFilepathHistoryItem
---@field public bufnr                  ?integer
---@field public filepath               ?string

---@class dot.win.IWinline
---@field public bufnr                  integer
---@field public lsp_symbols            ?dot.t.ILspSymbol[]
---@field public nvimbar                era.m.nvimbar.Nvimbar
---@field public fork                   ?fun(winnr: integer): era.m.nvimbar.Nvimbar|nil
---@field public fork_source_winnr      integer|nil
---@field public forks                  ?table<integer, era.m.nvimbar.Nvimbar>

---@class dot.win.IMeta
---@field public history                ?stl.c.History
---@field public winline                ?dot.win.IWinline

local wintype_attrs = {
  focusable = {
    [stl.e.WinTypeEnum.BOARD] = true,
    [stl.e.WinTypeEnum.EXPLORER] = true,
    [stl.e.WinTypeEnum.INPUT] = true,
    [stl.e.WinTypeEnum.NOTIFY] = true,
    [stl.e.WinTypeEnum.PICKER_FINDER] = true,
    [stl.e.WinTypeEnum.PICKER_PREVIEW] = true,
    [stl.e.WinTypeEnum.PICKER_RESULT] = true,
    [stl.e.WinTypeEnum.POPUPMENU] = true,
    [stl.e.WinTypeEnum.SEARCHER_FINDER] = true,
    [stl.e.WinTypeEnum.SEARCHER_PREVIEW] = true,
    [stl.e.WinTypeEnum.SEARCHER_RESULT] = true,
    [stl.e.WinTypeEnum.SELECT] = true,
    [stl.e.WinTypeEnum.TERMINAL] = true,
    [stl.e.WinTypeEnum.TEXTAREA] = true,
  },
  projectable = {},
  sourcefile = {},
  swappable = {},
}

local meta_map = {} ---@type table<integer, dot.win.IMeta|nil>

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
    if filetype == c_filetype and stl.nvim.win.is_fixed(winnr) then
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
    if vim.api.nvim_get_option_value("filetype", { buf = bufnr }) == filetype and stl.nvim.win.is_float(winnr) then
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
  if not stl.nvim.win.is_valid(winnr) then
    return false
  end

  local wintype = vim.w[winnr].wintype ---@type stl.e.WinTypeEnum|nil
  if wintype ~= nil then
    return wintype_attrs.focusable[wintype] == true
  end

  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config.focusable == true
end

---@param winnr                         integer
---@return boolean
function M.is_projectable(winnr)
  if not stl.nvim.win.is_valid(winnr) then
    return false
  end

  local wintype = vim.w[winnr].wintype ---@type stl.e.WinTypeEnum|nil
  if wintype ~= nil then
    return wintype_attrs.projectable[wintype] == true
  end

  if vim.api.nvim_get_option_value("winfixbuf", { win = winnr }) or stl.nvim.win.is_float(winnr) then
    return false
  end

  return true
end

---@param winnr                         integer
---@return boolean
function M.is_sourcefile(winnr)
  if not stl.nvim.win.is_valid(winnr) then
    return false
  end

  local wintype = vim.w[winnr].wintype ---@type stl.e.WinTypeEnum|nil
  if wintype ~= nil then
    return wintype_attrs.sourcefile[wintype] == true
  end

  if vim.api.nvim_get_option_value("winfixbuf", { win = winnr }) or stl.nvim.win.is_float(winnr) then
    return false
  end

  return true
end

---@param winnr                         integer
---@return boolean
function M.is_swappable(winnr)
  if not stl.nvim.win.is_valid(winnr) then
    return false
  end

  local wintype = vim.w[winnr].wintype ---@type stl.e.WinTypeEnum|nil
  if wintype ~= nil then
    return wintype_attrs.swappable[wintype] == true
  end

  if stl.nvim.win.is_float(winnr) then
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
  local wintype = vim.w[winnr].wintype ---@type stl.e.WinTypeEnum|nil
  if wintype == stl.e.WinTypeEnum.CMDLINE or wintype == stl.e.WinTypeEnum.NOTIFY then
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
  if winnr_candidate ~= nil and stl.nvim.win.is_valid(winnr_candidate) and M.is_sourcefile(winnr_candidate) then
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

  local wintype_source = vim.w[winnr_source].wintype ---@type stl.e.WinTypeEnum|nil
  if wintype_source ~= nil then
    vim.w[winnr_target].wintype = wintype_source
  end

  if meta_source.history ~= nil then
    if meta_target.history ~= nil then
      meta_target.history:clear()
    end
    local history_forked = meta_source.history:fork({ name = "win_filepath" }) ---@type stl.c.History
    meta_target.history = history_forked
  end

  local source_winline = meta_source.winline
  if source_winline ~= nil and source_winline.fork ~= nil then
    local ok, nvimbar = pcall(source_winline.fork, winnr_target)
    if ok and nvimbar ~= nil and not nvimbar:isdisposed() then
      source_winline.forks = source_winline.forks or {}
      source_winline.forks[winnr_target] = nvimbar
      if meta_target.winline ~= nil then
        meta_target.winline.fork_source_winnr = winnr_source
      end
      nvimbar:refresh()
    elseif not ok then
      stl.reporter.error({
        from = __module_name__,
        subject = "fork_winline",
        message = "Failed to fork window-owned Nvimbar",
        details = { error = nvimbar, winnr_source = winnr_source, winnr_target = winnr_target },
      })
    end
  end

  return meta_target
end

---Render one window-owned Nvimbar and any live window forks.
---@param winnr                         integer
---@return nil
function M.render_winline(winnr)
  local meta = M.resolve(winnr, false)
  local winline = meta and meta.winline or nil ---@type dot.win.IWinline|nil
  if winline == nil then
    return
  end

  if not winline.nvimbar:isdisposed() then
    winline.nvimbar:refresh()
  end
  local forks = winline.forks
  if forks ~= nil then
    for fork_winnr, nvimbar in pairs(forks) do
      if not vim.api.nvim_win_is_valid(fork_winnr) or nvimbar:isdisposed() then
        forks[fork_winnr] = nil
      else
        nvimbar:refresh()
      end
    end
  end
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

  local wintype = vim.w[winnr].wintype ---@type stl.e.WinTypeEnum|nil
  if wintype ~= nil or stl.nvim.win.is_float(winnr) then
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

----------------------------------------------------------------------------------------------------

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
  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(winnr) or vim.api.nvim_win_get_buf(winnr) ~= bufnr then
      return
    end
    vim.cmd("stopinsert")

    if lnum ~= nil and col ~= nil then
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

  if last_bufnr == nil then
    return
  end
  vim.api.nvim_win_set_buf(winnr, last_bufnr)

  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(winnr) or vim.api.nvim_win_get_buf(winnr) ~= last_bufnr then
      return
    end
    vim.cmd("stopinsert")

    if lnum ~= nil and col ~= nil then
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

  local fork_source_winnr = meta.winline and meta.winline.fork_source_winnr or nil ---@type integer|nil
  local fork_source = fork_source_winnr and meta_map[fork_source_winnr] or nil ---@type dot.win.IMeta|nil
  if fork_source and fork_source.winline and fork_source.winline.forks then
    fork_source.winline.forks[winnr] = nil
  end

  meta_map[winnr] = nil

  if meta.history ~= nil then
    meta.history:clear()
  end

  if meta.winline ~= nil then
    if meta.winline.nvimbar ~= nil then
      meta.winline.nvimbar:dispose()
    end

    local forks = meta.winline.forks
    if forks ~= nil then
      for fork_winnr in pairs(forks) do
        local fork_meta = meta_map[fork_winnr] ---@type dot.win.IMeta|nil
        if fork_meta and fork_meta.winline then
          fork_meta.winline.fork_source_winnr = nil
        end
      end
    end
    meta.winline.forks = nil
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
