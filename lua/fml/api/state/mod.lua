local schedule_fn = require("fml.fn.schedule_fn")

---@class fml.api.state
local M = {}

M.schedule_refresh = schedule_fn("fml.api.state.refresh", function()
  M.refresh()
end)

M.schedule_refresh_bufs = schedule_fn("fml.api.state.refresh_bufs", function()
  M.refresh_bufs()
end)

M.schedule_refresh_tabs = schedule_fn("fml.api.state.refresh_tabs", function()
  M.refresh_tabs()
end)

---@return nil
function M.refresh()
  M.refresh_bufs()
  M.refresh_tabs()
end

return M
