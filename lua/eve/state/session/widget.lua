---@class eve.state.widget.data
---@field public history                eve.collection.history.ISerializedData

---@class eve.state.widget.state
---@field public history                eve.collection.IHistory
---
---@field public backward               fun(): nil
---@field public forward                fun(): nil
---
---@field public close_present          fun(): nil
---@field public equals                 fun(w1: eve.t.ux.IWidget, w2: eve.t.ux.IWidget): boolean
---@field public get_keymaps            fun(widget: eve.t.ux.IWidget): eve.t.IKeymap[]
---@field public get_widget_current     fun(): eve.t.ux.IWidget|nil, integer|nil
---@field public get_widget_visible     fun(): eve.t.ux.IWidget|nil, integer|nil
---@field public open                   fun(widget: eve.t.ux.IWidget): nil
---@field public resize                 fun(): nil
---@field public resume                 fun(): eve.t.ux.IWidget|nil
---@field public wrap                   fun(raw_widget: eve.t.ux.IRawWidget): eve.t.ux.IWidget

---@class eve.state.widget : eve.state.widget.state
---@field public defaults                fun(): eve.state.widget.data
---@field public dump                    fun(): eve.state.widget.data
---@field public load                    fun(data: unknown): nil
---@field public normalize               fun(data: unknown): eve.state.widget.data
local M = {}

---@return eve.state.widget.data
function M.defaults()
  ---@type eve.state.widget.data
  return {
    history = { present = 0, stack = {} },
  }
end

---@param data                        any
---@return eve.state.widget.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.widget.data
  if type(data) == "table" then
    if type(data.history) == "table" then
      if type(data.history.present) == "number" then
        resolved.history.present = data.history.present
      end
      if type(data.history.stack) == "table" then
        resolved.history.stack = data.history.stack
      end
    end
  end

  ---@type eve.state.widget.data
  return resolved
end

---@return eve.state.widget.data
function M.dump()
  ---@type eve.collection.history.ISerializedData
  local history = M.history and M.history:dump() or { present = 0, stack = {} }

  local stack = {} ---@type string[]
  for _, widget in ipairs(history.stack) do
    table.insert(stack, widget.name)
  end

  ---@type eve.state.widget.data
  return {
    history = { present = history.present, stack = stack },
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  ---@diagnostic disable-next-line: unused-local
  local data = M.normalize(raw_data) ---@type eve.state.widget.data

  ---@type eve.collection.IHistory
  local history = M.history or eve.col.History.new({
    name = "widget",
    capacity = 100,
  })
  M.history = history
end

----------------------------------------------------------------------------------------------------

---@type fun(w1: eve.t.ux.IWidget, w2: eve.t.ux.IWidget): boolean
M.equals = eve.std.fn.equals_shallow

---@type eve.collection.IHistory
M.history = eve.col.History.new({
  name = "widget",
  capacity = 20,
  equals = eve.std.fn.equals_shallow,
})

---@return nil
function M.backward()
  local present, present_index = M.history:present() ---@type eve.t.ux.IWidget|nil, integer|nil
  if present == nil or present_index <= 1 then
    return
  end

  local widget = nil ---@type eve.t.ux.IWidget|nil
  local is_bottom = false ---@type boolean
  while not is_bottom do
    widget, is_bottom = M.history:backward()
    if widget ~= nil and not M.equals(widget, present) and widget:status() ~= "closed" and not widget:focused() then
      present:hide()
      widget:focus()
      break
    end
  end
end

---@return nil
function M.forward()
  local present, present_index = M.history:present() ---@type eve.t.ux.IWidget|nil, integer|nil
  if present == nil or present_index >= M.history:size() then
    return
  end

  local widget = nil ---@type eve.t.ux.IWidget|nil
  local is_top = false ---@type boolean
  while not is_top do
    widget, is_top = M.history:forward() ---@type eve.t.ux.IWidget|nil, boolean
    if widget ~= nil and not M.equals(widget, present) and widget:status() ~= "closed" and not widget:focused() then
      present:hide()
      widget:focus()
      break
    end
  end
end

---@return nil
function M.close_present()
  local widget = M.get_widget_current() ---@type eve.t.ux.IWidget|nil
  if widget ~= nil and widget:status() == "visible" then
    widget:close()
  end
end

---@param widget                        eve.t.ux.IWidget
---@return eve.t.IKeymap[]
function M.get_keymaps(widget)
  local function on_close()
    widget:close()

    local widget_visible, widget_visible_index = M.get_widget_visible() ---@type eve.t.ux.IWidget|nil, integer|nil
    if widget_visible ~= nil and widget_visible_index ~= nil then
      widget_visible:focus()
      M.history:go(widget_visible_index)
    else
      local winnr_command = eve.state.editor.get_winnr_command() ---@type integer|nil
      if winnr_command ~= nil then
        vim.api.nvim_set_current_win(winnr_command)
      end
    end
  end

  ---@type eve.t.IKeymap[]
  local keymaps = {
    {
      modes = { "i", "n", "t", "v" },
      key = "<C-a>i",
      aliases = { "<D-i>", "<M-i>" },
      callback = M.backward,
      desc = "widget: backward",
    },
    {
      modes = { "i", "n", "t", "v" },
      key = "<C-a>o",
      aliases = { "<D-o>", "<M-o>" },
      callback = M.forward,
      desc = "widget: forward",
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>q",
      aliases = { "<D-q>", "<M-q>" },
      callback = on_close,
      desc = "widget: close present",
    },
    {
      modes = { "n", "v" },
      key = "q",
      callback = on_close,
      desc = "widget: close present",
    },
  }
  return keymaps
end

---@return eve.t.ux.IWidget|nil
---@return integer|nil
function M.get_widget_current()
  local present, present_index = M.history:present() ---@type eve.t.ux.IWidget|nil
  if present ~= nil and present:status() ~= "closed" then
    return present, present_index
  end

  for index = present_index - 1, 1, -1 do
    local widget = M.history:at(index) ---@type eve.t.ux.IWidget|nil
    if widget ~= nil and widget:status() ~= "closed" then
      M.history:go(index)
      return widget, index
    end
  end
  M.history:go(1)
end

---@return eve.t.ux.IWidget|nil
---@return integer|nil
function M.get_widget_visible()
  local present, present_index = M.history:present() ---@type eve.t.ux.IWidget|nil, integer
  if present ~= nil and present:status() == "visible" then
    return present, present_index
  end

  for index = M.history:size(), 1, -1 do
    local widget = M.history:at(index) ---@type eve.t.ux.IWidget|nil
    if widget ~= nil and widget:status() == "visible" then
      M.history:go(index)
      return widget, index
    end
  end
  return nil, nil
end

---@param widget                        eve.t.ux.IWidget
---@return nil
function M.open(widget)
  local present = M.get_widget_current() ---@type eve.t.ux.IWidget|nil
  if present == nil then
    M.history:push(widget)
    widget:focus()
    return
  end

  if not M.equals(present, widget) then
    if M.history:size() == M.history:capacity() then
      local bottom_widget = M.history:bottom() ---@type eve.t.ux.IWidget
      bottom_widget:close()
    end
    M.history:push(widget)

    present:hide()
  end
  widget:focus()
end

---@return nil
function M.resize()
  for widget in M.history:iterator() do
    local status = widget:status() ---@type eve.e.WidgetStatus
    if status ~= "closed" then
      widget:resize()
    end
  end
end

---@return eve.t.ux.IWidget|nil
function M.resume()
  local present = M.get_widget_current() ---@type eve.t.ux.IWidget|nil
  if present ~= nil then
    if present:focused() then
      present:hide()
    else
      present:focus()
    end
  end
  return present
end

---@param raw_widget                    eve.t.ux.IRawWidget
---@return eve.t.ux.IWidget
function M.wrap(raw_widget)
  local widget ---@type eve.t.ux.IWidget

  local close = raw_widget.close
  local focus = raw_widget.focus
  local focused = raw_widget.focused
  local hide = raw_widget.hide
  local resize = raw_widget.resize
  local status = raw_widget.status

  ---@type eve.t.ux.IWidget
  widget = {
    name = raw_widget.name,
    close = function()
      close(widget)
    end,
    focus = function()
      local present = M.get_widget_current() ---@type eve.t.ux.IWidget|nil
      if present == nil then
        M.history:push(widget)
        focus(widget)
        return
      end

      if not M.equals(present, widget) then
        if M.history:size() == M.history:capacity() then
          local bottom_widget = M.history:bottom() ---@type eve.t.ux.IWidget
          bottom_widget:close()
        end
        M.history:push(widget)

        present:hide()
      end
      focus(widget)
    end,
    focused = function()
      return focused(widget)
    end,
    hide = function()
      hide(widget)
    end,
    resize = function()
      resize(widget)
    end,
    status = function()
      return status(widget)
    end,
  }
  return widget
end

return M
