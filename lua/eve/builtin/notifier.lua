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
---@field public highlights             eve.t.IHighlight[]|nil
---@field public lines                  string[]
---@field public times                  integer
---@field public timeout                integer
---@field public timestamp              integer
---@field public width                  integer|nil

---@class eve.builtin.notifier.INotifyParams
---@field public group                  string|nil
---@field public level                  string
---@field public title                  string
---@field public content                string
---@field public highlights             eve.t.IHighlight[]|nil
---@field public timeout                integer
---@field public anonymous              boolean
---@field public silent                 boolean

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
  INFO = "INFO",
  WARN = "WARN",
  ERROR = "ERROR",
  [vim.log.levels.TRACE] = "TRACE",
  [vim.log.levels.DEBUG] = "DEBUG",
  [vim.log.levels.INFO] = "INFO",
  [vim.log.levels.WARN] = "WARN",
  [vim.log.levels.ERROR] = "ERROR",
}

---@class eve.builtin.notifier.LevelTitleMap
local LevelTitleMap = {
  TRACE = "Trace",
  DEBUG = "Debug",
  INFO = "Information",
  WARN = "Warning",
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

local __TASKS__ = eve.std.CircularQueue.new({ capacity = 50 })
local __TASK_HISTORY__ = eve.std.CircularQueue.new({ capacity = 200 })
local __WINS__ = {} ---@type eve.builtin.notifier.IWindow[]
local processing = false ---@type boolean

---@param task                          eve.builtin.notifier.ITask
---@return integer
local function measure_task_width(task)
  if task.width == nil then
    local width = vim.api.nvim_strwidth(task.title) + 14 ---@type integer
    for _, line in ipairs(task.lines) do
      local line_width = vim.api.nvim_strwidth(line) + 4 ---@type integer
      width = width < line_width and line_width or width
    end
    task.width = width
  end

  local width = task.width ---@type integer
  if task.times > 1 then
    width = width + vim.api.nvim_strwidth(string.format(" (x%d) ", task.times)) ---@type integer
  end
  return math.min(width, 82, vim.o.columns - 4) ---@type integer
end

---@param task                          eve.builtin.notifier.ITask
---@return integer
local function measure_task_height(task)
  local height = #task.lines + 1 ---@type integer
  return math.min(height, 42, vim.o.lines - 4) ---@type integer
end

---@class eve.builtin.notifier
local M = {}
setmetatable(M, {
  ---@param self                          eve.builtin.notifier
  ---@param msg                           string
  ---@param level0                        integer
  ---@param opts                          any
  ---@return nil
  __call = function(self, msg, level0, opts)
    opts = opts or {}

    local level = eve.notifier.resolve_level(level0) ---@type eve.builtin.notifier.LevelEnum
    local group = type(opts.group) == "string" and opts.group or nil ---@type string|nil
    local title = opts.title or eve.notifier.resolve_title(level) ---@type string
    local content = msg ---@type string
    if type(opts.message) == "string" then
      content = opts.message
    elseif type(opts.content) == "string" then
      content = opts.content
    end
    local highlights = type(opts.highlights) == "table" and opts.highlights or nil ---@type eve.t.IHighlight[]|nil
    local timeout = opts.timeout or 3000 ---@type integer
    local anonymous = type(opts.anonymous) == "boolean" and opts.anonymous or false ---@type boolean
    local silent = type(opts.silent) == "boolean" and opts.silent or false ---@type boolean

    self.notify({
      level = level,
      group = group,
      title = title,
      content = content,
      highlights = highlights,
      timeout = timeout,
      anonymous = anonymous,
      silent = silent,
    })
  end,
})

---@type eve.std.collection.Scheduler
local scheduler = eve.std.Scheduler.new({
  name = "eve.notifier.schedule",
  delay = 256,
  task = function(callback)
    if not processing then
      local notification_paused = eve.status.notification_paused:snapshot() ---@type boolean
      if notification_paused then
        return
      end

      processing = true
      vim.schedule(function()
        local ok, error = pcall(M.handle)
        processing = false

        if not ok then
          vim.schedule(function()
            M.notify({
              group = nil,
              level = "ERROR",
              title = "Notifier Interval Error on handle",
              content = vim.inspect(error),
              timeout = 100000,
              anonymous = false,
              silent = true,
            })
          end)
        end

        callback("fulfilled")
      end)
    end
  end,
})

---@return nil
function M.schedule()
  scheduler:schedule()
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
  eve.status.notification_paused:next(true)
end

---@return nil
function M.resume()
  eve.status.notification_paused:next(false)
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

---@param params                        eve.builtin.notifier.INotifyParams
---@return nil
function M.notify(params)
  local group = params.group ---@type string|nil
  local level = params.level ---@type string
  local title = params.title ---@type string
  local content = params.content ---@type string
  local highlights = params.highlights ---@type eve.t.IHighlight[]|nil
  local timeout = params.timeout ---@type integer
  local anonymous = params.anonymous ---@type boolean
  local silent = params.silent ---@type boolean

  local timestamp = os.time() ---@type integer
  local lines = vim.split(content, "\n", { plain = true }) ---@type string[]
  local md5 = eve.std.md5.new():update(level):update(group or ""):update(title):update(content):finish()
  local uuid = eve.std.md5.tohex(md5) ---@type string

  ---@type eve.builtin.notifier.ITask
  local task = {
    uuid = uuid,
    group = group,
    level = level,
    title = title,
    content = content,
    highlights = highlights,
    lines = lines,
    times = 1,
    timeout = timeout,
    timestamp = timestamp,
  }

  local notification_paused = eve.status.notification_paused:snapshot() ---@type boolean
  local notification_level = eve.status.notification_level:snapshot() ---@type eve.builtin.notifier.LevelEnum
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
        elseif t.group ~= nil and t.group == task.group then
          inserted = true
          __TASKS__:update(index, task)
        end
      end
    end

    if not inserted then
      for _, w in ipairs(__WINS__) do
        if
          (w.task.uuid == uuid or (w.task.group ~= nil and w.task.group == task.group))
          and w.winnr ~= nil
          and w.bufnr ~= nil
          and vim.api.nvim_win_is_valid(w.winnr)
          and vim.api.nvim_buf_is_valid(w.bufnr)
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
  if bufnr == nil or not eve.buf.is_valid(bufnr) then
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

    if vim.treesitter ~= nil and vim.treesitter.language ~= nil then
      local lang = vim.treesitter.language.get_lang("markdown") or "markdown" ---@type string
      local has_ts_parser = pcall(vim.treesitter.language.add, lang)
      if has_ts_parser then
        vim.treesitter.start(bufnr, lang)
      end
    end
  else
    vim.bo[bufnr].readonly = false
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, win.task.lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true

  if win.task.highlights then
    local nsnr = eve.var.nsnr.notify ---@type integer
    vim.api.nvim_buf_clear_namespace(bufnr, nsnr, 0, -1)
    for _, hl in ipairs(win.task.highlights) do
      local row = hl.lnum ---@type integer
      vim.hl.range(bufnr, nsnr, hl.hlname, { row, hl.coll }, { row, hl.colr })
    end
  end

  return bufnr
end

---@protected
---@param win                           eve.builtin.notifier.IWindow
---@return integer
function M.create_win_as_needed(win)
  local task = win.task ---@type eve.builtin.notifier.ITask
  local width = measure_task_width(task) ---@type integer
  local height = measure_task_height(task) ---@type integer

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

  if winnr == nil or not eve.win.is_valid(winnr) then
    wincfg.noautocmd = true
    winnr = vim.api.nvim_open_win(bufnr, false, wincfg) ---@type integer
    win.winnr = winnr

    eve.win.set_type(winnr, eve.win.Types.NOTIFY)
    vim.w[winnr][eve.var.Names.WINLINE_DISABLED] = true

    vim.wo[winnr].conceallevel = 0
    vim.wo[winnr].concealcursor = "n"
    vim.wo[winnr].cursorline = false
    vim.wo[winnr].number = false
    vim.wo[winnr].relativenumber = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].spell = false
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
  local max_width_title = width - 14 ---@type integer
  local text_title = task.times > 1 and string.format("%s (x%d) ", task.title, task.times) or task.title ---@type string
  local width_title = vim.api.nvim_strwidth(text_title) ---@type integer
  if width_title > max_width_title then
    text_title = text_title:sub(1, max_width_title)
    width_title = vim.api.nvim_strwidth(text_title) ---@type integer
  end

  local text_left = string.format("%s %s", eve.icon.loglevel[task.level], text_title) ---@type string
  local text_right = string.format("%s", os.date("%H:%M:%S", task.timestamp)) ---@type string
  local hlname = config.winbar[task.level] ---@type string
  local hl_text = eve.nvim.txt(text_left, hlname) .. "%=%=" .. eve.nvim.txt(text_right, hlname)
  return hl_text
end

---@protected
---@return nil
function M.handle()
  local N = 0 ---@type integer
  local invalid_wins = {} ---@type eve.builtin.notifier.IWindow[]
  for _, win in ipairs(__WINS__) do
    if
      win.winnr == nil
      or win.bufnr == nil
      or not vim.api.nvim_win_is_valid(win.winnr)
      or not vim.api.nvim_buf_is_valid(win.bufnr)
    then
      win.task = nil
      table.insert(invalid_wins, win)
    else
      N = N + 1 ---@type integer
      __WINS__[N] = win
    end
  end
  for index = #__WINS__, N + 1, -1 do
    __WINS__[index] = nil
  end

  while true do
    local candidate = __TASKS__:dequeue() ---@type eve.builtin.notifier.ITask|nil
    local consumed = false ---@type boolean

    local n = 0 ---@type integer
    local row = 1 ---@type integer
    for index = 1, N, 1 do
      local win = __WINS__[index] ---@type eve.builtin.notifier.IWindow

      if candidate ~= nil then
        if candidate.uuid == win.task.uuid then
          candidate.times = candidate.times + win.task.times ---@type integer
          win.task = candidate ---@type eve.builtin.notifier.ITask|nil
          win.dirty = true ---@type boolean
          consumed = true ---@type boolean
        elseif candidate.group ~= nil and candidate.group == win.task.group then
          win.task = candidate ---@type eve.builtin.notifier.ITask|nil
          win.dirty = true ---@type boolean
          consumed = true ---@type boolean
        end
      end

      local height = measure_task_height(win.task) ---@type integer
      local next_row = row + height + 3 ---@type integer
      if next_row > vim.o.lines then
        break
      end

      win.row = row ---@type integer
      row = next_row ---@type integer
      n = n + 1 ---@type integer
    end

    if n == N and not consumed and candidate ~= nil then
      local height = measure_task_height(candidate) ---@type integer
      if row + height + 3 <= vim.o.lines then
        ---@type eve.builtin.notifier.IWindow
        local win = {
          winnr = nil,
          bufnr = nil,
          tick = 0,
          task = candidate,
          row = row,
          dirty = true,
        }
        consumed = true

        N = N + 1 ---@type integer
        n = N ---@type integer
        __WINS__[N] = win ---@type eve.builtin.notifier.IWindow
      end
    end

    if not consumed and candidate ~= nil then
      __TASKS__:enqueue_front(candidate)
    end

    if n < N then
      for index = N, n + 1, -1 do
        local win = __WINS__[index] ---@type eve.builtin.notifier.IWindow
        __WINS__[index] = nil
        __TASKS__:enqueue_front(win.task)
        invalid_wins[#invalid_wins + 1] = win ---@type eve.builtin.notifier.IWindow
      end
      break
    end

    if not consumed or candidate == nil then
      break
    end
  end

  for _, win in ipairs(invalid_wins) do
    M.destroy_win(win)
  end

  for _, win in ipairs(__WINS__) do
    local task = win.task ---@type eve.builtin.notifier.ITask
    if win.dirty then
      win.dirty = false ---@type boolean
      win.tick = win.tick + 1 ---@type integer

      local tick = win.tick ---@type integer
      local winnr = M.create_win_as_needed(win) ---@type integer
      eve.std.timer.set_timeout(function()
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) and win.tick == tick then
          vim.api.nvim_win_close(winnr, true)
          M.schedule()
        end
      end, task.timeout)
    else
      local width = measure_task_width(task) ---@type integer
      local height = measure_task_height(task) ---@type integer
      local wincfg = vim.api.nvim_win_get_config(win.winnr) ---@type vim.api.keyset.win_config
      local winbar = wincfg.width ~= width and M.gen_winbar(task, width) or vim.wo[win.winnr].winbar

      wincfg.row = win.row
      wincfg.width = width
      wincfg.height = height + 1
      vim.api.nvim_win_set_config(win.winnr, wincfg)
      vim.wo[win.winnr].winbar = winbar
    end
  end
end

vim.api.nvim_create_autocmd("WinEnter", {
  group = eve.nvim.augroup("notifier_on_WinEnter"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    local wintype = eve.win.get_type(winnr) ---@type eve.builtin.win.TypeEnum|nil
    if wintype == eve.win.Types.NOTIFY then
      for _, win in ipairs(__WINS__) do
        if win.winnr == winnr then
          win.tick = win.tick + 1
          break
        end
      end
    end
  end,
})

vim.api.nvim_create_autocmd("VimResized", {
  group = eve.nvim.augroup("notifier_on_VimResized"),
  callback = function()
    M.schedule()
  end,
})

return M
