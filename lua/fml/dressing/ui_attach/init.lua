local __module_name__ = "fml.dressing.ui_attach" ---@type string

---@class fml.dressing.ui_attach.ITask
---@field public event                  string
---@field public kind                   string
---@field public args                   any[]

---@alias fml.dressing.ui_attach.IHandleTask
---| fun(task: fml.dressing.ui_attach.ITask): nil

local timer = vim.uv.new_timer()
if timer == nil then
  return
end

local ns = vim.api.nvim_create_namespace("fml_cmdline") ---@type integer
local tasks = eve.std.CircularQueue.new({ capacity = 500 })
local processing = false ---@type boolean

local handlers = {
  cmdline_show = function(task)
    require("fml.dressing.ui_attach.cmdline").show(task)
  end,
  cmdline_hide = function(task)
    require("fml.dressing.ui_attach.cmdline").hide(task)
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
  if processing then
    return
  end

  timer:stop()

  processing = true
  while tasks:size() > 0 do
    local task = tasks:dequeue() ---@type fml.dressing.ui_attach.ITask
    pcall(process_task, task)
  end
  processing = false
end

local schedule_process = vim.schedule_wrap(process_queue) ---@type fun(): nil

---@param event                         string
---@param kind                          string
---@param ...                           any
---@return boolean|nil
local function ui_attach_callback(event, kind, ...)
  if vim.v.exiting ~= vim.NIL then
    return
  end

  -- HACK: special case for return prompts
  if event == "msg_show" and kind == "return_prompt" then
    vim.api.nvim_input("<cr>")
    return true
  end

  local handler = handlers[event]
  if handler == nil then
    eve.reporter.warn({
      from = __module_name__,
      message = "Unknown event.",
      details = { event = event, kind = kind, extra = { ... } },
    })
    return
  end

  ---@type fml.dressing.ui_attach.ITask
  local task = {
    event = event,
    kind = kind,
    args = { ... },
  }
  tasks:enqueue(task)

  if vim.in_fast_event() then
    timer:start(0, 0, schedule_process)
  else
    process_queue()
  end

  ---! make sure no further handlers received these events.
  return true
end

local flag_dressing_cmdline = eve.state.flight.dressing_cmdline:snapshot() ---@type boolean
local flag_dressing_messages = eve.state.flight.dressing_cmdline:snapshot() ---@type boolean
local flag_dressing_popupmenu = eve.state.flight.dressing_cmdline:snapshot() ---@type boolean
if flag_dressing_cmdline or flag_dressing_messages or flag_dressing_popupmenu then
  vim.ui_attach(ns, {
    ext_cmdline = flag_dressing_cmdline,
    ext_messages = flag_dressing_messages,
    ext_popupmenu = flag_dressing_popupmenu,
  }, ui_attach_callback)
end
