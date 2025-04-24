local kind_2_level_map = {
  err = vim.log.levels.ERROR,
  emsg = vim.log.levels.ERROR,
  warn = vim.log.levels.WARN,
  info = vim.log.levels.INFO,
  debug = vim.log.levels.DEBUG,
}

local last_msg_group = nil ---@type string|nil

local history_bufnr = nil ---@type integer|nil
local history_winnr = nil ---@type integer|nil

---@class fml.dressing.ui_attach.messages
local M = {}

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
---@diagnostic disable-next-line: unused-local
function M.history_clear(task)
  --- nothing need to do
end

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
function M.history_show(task)
  local entries = unpack(task.args)
  ---@cast entries                      [string, [integer, string, integer]][]

  local lines = {} ---@type string[]
  for _, entry in ipairs(entries) do
    local kind, content = entry[1], entry[2]
    local text = kind or "" ---@type string
    for _, item in ipairs(content) do
      text = text .. item[2]
    end
    table.insert(lines, text)
  end

  local bufnr = history_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    history_bufnr = bufnr

    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].filetype = eve.filetype.UX_MESSAGE_HISTORY
    vim.bo[bufnr].swapfile = false
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false

  local winnr = history_winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    vim.cmd("botright 10split")
    winnr = vim.api.nvim_get_current_win()
    history_winnr = winnr

    vim.api.nvim_win_set_buf(winnr, bufnr)

    vim.wo[winnr].number = true
    vim.wo[winnr].relativenumber = true
    vim.wo[winnr].signcolumn = "yes"
    vim.wo[winnr].spell = false
    vim.wo[winnr].winfixbuf = true
    vim.wo[winnr].wrap = false
  else
    vim.wo[winnr].winfixbuf = false
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.wo[winnr].winfixbuf = true
  end
end

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
