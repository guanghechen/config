---@class fml.action.find.vim_options.IItemData
---@field public name                   string
---@field public type                   string
---@field public scope                  string
---@field public value                  string|number|boolean
---@field public text                   string

---@class fml.action.find.vim_options.IItem : eve.ux.select.IItem
---@field public data                   fml.action.find.vim_options.IItemData

local WIDTH_NAME = 25 ---@type integer
local WIDTH_TYPE = 12 ---@type integer
local WIDTH_SCOPE = 11 ---@type integer
local OFFSET_NAME = 0 ---@type integer
local OFFSET_TYPE = OFFSET_NAME + WIDTH_NAME ---@type integer
local OFFSET_SCOPE = OFFSET_TYPE + WIDTH_TYPE ---@type integer
local OFFSET_VALUE = OFFSET_SCOPE + WIDTH_SCOPE ---@type integer

---@type eve.ux.select.IProvider
local provider = {
  fetch_data = function()
    local items = {} ---@type eve.ux.select.IItem[]

    for name, info in pairs(vim.api.nvim_get_all_options_info()) do
      local ok, value = pcall(vim.api.nvim_get_option_value, name, {})
      if not ok or value == nil then
        value = info.default
      end

      local text_name = eve.string.pad_end(info.name, WIDTH_NAME, " ") ---type string
      local text_type = eve.string.pad_end(info.type, WIDTH_TYPE, " ") ---type string
      local text_scope = eve.string.pad_end(info.scope, WIDTH_SCOPE, " ") ---type string
      local text_value = tostring(value):gsub(string.char(9), "<TAB>"):gsub("", "<C-F>"):gsub(" ", "<Space>") ---@type string
      local text = text_name .. text_type .. text_scope .. text_value ---@type string
      local text_for_search = text_name .. string.rep(" ", WIDTH_TYPE + WIDTH_SCOPE) .. text_value ---@type string

      ---@type fml.action.find.vim_options.IItemData
      local data = {
        name = name,
        scope = info.scope,
        type = info.type,
        value = value,
        text = text,
      }

      ---@type fml.action.find.vim_options.IItem
      local item = { uuid = name, text = text_for_search, data = data }
      table.insert(items, item)
    end

    table.sort(items, function(a, b)
      return a.data.name < b.data.name
    end)
    return { items = items }
  end,
  render_item = function(item, match)
    local data = item.data ---@type fml.action.find.vim_options.IItemData

    ---@type eve.t.IHighlightInline[]
    local highlights = {
      { coll = OFFSET_NAME, colr = OFFSET_NAME + #data.name, hlname = "f_us_vo_name" },
      { coll = OFFSET_TYPE, colr = OFFSET_TYPE + #data.type, hlname = "f_us_vo_type" },
      { coll = OFFSET_SCOPE, colr = OFFSET_SCOPE + #data.scope, hlname = "f_us_vo_scope" },
      { coll = OFFSET_VALUE, colr = #item.text, hlname = "f_us_vo_value" },
    }

    for _, piece in ipairs(match.matches) do
      ---@type eve.t.IHighlightInline[]
      local highlight = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
      table.insert(highlights, highlight)
    end
    return data.text, highlights
  end,
}

---@type eve.ux.ISelect
local select = eve.ux.Select.new({
  dimension = {
    height = 0.8,
    max_height = 1,
    max_width = 1,
    width = 0.8,
    width_preview = 0,
  },
  dirty_on_invisible = false,
  multiple = false,
  preview_enabled = false,
  extend_preset_keymaps = true,
  provider = provider,
  title = "Find Vim Options",
  on_confirm = function(widget, items)
    if #items == 1 then
      widget:close()
      local item = items[1] ---@type eve.ux.select.IItem
      local data = item.data ---@type fml.action.find.vim_options.IItemData
      local esc = vim.fn.mode() == "i" and vim.api.nvim_replace_termcodes("<esc>", true, false, true) or "" ---@type string
      vim.api.nvim_feedkeys(string.format("%s:set %s=%s", esc, data.name, data.value), "m", true)
    end
  end,
})

---@class fml.action.find
local M = {}

---@return nil
function M.find_vim_options()
  select:focus()
end

return M
