local History = require("eve.collection.history")

local _widgets = History.new({ name = "widgets", capacity = 100 })

---@class eve.globals.widgets
local M = {}

---@return nil
function M.backward()
  local present, present_index = _widgets:present() ---@type eve.types.ux.IWidget|nil, integer|nil
  if present == nil or present_index <= 1 then
    return
  end

  while true do
    local widget, is_bottom = _widgets:backward() ---@type eve.types.ux.IWidget|nil, boolean
    if widget ~= nil and widget ~= present and widget:status() == "hidden" then
      present:hide()
      widget:show()
      break
    end

    if is_bottom then
      break
    end
  end
end

---@return nil
function M.forward()
  local present, present_index = _widgets:present() ---@type eve.types.ux.IWidget|nil, integer|nil
  if present == nil or present_index >= _widgets:size() then
    return
  end

  while true do
    local widget, is_top = _widgets:forward() ---@type eve.types.ux.IWidget|nil, boolean
    if widget ~= nil and widget ~= present and widget:status() == "hidden" then
      present:hide()
      widget:show()
      break
    end

    if is_top then
      break
    end
  end
end

---@return eve.types.ux.IWidget|nil
function M.get_current_widget()
  while true do
    local present, preset_index = _widgets:present() ---@type eve.types.ux.IWidget|nil, integer
    if present == nil then
      return nil
    end

    local status = present:status() ---@type eve.enums.WidgetStatus
    if status ~= "closed" then
      return present
    end

    if preset_index <= 1 then
      break
    end

    _widgets:backward()
  end
  return nil
end

---@return eve.types.ux.IKeymap[]
function M.get_keymaps()
  ---@type eve.types.ux.IKeymap[]
  local keymaps = {
    { modes = { "i", "n", "t", "v" }, key = "<C-a>i", callback = M.backward, desc = "widgets: backward" },
    { modes = { "i", "n", "t", "v" }, key = "<C-a>o", callback = M.forward, desc = "widgets: forward" },
    { modes = { "i", "n", "t", "v" }, key = "<M-i>", callback = M.backward, desc = "widgets: backward" },
    { modes = { "i", "n", "t", "v" }, key = "<M-o>", callback = M.forward, desc = "widgets: forward" },
  }
  return keymaps
end

---@param widget                        eve.types.ux.IWidget
---@return nil
function M.push(widget)
  _widgets:push(widget)
  for w in _widgets:iterator() do
    if w ~= widget and w:status() == "visible" then
      w:hide()
    end
  end
end

---@return boolean
function M.resume()
  while true do
    local present, present_index = _widgets:present() ---@type eve.types.ux.IWidget|nil, integer
    if present == nil then
      break
    end

    local status = present:status() ---@type eve.enums.WidgetStatus
    if status == "visible" then
      vim.schedule(function()
        present:hide()
      end)
      return true
    elseif status == "hidden" then
      vim.schedule(function()
        present:show()
      end)
      return true
    end

    if present_index <= 1 then
      break
    end

    _widgets:backward()
  end
  return false
end

---@return nil
function M.resize()
  for widget in _widgets:iterator() do
    local status = widget:status() ---@type eve.enums.WidgetStatus
    if status == "visible" then
      widget:resize()
    end
  end
end

return M
