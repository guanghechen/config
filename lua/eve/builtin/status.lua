---@class eve.builtin.status
---@field public ticker_editor          eve.std.collection.ITicker
---@field public ticker_session         eve.std.collection.ITicker
---@field public ticker_workspace       eve.std.collection.ITicker
---
---@field public dirtier_statusline     eve.std.collection.IDirtier
---@field public dirtier_tabline        eve.std.collection.IDirtier
---@field public dirty_winline_nr       eve.std.collection.IObservable -- integer>
---
---@field public lint_schedule_nr       eve.std.collection.IObservable -- integer>
---
---@field public lsp_msg                eve.std.collection.IObservable -- string>
---@field public recording_msg          eve.std.collection.IObservable -- string>
---
---@field public maximized_winnrs       table<integer, boolean>
---@field public notification_paused    eve.std.collection.IObservable -- boolean>
---@field public notification_level     eve.std.collection.IObservable -- eve.builtin.notifier.LevelEnum>
---@field public searching              eve.std.collection.IObservable -- boolean>
---@field public suppress_warning       eve.std.collection.IObservable -- boolean>
---@field public tmux_zen_mode          eve.std.collection.IObservable -- boolean>
local M = {
  ticker_editor = eve.std.Ticker.new({ start = 0 }),
  ticker_workspace = eve.std.Ticker.new({ start = 0 }),
  ticker_session = eve.std.Ticker.new({ start = 0 }),

  dirtier_statusline = eve.std.Dirtier.new({ dirty = true }),
  dirtier_tabline = eve.std.Dirtier.new({ dirty = true }),
  dirty_winline_nr = eve.std.Observable.from_value(0, eve.std.fn.falsy),

  lint_schedule_nr = eve.std.Observable.from_value(0, eve.std.fn.falsy),

  lsp_msg = eve.std.Observable.from_value(""),
  recording_msg = eve.std.Observable.from_value(""),

  maximized_winnrs = {},
  notification_paused = eve.std.Observable.from_value(false),
  notification_level = eve.std.Observable.from_value("TRACE"),
  searching = eve.std.Observable.from_value(false),
  suppress_warning = eve.std.Observable.from_value(false),
  tmux_zen_mode = eve.std.Observable.from_value(true),
}

---@return nil
function M.reset()
  M.ticker_editor:next(0)
  M.ticker_session:next(0)
  M.ticker_workspace:next(0)

  M.dirtier_statusline:mark_dirty()
  M.dirtier_tabline:mark_dirty()
  M.dirty_winline_nr:next(0)

  M.lint_schedule_nr:next(0)
  M.lsp_msg:next("")
  M.recording_msg:next("")

  M.maximized_winnrs = {}
  M.notification_paused:next(false)
  M.notification_level:next("TRACE")
  M.searching:next(false)
  M.suppress_warning:next(false)
  M.tmux_zen_mode:next(true)
end

return M
