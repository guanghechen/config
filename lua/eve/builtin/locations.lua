local path = require("eve.lib.path")
local Disposable = require("eve.lib.collection.disposable")
local Observable = require("eve.lib.collection.observable")
local checks = require("eve.builtin.checks")
local mvc = require("eve.builtin.mvc")

local _initial_winnr = vim.api.nvim_get_current_win() ---@type integer
local _initial_bufnr = vim.api.nvim_get_current_buf() ---@type integer
local _current_bufnr = Observable.from_value(_initial_bufnr) ---@type eve.lib.collection.IObservable
local _current_winnr = Observable.from_value(_initial_winnr) ---@type eve.lib.collection.IObservable
local _current_buf_dirpath = path.cwd() ---@type string
local _current_buf_filepath = nil ---@type string|nil

---@class eve.builtin.locations
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

---@param bufnr                         integer
---@return nil
function M.set_current_bufnr(bufnr)
  local bufnr_cur = _current_bufnr:snapshot() ---@type integer|nil
  if bufnr == bufnr_cur or not checks.is_buf_valid(bufnr) then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local dirpath = path.dirname(filepath) ---@type string

  _current_buf_dirpath = dirpath ---@type string
  _current_buf_filepath = vim.fn.filereadable(filepath) == 1 and filepath or nil ---@type string|nil
  _current_bufnr:next(bufnr)
end

---@param winnr                         integer
---@return nil
function M.set_current_winnr(winnr)
  if winnr > 0 and vim.api.nvim_win_is_valid(winnr) then
    _current_winnr:next(winnr)
  end
end

---@param subscriber                    eve.lib.collection.ISubscriber
---@param ignoreInitial                 ?boolean
function M.watch_current_bufnr(subscriber, ignoreInitial)
  ---@type eve.lib.collection.IUnsubscribable
  local unsubscribable = _current_bufnr:subscribe(subscriber, ignoreInitial)
  mvc.add_disposable(Disposable.from_unsubscribable(unsubscribable))
end

---@param subscriber                    eve.lib.collection.ISubscriber
---@param ignoreInitial                 ?boolean
function M.watch_current_winnr(subscriber, ignoreInitial)
  ---@type eve.lib.collection.IUnsubscribable
  local unsubscribable = _current_winnr:subscribe(subscriber, ignoreInitial)
  mvc.add_disposable(Disposable.from_unsubscribable(unsubscribable))
end

return M
