---@class eve.state.status.data
---@field public tick_editor            integer
---@field public tick_session           integer
---@field public tick_workspace         integer
---
---@field public dirty_winline_nr       integer
---
---@field public lsp_msg                string
---@field public maximized_winnrs       table<integer, boolean>
---@field public suppress_warning       boolean
---@field public tmux_zen_mode          boolean

---@class eve.state.status.state
---@field public ticker_editor          eve.collection.ITicker
---@field public ticker_session         eve.collection.ITicker
---@field public ticker_workspace       eve.collection.ITicker
---
---@field public dirtier_statusline     eve.collection.IDirtier
---@field public dirtier_tabline        eve.collection.IDirtier
---@field public dirty_winline_nr       eve.collection.IObservable -- integer>
---
---@field public lsp_msg                eve.collection.IObservable -- string>
---@field public maximized_winnrs       table<integer, boolean>
---@field public suppress_warning       eve.collection.IObservable -- boolean>
---@field public tmux_zen_mode          eve.collection.IObservable -- boolean>
---
---@field public reset                  fun(): nil

---@class eve.state.status : eve.state.status.state
---@field public defaults               fun(): eve.state.status.data
---@field public dump                   fun(): eve.state.status.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.state.status.data
local M = {}

---@return eve.state.status.data
function M.defaults()
  ---@type eve.state.status.data
  return {
    tick_editor = 0,
    tick_session = 0,
    tick_workspace = 0,

    dirty_winline_nr = 0,

    lsp_msg = "",
    maximized_winnrs = {},
    suppress_warning = false,
    tmux_zen_mode = eve.tmux.is_tmux_pane_zoomed(),
  }
end

---@param data                        any
---@return eve.state.status.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.status.data
  ---@diagnostic disable-next-line: empty-block
  if type(data) == "table" then
    --
  end

  ---@type eve.state.status.data
  return resolved
end

---@return eve.state.status.data
function M.dump()
  ---@type eve.state.status.data
  return {
    tick_editor = M.ticker_editor:snapshot(),
    tick_session = M.ticker_session:snapshot(),
    tick_workspace = M.ticker_workspace:snapshot(),

    dirty_statusline = M.dirtier_statusline:snapshot(),
    dirty_tabline = M.dirtier_tabline:snapshot(),
    dirty_winline_nr = M.dirty_winline_nr:snapshot(),

    lsp_msg = M.lsp_msg:snapshot(),
    maximized_winnrs = vim.tbl_extend("force", {}, M.maximized_winnrs),
    suppress_warning = M.suppress_warning:snapshot(),
    tmux_zen_mode = M.tmux_zen_mode:snapshot(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  ---@diagnostic disable-next-line: unused-local
  local data = M.normalize(raw_data) ---@type eve.state.status.data

  M.ticker_editor:next(data.tick_editor)
  M.ticker_session:next(data.tick_session)
  M.ticker_workspace:next(data.tick_workspace)

  M.dirtier_statusline:mark_clean()
  M.dirtier_tabline:mark_clean()
  M.dirty_winline_nr:next(data.dirty_winline_nr)

  M.lsp_msg:next(data.lsp_msg)
  M.maximized_winnrs = data.maximized_winnrs
  M.suppress_warning:next(data.suppress_warning)
  M.tmux_zen_mode:next(eve.tmux.is_tmux_pane_zoomed())
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.state.status.data
M.ticker_editor = eve.col.Ticker.new({ start = _defaults.tick_editor })
M.ticker_workspace = eve.col.Ticker.new({ start = _defaults.tick_workspace })
M.ticker_session = eve.col.Ticker.new({ start = _defaults.tick_session })

M.dirtier_statusline = eve.col.Dirtier.new({ dirty = true })
M.dirtier_tabline = eve.col.Dirtier.new({ dirty = true })
M.dirty_winline_nr = eve.col.Observable.from_value(_defaults.dirty_winline_nr, eve.fn.falsy)

M.lsp_msg = eve.col.Observable.from_value(_defaults.lsp_msg)
M.maximized_winnrs = _defaults.maximized_winnrs
M.suppress_warning = eve.col.Observable.from_value(_defaults.suppress_warning)
M.tmux_zen_mode = eve.col.Observable.from_value(_defaults.tmux_zen_mode)

---@return nil
function M.reset()
  M.load(nil)
end

return M
