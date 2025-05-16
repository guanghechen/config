---@class fml.action.find.highlights.IItemData
---@field public lnum                   integer
---@field public hlid                   integer

---@class fml.action.find.highlights.IItem : eve.ux.select.IItem
---@field public data                   fml.action.find.highlights.IItemData

local _hlnames ---@type string[]|nil
local _hlgroups ---@type table<string, vim.api.keyset.get_hl_info>
local _preview_data ---@type eve.ux.ISearchPreviewData|nil

---@type eve.ux.select.IProvider
local provider = {
  fetch_data = function(force)
    if force or _hlnames == nil then
      local hlgroups = vim.api.nvim_get_hl(0, { create = false }) ---@type table<string, vim.api.keyset.get_hl_info>
      local hlnames = {} ---@type string[]
      for hlname in pairs(hlgroups) do
        table.insert(hlnames, hlname)
      end
      table.sort(hlnames)

      _hlnames = hlnames
      _hlgroups = hlgroups
      _preview_data = nil
    end

    local items = {} ---@type eve.ux.select.IItem[]
    for lnum, hlname in ipairs(_hlnames) do
      ---@type fml.action.find.highlights.IItemData
      local data = {
        lnum = lnum,
        hlid = vim.fn.hlID(hlname),
      }

      ---@type fml.action.find.highlights.IItem
      local item = { group = "H", uuid = hlname, text = hlname, data = data }
      table.insert(items, item)
    end
    ---@type eve.ux.select.IData
    return { items = items }
  end,
  fetch_preview_data = function(item)
    if _preview_data == nil then
      local hlnames = _hlnames or {} ---@type string[]
      local hlgroups = _hlgroups or {} ---@type table<string, vim.api.keyset.get_hl_info>

      local lines = {} ---@type string[]
      local highlights = {} ---@type std.t.IHighlight[]

      local max_hlname_width = 0 ---@type integer
      for _, hlname in ipairs(hlnames) do
        max_hlname_width = math.max(max_hlname_width, vim.api.nvim_strwidth(hlname))
      end

      for lnum, hlname in ipairs(hlnames) do
        local line = "xxx   " .. std.string.pad_end(hlname, max_hlname_width, " ") ---@type string
        local highlight = { lnum = lnum, coll = 0, colr = 3, hlname = hlname } ---@type std.t.IHighlight

        local hlgroup = hlgroups[hlname] or {} ---@type vim.api.keyset.get_hl_info
        if hlgroup.fg ~= nil then
          local color_name = std.color.int2hex(hlgroup.fg) ---@type string
          line = line .. " fg=" .. color_name
        end
        if hlgroup.bg ~= nil then
          local color_name = std.color.int2hex(hlgroup.bg) ---@type string
          line = line .. " bg=" .. color_name
        end
        if hlgroup.link ~= nil then
          line = line .. " link=" .. hlgroup.link
        end
        if hlgroup.cterm ~= nil then
          local flags = {} ---@type string[]
          for flag in pairs(hlgroup.cterm) do
            table.insert(flags, flag)
          end
          line = line .. " cterm=" .. table.concat(flags, ",")
        end

        for key, val in pairs(hlgroup) do
          if key ~= "fg" and key ~= "bg" and key ~= "link" and key ~= "cterm" then
            if type(val) ~= "string" then
              val = vim.inspect(val)
            end
            line = line .. " " .. key .. "=" .. val
          end
        end

        table.insert(lines, line)
        table.insert(highlights, highlight)
      end

      ---@type eve.ux.ISearchPreviewData
      _preview_data = {
        lines = lines,
        highlights = highlights,
        filetype = "text",
        title = "Highlights Preview",
        lnum = item.data.lnum,
        col = 0,
      }
    end
    return _preview_data
  end,
  patch_preview_data = function(item, _, last_data)
    ---@type eve.ux.ISearchPreviewData
    local data = {
      lines = last_data.lines,
      highlights = last_data.highlights,
      filetype = last_data.filetype,
      title = last_data.title,
      lnum = item.data.lnum,
      col = 0,
    }
    return data
  end,
  render_item = function(item, match)
    local text = string.format("%s xxx   %s", std.string.pad_end(tostring(item.data.hlid), 5, " "), item.text) ---@type string
    local highlights = { { coll = 6, colr = 9, hlname = item.text } } ---@type std.t.IHighlightInline[]

    local offset = 12 ---@type integer
    for _, piece in ipairs(match.matches) do
      ---@type std.t.IHighlightInline[]
      local highlight = { coll = offset + piece.l, colr = offset + piece.r, hlname = "f_us_main_match" }
      table.insert(highlights, highlight)
    end
    return text, highlights
  end,
}

---@type eve.ux.ISelect
local select = eve.ux.Select.new({
  dimension = {
    height = 0.8,
    max_height = 1,
    max_width = 1,
    width = 0.35,
    width_preview = 0.5,
  },
  dirty_on_invisible = false,
  preview_enabled = true,
  extend_preset_keymaps = true,
  multiple = false,
  permanent = false,
  provider = provider,
  title = "Find Highlights",
  on_confirm = function(widget, items)
    if #items == 1 then
      widget:close()
      local item = items[1] ---@type eve.ux.select.IItem
      vim.fn.setreg("+", item.text)
    end
  end,
})

---@class fml.action.find
local M = {}

---@return nil
function M.find_highlights()
  select:focus()
end

return M
