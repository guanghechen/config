local util = require("fml.util")

---@class fml.api.state
local M = require("fml.api.state.mod")

require("fml.api.state.buf")
require("fml.api.state.tab")
require("fml.api.state.win")
require("fml.api.state.serialize")

---@return nil
function M.refresh_all()
  M.refresh_bufs()
  M.refresh_tabs()
  M.refresh_wins()
  M.remove_unrefereced_bufs()
end

M.schedule_refresh_all = util.schedule("fml.api.state.refresh", M.refresh_all)
M.schedule_refresh_bufs = util.schedule("fml.api.state.refresh_bufs", M.refresh_bufs)
M.schedule_refresh_wins = util.schedule("fml.api.state.refresh_wins", M.refresh_wins, 16)
M.schedule_refresh_tabs = util.schedule("fml.api.state.refresh_tabs", M.refresh_tabs)

return M
