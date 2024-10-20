---@class ghc.action.find_vim_options.IItemData
---@field public name                   string
---@field public type                   string
---@field public scope                  string
---@field public value                  string|number|boolean
---@field public text                   string

---@class ghc.action.find_vim_options.IItem : t.fml.ux.select.IItem
---@field public data                   ghc.action.find_vim_options.IItemData

local WIDTH_NAME = 25 ---@type integer
local WIDTH_TYPE = 12 ---@type integer
local WIDTH_SCOPE = 11 ---@type integer
local OFFSET_NAME = 0 ---@type integer
local OFFSET_TYPE = OFFSET_NAME + WIDTH_NAME ---@type integer
local OFFSET_SCOPE = OFFSET_TYPE + WIDTH_TYPE ---@type integer
local OFFSET_VALUE = OFFSET_SCOPE + WIDTH_SCOPE ---@type integer

---@type t.fml.ux.select.IProvider
local provider = {
  fetch_data = function()
    local items = {} ---@type t.fml.ux.select.IItem[]

    for name, info in pairs(vim.api.nvim_get_all_options_info()) do
      local ok, value = pcall(vim.api.nvim_get_option_value, name, {})
      if not ok or value == nil then
        value = info.default
      end

      local text_name = eve.string.pad_end(info.name, WIDTH_NAME, " ") ---type string
      local text_type = eve.string.pad_end(info.type, WIDTH_TYPE, " ") ---type string
      local text_scope = eve.string.pad_end(info.scope, WIDTH_SCOPE, " ") ---type string
      local text_value = eve.string.make_termcodes_visible(tostring(value)) ---@type string
      local text = text_name .. text_type .. text_scope .. text_value ---@type string
      local text_for_search = text_name .. string.rep(" ", WIDTH_TYPE + WIDTH_SCOPE) .. text_value ---@type string

      ---@type ghc.action.find_vim_options.IItemData
      local data = {
        name = name,
        scope = info.scope,
        type = info.type,
        value = value,
        text = text,
      }

      ---@type ghc.action.find_vim_options.IItem
      local item = { uuid = name, text = text_for_search, data = data }
      table.insert(items, item)
    end

    table.sort(items, function(a, b)
      return a.data.name < b.data.name
    end)
    return { items = items }
  end,
  render_item = function(item, match)
    local data = item.data ---@type ghc.action.find_vim_options.IItemData

    ---@type t.eve.IHighlightInline[]
    local highlights = {
      { coll = OFFSET_NAME, colr = OFFSET_NAME + #data.name, hlname = "f_us_vo_name" },
      { coll = OFFSET_TYPE, colr = OFFSET_TYPE + #data.type, hlname = "f_us_vo_type" },
      { coll = OFFSET_SCOPE, colr = OFFSET_SCOPE + #data.scope, hlname = "f_us_vo_scope" },
      { coll = OFFSET_VALUE, colr = #item.text, hlname = "f_us_vo_value" },
    }

    for _, piece in ipairs(match.matches) do
      ---@type t.eve.IHighlightInline[]
      local highlight = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
      table.insert(highlights, highlight)
    end
    return data.text, highlights
  end,
}

---@type t.fml.ux.ISelect
local select = fml.ux.Select.new({
  dimension = {
    height = 0.8,
    max_height = 1,
    max_width = 1,
    width = 0.8,
  },
  dirty_on_invisible = false,
  enable_preview = false,
  extend_preset_keymaps = true,
  provider = provider,
  title = "Find Vim Options",
  on_confirm = function(item)
    local data = item.data ---@type ghc.action.find_vim_options.IItemData
    local esc = vim.fn.mode() == "i" and vim.api.nvim_replace_termcodes("<esc>", true, false, true) or "" ---@type string
    vim.api.nvim_feedkeys(string.format("%s:set %s=%s", esc, data.name, data.value), "m", true)
    return "hide"
  end,
})

---@class ghc.action.find_vim_options
local M = {}

---@return nil
function M.toggle()
  select:toggle()
end

return M
