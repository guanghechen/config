local fn = require("eve.builtin.fn")
local tmux = require("eve.builtin.tmux")
local Dirtier = require("eve.collection.dirtier")
local Observable = require("eve.collection.observable")
local Ticker = require("eve.collection.ticker")

---@class eve.state.status.data
---@field public tick_editor            integer
---@field public tick_session           integer
---@field public tick_workspace         integer
---
---@field public dirty_statusline       integer
---@field public dirty_tabline          integer
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
---@field public dirty_winline_nr       eve.collection.IObservable
---
---@field public lsp_msg                eve.collection.IObservable
---@field public maximized_winnrs       table<integer, boolean>
---@field public suppress_warning       eve.collection.IObservable
---@field public tmux_zen_mode          eve.collection.IObservable
---
---@field public reset                  fun(): nil

---@class eve.state.status
---@field public defaults               fun(): eve.state.status.data
---@field public dump                   fun(): eve.state.status.data
---@field public load                   fun(data: unknown): eve.state.status.state
---@field public normalize              fun(data: unknown): eve.state.status.data
local M = {}

local _state = nil ---@type eve.state.status.state | nil

---@return eve.state.status.data
function M.defaults()
  ---@type eve.state.status.data
  return {
    tick_editor = 0,
    tick_session = 0,
    tick_workspace = 0,

    dirty_statusline = 0,
    dirty_tabline = 0,
    dirty_winline_nr = 0,

    lsp_msg = "",
    maximized_winnrs = {},
    suppress_warning = false,
    tmux_zen_mode = tmux.is_tmux_pane_zoomed(),
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
  if _state == nil then
    ---@type eve.state.status.data
    return M.defaults()
  end

  ---@type eve.state.status.data
  return {
    tick_editor = _state.ticker_editor:snapshot(),
    tick_session = _state.ticker_session:snapshot(),
    tick_workspace = _state.ticker_workspace:snapshot(),

    dirty_statusline = _state.dirtier_statusline:snapshot(),
    dirty_tabline = _state.dirtier_tabline:snapshot(),
    dirty_winline_nr = _state.dirty_winline_nr:snapshot(),

    lsp_msg = _state.lsp_msg:snapshot(),
    maximized_winnrs = vim.tbl_extend("force", {}, _state.maximized_winnrs),
    suppress_warning = _state.suppress_warning:snapshot(),
    tmux_zen_mode = _state.tmux_zen_mode:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.state.status.state
function M.load(raw_data)
  ---@diagnostic disable-next-line: unused-local
  local data = M.normalize(raw_data) ---@type eve.state.status.data

  if _state == nil then
    ---@type eve.state.status.state
    _state = {
      ticker_editor = Ticker.new({ start = data.tick_editor }),
      ticker_workspace = Ticker.new({ start = data.tick_workspace }),
      ticker_session = Ticker.new({ start = data.tick_session }),

      dirtier_statusline = Dirtier.new({ dirty = true }),
      dirtier_tabline = Dirtier.new({ dirty = true }),
      dirty_winline_nr = Observable.from_value(data.dirty_winline_nr, fn.falsy),

      lsp_msg = Observable.from_value(data.lsp_msg),
      maximized_winnrs = data.maximized_winnrs,
      suppress_warning = Observable.from_value(data.suppress_warning),
      tmux_zen_mode = Observable.from_value(data.tmux_zen_mode),

      reset = function()
        ---@cast _state                 eve.state.status.state

        _state.lsp_msg:next(data.lsp_msg)
        _state.maximized_winnrs = data.maximized_winnrs
        _state.suppress_warning:next(data.suppress_warning)

        _state.dirtier_statusline:mark_dirty()
        _state.dirtier_tabline:mark_dirty()
        _state.dirty_winline_nr:next(data.dirty_winline_nr)
      end,
    }
    return _state
  end
  return _state
end

return M
