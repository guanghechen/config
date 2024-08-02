local Observable = require("fml.collection.observable")

local cwd = fml.path.cwd() ---@type string

---@class ghc.command.search.word.IItemData
---@field public filepath               string

---@param input_text                  string
---@param callback                    fml.types.ui.search.IFetchItemsCallback
---@return nil
local function fetch_items(input_text, callback) end

local search = fml.ui.search.Search.new({
  title = "Search file",
  input = Observable.from_value(""),
  fetch_items = fetch_items,
  max_height = 25,
  on_confirm = function(item)
    local winnr = fml.api.state.win_history:present() ---@type integer
    if winnr ~= nil then
      local data = item.data ---@type ghc.command.search.word.IItemData
      local filepath = fml.path.resolve(cwd, data.filepath) ---@type string
      vim.schedule(function()
        fml.api.buf.open(winnr, filepath)
      end)
      return true
    end
    return false
  end,
})

search:open()
