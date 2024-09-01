---@class ghc.state.input_history.IData
---@field public find_files                  fc.types.collection.history.ISerializedData|nil
---@field public search_in_files             fc.types.collection.history.ISerializedData|nil

---@class ghc.state.input_history.IState
---@field public find_files                  fc.types.collection.IHistory
---@field public search_in_files             fc.types.collection.IHistory

local FILEPATH = fc.path.locate_session_filepath({ filename = "state.input_history.json" }) ---@type string
local state = nil ---@type ghc.state.input_history.IState|nil

---@class ghc.state.files_history
local M = {}

---@return ghc.state.input_history.IState
function M.load_and_autosave()
  if state == nil then
    state = {
      find_files = fc.c.History.new({ name = "find_files", capacity = 100 }),
      search_in_files = fc.c.History.new({ name = "search_in_files", capacity = 300 }),
    }

    local data = fc.fs.read_json({ filepath = FILEPATH, silent_on_bad_path = true, silent_on_bad_json = false })
    if data ~= nil and type(data) == "table" then
      for key, value in pairs(data) do
        if state[key] ~= nil and type(value) == "table" then
          ---@cast value fc.types.collection.history.ISerializedData
          state[key]:load(value)
        end
      end
    end

    fml.disposable:add_disposable(fc.c.Disposable.new({
      on_dispose = function()
        ---@type boolean, ghc.state.input_history.IData
        local ok, json_data = pcall(function()
          local serialized_data = {} ---@type table<string, fc.types.collection.history.ISerializedData>
          for key, value in pairs(state) do
            local history_data = value:dump() ---@type fc.types.collection.history.ISerializedData
            serialized_data[key] = history_data
          end
          return serialized_data
        end)
        if ok then
          fc.fs.write_json(FILEPATH, json_data, false)
        else
          fc.fs.write_json(FILEPATH, { error = json_data }, false)
        end
      end,
    }))
  end

  return state
end

return M
