local Observable = require("fml.collection.observable")
local session = require("ghc.context.session")

---@class ghc.command.search.IItemData
---@field public filepath               string
---@field public s_row                  ?integer
---@field public s_col                  ?integer
---@field public t_row                  ?integer
---@field public t_col                  ?integer

local _item_data_map = {} ---@type table<string, ghc.command.search.IItemData>

---@param input_text                  string
---@param callback                    fml.types.ui.search.IFetchItemsCallback
---@return nil
local function fetch_items(input_text, callback)
  local cwd = session.search_cwd:snapshot() ---@type string
  local flag_case_sensitive = session.search_flag_regex:snapshot() ---@type boolean
  local flag_regex = session.search_flag_regex:snapshot() ---@type boolean
  local search_paths = session.search_paths:snapshot() ---@type string
  local include_patterns = session.search_include_patterns:snapshot() ---@type string
  local exclude_patterns = session.search_exclude_patterns:snapshot() ---@type string
  local scope = session.search_scope:snapshot() ---@type string

  ---@type fml.std.oxi.search.IResult
  local result = fml.oxi.search({
    cwd = cwd,
    flag_case_sensitive = flag_case_sensitive,
    flag_regex = flag_regex,
    search_pattern = input_text,
    search_paths = search_paths,
    include_patterns = include_patterns,
    exclude_patterns = exclude_patterns,
    specified_filepath = nil,
  })

  if result.error ~= nil or result.items == nil then
    callback(false, result.error)
    return
  end

  local items = {} ---@type fml.types.ui.search.IItem[]
  local item_data_map = {} ---@type table<string, ghc.command.search.IItemData>
  for _, raw_filepath in ipairs(result.item_orders) do
    local file_item = result.items[raw_filepath] ---@type fml.std.oxi.search.IFileMatch|nil
    if file_item ~= nil then
      local filename = fml.path.basename(raw_filepath)
      local icon, icon_hl = fml.util.calc_fileicon(filename)
      local filepath = fml.path.relative(cwd, raw_filepath)

      ---@class ghc.command.search.IItemData
      local data_root = { filepath = filepath }
      item_data_map[filepath] = data_root

      local icon_width = string.len(icon) ---@type integer
      local highlights = { { cstart = 0, cend = icon_width, hlname = icon_hl } } ---@type fml.types.ui.printer.ILineHighlight[]

      ---@type fml.types.ui.search.IItem
      local item = {
        uuid = filepath,
        text = icon .. " " .. filepath,
        highlights = highlights,
      }
      table.insert(items, item)
    end
  end
  _item_data_map = item_data_map
  callback(true, items)
end

local search = fml.ui.search.Search.new({
  title = "Search file",
  input = Observable.from_value(""),
  fetch_items = fetch_items,
  width = 80,
  height = 0.8,
  on_confirm = function(item)
    local winnr = fml.api.state.win_history:present() ---@type integer
    if winnr ~= nil then
      local cwd = session.search_cwd:snapshot() ---@type string
      local data = _item_data_map[item.uuid] ---@type ghc.command.search.IItemData|nil
      if data ~= nil then
        local filepath = fml.path.join(cwd, data.filepath) ---@type string
        vim.schedule(function()
          fml.api.buf.open(winnr, filepath)
        end)
      end
      return true
    end
    return false
  end,
})

search:open()
