local Disposable = require("eve.collection.disposable")
local Observable = require("eve.collection.observable")
local History = require("eve.collection.history")
local path = require("eve.std.path")
local mvc = require("eve.globals.mvc")

local initial_winnr = vim.api.nvim_get_current_win() ---@type integer
local initial_bufnr = vim.api.nvim_get_current_buf() ---@type integer

local _widgets = History.new({ name = "widgets", capacity = 100 })
local _current_bufnr = Observable.from_value(initial_bufnr) ---@type eve.types.collection.IObservable
local _current_winnr = Observable.from_value(initial_winnr) ---@type eve.types.collection.IObservable
local _current_buf_dirpath = path.cwd() ---@type string
local _current_buf_filepath = nil ---@type string|nil

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
