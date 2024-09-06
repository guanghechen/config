---@class ghc.dressing.provider.codeaction.IItemData : ghc.dressing.select.IItemData
---@field public order                  string
---@field public content                string
---@field public client_name            string

---@class ghc.dressing.provider.codeaction.IItem : fml.types.ui.select.IItem
---@field public data                   ghc.dressing.provider.codeaction.IItemData

---@param items                         any[]
---@return fml.types.ui.select.IProvider
---@return integer
local function codeaction_provider(items)
  local width_order = #tostring(#items) ---@type integer
  local width_content = 0 ---@type integer
  local width_client_name = 0 ---@type integer
  local select_items = {} ---@type ghc.dressing.provider.codeaction.IItem[]
  for index, item in ipairs(items) do
    local order = eve.string.pad_start(tostring(index), width_order, " ") ---@type string
    local content = item.action.title ---@type string
    local client_id = item.ctx.client_id ---@type integer
    local client = vim.lsp.get_client_by_id(client_id) ---@type vim.lsp.Client|nil
    local client_name = client and client.name or tostring(client_id) ---@type string

    width_order = width_order < #order and #order or width_order
    width_content = width_content < #content and #content or width_content
    width_client_name = width_client_name < #client_name and #client_name or width_client_name

    ---@type ghc.dressing.provider.codeaction.IItemData
    local item_data = {
      original_item = item,
      order = order,
      content = content,
      client_name = client_name,
    }

    ---@type ghc.dressing.provider.codeaction.IItem
    local select_item = {
      uuid = order,
      text = content,
      data = item_data,
    }
    table.insert(select_items, select_item)
  end

  ---@type fml.types.ui.select.IProvider
  local provider = {
    fetch_data = function()
      return { items = select_items }
    end,
    render_item = function(item, match)
      local item_data = item.data ---@type ghc.dressing.provider.codeaction.IItemData
      local text_order = item_data.order ---@type string
      local text_content = eve.string.pad_end(item_data.content, width_content, " ")
      local text_client_name = item_data.client_name ---@type string
      local text = text_order .. ": " .. text_content .. "  " .. text_client_name ---@type string

      ---@type eve.types.ux.IInlineHighlight[]
      local highlights = {
        { coll = 0, colr = #text_order + 1, hlname = "f_us_codeaction_order" },
        { coll = #text_order + 2, colr = #text_order + 2 + #text_content, hlname = "f_us_codeaction_content" },
        {
          coll = #text_order + #text_content + 4,
          colr = #text_order + #text_content + 4 + #text_client_name,
          hlname = "f_us_codeaction_client_name",
        },
      }

      local offset = #text_order + 2 ---@type integer
      for _, piece in ipairs(match.matches) do
        ---@type eve.types.ux.IInlineHighlight[]
        local highlight = { coll = offset + piece.l, colr = offset + piece.r, hlname = "f_us_main_match" }
        table.insert(highlights, highlight)
      end

      return text, highlights
    end,
  }

  local width = width_order + width_content + width_client_name + 4 ---@type integer
  return provider, width
end

return codeaction_provider
