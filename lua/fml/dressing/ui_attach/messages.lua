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
  ---@cast entries                      [string, [integer, string, integer][]][]

  local lines = {} ---@type string[]
  for _, entry in ipairs(entries) do
    local content = entry[2] ---@type [integer, string, integer][]
    local text = "" ---@type string
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

  for lnum, entry in ipairs(entries) do
    local offset = 0 ---@type integer
    local row = lnum - 1 ---@type integer
    for _, item in ipairs(entry[2]) do
      local _, text_chunk, hlid = unpack(item) ---@type integer, string, integer
      local hlname = eve.state.theme.get_hlname_by_id(eve.constant.nsnr.attach, hlid)
      local offset_next = offset + #text_chunk ---@type integer
      vim.hl.range(bufnr, eve.constant.nsnr.attach, hlname, { row, offset }, { row, offset_next })
      offset = offset_next ---@type integer
    end
  end

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

  if kind == "search_count" or kind == "search_cmd" then
    eve.state.status.searching:next(true)
    local line = vim.fn.line(".") - 1
    local virt_text = {} ---@type string[][]
    for _, piece in ipairs(content) do
      local text = vim.trim(piece[2]) ---@type string
      table.insert(virt_text, { text, "f_um_search_count" })
    end

    vim.api.nvim_buf_clear_namespace(0, eve.constant.nsnr.search_count, 0, -1)
    vim.api.nvim_buf_set_extmark(0, eve.constant.nsnr.search_count, line, -1, {
      virt_text = virt_text,
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
    return
  end

  local level = kind_2_level_map[kind] or vim.log.levels.INFO
  local title = string.format("%s | %s", task.event, kind) ---@type string
  local message = "" ---@type string
  for _, piece in ipairs(content) do
    message = message .. piece[2] ---@type string
  end

  local group = replace_last and last_msg_group or nil ---@type string|nil
  if group == nil then
    local md5 = eve.std.md5.new():update(tostring(level)):update(title):update(message):finish()
    group = eve.std.md5.tohex(md5) ---@type string
  end
  last_msg_group = group

  vim.notify(message, level, {
    group = group,
    title = title,
    timeout = 3000,
    message = message,
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
function M.clear(task)
  eve.state.status.searching:next(true)
end

return M
