---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.ui_attach" ---@type string

---@class era.m.ui_attach
local M = {}

---@return nil
function M.dressing()
  local enabled = dot.context.flight.dressing_ui_attach:snapshot() ---@type boolean
  if not enabled then
    return
  end

  local timer = vim.uv.new_timer()
  if timer == nil then
    return
  end

  -- `vim.ui_attach` is the single writer into this lossless FIFO. Handlers
  -- consume in order; after an event is claimed there is no remote fallback,
  -- so failures are reported with context and the stream degrades by continuing.
  local tasks = {} ---@type era.m.ui_attach.ITask[]
  local task_head = 1
  local processing = false ---@type boolean

  ---@type table<string, boolean|nil>
  local IGNOREABLE_EVENTS = {
    grid_destroy = true,
    win_hide = true,
    win_show = true,
  }

  ---@type table<string, boolean|nil>
  local DEVMODE_IGNORED_EVENTS = {
    msg_showcmd = true,
    cmdline_show = false,
    cmdline_hide = false,
  }

  local handlers = {
    cmdline_hide = function(task)
      require("era.m.ui_attach.cmdline").hide(task)
    end,
    cmdline_special_char = function(task)
      require("era.m.ui_attach.cmdline").special_char(task)
    end,
    cmdline_pos = function(task)
      require("era.m.ui_attach.cmdline").pos(task)
    end,
    cmdline_show = function(task)
      require("era.m.ui_attach.cmdline").show(task)
    end,
    cmdline_block_show = function(task)
      require("era.m.ui_attach.cmdline").block_show(task)
    end,
    cmdline_block_append = function(task)
      require("era.m.ui_attach.cmdline").block_append(task)
    end,
    cmdline_block_hide = function(task)
      require("era.m.ui_attach.cmdline").block_hide(task)
    end,
    msg_clear = function(task)
      require("era.m.ui_attach.messages").clear(task)
    end,
    msg_history_show = function(task)
      require("era.m.ui_attach.messages").history_show(task)
    end,
    msg_show = function(task)
      require("era.m.ui_attach.messages").show(task)
    end,
    msg_showcmd = function(task)
      require("era.m.ui_attach.messages").showcmd(task)
    end,
    msg_showmode = function(task)
      require("era.m.ui_attach.messages").showmode(task)
    end,
    msg_ruler = function(task)
      require("era.m.ui_attach.messages").ruler(task)
    end,
    popupmenu_hide = function(task)
      require("era.m.ui_attach.popupmenu").hide(task)
    end,
    popupmenu_select = function(task)
      require("era.m.ui_attach.popupmenu").select(task)
    end,
    popupmenu_show = function(task)
      require("era.m.ui_attach.popupmenu").show(task)
    end,
  }

  ---@param task                        era.m.ui_attach.ITask
  ---@return nil
  local function process_task(task)
    local handle = handlers[task.event] ---@type era.m.ui_attach.IHandleTask
    handle(task)
  end

  ---@param task                        era.m.ui_attach.ITask
  ---@param err                         string
  ---@return nil
  local function report_task_error(task, err)
    local options = {
      from = __module_name__,
      message = string.format("failed to handle UI event | %s", task.event),
      details = {
        event = task.event,
        args = task.args,
        error = err,
      },
      anonymous = false,
    }
    local reported = pcall(stl.reporter.error, options)
    if not reported then
      stl.debug.log_silent(options.message, options.details)
    end
  end

  ---@return nil
  local function process_queue()
    if processing or task_head > #tasks then
      return
    end

    processing = true
    while task_head <= #tasks do
      local task = tasks[task_head] ---@type era.m.ui_attach.ITask
      task_head = task_head + 1

      local ok, err = xpcall(function()
        process_task(task)
      end, debug.traceback)
      if not ok then
        report_task_error(task, tostring(err))
      end
    end
    tasks = {}
    task_head = 1
    processing = false
  end

  local schedule_process = vim.schedule_wrap(process_queue) ---@type fun(): nil

  ---@param event                       string
  ---@param kind                        unknown
  ---@param ...                         any
  ---@return boolean|nil
  local function ui_attach_callback(event, kind, ...)
    local devmode = dot.context.flight.devmode:snapshot() ---@type boolean
    if devmode then
      if not DEVMODE_IGNORED_EVENTS[event] then
        stl.debug.log_silent(string.format("DEVMODE | %s", event), { event, kind, ... })
      end
    end

    if vim.v.exiting ~= vim.NIL then
      return
    end

    local handler = handlers[event]
    if handler == nil then
      local ignoreable = IGNOREABLE_EVENTS[event] == true ---@type boolean
      local silent = ignoreable

      stl.reporter.warn({
        from = __module_name__,
        message = string.format("unhandled | %s", event),
        details = { event, kind, ... },
        silent = silent,
        anonymous = false,
      })
      return
    end

    ---@type era.m.ui_attach.ITask
    local task = {
      event = event,
      args = { kind, ... },
    }
    tasks[#tasks + 1] = task

    if vim.in_fast_event() then
      timer:stop()
      timer:start(0, 0, schedule_process)
    else
      process_queue()
    end

    ---! make sure no further handlers received these events.
    return true
  end

  stl.nvim.fn.make_keys({ "i", "n", "s" }, "<esc>", function()
    -- WHY: gate on v:hlsearch (ground truth) too — the `searching` flag is
    -- derived from ext_messages search_count events and desyncs for searches
    -- that don't emit one (`:s`, `:g`, `:vimgrep`, `let @/=...`), leaving
    -- hlsearch stuck on with no way to clear it via <esc>.
    local searching = dot.state.status.searching:snapshot() or vim.v.hlsearch == 1 ---@type boolean
    if searching then
      dot.state.status.searching:next(false)
      vim.schedule(function()
        vim.cmd("noh")
        local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
        for _, bufnr in ipairs(bufnrs) do
          vim.api.nvim_buf_clear_namespace(bufnr, dot.var.nsnr.search_count, 0, -1)
        end
      end)
    end
    if vim.snippet then
      vim.snippet.stop()
    end
    return "<esc>"
  end, "system: clear search highlights", true)

  vim.ui_attach(dot.var.nsnr.attach, {
    ext_cmdline = true,
    ext_messages = true,
    ext_popupmenu = true,
  }, ui_attach_callback)
end

return M
