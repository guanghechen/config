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
---@field public get_keymaps            fun(widget: eve.t.ux.IWidget): eve.t.IKeymap[]
---@field public get_widget_current     fun(): eve.t.ux.IWidget|nil, integer|nil
---@field public get_widget_visible     fun(): eve.t.ux.IWidget|nil, integer|nil
---@field public open                   fun(widget: eve.t.ux.IWidget): nil
---@field public resize                 fun(): nil
---@field public resume                 fun(): eve.t.ux.IWidget|nil
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
    local widget = S.get_widget_current() ---@type eve.t.ux.IWidget|nil
    if widget ~= nil and widget:status() == "visible" then
      widget:close()
    end
  end,
  get_keymaps = function(widget)
    local function on_close()
      local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
      local winnr_fixed = require("eve.state").tab.get_winnr_fixed(tabnr) ---@type integer|nil

      widget:close()

      local widget_visible, widget_visible_index = S.get_widget_visible() ---@type eve.t.ux.IWidget|nil, integer|nil
      if widget_visible ~= nil and widget_visible_index ~= nil then
        widget_visible:focus()
        S.history:go(widget_visible_index)
      else
        if winnr_fixed ~= nil and eve.std.win.is_valid(winnr_fixed) then
          vim.api.nvim_tabpage_set_win(tabnr, winnr_fixed)
        end
      end
    end

    ---@type eve.t.IKeymap[]
    local keymaps = {
      {
        modes = { "i", "n", "t", "v" },
        key = "<C-a>i",
        aliases = { "<D-i>", "<M-i>" },
        callback = S.backward,
        desc = "widget: backward",
      },
      {
        modes = { "i", "n", "t", "v" },
        key = "<C-a>o",
        aliases = { "<D-o>", "<M-o>" },
        callback = S.forward,
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
  end,
  get_widget_current = function()
    local present, present_index = S.history:present() ---@type eve.t.ux.IWidget|nil
    if present ~= nil and present:status() ~= "closed" then
      return present, present_index
    end

    for index = present_index - 1, 1, -1 do
      local widget = S.history:at(index) ---@type eve.t.ux.IWidget|nil
      if widget ~= nil and widget:status() ~= "closed" then
        S.history:go(index)
        return widget, index
      end
    end
    S.history:go(1)
  end,
  get_widget_visible = function()
    local present, present_index = S.history:present() ---@type eve.t.ux.IWidget|nil, integer
    if present ~= nil and present:status() == "visible" then
      return present, present_index
    end

    for index = S.history:size(), 1, -1 do
      local widget = S.history:at(index) ---@type eve.t.ux.IWidget|nil
      if widget ~= nil and widget:status() == "visible" then
        S.history:go(index)
        return widget, index
      end
    end
    return nil, nil
  end,
  open = function(widget)
    local present = S.get_widget_current() ---@type eve.t.ux.IWidget|nil
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
    local present = S.get_widget_current() ---@type eve.t.ux.IWidget|nil
    if present ~= nil then
      if present:focused() then
        present:hide()
      else
        present:focus()
      end
    end
    return present
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
      close = function()
        close(widget)
      end,
      focus = function()
        local present = S.get_widget_current() ---@type eve.t.ux.IWidget|nil
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
