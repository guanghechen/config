local Observable = require("fml.collection.observable")
local util = require("fml.std.util")

---@class fml.api.state
---@field public term_map               table<string, fml.api.state.ITerm>
---@field public winline_dirty_nr       fml.types.collection.IObservable
local M = {}

M.term_map = {}
M.winline_dirty_nr = Observable.from_value(0, util.falsy)

M.schedule_refresh = util.schedule("fml.api.state.refresh", M.refresh)
M.schedule_refresh_bufs = util.schedule("fml.api.state.refresh_bufs", M.refresh_buf)
M.schedule_refresh_tabs = util.schedule("fml.api.state.refresh_tabs", M.refresh_tabs)

---@return nil
function M.refresh()
  M.refresh_bufs()
  M.refresh_tabs()
end

return M
