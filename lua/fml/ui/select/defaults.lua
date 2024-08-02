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
    return item1.idx < item2.idx
  end
  return item1.score > item2.score
end

---@param lower_input                   string
---@param items                         fml.types.ui.select.IItem[]
---@param old_matches                   fml.types.ui.select.ILineMatch[]
---@return fml.types.ui.select.ILineMatch[]
function M.match(lower_input, items, old_matches)
  local lines = {} ---@type string[]
  for _, match in ipairs(old_matches) do
    local idx = match.idx ---@type integer
    local text = items[idx].lower ---@type string
    table.insert(lines, text)
  end
  local matches = oxi.find_match_points(lower_input, lines) ---@type fml.types.ui.select.ILineMatch[]
  for _, match in ipairs(matches) do
    ---! The index in lua is start from 1 but rust is start from 0.
    local idx = old_matches[match.idx + 1].idx
    match.idx = idx
  end
  return matches
end

---@param params                        fml.types.ui.select.main.IRenderLineParams
---@return string
---@return fml.types.ui.printer.ILineHighlight[]
function M.render_line(params)
  local match = params.match ---@type fml.types.ui.select.ILineMatch
  local item = params.item ---@type fml.types.ui.select.IItem
  local highlights = {} ---@type fml.types.ui.printer.ILineHighlight[]
  for _, piece in ipairs(match.pieces) do
    table.insert(highlights, { cstart = piece.l, cend = piece.r, hlname = "f_us_main_match" })
  end
  return item.display, highlights
end

---@param params                        fml.types.ui.select.main.IRenderLineParams
---@return string
---@return fml.types.ui.printer.ILineHighlight[]
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
  local highlights = { { cstart = 0, cend = icon_width, hlname = icon_hl } } ---@type fml.types.ui.printer.ILineHighlight[]
  for _, piece in ipairs(match.pieces) do
    table.insert(highlights, { cstart = piece.l + icon_width, cend = piece.r + icon_width, hlname = "f_us_main_match" })
  end
  return text, highlights
end

return M
