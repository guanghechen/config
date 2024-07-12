local Ticker = require("fml.collection.ticker")
local schedule_fn = require("fml.fn.schedule_fn")

---@class fml.api.state
---@field public term_map               table<string, fml.api.state.ITerm>
---@field public winline_dirty_ticker   fml.types.collection.ITicker
local M = {}

M.term_map = {}
M.winline_dirty_ticker = Ticker.new()

M.schedule_refresh = schedule_fn("fml.api.state.refresh", M.refresh)

M.schedule_refresh_bufs = schedule_fn("fml.api.state.refresh_bufs", M.refresh_buf)

M.schedule_refresh_tabs = schedule_fn("fml.api.state.refresh_tabs", M.refresh_tabs)

---@return nil
function M.refresh()
  M.refresh_bufs()
  M.refresh_tabs()
end

return M
