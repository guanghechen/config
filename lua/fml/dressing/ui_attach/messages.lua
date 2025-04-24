local kind_2_level_map = {
  err = vim.log.levels.ERROR,
  warn = vim.log.levels.WARN,
  info = vim.log.levels.INFO,
  debug = vim.log.levels.DEBUG,
}

local last_msg_group = nil ---@type string|nil

---@class fml.dressing.ui_attach.messages
local M = {}

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
function M.show(task)
  local kind, content, replace_last, history = unpack(task.args)
  ---@cast kind                         string
  ---@cast content                      [integer, string][]
  ---@cast replace_last                 boolean
  ---@cast history                      boolean

  local level = kind_2_level_map[kind] or vim.log.levels.INFO
  local group = replace_last and last_msg_group or string.format("%s_%d", task.event, os.time()) ---@type string

  local text = "" ---@type string
  for _, piece in ipairs(content) do
    text = text .. piece[2] ---@type string
  end

  vim.notify(text, level, {
    group = group,
    title = task.event,
    timeout = 3000,
    message = text,
    anonymous = not history,
    silent = false,
  })
end

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
---@diagnostic disable-next-line: unused-local
function M.showcmd(task)
  eve.state.status.dirtier_statusline:mark_dirty()
end

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
---@diagnostic disable-next-line: unused-local
function M.clear(task) end

return M
