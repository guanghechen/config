local _select ---@type fml.types.ui.ISelect
local _hlnames ---@type string[]|nil
local _hlgroups ---@type table<string, vim.api.keyset.hl_info>
local _preview_data ---@type fml.ui.search.preview.IData|nil

---@class ghc.command.find_highlights.IItem : fml.types.ui.select.IItem
---@field public data                   integer

---@type fml.types.ui.select.IProvider
local provider = {
  fetch_data = function(force)
    if force or _hlnames == nil then
      ---@type table<string, vim.api.keyset.hl_info[]>
      local hlgroups = vim.api.nvim_get_hl(0, { create = false })
      local hlnames = {} ---@type string[]
      for hlname in pairs(hlgroups) do
        table.insert(hlnames, hlname)
      end
      table.sort(hlnames)

      _hlnames = hlnames
      _hlgroups = hlgroups
      _preview_data = nil
    end

    ---@type fml.types.ui.select.IData
    local data = {
      items = {},
    }

    for lnum, hlname in ipairs(_hlnames) do
      ---@type ghc.command.find_highlights.IItem
      local item = { group = "H", uuid = hlname, text = hlname, data = lnum }
      table.insert(data.items, item)
    end
    return data
  end,
  fetch_preview_data = function(item)
    if _preview_data == nil then
      local hlnames = _hlnames or {} ---@type string[]
      local hlgroups = _hlgroups or {} ---@type table<string, vim.api.keyset.hl_info>

      local lines = {} ---@type string[]
      local highlights = {} ---@type fml.types.ui.IHighlight[]

      local max_hlname_width = 0 ---@type integer
      for _, hlname in ipairs(hlnames) do
        max_hlname_width = math.max(max_hlname_width, vim.fn.strwidth(hlname))
      end

      for lnum, hlname in ipairs(hlnames) do
        local line = "xxx   " .. fml.string.pad_end(hlname, max_hlname_width, " ") ---@type string
        local highlight = { lnum = lnum, coll = 0, colr = 3, hlname = hlname } ---@type fml.types.ui.IHighlight

        local hlgroup = hlgroups[hlname] or {} ---@type vim.api.keyset.hl_info
        for key, val in pairs(hlgroup) do
          if type(val) == "number" then
            val = fml.std.color.int2hex(val)
          else
            val = fml.json.stringify(val)
          end
          line = line .. " " .. key .. "=" .. val
        end

        table.insert(lines, line)
        table.insert(highlights, highlight)
      end

      ---@type fml.ui.search.preview.IData
      _preview_data = {
        lines = lines,
        highlights = highlights,
        filetype = "text",
        title = "Highlights Preview",
        lnum = item.data,
        col = 0,
      }
    end

    return _preview_data
  end,
  patch_preview_data = function(item, _, last_data)
    ---@type fml.ui.search.preview.IData
    local data = {
      lines = last_data.lines,
      highlights = last_data.highlights,
      filetype = last_data.filetype,
      title = last_data.title,
      lnum = item.data,
      col = 0,
    }

    return data
  end,
  render_item = function(item, match)
    local text_prefix = "xxx   " ---@type string
    local width_prefix = string.len(text_prefix) ---@type integer
    local text = text_prefix .. item.text
    local highlights = { { coll = 0, colr = 3, hlname = item.text } } ---@type fml.types.ui.IInlineHighlight[]
    for _, piece in ipairs(match.matches) do
      ---@type fml.types.ui.IInlineHighlight[]
      local highlight = { coll = width_prefix + piece.l, colr = width_prefix + piece.r, hlname = "f_us_main_match" }
      table.insert(highlights, highlight)
    end
    return text, highlights
  end,
}

_select = fml.ui.Select.new({
  destroy_on_close = true,
  dimension = {
    height = 0.8,
    max_height = 1,
    max_width = 1,
    width = 0.35,
    width_preview = 0.5,
  },
  dirty_on_close = false,
  enable_preview = true,
  extend_preset_keymaps = true,
  provider = provider,
  title = "Find highlights",
  on_confirm = function()
    return false
  end,
})

---@class ghc.command.find_highlights
local M = {}

---@return nil
function M.focus()
  _select:focus()
end

return M
