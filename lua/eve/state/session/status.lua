local functional = require("eve.lib.functional")
local tmux = require("eve.lib.tmux")
local Dirtier = require("eve.lib.collection.dirtier")
local Observable = require("eve.lib.collection.observable")
local Ticker = require("eve.lib.collection.ticker")

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
---@field public tmux_zen_mode          boolean

---@class eve.state.status.state
---@field public ticker_editor          eve.lib.collection.ITicker
---@field public ticker_session         eve.lib.collection.ITicker
---@field public ticker_workspace       eve.lib.collection.ITicker
---
---@field public dirtier_statusline     eve.lib.collection.IDirtier
---@field public dirtier_tabline        eve.lib.collection.IDirtier
---@field public dirty_winline_nr       eve.lib.collection.IObservable
---
---@field public lsp_msg                eve.lib.collection.IObservable
---@field public tmux_zen_mode          eve.lib.collection.IObservable
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
      ticker_editor = Ticker.new({ start = 0 }),
      ticker_workspace = Ticker.new({ start = 0 }),
      ticker_session = Ticker.new({ start = 0 }),

      dirtier_statusline = Dirtier.new({ dirty = true }),
      dirtier_tabline = Dirtier.new({ dirty = true }),
      dirty_winline_nr = Observable.from_value(0, functional.falsy),

      lsp_msg = Observable.from_value(""),
      tmux_zen_mode = Observable.from_value(tmux.is_tmux_pane_zoomed()),

      reset = function()
        ---@cast _state eve.state.status.state

        _state.lsp_msg:next("")
        _state.tmux_zen_mode:next(tmux.is_tmux_pane_zoomed())
        _state.dirtier_statusline:mark_dirty()
        _state.dirtier_tabline:mark_dirty()
        _state.dirty_winline_nr:next(0)
      end,
    }
    return _state
  end
  return _state
end

return M
