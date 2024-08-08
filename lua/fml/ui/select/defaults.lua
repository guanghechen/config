local oxi = require("fml.std.oxi")
local path = require("fml.std.path")
local util = require("fml.std.util")

---@class fml.ui.select.defaults
local M = {}

---@param item1                         fml.types.ui.select.ILineMatch
---@param item2                         fml.types.ui.select.ILineMatch
---@return boolean
function M.line_match_cmp(item1, item2)
  if item1.score == item2.score then
    return item1.order < item2.order
  end
  return item1.score > item2.score
end

---@param lower_input                   string
---@param item_map                      table<string, fml.types.ui.select.IItem>
---@param old_matches                   fml.types.ui.select.ILineMatch[]
---@return fml.types.ui.select.ILineMatch[]
function M.match(lower_input, item_map, old_matches)
  local lines = {} ---@type string[]
  for _, match in ipairs(old_matches) do
    local uuid = match.uuid ---@type string
    local text = item_map[uuid].lower ---@type string
    table.insert(lines, text)
  end

  local oxi_matches = oxi.find_match_points(lower_input, lines) ---@type fml.std.oxi.string.ILineMatch[]
  local matches = {} ---@type fml.types.ui.select.ILineMatch[]
  for _, oxi_match in ipairs(oxi_matches) do
    ---! The index in lua is start from 1 but rust is start from 0.
    local old_match = old_matches[oxi_match.idx + 1] ---@type fml.types.ui.select.ILineMatch

    ---@type fml.types.ui.select.ILineMatch
    local match = {
      order = old_match.order,
      uuid = old_match.uuid,
      score = oxi_match.score,
      pieces = oxi_match.pieces,
    }
    table.insert(matches, match)
  end
  return matches
end

---@param params                        fml.types.ui.select.main.IRenderLineParams
---@return string
---@return fml.types.ui.IInlineHighlight[]
function M.render_line(params)
  local match = params.match ---@type fml.types.ui.select.ILineMatch
  local item = params.item ---@type fml.types.ui.select.IItem
  local highlights = {} ---@type fml.types.ui.IInlineHighlight[]
  for _, piece in ipairs(match.pieces) do
    ---@type fml.types.ui.IInlineHighlight[]
    local highlight = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
    table.insert(highlights, highlight)
  end
  return item.display, highlights
end

---@param params                        fml.types.ui.select.main.IRenderLineParams
---@return string
---@return fml.types.ui.IInlineHighlight[]
function M.render_filepath(params)
  local match = params.match ---@type fml.types.ui.select.ILineMatch
  local item = params.item ---@type fml.types.ui.select.IItem

  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast item fml.types.ui.select.IFileItem

  local filename = item.filename ---@type string|nil
  local icon = item.icon ---@type string|nil
  local icon_hl = item.icon_hl ---@type string|nil

  if filename == nil or icon == nil or icon_hl == nil then
    filename = path.basename(item.display)
    icon, icon_hl = util.calc_fileicon(filename)
    icon = icon .. " "

    item.filename = filename
    item.icon = icon
    item.icon_hl = icon_hl
  end

  local icon_width = string.len(icon) ---@type integer
  local text = icon .. item.display ---@type string

  ---@type fml.types.ui.IInlineHighlight[]
  local highlights = { { coll = 0, colr = icon_width, hlname = icon_hl } }
  for _, piece in ipairs(match.pieces) do
    ---@type fml.types.ui.IInlineHighlight
    local highlight = { coll = piece.l + icon_width, colr = piece.r + icon_width, hlname = "f_us_main_match" }
    table.insert(highlights, highlight)
  end
  return text, highlights
end

return M
