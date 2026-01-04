local __module_name__ = "era.view.notifications" ---@type string

---@class era.view.notifications.IConfig
local config = {
  winhighlight = table.concat({
    "CursorLine:m_nf_current",
    "FloatBorder:FloatBorder",
    "FloatTitle:FloatTitle",
    "Normal:m_nf_normal",
  }, ","),
  icon_hlgroup = {
    DEBUG = "m_nf_icon_debug",
    ERROR = "m_nf_icon_error",
    INFO = "m_nf_icon_info",
    TRACE = "m_nf_icon_trace",
    WARN = "m_nf_icon_warn",
  },
  level_hlgroup = {
    DEBUG = "m_nf_level_debug",
    ERROR = "m_nf_level_error",
    INFO = "m_nf_level_info",
    TRACE = "m_nf_level_trace",
    WARN = "m_nf_level_warn",
  },
  title_hlgroup = {
    DEBUG = "m_nf_title_debug",
    ERROR = "m_nf_title_error",
    INFO = "m_nf_title_info",
    TRACE = "m_nf_title_trace",
    WARN = "m_nf_title_warn",
  },
}

---@class era.view.notifications.IState
---@field protected _bufnr                integer|nil
---@field protected _winnr                integer|nil
---@field protected _ns                   integer
---@field protected _tasks                era.t.INotifierTask[]
---@field protected _task_line_map        table<integer, integer>
---@field protected _cursor               integer

---@class era.view.Notifications : era.view.notifications.IState
local M = {}
M.__index = M

---@return era.view.Notifications
function M.new()
  local self = setmetatable({}, M)
  self._bufnr = nil
  self._winnr = nil
  self._ns = vim.api.nvim_create_namespace("era.view.notifications")
  self._tasks = {}
  self._task_line_map = {}
  self._cursor = 1
  return self
end

---@return boolean
function M:isvisible()
  local winnr = self._winnr ---@type integer|nil
  return winnr ~= nil and vim.api.nvim_win_is_valid(winnr)
end

---@return nil
function M:open()
  self._tasks = era.m.notifier.history()
  self._cursor = 1

  if #self._tasks == 0 then
    stl.reporter.info({
      from = __module_name__,
      subject = "open",
      message = "No notifications in history.",
    })
    return
  end

  self:__create_win__()
  self:__render__()
  self:__setup_keymaps__()
end

---@return nil
function M:close()
  if self._winnr ~= nil and vim.api.nvim_win_is_valid(self._winnr) then
    vim.api.nvim_win_close(self._winnr, true)
  end

  if self._bufnr ~= nil and vim.api.nvim_buf_is_valid(self._bufnr) then
    vim.api.nvim_buf_delete(self._bufnr, { force = true })
  end

  self._winnr = nil
  self._bufnr = nil
  self._tasks = {}
  self._cursor = 1
end

---@return nil
function M:refresh()
  self._tasks = era.m.notifier.history()
  if #self._tasks == 0 then
    self:close()
    return
  end

  self._cursor = math.min(self._cursor, #self._tasks)
  self:__render__()
end

----------------------------------------------------------------------------------------------------

---@protected
---@return nil
function M:__create_win__()
  if self._bufnr == nil or not vim.api.nvim_buf_is_valid(self._bufnr) then
    local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    self._bufnr = bufnr

    vim.b[bufnr].miniindentscope_disable = true
    vim.b[bufnr].miniai_disable = true
    vim.b[bufnr].minihipatterns_disable = true
    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].filetype = stl.filetype.BOARD
    vim.bo[bufnr].swapfile = false
  end

  if self._winnr == nil or not vim.api.nvim_win_is_valid(self._winnr) then
    local width = math.min(100, vim.o.columns - 4) ---@type integer
    local height = math.floor(vim.o.lines * 0.8) ---@type integer
    local row = math.floor((vim.o.lines - height) / 2) ---@type integer
    local col = math.floor((vim.o.columns - width) / 2) ---@type integer

    local winnr = vim.api.nvim_open_win(self._bufnr, true, {
      relative = "editor",
      row = row,
      col = col,
      width = width,
      height = height,
      border = "rounded",
      style = "minimal",
      focusable = true,
      title = " Notification History ",
      title_pos = "center",
      zindex = dot.win.resolve_zindex(),
    })
    self._winnr = winnr

    dot.win.set_type(winnr, stl.nvim.win.Types.BOARD)
    vim.wo[winnr].cursorline = true
    vim.wo[winnr].list = false
    vim.wo[winnr].number = true
    vim.wo[winnr].relativenumber = true
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].spell = false
    vim.wo[winnr].winblend = dot.context.theme.get_float_winblend()
    vim.wo[winnr].winfixbuf = true
    vim.wo[winnr].winhighlight = config.winhighlight
    vim.wo[winnr].wrap = false
  end
end

---@protected
---@return nil
function M:__render__()
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local winnr = self._winnr ---@type integer|nil
  local win_width = winnr and vim.api.nvim_win_get_width(winnr) or 100 ---@type integer

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_clear_namespace(bufnr, self._ns, 0, -1)

  local lines = {} ---@type string[]
  local highlights = {} ---@type { lnum: integer, coll: integer, colr: integer, hlname: string }[]
  local task_line_map = {} ---@type table<integer, integer>

  for _, task in ipairs(self._tasks) do
    local icon = stl.icon.loglevel[task.level] or " " ---@type string
    local time = os.date("%H:%M:%S", task.timestamp) ---@type string
    local level = string.format("%-5s", task.level) ---@type string
    local times_str = task.times > 1 and string.format(" (x%d)", task.times) or "" ---@type string
    local title = task.title .. times_str ---@type string

    local max_title_width = win_width - 22 ---@type integer
    if vim.api.nvim_strwidth(title) > max_title_width then
      title = string.sub(title, 1, max_title_width - 1) .. "…"
    end

    local header_line = string.format(" %s %s  %s  %s", icon, time, level, title) ---@type string
    local lnum = #lines ---@type integer
    lines[#lines + 1] = header_line
    task_line_map[#task_line_map + 1] = lnum + 1

    local icon_end = 1 + #icon ---@type integer
    local time_end = icon_end + 1 + #time ---@type integer
    local level_end = time_end + 2 + #level ---@type integer

    highlights[#highlights + 1] = { lnum = lnum, coll = 1, colr = icon_end, hlname = config.icon_hlgroup[task.level] }
    highlights[#highlights + 1] = { lnum = lnum, coll = icon_end + 1, colr = time_end, hlname = "m_nf_time" }
    highlights[#highlights + 1] = { lnum = lnum, coll = time_end + 2, colr = level_end, hlname = config.level_hlgroup[task.level] }
    highlights[#highlights + 1] = { lnum = lnum, coll = level_end + 2, colr = -1, hlname = config.title_hlgroup[task.level] }

    for _, content_line in ipairs(task.lines) do
      local body_lnum = #lines ---@type integer
      lines[#lines + 1] = "     " .. content_line
      highlights[#highlights + 1] = { lnum = body_lnum, coll = 0, colr = -1, hlname = "m_nf_body" }
    end

    lines[#lines + 1] = ""
  end

  if #lines > 0 and lines[#lines] == "" then
    lines[#lines] = nil
  end

  self._task_line_map = task_line_map

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  for _, hl in ipairs(highlights) do
    vim.hl.range(bufnr, self._ns, hl.hlname, { hl.lnum, hl.coll }, { hl.lnum, hl.colr })
  end

  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true

  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    local lnum = task_line_map[self._cursor] or 1 ---@type integer
    pcall(vim.api.nvim_win_set_cursor, winnr, { lnum, 0 })
  end
end

---@protected
---@return nil
function M:__setup_keymaps__()
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "n" },
      key = "q",
      desc = "notifications: close",
      callback = function()
        self:close()
      end,
    },
    {
      modes = { "n" },
      key = "<Esc>",
      desc = "notifications: close",
      callback = function()
        self:close()
      end,
    },
    {
      modes = { "n" },
      key = "r",
      desc = "notifications: refresh",
      callback = function()
        self:refresh()
      end,
    },
  }

  stl.nvim.fn.bindkeys(keymaps, { bufnr = bufnr, noremap = true, silent = true })
end

----------------------------------------------------------------------------------------------------

local __instance__ = nil ---@type era.view.Notifications|nil

---@return nil
local function open()
  if __instance__ == nil then
    __instance__ = M.new()
  end

  if __instance__:isvisible() then
    __instance__:close()
  else
    __instance__:open()
  end
end

---@return nil
local function close()
  if __instance__ ~= nil then
    __instance__:close()
  end
end

return {
  open = open,
  close = close,
}
