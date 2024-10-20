---@param items                         any[]
---@param opts                          ghc.dressing.select.IOptions
---@return t.fml.ux.select.IProvider
---@return integer
local function normal_provider(items, opts)
  local format_item = opts.format_item or eve.util.identity ---@type fun(item): string
  local width = 0 ---@type integer
  local select_items = {} ---@type t.fml.ux.select.IItem[]
  for index, item in ipairs(items) do
    local uuid = tostring(index) ---@type string
    local text = format_item(item) ---@type string
    local data = { original_item = item } ---@type ghc.dressing.select.IItemData
    local select_item = { uuid = uuid, text = text, data = data } ---@type t.fml.ux.select.IItem
    width = width < #text and #text or width ---@type integer
    table.insert(select_items, select_item)
  end

  ---@type t.fml.ux.select.IProvider
  local provider = {
    fetch_data = function()
      return { items = select_items }
    end,
  }
  return provider, width
end

return normal_provider
