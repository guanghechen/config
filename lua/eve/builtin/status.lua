local functional = require("eve.lib.functional")
local tmux = require("eve.lib.tmux")
local Observable = require("eve.lib.collection.observable")
local Diritier = require("eve.lib.collection.dirtier")

---@class eve.builtin.status
---@field public lsp_msg                eve.lib.collection.IObservable
---@field public tmux_zen_mode          eve.lib.collection.IObservable
---@field public statusline_dirtier     eve.lib.collection.IDirtier
---@field public tabline_dirtier        eve.lib.collection.IDirtier
---@field public winline_dirty_nr       eve.lib.collection.IObservable
---@field public reset                  fun(): nil
local M = {}

M.lsp_msg = Observable.from_value("")
M.tmux_zen_mode = Observable.from_value(tmux.is_tmux_pane_zoomed())
M.statusline_dirtier = Diritier.new({ dirty = true })
M.tabline_dirtier = Diritier.new({ dirty = true })
M.winline_dirty_nr = Observable.from_value(0, functional.falsy)

---@return nil
function M.reset()
  M.lsp_msg:next("")
  M.tmux_zen_mode:next(tmux.is_tmux_pane_zoomed())
  M.statusline_dirtier:mark_dirty()
  M.tabline_dirtier:mark_dirty()
  M.winline_dirty_nr:next(0)
end

return M
