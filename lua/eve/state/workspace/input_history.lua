local History = require("eve.collection.history")

---@class eve.state.input_history.data
---@field public find_buffer            eve.collection.history.ISerializedData
---@field public find_file              eve.collection.history.ISerializedData
---@field public search_in_file         eve.collection.history.ISerializedData

---@class eve.state.input_history.state
---@field public find_buffer            eve.collection.IHistory
---@field public find_file              eve.collection.IHistory
---@field public search_in_file         eve.collection.IHistory

---@class eve.state.input_history
---@field public defaults               fun(): eve.state.input_history.data
---@field public dump                   fun(): eve.state.input_history.data
---@field public load                   fun(data: unknown): eve.state.input_history.state
---@field public normalize              fun(data: unknown): eve.state.input_history.data
local M = {}

local _state = nil ---@type eve.state.input_history.state | nil

---@return eve.state.input_history.data
function M.defaults()
  ---@type eve.state.input_history.data
  return {
    find_buffer = { present = 0, stack = {} },
    find_file = { present = 0, stack = {} },
    search_in_file = { present = 0, stack = {} },
  }
end

---@param data                        any
---@return eve.state.input_history.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.input_history.data
  if type(data) == "table" then
    for key, history in pairs(resolved) do
      local data_history = data[key] ---@type eve.collection.history.ISerializedData|nil
      if type(data_history) == "table" then
        if type(data_history.present) == "number" then
          history.present = data_history.present
        end
        if type(data_history.stack) == "table" then
          history.stack = data_history.stack
        end
      end
    end
  end

  ---@type eve.state.input_history.data
  return resolved
end

---@return eve.state.input_history.data
function M.dump()
  if _state == nil then
    ---@type eve.state.input_history.data
    return M.defaults()
  end

  ---@type eve.state.input_history.data
  return {
    find_buffer = _state.find_buffer:dump(),
    find_file = _state.find_file:dump(),
    search_in_file = _state.search_in_file:dump(),
  }
end

---@param raw_data                      any
---@return eve.state.input_history.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.input_history.data

  if _state == nil then
    ---@type eve.state.input_history.state
    _state = {
      find_buffer = History.deserialize({
        name = "find_buffer",
        capacity = 100,
        data = data.find_buffer,
      }),
      find_file = History.deserialize({
        name = "find_file",
        capacity = 100,
        data = data.find_file,
      }),
      search_in_file = History.deserialize({
        name = "search_in_files",
        capacity = 300,
        data = data.search_in_file,
      }),
    }
    return _state
  end

  _state.find_buffer:load(data.find_buffer)
  _state.find_file:load(data.find_file)
  _state.search_in_file:load(data.search_in_file)
  return _state
end

return M
