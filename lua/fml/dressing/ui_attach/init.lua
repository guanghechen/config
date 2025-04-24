local __module_name__ = "fml.dressing.ui_attach" ---@type string

local flag_dressing_cmdline = eve.state.flight.dressing_cmdline:snapshot() ---@type boolean
local flag_dressing_messages = eve.state.flight.dressing_cmdline:snapshot() ---@type boolean
local flag_dressing_popupmenu = eve.state.flight.dressing_cmdline:snapshot() ---@type boolean
if not flag_dressing_cmdline and not flag_dressing_messages and not flag_dressing_popupmenu then
  return
end

---@class fml.dressing.ui_attach.cmdline_show.IContentItem
---@field public text                   string
---@field public hlname                 string

---@class fml.dressing.ui_attach.cmdline_show.IParams
---@field public content                string[][]
---@field public pos                    integer Cursor position in the command line (0-based)
---@field public firstc                 string  Command line prefix character, e.g., ':', '/', '?'
---@field public prompt                 string  Prompt text (optional)
---@field public indent                 integer Indentation level (optional)
---@field public level                  integer Nesting level, 0 means top level
---@field public type                   string  Command line type, e.g., 'cmd', 'search_forward', 'search_backward', etc.

---@class fml.dressing.ui_attach.ITask
---@field public event                  string
---@field public args                   any[]

---@alias fml.dressing.ui_attach.IHandleTask
---| fun(task: fml.dressing.ui_attach.ITask): nil

local timer = vim.uv.new_timer()
if timer == nil then
  return
end

local tasks = eve.std.CircularQueue.new({ capacity = 500 })
local processing = false ---@type boolean

local handlers = {
  cmdline_hide = function(task)
    require("fml.dressing.ui_attach.cmdline").hide(task)
  end,
  cmdline_pos = function(task)
    require("fml.dressing.ui_attach.cmdline").pos(task)
  end,
  cmdline_show = function(task)
    require("fml.dressing.ui_attach.cmdline").show(task)
  end,
  msg_clear = function(task)
    require("fml.dressing.ui_attach.messages").clear(task)
  end,
  msg_history_clear = function(task)
    require("fml.dressing.ui_attach.messages").history_clear(task)
  end,
  msg_history_show = function(task)
    require("fml.dressing.ui_attach.messages").history_show(task)
  end,
  msg_show = function(task)
    require("fml.dressing.ui_attach.messages").show(task)
  end,
  msg_showcmd = function(task)
    require("fml.dressing.ui_attach.messages").showcmd(task)
  end,
  popupmenu_hide = function(task)
    require("fml.dressing.ui_attach.popupmenu").hide(task)
  end,
  popupmenu_show = function(task)
    require("fml.dressing.ui_attach.popupmenu").show(task)
  end,
}

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
local function process_task(task)
  local handle = handlers[task.event] ---@type fml.dressing.ui_attach.IHandleTask
  handle(task)
end

---@return nil
local function process_queue()
  if processing or tasks:size() < 1 then
    return
  end

  processing = true
  while tasks:size() > 0 do
    local task = tasks:dequeue() ---@type fml.dressing.ui_attach.ITask
    pcall(process_task, task)
  end
  processing = false

  vim.api.nvim__redraw({ flush = true })
end

local schedule_process = vim.schedule_wrap(process_queue) ---@type fun(): nil

---@param event                         string
---@param ...                           any
---@return boolean|nil
local function ui_attach_callback(event, ...)
  eve.debug.log_silent(event, { event, ... })

  if vim.v.exiting ~= vim.NIL then
    return
  end

  ---@type fml.dressing.ui_attach.ITask
  local task = {
    event = event,
    args = { ... },
  }

  -- HACK: special case for return prompts
  if event == "msg_show" and task.args[1] == "return_prompt" then
    vim.api.nvim_input("<cr>")
    return true
  end

  local handler = handlers[event]
  if handler == nil then
    eve.reporter.warn({
      from = __module_name__,
      message = string.format("unhandled | %s", event),
      details = { task = task },
    })
    return
  end

  tasks:enqueue(task)

  if vim.in_fast_event() then
    timer:stop()
    timer:start(0, 0, schedule_process)
  else
    process_queue()
  end

  ---! make sure no further handlers received these events.
  return true
end

eve.nvim.make_keys({ "i", "n", "s" }, "<esc>", function()
  local searching = eve.state.status.searching:snapshot() ---@type boolean
  if searching then
    eve.state.status.searching:next(false)
    vim.schedule(function()
      vim.cmd.noh()
      local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
      for _, bufnr in ipairs(bufnrs) do
        vim.api.nvim_buf_clear_namespace(bufnr, eve.constant.nsnr.search_count, 0, -1)
      end
    end)
  end
  if vim.snippet then
    vim.snippet.stop()
  end
  return "<esc>"
end, "system: clear search highlights", true)

vim.ui_attach(eve.constant.nsnr.attach, {
  ext_cmdline = flag_dressing_cmdline,
  ext_messages = flag_dressing_cmdline,
  ext_popupmenu = flag_dressing_cmdline,
}, ui_attach_callback)
