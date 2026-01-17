---@type fun(w1: dot.t.IWidget, w2: dot.t.IWidget): boolean
local equals = stl.fn.equals_shallow

---@class dot.state.widget
local M = {}

---@type stl.c.History
M.history = stl.c.History.new({
  name = "widget",
  capacity = 100,
  equals = equals,
})

---@return nil
function M.backward()
  local present, present_index = M.history:present() ---@type dot.t.IWidget|nil, integer
  if present == nil or present_index <= 1 then
    return
  end

  local widget = nil ---@type dot.t.IWidget|nil
  local is_bottom = false ---@type boolean
  while not is_bottom do
    widget, is_bottom = M.history:backward()
    if widget ~= nil and not widget:isdisposed() and not equals(widget, present) then
      present:hide()
      widget:focus()
      break
    end
  end
end

---@return nil
function M.forward()
  local present, present_index = M.history:present() ---@type dot.t.IWidget|nil, integer
  if present == nil or present_index >= M.history:size() then
    return
  end

  local widget = nil ---@type dot.t.IWidget|nil
  local is_top = false ---@type boolean
  while not is_top do
    widget, is_top = M.history:forward() ---@type dot.t.IWidget|nil, boolean
    if widget ~= nil and not widget:isdisposed() and not equals(widget, present) then
      present:hide()
      widget:focus()
      break
    end
  end
end

---@param widget                        dot.t.IWidget
---@return stl.t.IKeymap[]
function M.get_keymaps(widget)
  ---@return nil
  local function on_close()
    widget:close()

    local widget_visible, widget_visible_index = M.get_widget_visible() ---@type dot.t.IWidget|nil, integer|nil
    if widget_visible ~= nil and widget_visible_index ~= nil then
      widget_visible:focus()
      M.history:go(widget_visible_index)
    else
      local winnr_command = dot.state.status.get_winnr_command() ---@type integer|nil
      if winnr_command ~= nil then
        vim.api.nvim_set_current_win(winnr_command)
      end
    end
  end

  ---@type stl.t.IKeymap[]
  local keymaps = {
    {
      modes = { "i", "n", "t", "x" },
      key = "<C-a>i",
      aliases = { "<D-i>", "<M-i>" },
      callback = M.backward,
      desc = "widget: backward",
    },
    {
      modes = { "i", "n", "t", "x" },
      key = "<C-a>o",
      aliases = { "<D-o>", "<M-o>" },
      callback = M.forward,
      desc = "widget: forward",
    },
    {
      modes = { "i", "n", "x" },
      key = "<C-a>q",
      aliases = { "<D-q>", "<M-q>" },
      callback = on_close,
      desc = "widget: close present",
    },
    {
      modes = { "n", "x" },
      key = "q",
      callback = on_close,
      desc = "widget: close present",
    },
  }
  return keymaps
end

---@return dot.t.IWidget|nil
---@return integer|nil
function M.get_widget_current()
  local present, present_index = M.history:present() ---@type dot.t.IWidget|nil, integer
  if present ~= nil and not present:isdisposed() then
    return present, present_index
  end

  for index = present_index - 1, 1, -1 do
    local widget = M.history:at(index) ---@type dot.t.IWidget|nil
    if widget ~= nil and not widget:isdisposed() then
      M.history:go(index)
      return widget, index
    end
  end
  M.history:go(1)
end

---@return dot.t.IWidget|nil
---@return integer|nil
function M.get_widget_visible()
  local present, present_index = M.history:present() ---@type dot.t.IWidget|nil, integer
  if present ~= nil and present:isvisible() then
    return present, present_index
  end

  for index = M.history:size(), 1, -1 do
    local widget = M.history:at(index) ---@type dot.t.IWidget|nil
    if widget ~= nil and widget:isvisible() then
      M.history:go(index)
      return widget, index
    end
  end
  return nil, nil
end

---@param widget                        dot.t.IWidget
---@return nil
function M.push(widget)
  local present = M.get_widget_current() ---@type dot.t.IWidget|nil
  if present == nil then
    M.history:push(widget)
    return
  end

  if not equals(present, widget) then
    if M.history:size() == M.history:capacity() then
      local bottom_widget = M.history:bottom() ---@type dot.t.IWidget|nil
      if bottom_widget ~= nil then
        bottom_widget:hide()
      end
    end
    M.history:push(widget)
    -- present:hide()
  end
end

---@return nil
function M.resize()
  for widget in M.history:iterator() do
    if widget:isvisible() then
      widget:resize()
    end
  end
end

---@return dot.t.IWidget|nil
function M.resume()
  local present, present_index = M.get_widget_current() ---@type dot.t.IWidget|nil, integer|nil
  if present ~= nil then
    if present:isfocused() then
      present:hide()
    else
      if present_index ~= nil then
        for index = M.history:size(), 1, -1 do
          local widget = M.history:at(index) ---@type dot.t.IWidget|nil
          if widget ~= nil and widget:isvisible() then
            M.history:go(index)
            widget:focus()
            return widget
          end
        end
      end
      present:focus()
    end
  end

  return present
end

---@param raw_widget                    dot.t.IRawWidget
---@return dot.t.IWidget
function M.wrap(raw_widget)
  local widget ---@type dot.t.IWidget

  local close = raw_widget.close
  local focus = raw_widget.focus
  local hide = raw_widget.hide
  local isdisposed = raw_widget.isdisposed
  local isfocused = raw_widget.isfocused
  local isvisible = raw_widget.isvisible
  local resize = raw_widget.resize

  ---@type dot.t.IWidget
  widget = {
    name = raw_widget.name,
    close = function()
      close(widget)
    end,
    focus = function()
      focus(widget)
      M.push(widget)
    end,
    hide = function()
      hide(widget)
    end,
    isdisposed = function()
      return isdisposed(widget)
    end,
    isfocused = function()
      return isfocused(widget)
    end,
    isvisible = function()
      return isvisible(widget)
    end,
    resize = function()
      resize(widget)
    end,
  }
  return widget
end

return M
