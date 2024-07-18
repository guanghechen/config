local oxi = require("fml.std.oxi")

---@class fml.ui.select.util
local M = {}

---@param item1                         fml.types.ui.select.ILineMatch
---@param item2                         fml.types.ui.select.ILineMatch
---@return boolean
function M.default_line_match_cmp(item1, item2)
  if item1.score == item2.score then
    return item1.idx < item2.idx
  end
  return item1.score > item2.score
end

---@param lower_input                   string
---@param lower_texts                   string[]
---@param old_matches                   fml.types.ui.select.ILineMatch[]
---@return fml.types.ui.select.ILineMatch[]
function M.default_match(lower_input, lower_texts, old_matches)
  local lines = {} ---@type string[]
  for _, m in ipairs(old_matches) do
    local idx = m.idx ---@type integer
    local text = lower_texts[idx] ---@type string
    table.insert(lines, text)
  end
  local matches = oxi.find_match_points(lower_input, lines) ---@type fml.types.ui.select.ILineMatch[]
  for _, match in ipairs(matches) do
    match.idx = old_matches[match.idx + 1].idx
  end
  return matches
end

return M
