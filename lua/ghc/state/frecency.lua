---@class ghc.state.frecency.IData
---@field public files                  eve.types.collection.frecency.ISerializedData|nil

---@class ghc.state.frecency.IState
---@field public files                  eve.types.collection.IFrecency

local FILEPATH = eve.path.locate_session_filepath({ filename = "state.frecency.json" }) ---@type string
local state = nil ---@type ghc.state.frecency.IState|nil

---@class ghc.state.files_frecency
local M = {}

---@return ghc.state.frecency.IState
function M.load_and_autosave()
  if state == nil then
    state = {
      files = eve.c.Frecency.new({
        items = {},
        normalize = function(key)
          return eve.md5.sumhexa(key)
        end,
      }),
    }

    local data = eve.fs.read_json({ filepath = FILEPATH, silent_on_bad_path = true, silent_on_bad_json = false })
    if data ~= nil and type(data) == "table" then
      for key, value in pairs(data) do
        if state[key] ~= nil and type(value) == "table" then
          ---@cast value eve.types.collection.frecency.ISerializedData
          state[key]:load(value)
        end
      end
    end

    fml.disposable:add_disposable(eve.c.Disposable.new({
      on_dispose = function()
        ---@type boolean, ghc.state.frecency.IData
        local ok, json_data = pcall(function()
          local serialized_data = {} ---@type table<string, eve.types.collection.frecency.ISerializedData>
          for key, value in pairs(state) do
            local frecency_data = value:dump() ---@type eve.types.collection.frecency.ISerializedData
            serialized_data[key] = frecency_data
          end
          return serialized_data
        end)
        if ok then
          eve.fs.write_json(FILEPATH, json_data, false)
        else
          eve.fs.write_json(FILEPATH, { error = json_data }, false)
        end
      end,
    }))
  end

  return state
end

return M
