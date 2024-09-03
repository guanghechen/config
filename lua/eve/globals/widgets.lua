local CircularStack = require("eve.collection.circular_stack")

local widgets = CircularStack.new({ capacity = 100 })

---@class eve.globals.widgets
local M = {}

---@param widget                        eve.types.ux.IWidget
---@return nil
function M.push(widget)
  widgets:push(widget)
end

---@return boolean
function M.resume()
  while widgets:size() > 0 do
    local widget = widgets:top() ---@type eve.types.ux.IWidget

    if widget:alive() then
      vim.schedule(function()
        widget:toggle()
      end)
      return true
    end

    widgets:pop()
  end
  return false
end

---@return nil
function M.resize()
  for widget in widgets:iterator() do
    widget:resize()
  end
end

return M
