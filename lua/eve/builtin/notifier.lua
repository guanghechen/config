---@alias eve.builtin.notifier.LevelEnum
---| 'TRACE'
---| 'DEBUG'
---| 'INFO'
---| 'WARN'
---| 'ERROR'

---@class eve.builtin.notifier.ITask
---@field public group                  string|nil
---@field public level                  string
---@field public title                  string
---@field public lines                  string[]
---@field public width                  integer
---@field public height                 integer
---@field public timeout                integer
---@field public timestamp              integer

---@class eve.builtin.notifier.IWindow
---@field public winnr                  integer|nil
---@field public bufnr                  integer|nil
---@field public tick                   integer
---@field public task                   eve.builtin.notifier.ITask
---@field public row                    integer

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
      "FloatBorder:f_notify_border_trace",
      "Normal:f_notify_normal_trace",
    }, ","),
    DEBUG = table.concat({
      "FloatBorder:f_notify_border_debug",
      "Normal:f_notify_normal_debug",
    }, ","),
    INFO = table.concat({
      "FloatBorder:f_notify_border_info",
      "Normal:f_notify_normal_info",
    }, ","),
    WARN = table.concat({
      "FloatBorder:f_notify_border_warn",
      "Normal:f_notify_normal_warn",
    }, ","),
    ERROR = table.concat({
      "FloatBorder:f_notify_border_error",
      "Normal:f_notify_normal_error",
    }, ","),
  },
  winbar = {
    TRACE = "f_notify_winbar_trace",
    DEBUG = "f_notify_winbar_debug",
    INFO = "f_notify_winbar_info",
    WARN = "f_notify_winbar_warn",
    ERROR = "f_notify_winbar_error",
  },
}

---@type string[]
local blocking_modes = { "ic", "ix", "c", "no", "r%?", "rm" }

---@protected
---@return boolean
local function is_blocking()
  return true
  -- local mode = vim.api.nvim_get_mode() ---@type vim.api.keyset.get_mode
  -- if mode.blocking then
  --   return true
  -- end
  --
  -- for _, m in ipairs(blocking_modes) do
  --   if mode.mode:find(m) == 1 then
  --     return true
  --   end
  -- end
  -- return false
end

local __TASKS__ = eve.std.CircularQueue.new({ capacity = 100 })
local __WINS__ = {} ---@type eve.builtin.notifier.IWindow[]

---@class eve.builtin.notifier
local M = {}


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

---@param level                         eve.builtin.notifier.LevelEnum
---@param group                         string|nil
---@param title                         string
---@param message                       string
---@param timeout                       integer
---@return nil
function M.notify(level, group, title, message, timeout)
  local lines = vim.split(message, "\n", { plain = true }) ---@type string[]
  local width = vim.api.nvim_strwidth(message) + 14 ---@type integer
  for _, line in ipairs(lines) do
    local line_width = vim.api.nvim_strwidth(line) + 4 ---@type integer
    width = width < line_width and line_width or width
  end

  ---@type eve.builtin.notifier.ITask
  local task = {
    group = group,
    level = level,
    title = title,
    lines = lines,
    width = width,
    height = #lines,
    timeout = timeout,
    timestamp = os.time(),
  }
  __TASKS__:enqueue(task)
  M.schedule()
end

---@param group                         string|nil
---@param title                         string
---@param message                       string
---@param timeout                       integer
---@return nil
function M.trace(group, title, message, timeout)
  return M.notify("TRACE", group, title, message, timeout)
end

---@param group                         string|nil
---@param title                         string
---@param message                       string
---@param timeout                       integer
---@return nil
function M.debug(group, title, message, timeout)
  return M.notify("DEBUG", group, title, message, timeout)
end

---@param group                         string|nil
---@param title                         string
---@param message                       string
---@param timeout                       integer
---@return nil
function M.info(group, title, message, timeout)
  return M.notify("INFO", group, title, message, timeout)
end

---@param group                         string|nil
---@param title                         string
---@param message                       string
---@param timeout                       integer
---@return nil
function M.warn(group, title, message, timeout)
  return M.notify("WARN", group, title, message, timeout)
end

---@param group                         string|nil
---@param title                         string
---@param message                       string
---@param timeout                       integer
---@return nil
function M.error(group, title, message, timeout)
  return M.notify("ERROR", group, title, message, timeout)
end

---@return nil
function M.dismiss_all()
  local wins = __WINS__ ---@type eve.builtin.notifier.IWindow[]
  __WINS__ = {} ---@type eve.builtin.notifier.IWindow[]
  for _, win in ipairs(wins) do
    M.destroy_win(win)
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
            vim.cmd.close()
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

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, win.task.lines)
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
  local width = math.min(82, vim.o.columns, task.width) ---@type integer
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

    vim.wo[winnr].conceallevel = 2
    vim.wo[winnr].concealcursor = "n"
    vim.wo[winnr].cursorline = false
    vim.wo[winnr].number = false
    vim.wo[winnr].relativenumber = false
    vim.wo[winnr].signcolumn = "no"
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
  local text_title = task.title or "" ---@type string
  local text_time = os.date("%H:%M:%S", task.timestamp)

  local max_width_title = width - 14 ---@type integer
  local width_title = vim.api.nvim_strwidth(text_title) ---@type integer
  if width_title > max_width_title then
    text_title = text_title:sub(1, max_width_title)
    width_title = vim.api.nvim_strwidth(text_title) ---@type integer
  end

  local text_blank = string.rep(" ", width - width_title - 12) ---@type string
  local text = string.format(" %s %s%s%s ", eve.icon.loglevel[task.level], text_title, text_blank, text_time)
  return eve.nvim.txt(text, config.winbar[task.level])
end

---@protected
---@param next_task                     eve.builtin.notifier.ITask|nil
---@return boolean
function M.relayout(next_task)
  local invalid_wins = {} ---@type eve.builtin.notifier.IWindow[]
  local requeue_tasks = {} ---@type eve.builtin.notifier.ITask[]
  local wins = __WINS__ ---@type eve.builtin.notifier.IWindow[]
  __WINS__ = {} ---@type eve.builtin.notifier.IWindow[]

  local win_task = nil ---@type eve.builtin.notifier.IWindow|nil
  local group = next_task ~= nil and next_task.group or nil ---@type string|nil
  local row = 1 ---@type integer
  local room_enough = true---@type boolean
  for _, win in ipairs(wins) do
    local winnr = win.winnr ---@type integer|nil
    if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
      goto continue
    end

    if not room_enough then
      invalid_wins[#invalid_wins + 1] = win
      requeue_tasks[#requeue_tasks + 1] = win.task
      goto continue
    end

    if group ~= nil and win.task.group == group then
      win_task = win ---@type eve.builtin.notifier.IWindow
      win.task = next_task ---@type eve.builtin.notifier.ITask|nil
    end

    local next_row = row + win.task.height + 3  ---@type integer
    if next_row > vim.o.lines then
      room_enough = false
      invalid_wins[#invalid_wins + 1] = win
      requeue_tasks[#requeue_tasks + 1] = win.task
      goto continue
    end

    win.row = row ---@type integer
    __WINS__[#__WINS__ + 1] = win
    row = next_row ---@type integer
    ::continue::
  end

  if win_task == nil and next_task ~= nil then
    if room_enough and row + next_task.height + 3 <= vim.o.lines then
      ---@type eve.builtin.notifier.IWindow
      local win = {
        winnr = nil,
        bufnr = nil,
        tick = 0,
        task = next_task,
        row = row,
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

  for _, win in ipairs(__WINS__) do
    if win ~= win_task then
      local wincfg = vim.api.nvim_win_get_config(win.winnr) ---@type vim.api.keyset.win_config
      wincfg.row = win.row
      wincfg.noautocmd = nil
      vim.api.nvim_win_set_config(win.winnr, wincfg)
    end
  end

  if win_task ~= nil then
    win_task.tick = win_task.tick + 1
    local winnr = M.create_win_as_needed(win_task) ---@type integer
    local tick = win_task.tick ---@type integer
    vim.defer_fn(function()
      if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) and win_task.tick == tick then
        vim.api.nvim_win_close(winnr, true)
        M.schedule()
      end
    end, win_task.task.timeout)
  end

  for _, win in ipairs(invalid_wins) do
    M.destroy_win(win)
  end
  return room_enough and win_task ~= nil
end

---@protected
---@return nil
function M.schedule()
  vim.schedule(M.handle)
end

---@protected
---@return nil
function M.handle()
  if is_blocking() then
    local task = __TASKS__:dequeue() ---@type eve.builtin.notifier.ITask|nil
    if task ~= nil and M.relayout(task) then
      M.schedule()
    end
  end
end


vim.api.nvim_create_autocmd("WinEnter", {
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    for _, win in ipairs(__WINS__) do
      if win.winnr == winnr then
        win.tick = win.tick + 1
        break
      end
    end
  end,
})

return M
