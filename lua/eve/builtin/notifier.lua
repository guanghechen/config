---@alias eve.builtin.notifier.LevelEnum
---| 'TRACE'
---| 'DEBUG'
---| 'INFO'
---| 'WARN'
---| 'ERROR'

---@class eve.builtin.notifier.ITask
---@field public uuid                   string
---@field public group                  string|nil
---@field public level                  string
---@field public title                  string
---@field public content                string
---@field public lines                  string[]
---@field public width                  integer
---@field public height                 integer
---@field public times                  integer
---@field public timeout                integer
---@field public timestamp              integer

---@class eve.builtin.notifier.IWindow
---@field public winnr                  integer|nil
---@field public bufnr                  integer|nil
---@field public tick                   integer
---@field public task                   eve.builtin.notifier.ITask
---@field public row                    integer
---@field public dirty                  boolean

---@class eve.builtin.notifier.Levels
local Levels = {
  TRACE = vim.log.levels.TRACE,
  DEBUG = vim.log.levels.DEBUG,
  INFO = vim.log.levels.INFO,
  WARN = vim.log.levels.WARN,
  ERROR = vim.log.levels.ERROR,
}

---@class eve.builtin.notifier.LevelMap
local LevelMap = {
  TRACE = "TRACE",
  DEBUG = "DEBUG",
  INFO  = "INFO",
  WARN  = "WARN",
  ERROR = "ERROR",
  [vim.log.levels.TRACE] = "TRACE",
  [vim.log.levels.DEBUG] = "DEBUG",
  [vim.log.levels.INFO]  = "INFO",
  [vim.log.levels.WARN]  = "WARN",
  [vim.log.levels.ERROR] = "ERROR",
}

---@class eve.builtin.notifier.LevelTitleMap 
local LevelTitleMap = {
  TRACE = "Trace",
  DEBUG = "Debug",
  INFO  = "Information",
  WARN  = "Warning",
  ERROR = "Error",
}

local config = {
  winhighlight = {
    TRACE = table.concat({
      "FloatBorder:f_un_border_trace",
      "Normal:f_un_normal_trace",
    }, ","),
    DEBUG = table.concat({
      "FloatBorder:f_un_border_debug",
      "Normal:f_un_normal_debug",
    }, ","),
    INFO = table.concat({
      "FloatBorder:f_un_border_info",
      "Normal:f_un_normal_info",
    }, ","),
    WARN = table.concat({
      "FloatBorder:f_un_border_warn",
      "Normal:f_un_normal_warn",
    }, ","),
    ERROR = table.concat({
      "FloatBorder:f_un_border_error",
      "Normal:f_un_normal_error",
    }, ","),
  },
  winbar = {
    TRACE = "f_un_winbar_trace",
    DEBUG = "f_un_winbar_debug",
    INFO = "f_un_winbar_info",
    WARN = "f_un_winbar_warn",
    ERROR = "f_un_winbar_error",
  },
}

---@type string[]
local blocking_modes = { "ic", "ix", "c", "no", "r%?", "rm" }

local __TASKS__ = eve.std.CircularQueue.new({ capacity = 100 })
local __TASK_HISTORY__ = eve.std.CircularQueue.new({ capacity = 200 })
local __WINS__ = {} ---@type eve.builtin.notifier.IWindow[]

---@class eve.builtin.notifier
local M = {}

---@protected
---@return boolean
function M.is_blocking()
  local mode = vim.api.nvim_get_mode() ---@type vim.api.keyset.get_mode
  if mode.blocking then
    return true
  end

  for _, m in ipairs(blocking_modes) do
    if mode.mode:find(m) == 1 then
      return true
    end
  end
  return false
end

---@return nil
function M.dismiss_all()
  local wins = __WINS__ ---@type eve.builtin.notifier.IWindow[]
  __WINS__ = {} ---@type eve.builtin.notifier.IWindow[]
  for _, win in ipairs(wins) do
    M.destroy_win(win)
  end
end

---@return eve.builtin.notifier.ITask[]
function M.history()
  return __TASK_HISTORY__:collect()
end

---@return nil
function M.pause()
  eve.state.status.notification_paused:next(true)
end

---@return nil
function M.resume()
  eve.state.status.notification_paused:next(false)
  M.schedule()
end

---@param level                         number
---@return eve.builtin.notifier.LevelEnum
function M.resolve_level(level)
  return LevelMap[level] or "INFO"
end

---@param level                         eve.builtin.notifier.LevelEnum
---@return string
function M.resolve_title(level)
  return LevelTitleMap[level]
end

---@return nil
function M.schedule()
  local notification_paused = eve.state.status.notification_paused:snapshot() ---@type boolean
  if notification_paused then
    return
  end
  vim.schedule(M.handle)
end

---@param level                         eve.builtin.notifier.LevelEnum
---@param group                         string|nil
---@param title                         string
---@param message                       string
---@param timeout                       integer
---@param anonymous                     boolean
---@param silent                        boolean
---@return nil
function M.notify(level, group, title, message, timeout, anonymous, silent)
  local timestamp = os.time() ---@type integer
  local lines = vim.split(message, "\n", { plain = true }) ---@type string[]
  local width = vim.api.nvim_strwidth(title) + 14 ---@type integer
  for _, line in ipairs(lines) do
    local line_width = vim.api.nvim_strwidth(line) + 4 ---@type integer
    width = width < line_width and line_width or width
  end

  local md5 = eve.std.md5.new()
    :update(level)
    :update(group or "")
    :update(title)
    :update(message)
    :finish()
  local uuid = eve.std.md5.tohex(md5) ---@type string

  ---@type eve.builtin.notifier.ITask
  local task = {
    uuid = uuid,
    group = group,
    level = level,
    title = title,
    content = message,
    lines = lines,
    width = width,
    height = #lines + 1,
    times = 1,
    timeout = timeout,
    timestamp = timestamp,
  }

  local notification_paused = eve.state.status.notification_paused:snapshot() ---@type boolean
  local notification_level = eve.state.status.notification_level:snapshot() ---@type eve.builtin.notifier.LevelEnum
  local notification_priority = Levels[notification_level] ---@type integer
  local priority = Levels[level] ---@type integer

  if anonymous ~= true then
    __TASK_HISTORY__:enqueue(task)
  end

  if silent ~= true and not notification_paused and priority >= notification_priority then
    local inserted = false ---@type boolean
    if not inserted then
      for t, index in __TASKS__:iterator() do
        if t.uuid == uuid then
          inserted = true
          task.times = t.times + 1
          __TASKS__:update(index, task)
          break
        end
      end
    end

    if not inserted then
      for _, w in ipairs(__WINS__) do
        if
          w.task.uuid == uuid and
          w.winnr ~= nil and
          w.bufnr ~= nil and
          vim.api.nvim_win_is_valid(w.winnr) and
          vim.api.nvim_buf_is_valid(w.bufnr)
        then
          inserted = true
          __TASKS__:enqueue_front(task)
          break
        end
      end
    end

    if not inserted then
      __TASKS__:enqueue(task)
    end
    M.schedule()
  end
end

---@protected
---@param win                           eve.builtin.notifier.IWindow
---@return integer
function M.create_buf_as_needed(win)
  local bufnr = win.bufnr ---@type integer|nil
  if bufnr == nil or not eve.editor.is_buf_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    win.bufnr = bufnr

    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].filetype = eve.filetype.NOTIFY
    vim.bo[bufnr].swapfile = false

    ---@type eve.t.IKeymap[]
    local keymaps = {
      {
        modes = { "n", "v" },
        key = "q",
        desc = "notify: close",
        callback = function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
            M.schedule()
          end
        end,
      },
    }
    eve.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
  else
    vim.bo[bufnr].modifiable = true
    vim.bo[bufnr].readonly = false
  end

  vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, win.task.lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true

  if vim.treesitter ~= nil and vim.treesitter.language ~= nil then
    local lang = vim.treesitter.language.get_lang("markdown") or "markdown" ---@type string
    local has_ts_parser = pcall(vim.treesitter.language.add, lang)
    if has_ts_parser then
      vim.treesitter.start(bufnr, lang)
    end
  end
  return bufnr
end

---@protected
---@param win                           eve.builtin.notifier.IWindow
---@return integer
function M.create_win_as_needed(win)
  local task = win.task ---@type eve.builtin.notifier.ITask
  local extra_width = 0 ---@type integer
  if task.times > 1 then
    extra_width = vim.api.nvim_strwidth(string.format(" (x%d) ", task.times)) ---@type integer
  end
  local width = math.min(82, vim.o.columns, task.width + extra_width) ---@type integer
  local height = math.min(42, vim.o.lines - 4, task.height) ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = 100,
    relative = "editor",
    anchor = "NE",
    col = vim.o.columns - 1,
    row = win.row,
    width = width,
    height = height + 1,
    border = "rounded",
    style = "minimal",
    focusable = true,
  }

  local bufnr = M.create_buf_as_needed(win) ---@type integer
  local winnr = win.winnr ---@type integer|nil

  if winnr == nil or not eve.editor.is_win_valid(winnr) then
    wincfg.noautocmd = true
    winnr = vim.api.nvim_open_win(bufnr, false, wincfg) ---@type integer
    win.winnr = winnr

    vim.w[winnr][eve.var.Names.WIN_TYPE_NOTIFIER] = true
    vim.w[winnr][eve.var.Names.WINLINE_DISABLED] = true
    vim.w[winnr][eve.var.Names.FLAG_SOURCEFILE] = false

    vim.wo[winnr].conceallevel = 2
    vim.wo[winnr].concealcursor = "n"
    vim.wo[winnr].cursorline = false
    vim.wo[winnr].number = false
    vim.wo[winnr].relativenumber = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].spell= false
    vim.wo[winnr].wrap = false
  else
    vim.wo[winnr].winfixbuf = false
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_win_set_config(winnr, wincfg)
  end

  local winbar = M.gen_winbar(task, width) ---@type string
  local winblend = eve.state.theme.get_float_winblend() ---@type integer
  local winhighlight = config.winhighlight[task.level] ---@type string

  vim.wo[winnr].winbar = winbar
  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].winfixbuf = true
  vim.wo[winnr].winhighlight = winhighlight
  return winnr
end

---@protected
---@param win                           eve.builtin.notifier.IWindow
---@return nil
function M.destroy_win(win)
  if win.winnr ~= nil and vim.api.nvim_win_is_valid(win.winnr) then
    vim.api.nvim_win_close(win.winnr, true)
    win.winnr = nil
  end

  if win.bufnr ~= nil and vim.api.nvim_buf_is_valid(win.bufnr) then
    vim.api.nvim_buf_delete(win.bufnr, { force = true })
    win.bufnr = nil
  end
  win.tick = 0
end

---@protected
---@param task                          eve.builtin.notifier.ITask
---@param width                         integer
---@return string
function M.gen_winbar(task, width)
  local text_time = os.date("%H:%M:%S", task.timestamp)
  local text_title = task.times > 1
    and string.format("%s (x%d) ", task.title, task.times)
    or task.title

  local max_width_title = width - 14 ---@type integer
  local width_title = vim.api.nvim_strwidth(text_title) ---@type integer
  if width_title > max_width_title then
    text_title = text_title:sub(1, max_width_title)
    width_title = vim.api.nvim_strwidth(text_title) ---@type integer
  end

  local text_blank = string.rep(" ", width - width_title - 10) ---@type string
  local text = string.format("%s %s%s%s", eve.icon.loglevel[task.level], text_title, text_blank, text_time)
  return eve.nvim.txt(text, config.winbar[task.level])
end

---@protected
---@param next_task                     eve.builtin.notifier.ITask|nil
---@return boolean
function M.relayout(next_task)
  local requeue_tasks = {} ---@type eve.builtin.notifier.ITask[]
  local invalid_wins = {} ---@type eve.builtin.notifier.IWindow[]
  local wins = __WINS__ ---@type eve.builtin.notifier.IWindow[]
  __WINS__ = {} ---@type eve.builtin.notifier.IWindow[]

  local win_task = nil ---@type eve.builtin.notifier.IWindow|nil
  local row = 1 ---@type integer
  local room_enough = true---@type boolean
  for _, win in ipairs(wins) do
    local winnr = win.winnr ---@type integer|nil
    if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
      goto continue
    end

    if not room_enough then
      requeue_tasks[#requeue_tasks + 1] = win.task
      invalid_wins[#invalid_wins + 1] = win
      goto continue
    end

    if next_task ~= nil then
      if win.task.uuid == next_task.uuid then
        next_task.times = next_task.times + win.task.times ---@type integer
        win.task = next_task ---@type eve.builtin.notifier.ITask|nil
        win.dirty = true
        win_task = win ---@type eve.builtin.notifier.IWindow
      elseif win.task.group ~= nil and win.task.group == next_task.group then
        win.task = next_task ---@type eve.builtin.notifier.ITask|nil
        win.dirty = true
        win_task = win ---@type eve.builtin.notifier.IWindow
      end
    end

    local height = math.min(42, vim.o.lines - 4, win.task.height) ---@type integer
    local next_row = row + height + 3  ---@type integer
    if next_row > vim.o.lines then
      requeue_tasks[#requeue_tasks + 1] = win.task
      invalid_wins[#invalid_wins + 1] = win
      room_enough = false
      goto continue
    end

    win.row = row ---@type integer
    row = next_row ---@type integer
    __WINS__[#__WINS__ + 1] = win
    ::continue::
  end

  if win_task == nil and next_task ~= nil then
    local height = math.min(42, vim.o.lines - 4, next_task.height) ---@type integer
    if room_enough and row + height + 3 <= vim.o.lines then
      ---@type eve.builtin.notifier.IWindow
      local win = {
        winnr = nil,
        bufnr = nil,
        tick = 0,
        task = next_task,
        row = row,
        dirty = true,
      }
      win_task = win ---@type eve.builtin.notifier.IWindow
      __WINS__[#__WINS__ + 1] = win
    else
      room_enough = false
      requeue_tasks[#requeue_tasks + 1] = next_task
    end
  end

  for index = #requeue_tasks, 1, -1 do
    local task = requeue_tasks[index] ---@type eve.builtin.notifier.ITask
    __TASKS__:enqueue_front(task)
  end

  for _, win in ipairs(invalid_wins) do
    M.destroy_win(win)
  end

  for _, win in ipairs(__WINS__) do
    if win.dirty then
      win.tick = win.tick + 1
      local winnr = M.create_win_as_needed(win) ---@type integer
      local tick = win.tick ---@type integer
      vim.defer_fn(function()
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) and win.tick == tick then
          vim.api.nvim_win_close(winnr, true)
          M.schedule()
        end
      end, win.task.timeout)
    else
      local task = win.task ---@type eve.builtin.notifier.ITask
      local extra_width = 0 ---@type integer
      if task.times > 1 then
        extra_width = vim.api.nvim_strwidth(string.format(" (x%d) ", task.times)) ---@type integer
      end
      local width = math.min(82, vim.o.columns, task.width + extra_width) ---@type integer
      local height = math.min(42, vim.o.lines - 4, task.height) ---@type integer
      local wincfg = vim.api.nvim_win_get_config(win.winnr) ---@type vim.api.keyset.win_config
      local winbar = wincfg.width ~= width and M.gen_winbar(task, width) or vim.wo[win.winnr].winbar

      wincfg.row = win.row
      wincfg.width = width
      wincfg.height = height + 1
      vim.api.nvim_win_set_config(win.winnr, wincfg)
      vim.wo[win.winnr].winbar = winbar
    end
  end

  return room_enough and win_task ~= nil
end

---@protected
---@return nil
function M.handle()
  local task = __TASKS__:dequeue() ---@type eve.builtin.notifier.ITask|nil
  if task ~= nil and M.relayout(task) then
    M.schedule()
  end
end

vim.api.nvim_create_autocmd("WinEnter", {
  group = eve.nvim.augroup("notifier_on_win_enter"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    if vim.w[winnr][eve.var.Names.WIN_TYPE_NOTIFIER] then
      for _, win in ipairs(__WINS__) do
        if win.winnr == winnr then
          win.tick = win.tick + 1
          break
        end
      end
    end
  end,
})

vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, {
  group = eve.nvim.augroup("notifier_on_resize"),
  callback = function()
    M.schedule()
  end
})

return M
