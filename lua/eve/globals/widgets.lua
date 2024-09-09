local Disposable = require("eve.collection.disposable")
local Observable = require("eve.collection.observable")
local CircularStack = require("eve.collection.circular_stack")
local path = require("eve.std.path")
local mvc = require("eve.globals.mvc")

local initial_winnr = vim.api.nvim_get_current_win() ---@type integer
local initial_bufnr = vim.api.nvim_get_current_buf() ---@type integer

local _widgets = CircularStack.new({ capacity = 100 })
local _current_bufnr = Observable.from_value(initial_bufnr) ---@type eve.types.collection.IObservable
local _current_winnr = Observable.from_value(initial_winnr) ---@type eve.types.collection.IObservable
local _current_buf_dirpath = path.cwd() ---@type string
local _current_buf_filepath = nil ---@type string|nil

---@class eve.globals.widgets
local M = {}

---@return integer|nil
function M.get_current_bufnr()
  local bufnr = _current_bufnr:snapshot() ---@type integer
  return bufnr > 0 and bufnr or nil
end

---@return integer|nil
function M.get_current_winnr()
  local winnr = _current_winnr:snapshot() ---@type integer
  return winnr > 0 and winnr or nil
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
---@return nil
function M.set_current_bufnr(bufnr)
  local bufnr_cur = _current_bufnr:snapshot() ---@type integer|nil
  if bufnr ~= bufnr_cur and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
    local dirpath = path.dirname(filepath) ---@type string

    _current_buf_dirpath = dirpath ---@type string
    _current_buf_filepath = vim.fn.filereadable(filepath) == 1 and filepath or nil ---@type string|nil
    _current_bufnr:next(bufnr)
  end
end

---@param winnr                         integer
---@return nil
function M.set_current_winnr(winnr)
  if winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
    _current_winnr:next(winnr)
  end
end

---@param subscriber                    eve.types.collection.ISubscriber
---@param ignoreInitial                 ?boolean
function M.watch_current_bufnr(subscriber, ignoreInitial)
  ---@type eve.types.collection.IUnsubscribable
  local unsubscribable = _current_bufnr:subscribe(subscriber, ignoreInitial)
  mvc.add_disposable(Disposable.from_unsubscribable(unsubscribable))
end

---@param subscriber                    eve.types.collection.ISubscriber
---@param ignoreInitial                 ?boolean
function M.watch_current_winnr(subscriber, ignoreInitial)
  ---@type eve.types.collection.IUnsubscribable
  local unsubscribable = _current_winnr:subscribe(subscriber, ignoreInitial)
  mvc.add_disposable(Disposable.from_unsubscribable(unsubscribable))
end

return M
