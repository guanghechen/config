---@class eve.builtin.status
---@field protected _disposables        eve.std.collection.BatchDisposable
---
---
---@field public winnr_command          eve.std.collection.IObservable
---
---@field public dirtier_statusline     eve.std.collection.IDirtier
---@field public dirtier_tabline        eve.std.collection.IDirtier
---@field public dirty_winline_nr       eve.std.collection.IObservable
---
---@field public lint_schedule_nr       eve.std.collection.IObservable
---
---@field public msg_changes            eve.std.collection.IObservable
---@field public msg_command            eve.std.collection.IObservable
---@field public msg_lsp                eve.std.collection.IObservable
---@field public msg_mode               eve.std.collection.IObservable
---
---@field public notification_paused    eve.std.collection.IObservable
---@field public notification_level     eve.std.collection.IObservable
---@field public searching              eve.std.collection.IObservable
---@field public suppress_warning       eve.std.collection.IObservable
---@field public tmux_zen_mode          eve.std.collection.IObservable
local M = {
  _disposables = eve.std.BatchDisposable.new(),

  winnr_command = eve.std.Observable.from_value(0),

  dirtier_statusline = eve.std.Dirtier.new({ dirty = true }),
  dirtier_tabline = eve.std.Dirtier.new({ dirty = true }),
  dirty_winline_nr = eve.std.Observable.from_value(0, eve.std.fn.falsy),

  lint_schedule_nr = eve.std.Observable.from_value(0, eve.std.fn.falsy),

  msg_changes = eve.std.Observable.from_value(""),
  msg_command = eve.std.Observable.from_value(""),
  msg_lsp = eve.std.Observable.from_value(""),
  msg_mode = eve.std.Observable.from_value(""),

  notification_paused = eve.std.Observable.from_value(false),
  notification_level = eve.std.Observable.from_value("TRACE"),
  searching = eve.std.Observable.from_value(false),
  suppress_warning = eve.std.Observable.from_value(false),
  tmux_zen_mode = eve.std.Observable.from_value(true),
}

M._disposables
  :add_disposable(M.winnr_command)
  :add_disposable(M.dirtier_statusline)
  :add_disposable(M.dirtier_tabline)
  :add_disposable(M.dirty_winline_nr)
  :add_disposable(M.lint_schedule_nr)
  :add_disposable(M.msg_changes)
  :add_disposable(M.msg_command)
  :add_disposable(M.msg_lsp)
  :add_disposable(M.msg_mode)
  :add_disposable(M.notification_paused)
  :add_disposable(M.notification_level)
  :add_disposable(M.searching)
  :add_disposable(M.suppress_warning)
  :add_disposable(M.tmux_zen_mode)

---@param disposable                    eve.std.collection.IDisposable
---@return nil
function M.add_disposable(disposable)
  M._disposables:add_disposable(disposable)
end

---@return nil
function M.dispose()
  M._disposables:dispose()
end

---@return nil
function M.reset()
  M.winnr_command:next(0)

  M.dirtier_statusline:mark_dirty()
  M.dirtier_tabline:mark_dirty()
  M.dirty_winline_nr:next(0)

  M.lint_schedule_nr:next(0)

  M.msg_changes:next("")
  M.msg_command:next("")
  M.msg_lsp:next("")
  M.msg_mode:next("")

  M.notification_paused:next(false)
  M.notification_level:next("TRACE")
  M.searching:next(false)
  M.suppress_warning:next(false)
  M.tmux_zen_mode:next(true)
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

return M
