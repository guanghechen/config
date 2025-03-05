local Observable = require("eve.collection.observable")

---@class eve.state.lsp.data
---@field public python_py_path         string|nil
---@field public python_venv_path       string|nil

---@class eve.state.lsp.state
---@field public python_py_path         eve.collection.IObservable
---@field public python_venv_path       eve.collection.IObservable

---@class eve.state.lsp
---@field public defaults               fun(): eve.state.lsp.data
---@field public dump                   fun(): eve.state.lsp.data
---@field public load                   fun(data: unknown): eve.state.lsp.state
---@field public normalize              fun(data: unknown): eve.state.lsp.data
local M = {}

local _state = nil ---@type eve.state.lsp.state | nil

---@return eve.state.lsp.data
function M.defaults()
  ---@type eve.state.lsp.data
  return {
    python_py_path = nil,
    python_venv_path = nil,
  }
end

---@param data                        any
---@return eve.state.lsp.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.lsp.data
  if type(data) == "table" then
    if type(data.python_py_path) == "string" then
      resolved.python_py_path = data.python_py_path
    end
    if type(data.python_venv_path) == "string" then
      resolved.python_venv_path = data.python_venv_path
    end
  end
  return resolved
end

---@return eve.state.lsp.data
function M.dump()
  if _state == nil then
    return M.defaults()
  end

  ---@type eve.state.lsp.data
  return {
    python_py_path = _state.python_py_path:snapshot(),
    python_venv_path = _state.python_venv_path:snapshot(),
  }
end

---@param raw_data                      any
---@return eve.state.lsp.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.lsp.data

  if _state == nil then
    ---@type eve.state.lsp.state
    _state = {
      python_py_path = Observable.from_value(data.python_py_path),
      python_venv_path = Observable.from_value(data.python_venv_path),
    }
    return _state
  end

  _state.python_py_path:next(data.python_py_path)
  _state.python_venv_path:next(data.python_venv_path)
  return _state
end

return M
