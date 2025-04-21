---@diagnostic disable-next-line: unused-local
local original_notify = vim.notify ---@type fun(msg: string, level: integer, opts: any): nil

---@param msg                           string
---@param level0                        integer
---@param opts                          any
---@return nil
---@diagnostic disable-next-line: duplicate-set-field
vim.notify = function(msg, level0, opts)
  opts = opts or {}

  local level = eve.notifier.resolve_level(level0) ---@type eve.builtin.notifier.LevelEnum
  local timeout = opts.timeout or 3000 ---@type integer
  local title = opts.title or eve.notifier.resolve_title(level) ---@type string
  eve.notifier.notify(level, nil, title, msg, timeout)
end

eve.state.observe({ eve.state.status.notification_level, eve.state.status.notification_paused }, function()
  eve.notifier.schedule()
end)
