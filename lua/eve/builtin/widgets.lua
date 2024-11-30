local History = require("eve.lib.collection.history")

---@param w1                            eve.t.ux.IWidget
---@param w2                            eve.t.ux.IWidget
---@return boolean
local function equals_widgets(w1, w2)
  return w1 == w2
end

local _widgets = History.new({
  name = "widgets",
  capacity = 20,
  equals = equals_widgets,
})

---@class eve.builtin.widgets
local M = {}

---@return nil
function M.backward()
  local present, present_index = _widgets:present() ---@type eve.t.ux.IWidget|nil, integer|nil
  if present == nil or present_index <= 1 then
    return
  end

  local widget = nil ---@type eve.t.ux.IWidget|nil
  local is_bottom = false ---@type boolean
  while not is_bottom do
    widget, is_bottom = _widgets:backward()
    if widget ~= nil and not equals_widgets(widget, present) and widget:status() == "hidden" then
      present:hide()
      widget:show()
      break
    end
  end
end

---@return nil
function M.forward()
  local present, present_index = _widgets:present() ---@type eve.t.ux.IWidget|nil, integer|nil
  if present == nil or present_index >= _widgets:size() then
    return
  end

  local widget = nil ---@type eve.t.ux.IWidget|nil
  local is_top = false ---@type boolean
  while not is_top do
    widget, is_top = _widgets:forward() ---@type eve.t.ux.IWidget|nil, boolean
    if widget ~= nil and not equals_widgets(widget, present) and widget:status() == "hidden" then
      present:hide()
      widget:show()
      break
    end
  end
end

---@return nil
function M.close_present()
  local widget = M.get_current_widget() ---@type eve.t.ux.IWidget|nil
  if widget ~= nil and widget:status() == "visible" then
    widget:close()
  end
end

---@return eve.t.ux.IWidget|nil
function M.get_current_widget()
  local present = _widgets:present() ---@type eve.t.ux.IWidget|nil
  if present ~= nil and present:status() ~= "closed" then
    return present
  end

  local widget = nil ---@type eve.t.ux.IWidget|nil
  local is_bottom = false ---@type boolean
  while not is_bottom do
    widget, is_bottom = _widgets:backward()
    if widget ~= nil and widget:status() ~= "closed" then
      return widget
    end
  end

  return nil
end

---@return eve.t.IKeymap[]
function M.get_keymaps()
  ---@type eve.t.IKeymap[]
  local keymaps = {
    { modes = { "n", "v" }, key = "q", callback = M.close_present, desc = "widgets: close present" },
    { modes = { "i", "n", "t", "v" }, key = "<C-a>i", callback = M.backward, desc = "widgets: backward" },
    { modes = { "i", "n", "t", "v" }, key = "<C-a>o", callback = M.forward, desc = "widgets: forward" },
    { modes = { "i", "n", "t", "v" }, key = "<M-i>", callback = M.backward, desc = "widgets: backward" },
    { modes = { "i", "n", "t", "v" }, key = "<M-o>", callback = M.forward, desc = "widgets: forward" },
  }
  return keymaps
end

---@param widget                        eve.t.ux.IWidget
---@return nil
function M.open(widget)
  local present = M.get_current_widget() ---@type eve.t.ux.IWidget|nil
  if present == nil then
    _widgets:push(widget)
    widget:show()
    return
  end

  if not equals_widgets(present, widget) then
    if _widgets:size() == _widgets:capacity() then
      local bottom_widget = _widgets:bottom() ---@type eve.t.ux.IWidget
      bottom_widget:close()
    end
    _widgets:push(widget)

    present:hide()
  end

  widget:show()
end

---@return boolean
function M.resume()
  local present = M.get_current_widget() ---@type eve.t.ux.IWidget|nil
  if present == nil or present:status() == "closed" then
    return false
  end

  vim.schedule(function()
    local status = present:status() ---@type eve.e.WidgetStatus
    if status == "visible" then
      present:hide()
    elseif status == "hidden" then
      present:show()
    end
  end)
  return true
end

---@return nil
function M.resize()
  for widget in _widgets:iterator() do
    local status = widget:status() ---@type eve.e.WidgetStatus
    if status ~= "closed" then
      widget:resize()
    end
  end
end

return M
