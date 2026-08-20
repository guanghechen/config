---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.ui_attach.messages" ---@type string
local states = require("era.m.ui_attach.state")

local KIND_MAP = {
  TRANSIENT = {
    bufwrite = true,
    progress = true,
    undo = true,
  },
  CONFIRM = {
    confirm = true,
    confirm_sub = true,
    number_prompt = true,
  },
}

local TRANSIENT_TIMEOUT = 3000

local nsnrs = dot.var.nsnr ---@type dot.var.nsnr
local transient_generation = 0
local batch = {
  generation = 0,
  scheduled = false,
  has_empty = false,
  has_message = false,
}

local kind_2_level_map = {
  err = vim.log.levels.ERROR,
  echoerr = vim.log.levels.ERROR,
  emsg = vim.log.levels.ERROR,
  lua_error = vim.log.levels.ERROR,
  rpc_error = vim.log.levels.ERROR,
  shell_err = vim.log.levels.ERROR,
  warn = vim.log.levels.WARN,
  wmsg = vim.log.levels.WARN,
  info = vim.log.levels.INFO,
  debug = vim.log.levels.DEBUG,
}

---@class era.m.ui_attach.messages
local M = {}

---@param observable                    stl.c.Observable
---@param value                         string
---@return nil
local function update_statusline_message(observable, value)
  observable:next(value)
  dot.state.status.dirtier_statusline:mark_dirty()
end

---@return nil
local function reset_visible_messages()
  local groups = states.message.groups
  transient_generation = transient_generation + 1
  states.message.generation = states.message.generation + 1
  states.message.groups = {}
  states.message.id_refs = {}
  states.message.last_ref = nil
  update_statusline_message(dot.state.status.msg_transient, "")

  if next(groups) ~= nil then
    vim.schedule(function()
      for group in pairs(groups) do
        stl.reporter.dismiss(group)
      end
    end)
  end
end

---@return nil
local function reset_message_batch()
  batch.generation = batch.generation + 1
  batch.scheduled = false
  batch.has_empty = false
  batch.has_message = false
end

---@param empty                         boolean
---@return nil
local function track_message_batch(empty)
  batch.has_empty = batch.has_empty or empty
  batch.has_message = batch.has_message or not empty
  if batch.scheduled then
    return
  end

  batch.scheduled = true
  local generation = batch.generation
  vim.schedule(function()
    if batch.generation ~= generation then
      return
    end

    local should_clear = batch.has_empty and not batch.has_message
    batch.scheduled = false
    batch.has_empty = false
    batch.has_message = false
    if should_clear then
      reset_visible_messages()
    end
  end)
end

---@param id                            integer|string
---@return string
local function create_group(id)
  local generation = states.message.generation ---@type integer
  return string.format("ui_attach:message:%d:%s:%s", generation, type(id), tostring(id))
end

---@param id                            integer|string
---@param content                       era.m.ui_attach.IContent
---@param replace_last                  boolean
---@param append                        boolean
---@return era.m.ui_attach.message.IGroup
local function update_visible_message(id, content, replace_last, append)
  local ref = states.message.id_refs[id] ---@type era.m.ui_attach.message.IRef|nil
  local group = ref ~= nil and states.message.groups[ref.group] or nil ---@type era.m.ui_attach.message.IGroup|nil

  if group ~= nil and ref ~= nil then
    group.parts[ref.index] = { id = id, content = content }
  elseif append and states.message.last_ref ~= nil then
    local last_ref = states.message.last_ref --[[@as era.m.ui_attach.message.IRef]]
    group = states.message.groups[last_ref.group]
    if group ~= nil then
      ref = { group = group.key, index = #group.parts + 1 }
      group.parts[ref.index] = { id = id, content = content }
    end
  elseif replace_last and states.message.last_ref ~= nil then
    local last_ref = states.message.last_ref --[[@as era.m.ui_attach.message.IRef]]
    ref = last_ref
    group = states.message.groups[last_ref.group]
    if group ~= nil then
      local previous_part = group.parts[last_ref.index] --[[@as era.m.ui_attach.message.IPart]]
      local previous_id = previous_part.id
      if previous_id ~= id then
        states.message.id_refs[previous_id] = nil
      end
      group.parts[last_ref.index] = { id = id, content = content }
    end
  end

  if group == nil or ref == nil then
    local key = create_group(id)
    group = { key = key, parts = {} }
    states.message.groups[key] = group
    ref = { group = group.key, index = #group.parts + 1 }
    group.parts[ref.index] = { id = id, content = content }
  end

  states.message.id_refs[id] = ref
  states.message.last_ref = ref
  return group
end

---@param group                         era.m.ui_attach.message.IGroup
---@return string
---@return stl.t.IHighlight[]
local function render_group(group)
  local message = ""
  local highlights = {} ---@type stl.t.IHighlight[]
  local lnum, col_offset = 1, 0 ---@type integer, integer

  for _, part in ipairs(group.parts) do
    for _, item in ipairs(part.content) do
      local _, text, hlid = unpack(item) ---@type integer, string, integer
      message = message .. text

      local hlname = vim.fn.synIDattr(hlid, "name") ---@type string
      local lines = vim.split(text, "\n", { plain = true }) ---@type string[]
      for i, line in ipairs(lines) do
        if i > 1 then
          lnum = lnum + 1
          col_offset = 0
        end
        if #line > 0 then
          highlights[#highlights + 1] = {
            lnum = lnum,
            coll = col_offset,
            colr = col_offset + #line,
            hlname = hlname,
          }
          col_offset = col_offset + #line
        end
      end
    end
  end

  return message, highlights
end

---@param message                       string
---@return nil
local function show_transient_message(message)
  transient_generation = transient_generation + 1
  local generation = transient_generation
  local text = message:gsub("%c+", " ") ---@type string

  update_statusline_message(dot.state.status.msg_transient, vim.trim(text))
  vim.defer_fn(function()
    if transient_generation == generation then
      update_statusline_message(dot.state.status.msg_transient, "")
    end
  end, TRANSIENT_TIMEOUT)
end

---@param content                      era.m.ui_attach.IContent
---@return string
local function concat_content(content)
  local text = ""
  for _, item in ipairs(content) do
    text = text .. item[2]
  end
  return text
end

---@return nil
local function refresh_command_status()
  local values = {} ---@type string[]
  if states.message.showcmd ~= "" then
    values[#values + 1] = states.message.showcmd
  end
  if states.message.ruler ~= "" then
    values[#values + 1] = states.message.ruler
  end
  update_statusline_message(dot.state.status.msg_command, table.concat(values, "  "))
end

---@param task                          era.m.ui_attach.ITask
---@return nil
---@diagnostic disable-next-line: unused-local
function M.clear(task)
  reset_message_batch()
  reset_visible_messages()
end

---@param task                          era.m.ui_attach.ITask
---@return nil
function M.history_show(task)
  local entries = unpack(task.args)
  ---@cast entries                      [string, era.m.ui_attach.IContent, boolean][]

  local lines = {} ---@type string[]
  local positions = {} ---@type { row: integer, offset: integer }[]
  for index, entry in ipairs(entries) do
    local content = entry[2] ---@type era.m.ui_attach.IContent
    local text = "" ---@type string
    for _, item in ipairs(content) do
      text = text .. item[2]
    end
    local append = entry[3] == true ---@type boolean
    if append and #lines > 0 then
      positions[index] = { row = #lines - 1, offset = #lines[#lines] }
      lines[#lines] = lines[#lines] .. text
    else
      table.insert(lines, text)
      positions[index] = { row = #lines - 1, offset = 0 }
    end
  end

  local bufnr = states.message.history_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    states.message.history_bufnr = bufnr

    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", stl.filetype.UX_MESSAGE_HISTORY, { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.attach, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  for lnum, entry in ipairs(entries) do
    local position = positions[lnum]
    local offset = position.offset ---@type integer
    local row = position.row ---@type integer
    for _, item in ipairs(entry[2]) do
      local _, text_chunk, hlid = unpack(item) ---@type integer, string, integer
      local hlname = vim.fn.synIDattr(hlid, "name") ---@type string
      local offset_next = offset + #text_chunk ---@type integer
      vim.hl.range(bufnr, nsnrs.attach, hlname, { row, offset }, { row, offset_next })
      offset = offset_next ---@type integer
    end
  end

  local win_width = math.min(math.floor(vim.o.columns * 0.8), 120) ---@type integer
  local win_height = math.min(math.floor(vim.o.lines * 0.8), 40) ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = dot.var.zindex.MESSAGES,
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

    vim.w[winnr].wintype = stl.e.WinTypeEnum.BOARD
    vim.w[winnr][dot.var.N_WINLINE_DISABLED] = true

    vim.api.nvim_set_option_value("cursorline", true, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("number", true, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("relativenumber", true, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("signcolumn", "yes", { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("spell", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value(
      "winhighlight",
      "Normal:f_uc_normal,FloatBorder:f_uc_border,CursorLine:f_uc_normal",
      { win = winnr, scope = "local" }
    )
    vim.api.nvim_set_option_value("wrap", false, { win = winnr, scope = "local" })
  else
    vim.api.nvim_set_option_value("winfixbuf", false, { win = winnr, scope = "local" })
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_win_set_config(winnr, wincfg)
    vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr, scope = "local" })
  end
end

---@param task                          era.m.ui_attach.ITask
---@return nil
function M.show(task)
  local kind, content, replace_last, history, append, id = unpack(task.args)
  ---@cast kind                         string
  ---@cast content                      era.m.ui_attach.IContent
  ---@cast replace_last                 boolean
  ---@cast history                      boolean
  ---@cast append                       boolean
  ---@cast id                           integer|string

  append = append == true
  track_message_batch(kind == "empty")

  if kind == "empty" then
    return
  end

  if KIND_MAP.CONFIRM[kind] then
    states.message.confirming_task = task
    return
  end

  if kind == "search_cmd" then
    dot.state.status.searching:next(true)
    dot.state.status.clear_search_count()
    return
  end

  if kind == "search_count" then
    dot.state.status.searching:next(true)
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local bufnr = vim.api.nvim_get_current_buf() ---@type integer
    local texts = {} ---@type string[]
    for _, piece in ipairs(content) do
      local text = vim.trim(piece[2]) ---@type string
      texts[#texts + 1] = text
    end

    dot.state.status.set_search_count(winnr, bufnr, table.concat(texts))
    return
  end

  local level = kind_2_level_map[kind] or vim.log.levels.INFO
  local title = #kind > 0 and string.format("%s | %s", task.event, kind) or task.event ---@type string

  local group = update_visible_message(id, content, replace_last, append)
  local message, highlights = render_group(group)

  if KIND_MAP.TRANSIENT[kind] == true then
    show_transient_message(message)
  end

  local anonymous = KIND_MAP.TRANSIENT[kind] ~= true and kind ~= "echo" and not history ---@type boolean
  local silent = KIND_MAP.TRANSIENT[kind] == true ---@type boolean
  stl.reporter.log(level, {
    from = __module_name__,
    title = title,
    message = message,
    group = group.key,
    highlights = highlights,
    timeout = 3000,
    anonymous = anonymous,
    silent = silent,
  })
end

---@param task                          era.m.ui_attach.ITask
---@return nil
---@diagnostic disable-next-line: unused-local
function M.showcmd(task)
  local contents = unpack(task.args)
  ---@cast contents                     era.m.ui_attach.IContent
  states.message.showcmd = concat_content(contents)
  refresh_command_status()
end

function M.ruler(task)
  local contents = unpack(task.args)
  ---@cast contents                     era.m.ui_attach.IContent|nil
  states.message.ruler = contents ~= nil and concat_content(contents) or ""
  refresh_command_status()
end

function M.showmode(task)
  local contents = unpack(task.args)
  ---@cast contents                     era.m.ui_attach.IContent
  update_statusline_message(dot.state.status.msg_mode, concat_content(contents))
end

return M
