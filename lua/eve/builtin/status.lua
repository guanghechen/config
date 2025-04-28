---@class eve.builtin.status
---@field public winnr_command          eve.std.collection.IObservable -- integer|nil>
---@field public winnr_fixed            eve.std.collection.IObservable -- integer|nil>
---
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
  winnr_command = eve.std.Observable.from_value(0),
  winnr_fixed = eve.std.Observable.from_value(0),

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
  M.winnr_command:next(0)
  M.winnr_fixed:next(0)

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

---@return nil
function M.focus_win_fixed()
  local winnr_fixed = M.get_winnr_fixed()
  if winnr_fixed ~= nil then
    vim.api.nvim_set_current_win(winnr_fixed)
  end
end

---@return integer|nil
function M.get_winnr_command()
  local winnr_command = M.winnr_command:snapshot() ---@type integer
  if winnr_command ~= 0 and eve.win.is_valid(winnr_command) then
    return winnr_command
  else
    M.winnr_command:next(0)
    return nil
  end
end

---@return integer|nil
function M.get_winnr_fixed()
  local winnr_fixed = M.winnr_fixed:snapshot() ---@type integer
  if winnr_fixed ~= 0 and eve.win.is_valid(winnr_fixed) then
    return winnr_fixed
  else
    M.winnr_fixed:next(0)
    return nil
  end
end

---@param winnr                         integer|nil
---@return nil
function M.set_winnr_command(winnr)
  if winnr == nil then
    M.winnr_command:next(0)
    return
  end
  if eve.win.is_valid(winnr) then
    M.winnr_command:next(winnr)
  end
end

---@return nil
function M.on_refresh()
  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnr_fixed = eve.win.find_fixed_by_filetype(tabnr) or 0 ---@type integer
  M.winnr_fixed:next(winnr_fixed or 0)
end

---@param winnr                         integer
---@return nil
function M.on_win_enter(winnr)
  if not eve.win.is_valid(winnr) then
    return
  end

  if eve.win.is_fixed(winnr) then
    M.winnr_fixed:next(winnr)
  end
end

return M
