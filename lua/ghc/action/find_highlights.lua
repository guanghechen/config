local _select ---@type t.fml.ux.ISelect
local _hlnames ---@type string[]|nil
local _hlgroups ---@type table<string, vim.api.keyset.hl_info>
local _preview_data ---@type t.fml.ux.search.preview.IData|nil

---@class ghc.action.find_highlights.IItem : t.fml.ux.select.IItem
---@field public data                   integer

---@type t.fml.ux.select.IProvider
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

    local items = {} ---@type t.fml.ux.select.IItem[]
    for lnum, hlname in ipairs(_hlnames) do
      ---@type ghc.action.find_highlights.IItem
      local item = { group = "H", uuid = hlname, text = hlname, data = lnum }
      table.insert(items, item)
    end
    ---@type t.fml.ux.select.IData
    return { items = items }
  end,
  fetch_preview_data = function(item)
    if _preview_data == nil then
      local hlnames = _hlnames or {} ---@type string[]
      local hlgroups = _hlgroups or {} ---@type table<string, vim.api.keyset.hl_info>

      local lines = {} ---@type string[]
      local highlights = {} ---@type t.eve.IHighlight[]

      local max_hlname_width = 0 ---@type integer
      for _, hlname in ipairs(hlnames) do
        max_hlname_width = math.max(max_hlname_width, vim.api.nvim_strwidth(hlname))
      end

      for lnum, hlname in ipairs(hlnames) do
        local line = "xxx   " .. eve.string.pad_end(hlname, max_hlname_width, " ") ---@type string
        local highlight = { lnum = lnum, coll = 0, colr = 3, hlname = hlname } ---@type t.eve.IHighlight

        local hlgroup = hlgroups[hlname] or {} ---@type vim.api.keyset.hl_info
        if hlgroup.fg ~= nil then
          local color_name = eve.std.color.int2hex(hlgroup.fg) ---@type string
          line = line .. " fg=" .. color_name
        end
        if hlgroup.bg ~= nil then
          local color_name = eve.std.color.int2hex(hlgroup.bg) ---@type string
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
              val = eve.json.stringify(val)
            end
            line = line .. " " .. key .. "=" .. val
          end
        end

        table.insert(lines, line)
        table.insert(highlights, highlight)
      end

      ---@type t.fml.ux.search.preview.IData
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
    ---@type t.fml.ux.search.preview.IData
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
    local highlights = { { coll = 0, colr = 3, hlname = item.text } } ---@type t.eve.IHighlightInline[]
    for _, piece in ipairs(match.matches) do
      ---@type t.eve.IHighlightInline[]
      local highlight = { coll = width_prefix + piece.l, colr = width_prefix + piece.r, hlname = "f_us_main_match" }
      table.insert(highlights, highlight)
    end
    return text, highlights
  end,
}

_select = fml.ux.Select.new({
  dimension = {
    height = 0.8,
    max_height = 1,
    max_width = 1,
    width = 0.35,
    width_preview = 0.5,
  },
  dirty_on_invisible = false,
  enable_preview = true,
  extend_preset_keymaps = true,
  provider = provider,
  title = "Find Highlights",
  on_confirm = function(item)
    vim.fn.setreg("+", item.text)
    return "hide"
  end,
})

---@class ghc.action.find_highlights
local M = {}

---@return nil
function M.toggle()
  _select:toggle()
end

return M
