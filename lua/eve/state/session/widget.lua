local fn = require("eve.builtin.fn")
local History = require("eve.collection.history")

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
---@field public get_current_widget     fun(): eve.t.ux.IWidget|nil
---@field public get_keymaps            fun(): eve.t.IKeymap[]
---@field public open                   fun(widget: eve.t.ux.IWidget): nil
---@field public resize                 fun(): nil
---@field public resume                 fun(): boolean
---@field public wrap                   fun(raw_widget: eve.t.ux.IRawWidget): eve.t.ux.IWidget
local S = {}

---@class eve.state.widget
---@field public defaults                fun(): eve.state.widget.data
---@field public dump                    fun(): eve.state.widget.data
---@field public load                    fun(data: unknown): eve.state.widget.state
---@field public normalize               fun(data: unknown): eve.state.widget.data
local M = {}

---@type eve.state.widget.state
S = {
  history = History.new({
    name = "widget",
    capacity = 20,
    equals = fn.equals_shallow,
  }),
  equals = fn.equals_shallow,
  backward = function()
    local present, present_index = S.history:present() ---@type eve.t.ux.IWidget|nil, integer|nil
    if present == nil or present_index <= 1 then
      return
    end

    local widget = nil ---@type eve.t.ux.IWidget|nil
    local is_bottom = false ---@type boolean
    while not is_bottom do
      widget, is_bottom = S.history:backward()
      if widget ~= nil and not S.equals(widget, present) and widget:status() ~= "closed" and not widget:focused() then
        present:hide()
        widget:focus()
        break
      end
    end
  end,
  forward = function()
    local present, present_index = S.history:present() ---@type eve.t.ux.IWidget|nil, integer|nil
    if present == nil or present_index >= S.history:size() then
      return
    end

    local widget = nil ---@type eve.t.ux.IWidget|nil
    local is_top = false ---@type boolean
    while not is_top do
      widget, is_top = S.history:forward() ---@type eve.t.ux.IWidget|nil, boolean
      if widget ~= nil and not S.equals(widget, present) and widget:status() ~= "closed" and not widget:focused() then
        present:hide()
        widget:focus()
        break
      end
    end
  end,
  close_present = function()
    local widget = S.get_current_widget() ---@type eve.t.ux.IWidget|nil
    if widget ~= nil and widget:status() == "visible" then
      widget:close()
    end
  end,
  get_current_widget = function()
    local present = S.history:present() ---@type eve.t.ux.IWidget|nil
    if present ~= nil and present:status() ~= "closed" then
      return present
    end

    local widget = nil ---@type eve.t.ux.IWidget|nil
    local is_bottom = false ---@type boolean
    while not is_bottom do
      widget, is_bottom = S.history:backward()
      if widget ~= nil and widget:status() ~= "closed" then
        return widget
      end
    end

    return nil
  end,
  get_keymaps = function()
    ---@type eve.t.IKeymap[]
    local keymaps = {
      { modes = { "n", "v" }, key = "q", callback = S.close_present, desc = "widget: close present" },
      { modes = { "i", "n", "t", "v" }, key = "<C-a>i", callback = S.backward, desc = "widget: backward" },
      { modes = { "i", "n", "t", "v" }, key = "<C-a>o", callback = S.forward, desc = "widget: forward" },
      { modes = { "i", "n", "t", "v" }, key = "<D-i>", callback = S.backward, desc = "widget: backward" },
      { modes = { "i", "n", "t", "v" }, key = "<D-o>", callback = S.forward, desc = "widget: forward" },
      { modes = { "i", "n", "t", "v" }, key = "<M-i>", callback = S.backward, desc = "widget: backward" },
      { modes = { "i", "n", "t", "v" }, key = "<M-o>", callback = S.forward, desc = "widget: forward" },
    }
    return keymaps
  end,
  open = function(widget)
    local present = S.get_current_widget() ---@type eve.t.ux.IWidget|nil
    if present == nil then
      S.history:push(widget)
      widget:focus()
      return
    end

    if not S.equals(present, widget) then
      if S.history:size() == S.history:capacity() then
        local bottom_widget = S.history:bottom() ---@type eve.t.ux.IWidget
        bottom_widget:close()
      end
      S.history:push(widget)

      present:hide()
    end
    widget:focus()
  end,
  resize = function()
    for widget in S.history:iterator() do
      local status = widget:status() ---@type eve.e.WidgetStatus
      if status ~= "closed" then
        widget:resize()
      end
    end
  end,
  resume = function()
    local present = S.get_current_widget() ---@type eve.t.ux.IWidget|nil
    if present == nil or present:status() == "closed" then
      return false
    end

    if present:focused() then
      present:hide()
    else
      present:focus()
    end
    return true
  end,
  wrap = function(raw_widget)
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
      statusline_items = raw_widget.statusline_items,
      close = function()
        close(widget)
      end,
      focus = function()
        local present = S.get_current_widget() ---@type eve.t.ux.IWidget|nil
        if present == nil then
          S.history:push(widget)
          focus(widget)
          return
        end

        if not S.equals(present, widget) then
          if S.history:size() == S.history:capacity() then
            local bottom_widget = S.history:bottom() ---@type eve.t.ux.IWidget
            bottom_widget:close()
          end
          S.history:push(widget)

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
  end,
}

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
  local history = S.history and S.history:dump() or { present = 0, stack = {} }

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
---@return eve.state.widget.state
function M.load(raw_data)
  ---@diagnostic disable-next-line: unused-local
  local data = M.normalize(raw_data) ---@type eve.state.widget.data

  ---@type eve.collection.IHistory
  local history = S.history or History.new({
    name = "widget",
    capacity = 100,
  })
  S.history = history

  return S
end

return M
