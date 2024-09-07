local CircularStack = require("eve.collection.circular_stack")
local path = require("eve.std.path")

local _widgets = CircularStack.new({ capacity = 100 })
local _current_bufnr = nil ---@type integer|nil
local _current_buf_dirpath = path.cwd() ---@type string
local _current_buf_filepath = nil ---@type string|nil

---@class eve.globals.widgets
local M = {}

---@return integer|nil
function M.get_current_bufnr()
  return _current_bufnr
end

---@return string
function M.get_current_buf_dirpath()
  return _current_buf_dirpath
end

---@return string|nil
function M.get_current_buf_filepath()
  return _current_buf_filepath
end

---@return eve.types.ux.IWidget|nil
function M.get_current_widget()
  while _widgets:size() > 0 do
    local top = _widgets:top() ---@type eve.types.ux.IWidget|nil
    if top == nil then
      return nil
    end

    local status = top:status() ---@type eve.enums.WidgetStatus
    if status ~= "closed" then
      return top
    end

    _widgets:pop()
  end
  return nil
end

---@param widget                        eve.types.ux.IWidget
---@return nil
function M.push(widget)
  local widget_top = _widgets:top() ---@type eve.types.ux.IWidget|nil
  if widget_top == widget then
    return
  end

  for w in _widgets:iterator() do
    local status = w:status() ---@type eve.enums.WidgetStatus
    if status == "visible" then
      w:hide()
    end
  end
  _widgets:push(widget)
end

---@return boolean
function M.resume()
  while _widgets:size() > 0 do
    local widget = _widgets:top() ---@type eve.types.ux.IWidget
    local status = widget:status() ---@type eve.enums.WidgetStatus
    if status == "visible" then
      vim.schedule(function()
        widget:hide()
      end)
      return true
    elseif status == "hidden" then
      widget:show()
      return true
    end

    _widgets:pop()
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

---@param bufnr                         integer
---@param dirpath                       string
---@param filepath                      string
---@return nil
function M.set_current(bufnr, dirpath, filepath)
  _current_bufnr = bufnr ---@type integer
  _current_buf_dirpath = dirpath ---@type string
  _current_buf_filepath = vim.fn.filereadable(filepath) == 1 and filepath or nil ---@type string|nil
end

return M
