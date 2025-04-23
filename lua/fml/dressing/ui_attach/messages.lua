---@class fml.dressing.ui_attach.messages
local M = {}

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
---@diagnostic disable-next-line: unused-local
function M.showcmd(task)
  eve.state.status.dirtier_statusline:mark_dirty()
end

return M
