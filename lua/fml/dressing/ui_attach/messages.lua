local states = require("fml.dressing.ui_attach.state")

local KIND_MAP = {
  CHANGES = {
    undo = true,
    bufwrite = true,
  },
}

local nsnrs = eve.var.nsnr ---@type eve.var.nsnr

local kind_2_level_map = {
  err = vim.log.levels.ERROR,
  emsg = vim.log.levels.ERROR,
  lua_error = vim.log.levels.ERROR,
  warn = vim.log.levels.WARN,
  info = vim.log.levels.INFO,
  debug = vim.log.levels.DEBUG,
}

---@class fml.dressing.ui_attach.messages
local M = {}

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
---@diagnostic disable-next-line: unused-local
function M.clear(task)
  eve.status.searching:next(true)
end

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

  local bufnr = states.message.history_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    states.message.history_bufnr = bufnr

    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].filetype = eve.filetype.UX_MESSAGE_HISTORY
    vim.bo[bufnr].swapfile = false
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.attach, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false

  for lnum, entry in ipairs(entries) do
    local offset = 0 ---@type integer
    local row = lnum - 1 ---@type integer
    for _, item in ipairs(entry[2]) do
      local _, text_chunk, hlid = unpack(item) ---@type integer, string, integer
      local hlname = vim.fn.synIDattr(hlid, "name") ---@type string
      local offset_next = offset + #text_chunk ---@type integer
      vim.hl.range(bufnr, nsnrs.attach, hlname, { row, offset }, { row, offset_next })
      offset = offset_next ---@type integer
    end
  end

  local win_width = math.floor(vim.o.columns * 0.8) ---@type integer
  local win_height = math.floor(vim.o.lines * 0.8) ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = 100,
    relative = "editor",
    width = win_width,
    height = win_height,
    row = math.floor((vim.o.lines - win_height) / 2),
    col = math.floor((vim.o.columns - win_width) / 2),
    style = "minimal",
    border = "rounded",
    title = "message history",
    title_pos = "center",
    focusable = true,
  }

  local winnr = states.message.history_winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    wincfg.noautocmd = true
    winnr = vim.api.nvim_open_win(bufnr, true, wincfg)
    states.message.history_winnr = winnr

    vim.api.nvim_win_set_buf(winnr, bufnr)

    eve.win.set_type(winnr, eve.win.Types.BOARD)
    vim.w[winnr][eve.var.Names.WINLINE_DISABLED] = true

    vim.wo[winnr].cursorline = true
    vim.wo[winnr].number = true
    vim.wo[winnr].relativenumber = true
    vim.wo[winnr].signcolumn = "yes"
    vim.wo[winnr].spell = false
    vim.wo[winnr].winfixbuf = true
    vim.wo[winnr].winhighlight = "Normal:f_uc_normal,FloatBorder:f_uc_border,CursorLine:f_uc_normal"
    vim.wo[winnr].wrap = false
  else
    vim.wo[winnr].winfixbuf = false
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_win_set_config(winnr, wincfg)
    vim.wo[winnr].winfixbuf = true
  end
end

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
function M.show(task)
  local kind, content, replace_last, history = unpack(task.args)
  ---@cast kind                         string
  ---@cast content                      [integer, string, integer][]
  ---@cast replace_last                 boolean
  ---@cast history                      boolean

  if kind == "confirm" then
    states.message.confirming_task = task
    return
  end

  if kind == "search_count" or kind == "search_cmd" then
    eve.status.searching:next(true)
    local line = vim.fn.line(".") - 1
    local virt_text = {} ---@type string[][]
    for _, piece in ipairs(content) do
      local text = vim.trim(piece[2]) ---@type string
      table.insert(virt_text, { text, "f_um_search_count" })
    end

    vim.api.nvim_buf_clear_namespace(0, nsnrs.search_count, 0, -1)
    vim.api.nvim_buf_set_extmark(0, nsnrs.search_count, line, -1, {
      virt_text = virt_text,
      virt_text_pos = "eol",
      hl_mode = "combine",
    })
    return
  end

  local level = kind_2_level_map[kind] or vim.log.levels.INFO
  local title = #kind > 0 and string.format("%s | %s", task.event, kind) or task.event ---@type string
  local message = "" ---@type string
  for _, item in ipairs(content) do
    message = message .. item[2] ---@type string
  end

  if KIND_MAP.CHANGES[kind] == true then
    eve.status.msg_changes:next(message)
  end

  local highlights = {} ---@type eve.t.IHighlight[]
  local lnum, col_offset = 1, 0 ---@type integer, integer
  for _, item in ipairs(content) do
    local _, text, hlid = unpack(item) ---@type integer, string, integer
    local hlname = vim.fn.synIDattr(hlid, "name") ---@type string
    local lines = vim.split(text, "\n", { plain = true }) ---@type string[]
    for i, line in ipairs(lines) do
      if i > 1 then
        lnum = lnum + 1
        col_offset = 0
      end
      if #line > 0 then
        ---@type eve.t.IHighlight
        local highlight = {
          lnum = lnum,
          coll = col_offset,
          colr = col_offset + #line,
          hlname = hlname,
        }
        highlights[#highlights + 1] = highlight
        col_offset = col_offset + #line
      end
    end
  end

  local group = replace_last and states.message.last_group or nil ---@type string|nil
  if group == nil then
    local md5 = eve.std.md5.new():update(tostring(level)):update(title):update(message):finish()
    group = eve.std.md5.tohex(md5) ---@type string
  end
  states.message.last_group = group

  local anonymous = KIND_MAP.CHANGES[kind] ~= true and kind ~= "echo" and not history ---@type boolean
  local silent = KIND_MAP.CHANGES[kind] == true ---@type boolean
  vim.notify(message, level, {
    group = group,
    title = title,
    timeout = 3000,
    message = message,
    highlights = highlights,
    anonymous = anonymous,
    silent = silent,
  })
end

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
---@diagnostic disable-next-line: unused-local
function M.showcmd(task)
  local contents = unpack(task.args)
  ---@cast contents                     [integer, string, integer][]

  if #contents < 1 then
    return
  end

  local text = "" ---@type string
  for _, item in ipairs(contents) do
    local _, piece = unpack(item) ---@type integer, string
    text = text .. piece
  end
  eve.status.msg_command:next(text)
  eve.status.dirtier_statusline:mark_dirty()
end

function M.showmode(task)
  local contents = unpack(task.args)
  ---@cast contents                     [integer, string, integer][]

  local text = "" ---@type string
  for _, item in ipairs(contents) do
    local _, piece = unpack(item) ---@type integer, string
    text = text .. piece
  end
  eve.status.msg_mode:next(text)
end

return M
