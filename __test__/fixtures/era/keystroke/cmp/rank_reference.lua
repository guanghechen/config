---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.keystroke.cmp.rank_reference" ---@type string

local Context = require("era.keystroke.cmp.context")
local M = {}

---@param context                       era.keystroke.cmp.IContext
---@param groups                        era.keystroke.cmp.IRankGroup[]
---@param history                       ?yoz.completion.History
---@return { item: era.keystroke.cmp.IItem, score: number, order: integer }[]
function M.query(context, groups, history)
  local results, seen = {}, {}
  local offset = 0
  local nearby = table.concat(
    vim.api.nvim_buf_get_lines(
      context.bufnr,
      math.max(0, context.row - 30),
      math.min(vim.api.nvim_buf_line_count(context.bufnr), context.row + 31),
      false
    ),
    "\n"
  )
  if #nearby > 10000 then
    nearby = ""
  end
  for _, group in ipairs(groups) do
    local labels = {}
    for index, item in ipairs(group.items) do
      labels[index] = type(item.raw.filterText) == "string" and item.raw.filterText or item.raw.label
    end
    local query = context.line:sub(group.start_col + 1, context.col)
    local indexes, scores = yoz.completion.new(labels):query(query)
    for position, index in ipairs(indexes) do
      local item = group.items[index]
      if not seen[item.id] and Context.compatible(item.context, context, item.start_col) then
        seen[item.id] = true
        local usage = history and math.min(6, history:score(context.filetype .. "\0" .. item.frecency_key)) or 0
        local proximity = query ~= "" and nearby:find(item.raw.label, 1, true) and 2 or 0
        local deprecated = item.raw.deprecated == true
          or (type(item.raw.tags) == "table" and vim.list_contains(item.raw.tags, 1))
        results[#results + 1] = {
          item = item,
          score = scores[position] + item.score_offset + usage + proximity - (deprecated and 2 or 0),
          order = offset + index,
        }
      end
    end
    offset = offset + #group.items
  end
  table.sort(results, function(a, b)
    if a.score ~= b.score then
      return a.score > b.score
    end
    local left = type(a.item.raw.sortText) == "string" and a.item.raw.sortText or nil
    local right = type(b.item.raw.sortText) == "string" and b.item.raw.sortText or nil
    if left ~= right then
      return left == nil or (right ~= nil and left < right)
    end
    return a.order < b.order
  end)
  return vim.list_slice(results, 1, 200)
end

return M
