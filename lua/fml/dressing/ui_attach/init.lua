local __module_name__ = "fml.dressing.ui_attach" ---@type string

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
  msg_showmode = function(task)
    require("fml.dressing.ui_attach.messages").showmode(task)
  end,
  popupmenu_hide = function(task)
    require("fml.dressing.ui_attach.popupmenu").hide(task)
  end,
  popupmenu_select = function(task)
    require("fml.dressing.ui_attach.popupmenu").select(task)
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

    ---! Optimization: merge adjacent cmdline_hide and cmdline_show events.
    if task.event == "cmdline_hide" then
      local next_task = tasks:dequeue() ---@type fml.dressing.ui_attach.ITask
      if next_task ~= nil then
        if next_task.event == "cmdline_show" and task.args[1] == next_task.args[1] then
          task = next_task
        else
          tasks:enqueue_front(next_task)
        end
      end
    end

    pcall(process_task, task)
  end
  processing = false

  vim.api.nvim__redraw({ flush = true })
end

local schedule_process = vim.schedule_wrap(process_queue) ---@type fun(): nil

---@param event                         string
---@param kind                          unknown
---@param ...                           any
---@return boolean|nil
local function ui_attach_callback(event, kind, ...)
  local devmode = eve.state.flight.devmode:snapshot() ---@type boolean
  if devmode then
    eve.debug.log_silent(string.format("DEVMODE | %s", event), { event, kind, ... })
  end

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
      message = string.format("unhandled | %s", event),
      details = { event, kind, ... },
    })
    return
  end

  ---@type fml.dressing.ui_attach.ITask
  local task = {
    event = event,
    args = { kind, ... },
  }
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
  ext_cmdline = true,
  ext_messages = true,
  ext_popupmenu = true,
}, ui_attach_callback)
