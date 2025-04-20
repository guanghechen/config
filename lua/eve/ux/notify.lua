---@alias eve.eve.notify.LevelEnum
---| 'TRACE'
---| 'DEBUG'
---| 'INFO'
---| 'WARN'
---| 'ERROR'
---| 'OFF'

---@class eve.eve.notify.Levels
local Levels = {
  TRACE = vim.log.levels.TRACE,
  DEBUG = vim.log.levels.DEBUG,
  INFO = vim.log.levels.INFO,
  WARN = vim.log.levels.WARN,
  ERROR = vim.log.levels.ERROR,
  OFF = vim.log.levels.OFF,
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
    OFF = table.concat({
      "FloatBorder:f_notify_border_off",
      "Normal:NormalFloat",
    }, ","),
  },
}

---@class eve.ux.notify.ITask
---@field public group                  string
---@field public level                  string
---@field public timeout                integer
---@field public title                  string
---@field public message_lines          string[]

---@class eve.ux.notify.IWindow
---@field public group                  string
---@field public winnr                  integer|nil
---@field public bufnr                  integer|nil
---@field public times                  integer

local tasks = eve.std.CircularQueue.new({ capacity = 100 })
local wins = eve.std.CircularQueue.new({ capacity = 5 })

---@class eve.ux.notify
local M = {}

---@param group                         string
---@param level                         eve.eve.notify.LevelEnum
---@param title                         string
---@param message                       string
---@return nil
function M.notify(group, level, title, message)
  local task = {
    group = group,
    level = level,
    title = title,
    message = message,
  }
  tasks:enqueue(task)
  M.schedule()
end

function M.schedule()
  if M.is_blocking() then
    local row = M.relayout() ---@type integer
    local remain_height = vim.o.lines - row ---@type integer

    local task = tasks:at(1) ---@type eve.ux.notify.ITask|nil
    if task ~= nil then
      if remain_height > 12 or remain_height > #task.message_lines + 2 then
        tasks:dequeue() ---@type eve.ux.notify.ITask|nil
        if task ~= nil then
          M.handle(task, row)
        end
      end
    end
  end
end

---@protected
---@param bufnr                         integer|nil
---@param task                          eve.ux.notify.ITask
---@return integer
function M.create_buf_as_needed(bufnr, task)
  if bufnr == nil or not eve.editor.is_buf_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
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
        desc = "widget: close present",
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
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, task.message_lines)
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
---@param winnr                         integer|nil
---@param bufnr                         integer
---@param task                          eve.ux.notify.ITask
---@return integer
function M.create_win_as_needed(winnr, bufnr, task)
  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = 100,
    relative = "editor",
    anchor = "NE",
    row = 1,
    col = vim.o.columns - 1,
    height = 20,
    width = 50,
  }

  if winnr == nil or not eve.editor.is_win_valid(winnr) then
    winnr = vim.api.nvim_open_win(bufnr, true, wincfg) ---@type integer
    vim.wo[winnr].number = false
    vim.wo[winnr].relativenumber = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].wrap = false
  else
    vim.wo[winnr].winfixbuf = false
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_win_set_config(winnr, wincfg)
  end

  local winblend = eve.state.theme.get_float_winblend() ---@type integer
  local winhighlight = config.winhighlight[task.level] ---@type string

  vim.wo[winnr].cursorline = true
  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].winfixbuf = true
  vim.wo[winnr].winhighlight = winhighlight
  return winnr
end

local blocking_modes = {
  "ic",
  "ix",
  "c",
  "no",
  "r%?",
  "rm",
}

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

---@protected
---@return integer
function M.relayout()
  local row = 1 ---@type integer
  for win in wins:iterator() do
    ---@cast win eve.ux.notify.IWindow
    local winnr = win.winnr ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      local wincfg = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
      wincfg.row = row
      row = row + wincfg.height + 3 ---@type integer
      vim.api.nvim_win_set_config(winnr, wincfg)
    end
  end
  return row
end

---@protected
---@param task                          eve.ux.notify.ITask
---@param row                           integer
---@return nil
function M.handle(task, row)
  local win = wins[task.group] ---@type eve.ux.notify.IWindow|nil
  if win == nil then
    win = {
      group = task.group,
      winnr = nil,
      bufnr = nil,
      times = 1,
    }
    wins[task.group] = win
  else
    win.times = win.times + 1
  end

  local bufnr = M.create_buf_as_needed(win.bufnr, task) ---@type integer
  local winnr = M.create_win_as_needed(win.winnr, bufnr, task) ---@type integer
  local times = win.times ---@type integer
  vim.defer_fn(function()
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) and win.times == times then
      vim.api.nvim_win_close(winnr, true)
      M.schedule()
    end
  end, task.timeout)

  win.bufnr = bufnr
  win.winnr = winnr
end

return M
