---@alias eve.builtin.notify.LevelEnum
---| 'TRACE'
---| 'DEBUG'
---| 'INFO'
---| 'WARN'
---| 'ERROR'
---| 'OFF'

---@class eve.builtin.notify.ITask
---@field public group                  string
---@field public level                  string
---@field public title                  string
---@field public lines                  string[]
---@field public width                  integer
---@field public height                 integer
---@field public timeout                integer
---@field public timestamp              integer

---@class eve.builtin.notify.IWindow
---@field public group                  string
---@field public winnr                  integer|nil
---@field public bufnr                  integer|nil
---@field public tick                   integer
---@field public task                   eve.builtin.notify.ITask|nil
---@field public row                    integer

local txt = eve.nvim.txt

---@class eve.eve.notify.Levels
local Levels = {
  TRACE = vim.log.levels.TRACE,
  DEBUG = vim.log.levels.DEBUG,
  INFO = vim.log.levels.INFO,
  WARN = vim.log.levels.WARN,
  ERROR = vim.log.levels.ERROR,
}

local config = {
  winhighlight = {
    TRACE = table.concat({
      "FloatBorder:f_notify_border_trace",
      "Normal:NormalFloat",
    }, ","),
    DEBUG = table.concat({
      "FloatBorder:f_notify_border_debug",
      "Normal:NormalFloat",
    }, ","),
    INFO = table.concat({
      "FloatBorder:f_notify_border_info",
      "Normal:NormalFloat",
    }, ","),
    WARN = table.concat({
      "FloatBorder:f_notify_border_warn",
      "Normal:NormalFloat",
    }, ","),
    ERROR = table.concat({
      "FloatBorder:f_notify_border_error",
      "Normal:NormalFloat",
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

local __TASKS__ = eve.std.CircularQueue.new({ capacity = 100 })
local __WINS__ = {} ---@type eve.builtin.notify.IWindow[]

---@class eve.builtin.notify
local M = {}

---@param group                         string
---@param level                         eve.eve.notify.LevelEnum
---@param title                         string
---@param message                       string
---@param timeout                       integer
---@return nil
function M.notify(group, level, title, message, timeout)
  local lines = vim.split(message, "\n", { plain = true }) ---@type string[]
  local width = vim.api.nvim_strwidth(message) + 12 ---@type integer
  for _, line in ipairs(lines) do
    local line_width = vim.api.nvim_strwidth(line) + 12 ---@type integer
    width = width < line_width and line_width or width
  end

  ---@type eve.builtin.notify.ITask
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

---@protected
---@param win                           eve.builtin.notify.IWindow
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
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].readonly = true

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
      {
        modes = { "i", "n", "v", "c" },
        key = "<LeftMouse>",
        desc = "notify: focus",
        callback = function()
          win.tick = win.tick + 1
        end,
      },
    }
    eve.nvim.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
  end

  local task = win.task ---@type eve.builtin.notify.ITask
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, task.lines)
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
---@param win                           eve.builtin.notify.IWindow
---@return integer
function M.create_win_as_needed(win)
  local task = win.task ---@type eve.builtin.notify.ITask
  local width = math.min(82, vim.o.columns, task.width) ---@type integer
  local height = math.min(10, vim.o.lines, task.height) ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = 100,
    relative = "editor",
    anchor = "NE",
    col = vim.o.columns - 1,
    row = win.row,
    width = width,
    height = height,
  }

  local bufnr = M.create_buf_as_needed(win) ---@type integer
  local winnr = win.winnr ---@type integer|nil

  if winnr == nil or not eve.editor.is_win_valid(winnr) then
    wincfg.noautocmd = true
    winnr = vim.api.nvim_open_win(bufnr, true, wincfg) ---@type integer
    win.winnr = winnr

    vim.wo[winnr].cursorline = true
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
---@param win                           eve.builtin.notify.IWindow
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
---@param task                          eve.builtin.notify.ITask
---@param width                         integer
---@return string
function M.gen_winbar(task, width)
  local text_title = task.title or "" ---@type string
  local text_time = os.date("%H:%M:%S", task.timestamp)

  local max_width_title = width - 8 - 6 ---@type integer
  local width_title = vim.api.nvim_strwidth(text_title) ---@type integer
  if width_title > max_width_title then
    text_title = text_title:sub(1, max_width_title)
    width_title = vim.api.nvim_strwidth(text_title) ---@type integer
  end

  local text_blank = string.rep(" ", width - text_title - 3 - width_title - 8) ---@type string
  local text = string.format(" %s %s%s%s", eve.icon.loglevel[task.level], text_title, text_blank, text_time)
  return txt(text, config.winbar[task.level])
end

---@protected
---@param next_task                     eve.builtin.notify.ITask|nil
---@return boolean
function M.relayout(next_task)
  local group = next_task ~= nil and next_task.group or nil ---@type string|nil
  local win_task = nil ---@type eve.builtin.notify.IWindow|nil
  local row = 1 ---@type integer

  local invalid_wins = {} ---@type eve.builtin.notify.IWindow[]
  local requeue_tasks = {} ---@type eve.builtin.notify.ITask[]
  local wins = __WINS__ ---@type eve.builtin.notify.IWindow[]
  __WINS__ = {} ---@type eve.builtin.notify.IWindow[]
  for _, win in ipairs(wins) do
    local winnr = win.winnr ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      if win.group == group then
        win_task = win ---@type eve.builtin.notify.IWindow
        win.task = next_task ---@type eve.builtin.notify.ITask|nil
      end

      win.row = row ---@type integer
      if win.row + win.task.height + 3 > vim.o.lines then
        invalid_wins[#invalid_wins + 1] = win
        if win.task ~= nil then
          requeue_tasks[#requeue_tasks + 1] = win.task
        end
      else
        __WINS__[#__WINS__ + 1] = win
      end
    end
  end

  if not win_task and next_task ~= nil then
    if row + next_task.height + 3 < vim.o.lines then
      ---@type eve.builtin.notify.IWindow
      local win = {
        group = next_task.group,
        winnr = nil,
        bufnr = nil,
        tick = 0,
        task = next_task,
        row = row,
      }
      win_task = win ---@type eve.builtin.notify.IWindow
      __WINS__[#__WINS__ + 1] = win
    else
      requeue_tasks[#requeue_tasks + 1] = next_task
    end
  end

  for index = #requeue_tasks, 1, -1 do
    local task = requeue_tasks[index] ---@type eve.builtin.notify.ITask
    __TASKS__:enqueue_front(task)
  end

  for _, win in ipairs(__WINS__) do
    ---@cast win eve.builtin.notify.IWindow
    if win == win_task then
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
      local wincfg = vim.api.nvim_win_get_config(win.winnr) ---@type vim.api.keyset.win_config
      wincfg.row = win.row
      wincfg.noautocmd = false
      vim.api.nvim_win_set_config(win.winnr, wincfg)
    end
  end

  vim.schedule(function()
    for _, win in ipairs(invalid_wins) do
      M.destroy_win(win)
    end
  end)

  return win_task ~= nil
end

---@protected
---@return nil
function M.schedule()
  if is_blocking() then
    while true do
      local task = __TASKS__:dequeue() ---@type eve.builtin.notify.ITask|nil
      if task == nil or not M.relayout(task) then
        break
      end
    end
  end
end

return M
