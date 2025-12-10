---@class dot.status.data
---@field public msg_changes            string
---@field public msg_command            string
---@field public msg_lsp                string
---@field public msg_mode               string
---
---@field public notification_paused    boolean
---@field public notification_level     string
---@field public searching              boolean
---@field public suppress_warning       boolean
---@field public tmux_zen_mode          boolean

---@class dot.status
---@field protected _disposables        ark.c.BatchDisposable
---
---
---@field public winnr_command          ark.c.Observable
---
---@field public dirtier_statusline     ark.c.Dirtier
---@field public dirtier_tabline        ark.c.Dirtier
---@field public dirtier_termline       ark.c.Dirtier
---@field public dirtier_notepadline    ark.c.Dirtier
---@field public dirty_winline_nr       ark.c.Observable
---
---@field public lint_schedule_nr       ark.c.Observable
---
---@field public msg_changes            ark.c.Observable
---@field public msg_command            ark.c.Observable
---@field public msg_lsp                ark.c.Observable
---@field public msg_mode               ark.c.Observable
---
---@field public copilots               table<integer, string>
---@field public notification_paused    ark.c.Observable
---@field public notification_level     ark.c.Observable
---@field public searching              ark.c.Observable
---@field public suppress_warning       ark.c.Observable
---@field public tmux_zen_mode          ark.c.Observable
local M = {
  _disposables = ark.c.BatchDisposable.new(),

  winnr_command = ark.c.Observable.from_value(0),

  dirtier_statusline = ark.c.Dirtier.new({ dirty = true }),
  dirtier_tabline = ark.c.Dirtier.new({ dirty = true }),
  dirtier_termline = ark.c.Dirtier.new({ dirty = true }),
  dirtier_notepadline = ark.c.Dirtier.new({ dirty = true }),
  dirty_winline_nr = ark.c.Observable.from_value(0, ark.fn.falsy),

  lint_schedule_nr = ark.c.Observable.from_value(0, ark.fn.falsy),

  msg_changes = ark.c.Observable.from_value(""),
  msg_command = ark.c.Observable.from_value(""),
  msg_lsp = ark.c.Observable.from_value(""),
  msg_mode = ark.c.Observable.from_value(""),

  copilots = {}, -- Plain object for copilot status per client
  notification_paused = ark.c.Observable.from_value(false),
  notification_level = ark.c.Observable.from_value("TRACE"),
  searching = ark.c.Observable.from_value(false),
  suppress_warning = ark.c.Observable.from_value(false),
  tmux_zen_mode = ark.c.Observable.from_value(true),
}

M._disposables
  :add_disposable(M.winnr_command)
  :add_disposable(M.dirtier_statusline)
  :add_disposable(M.dirtier_tabline)
  :add_disposable(M.dirtier_termline)
  :add_disposable(M.dirtier_notepadline)
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

---@param disposable                    ark.c.IDisposable
---@return nil
function M.add_disposable(disposable)
  M._disposables:add_disposable(disposable)
end

---@return nil
function M.dispose()
  M._disposables:dispose()
end

---@return dot.status.data
function M.dump()
  ---@type dot.status.data
  local data = {
    msg_changes = M.msg_changes:snapshot(),
    msg_command = M.msg_command:snapshot(),
    msg_lsp = M.msg_lsp:snapshot(),
    msg_mode = M.msg_mode:snapshot(),
    notification_paused = M.notification_paused:snapshot(),
    notification_level = M.notification_level:snapshot(),
    searching = M.searching:snapshot(),
    suppress_warning = M.suppress_warning:snapshot(),
    tmux_zen_mode = M.tmux_zen_mode:snapshot(),
  }
  return data
end

---@return nil
function M.reset()
  M.winnr_command:next(0)

  M.dirtier_statusline:mark_dirty()
  M.dirtier_tabline:mark_dirty()
  M.dirtier_termline:mark_dirty()
  M.dirtier_notepadline:mark_dirty()
  M.dirty_winline_nr:next(0)

  M.lint_schedule_nr:next(0)

  M.msg_changes:next("")
  M.msg_command:next("")
  M.msg_lsp:next("")
  M.msg_mode:next("")

  -- Reset copilot status (plain object)
  for k in pairs(M.copilots) do
    M.copilots[k] = nil
  end

  M.notification_paused:next(false)
  M.notification_level:next("TRACE")
  M.searching:next(false)
  M.suppress_warning:next(false)
  M.tmux_zen_mode:next(true)
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

---@param winnr                         integer|nil
---@return nil
function M.set_winnr_command(winnr)
  if winnr == nil then
    M.winnr_command:next(0)
  elseif winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
    M.winnr_command:next(winnr)
  end
end

return M
