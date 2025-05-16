---@class fml.dressing.provider.codeaction.IItemData : fml.dressing.select.IItemData
---@field public index                  integer
---@field public client_name            string
---@field public content                string
---@field public order_client           integer
---@field public order_type             integer

---@class fml.dressing.provider.codeaction.IItem : eve.ux.select.IItem
---@field public data                   fml.dressing.provider.codeaction.IItemData

local ACTION_TYPE_ORDERS = {
  ["Add"] = 1,
  ["update"] = 1,
  ["fix"] = 1,
  ["disable"] = 10,
}

local LSP_CLIENT_NAME_ORDERS = {
  bashls = 5,
  clangd = 5,
  cssls = 5,
  dockerls = 5,
  docker_compose_language_service = 10,
  eslint = 7,
  html = 5,
  jsonls = 5,
  lua_ls = 5,
  pyright = 5,
  rust_analyzer = 5,
  tailwindcss = 3,
  taplo = 5,
  vtsls = 5,
  vuels = 7,
  yamlls = 5,
}

---@param items                         any[]
---@return eve.ux.select.IProvider
---@return integer
local function codeaction_provider(items)
  local width_order = #tostring(#items) ---@type integer
  local width_content = 0 ---@type integer
  local width_client_name = 0 ---@type integer
  local item_data_list = {} ---@type fml.dressing.provider.codeaction.IItemData[]
  for index, item in ipairs(items) do
    local order = std.string.pad_start(tostring(index), width_order, " ") ---@type string
    local content = item.action.title ---@type string
    local client_id = item.ctx.client_id ---@type integer
    local client = vim.lsp.get_client_by_id(client_id) ---@type vim.lsp.Client|nil
    local client_name = client and client.name or tostring(client_id) ---@type string

    width_order = width_order < #order and #order or width_order
    width_content = width_content < #content and #content or width_content
    width_client_name = width_client_name < #client_name and #client_name or width_client_name

    local action_type = content:match("^%S+") ---@type string|nil
    local order_type = action_type ~= nil and ACTION_TYPE_ORDERS[action_type:lower()] or math.huge ---@type integer
    local order_client = LSP_CLIENT_NAME_ORDERS[client_name] or math.huge ---@type integer

    ---@type fml.dressing.provider.codeaction.IItemData
    local item_data = {
      original_item = item,
      index = index,
      content = content,
      client_name = client_name,
      order_client = order_client,
      order_type = order_type,
    }
    item_data_list[#item_data_list + 1] = item_data
  end

  table.sort(item_data_list, function(a, b)
    if a.order_type ~= b.order_type then
      return a.order_type < b.order_type
    end

    if a.order_client ~= b.order_client then
      return a.order_client < b.order_client
    end
    return a.index < b.index
  end)

  local select_items = {} ---@type fml.dressing.provider.codeaction.IItem[]
  for index, item_data in ipairs(item_data_list) do
    local uuid = std.string.pad_start(tostring(item_data.index), width_order, " ") ---@type string
    local order = std.string.pad_start(tostring(index), width_order, " ") ---@type string
    item_data.index = index

    local text_content = std.string.pad_end(item_data.content, width_content, " ")
    local text_client_name = item_data.client_name ---@type string
    local text = order .. ": " .. text_content .. "  " .. text_client_name ---@type string

    ---@type fml.dressing.provider.codeaction.IItem
    local select_item = {
      uuid = uuid,
      text = text,
      data = item_data,
    }
    select_items[#select_items + 1] = select_item
  end

  ---@type eve.ux.select.IProvider
  local provider = {
    fetch_data = function()
      return { items = select_items }
    end,
    render_item = function(item, match)
      local item_data = item.data ---@type fml.dressing.provider.codeaction.IItemData
      local text_content = std.string.pad_end(item_data.content, width_content, " ")
      local text_client_name = item_data.client_name ---@type string
      local text = item.text ---@type string

      ---@type std.t.IHighlightInline[]
      local highlights = {
        { coll = 0, colr = width_order + 1, hlname = "f_us_codeaction_order" },
        { coll = width_order + 2, colr = width_order + 2 + #text_content, hlname = "f_us_codeaction_content" },
        {
          coll = width_order + #text_content + 4,
          colr = width_order + #text_content + 4 + #text_client_name,
          hlname = "f_us_codeaction_client_name",
        },
      }

      local offset = width_order + 2 ---@type integer
      for _, piece in ipairs(match.matches) do
        ---@type std.t.IHighlightInline[]
        local highlight = { coll = offset + piece.l, colr = offset + piece.r, hlname = "f_us_main_match" }
        highlights[#highlights + 1] = highlight
      end

      return text, highlights
    end,
  }

  local width = width_order + width_content + width_client_name + 4 ---@type integer
  return provider, width
end

return codeaction_provider
