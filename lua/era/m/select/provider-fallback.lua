---@return string
local function default_format_item(item)
  if type(item) == "string" then
    return item:gsub("\n", "\\n")
  end
  return tostring(item)
end

---@param items                         any[]
---@param opts                          era.m.select.IOptions
---@return era.m.picker.composer.list.IResetData
---@return integer
local function normal_provider(items, opts)
  local format_item = opts.format_item or default_format_item ---@type fun(item): string
  local width = 0 ---@type integer
  local select_items = {} ---@type era.m.select.ISelectItem[]
  for index, item in ipairs(items) do
    local uuid = tostring(index) ---@type string
    local text = format_item(item) ---@type string
    local data = { original_item = item } ---@type era.m.select.IItemData
    ---@type era.m.select.ISelectItem
    local select_item = {
      uuid = uuid,
      text = text,
      text_lower = text:lower(),
      highlights = {},
      data = data,
    }
    width = width < #text and #text or width ---@type integer
    select_items[#select_items + 1] = select_item
  end

  ---@type era.m.picker.composer.list.IResetData
  local data = { items = select_items }
  return data, width
end

return normal_provider
