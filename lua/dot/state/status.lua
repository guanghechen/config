---@class dot.state.status.data
---@field public msg_command            string
---@field public msg_lsp                string
---@field public msg_mode               string
---@field public msg_transient          string
---
---@field public lsp_symbol_ready       table<integer, boolean>
---@field public notification_paused    boolean
---@field public notification_level     string
---@field public searching              boolean
---@field public suppress_warning       boolean
---@field public tmux_zen_mode          boolean

---@class dot.state.status.ISearch
---@field public bufnr                  integer
---@field public count                  string|nil
---@field public pattern                string
---@field public winnr                  integer

---@class dot.state.status
---@field protected _disposables        stl.c.BatchDisposable
---
---
---@field public winnr_command          stl.c.Observable
---
---@field public dirtier_statusline     stl.c.Dirtier
---@field public dirtier_tabline        stl.c.Dirtier
---@field public dirtier_termline       stl.c.Dirtier
---@field public dirtier_notepadline    stl.c.Dirtier
---@field public dirty_winline_nr       stl.c.Observable
---
---@field public lint_schedule_nr       stl.c.Observable
---
---@field public msg_command            stl.c.Observable
---@field public msg_lsp                stl.c.Observable
---@field public msg_mode               stl.c.Observable
---@field public msg_transient          stl.c.Observable
---
---@field public lsp_symbol_ready       table<integer, boolean>
---@field public notification_paused    stl.c.Observable
---@field public notification_level     stl.c.Observable
---@field public searching              stl.c.Observable
---@field public suppress_warning       stl.c.Observable
---@field public tmux_zen_mode          stl.c.Observable
local M = {
  _disposables = stl.c.BatchDisposable.new(),

  winnr_command = stl.c.Observable.from_value(0),

  dirtier_statusline = stl.c.Dirtier.new({ dirty = true }),
  dirtier_tabline = stl.c.Dirtier.new({ dirty = true }),
  dirtier_termline = stl.c.Dirtier.new({ dirty = true }),
  dirtier_notepadline = stl.c.Dirtier.new({ dirty = true }),
  dirty_winline_nr = stl.c.Observable.from_value(0, stl.fn.falsy),

  lint_schedule_nr = stl.c.Observable.from_value(0, stl.fn.falsy),

  msg_command = stl.c.Observable.from_value(""),
  msg_lsp = stl.c.Observable.from_value(""),
  msg_mode = stl.c.Observable.from_value(""),
  msg_transient = stl.c.Observable.from_value(""),

  lsp_symbol_ready = {}, -- LSP clients that have responded (success or error) to documentSymbol
  notification_paused = stl.c.Observable.from_value(false),
  notification_level = stl.c.Observable.from_value("TRACE"),
  searching = stl.c.Observable.from_value(false),
  suppress_warning = stl.c.Observable.from_value(false),
  tmux_zen_mode = stl.c.Observable.from_value(true),
}

local search = nil ---@type dot.state.status.ISearch|nil

M._disposables
  :add_disposable(M.winnr_command)
  :add_disposable(M.dirtier_statusline)
  :add_disposable(M.dirtier_tabline)
  :add_disposable(M.dirtier_termline)
  :add_disposable(M.dirtier_notepadline)
  :add_disposable(M.dirty_winline_nr)
  :add_disposable(M.lint_schedule_nr)
  :add_disposable(M.msg_command)
  :add_disposable(M.msg_lsp)
  :add_disposable(M.msg_mode)
  :add_disposable(M.msg_transient)
  :add_disposable(M.notification_paused)
  :add_disposable(M.notification_level)
  :add_disposable(M.searching)
  :add_disposable(M.suppress_warning)
  :add_disposable(M.tmux_zen_mode)

---@param disposable                    stl.c.IDisposable
---@return nil
function M.add_disposable(disposable)
  M._disposables:add_disposable(disposable)
end

---Check whether status observables have entered terminal disposal.
---@return boolean
function M.isdisposed()
  return M._disposables:isdisposed()
end

---@return nil
function M.dispose()
  search = nil
  M._disposables:dispose()
end

---@return dot.state.status.data
function M.dump()
  ---@type dot.state.status.data
  local data = {
    msg_command = M.msg_command:snapshot(),
    msg_lsp = M.msg_lsp:snapshot(),
    msg_mode = M.msg_mode:snapshot(),
    msg_transient = M.msg_transient:snapshot(),
    lsp_symbol_ready = M.lsp_symbol_ready,
    notification_paused = M.notification_paused:snapshot(),
    notification_level = M.notification_level:snapshot(),
    searching = M.searching:snapshot(),
    suppress_warning = M.suppress_warning:snapshot(),
    tmux_zen_mode = M.tmux_zen_mode:snapshot(),
  }
  return data
end

---@param winnr                         integer
local function redraw_winline(winnr)
  if vim.api.nvim_win_is_valid(winnr) then
    M.dirty_winline_nr:next(winnr, { force = true })
  end
end

---@return nil
function M.clear_search()
  local winnr = search ~= nil and search.winnr or nil ---@type integer|nil
  search = nil
  if winnr ~= nil then
    redraw_winline(winnr)
  end
end

---@param winnr                         integer
---@param bufnr                         integer
---@param pattern                       string
---@param count                         string|nil
---@return nil
function M.set_search(winnr, bufnr, pattern, count)
  if pattern == "" or not vim.api.nvim_win_is_valid(winnr) or vim.api.nvim_win_get_buf(winnr) ~= bufnr then
    M.clear_search()
    return
  end

  local winnr_previous = search ~= nil and search.winnr or nil ---@type integer|nil
  search = { winnr = winnr, bufnr = bufnr, pattern = pattern, count = count }
  if winnr_previous ~= nil and winnr_previous ~= winnr then
    redraw_winline(winnr_previous)
  end
  redraw_winline(winnr)
end

---@param winnr                         integer
---@return string|nil pattern
---@return string|nil count
function M.get_search(winnr)
  local state = search
  if
    state == nil
    or state.winnr ~= winnr
    or not vim.api.nvim_win_is_valid(winnr)
    or vim.api.nvim_win_get_buf(winnr) ~= state.bufnr
  then
    return nil
  end
  return state.pattern, state.count
end

---@return integer|nil
function M.get_winnr_command()
  local winnr_command = M.winnr_command:snapshot() ---@type integer
  if winnr_command > 0 and vim.api.nvim_win_is_valid(winnr_command) then
    return winnr_command
  else
    M.winnr_command:next(0)
    return nil
  end
end

---@param winnr                         ?integer
---@return nil
function M.set_winnr_command(winnr)
  if winnr == nil then
    M.winnr_command:next(0)
  elseif winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
    M.winnr_command:next(winnr)
  end
end

return M
