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
  local matches = {} ---@type fml.types.ui.select.ILineMatch[]
  local N1 = #lower_input ---@type integer
  for _, m in ipairs(old_matches) do
    local idx = m.idx ---@type integer
    local text = lower_texts[idx] ---@type string

    local l = 1 ---@type integer
    local r = N1 ---@type integer
    local score = 0 ---@type integer
    local pieces = {} ---@type fml.types.ui.select.ILineMatchPiece[]
    local N2 = #text ---@type integer
    while r <= N2 do
      if string.sub(text, l, r) == lower_input then
        table.insert(pieces, { l = l, r = r })
        score = score + 10
        l = r + 1
        r = r + N1
      else
        l = l + 1
        r = r + 1
      end
    end
    if #pieces > 0 then
      local match = { idx = idx, score = score, pieces = pieces } ---@type fml.types.ui.select.ILineMatch
      table.insert(matches, match)
    end
  end
  return matches
end

return M
