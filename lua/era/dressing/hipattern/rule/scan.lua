---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.hipattern.rule.scan" ---@type string

---@class era.dressing.hipattern.rule.scan.IMatch
---@field public full_match             string
---@field public match                  string
---@field public coll                   integer
---@field public colr                   integer

---@class era.dressing.hipattern.rule.scan
local M = {}

---@param line                          string
---@param pattern                       string
---@return era.dressing.hipattern.rule.scan.IMatch[]
function M.collect(line, pattern)
  local matches = {} ---@type era.dressing.hipattern.rule.scan.IMatch[]
  local init = 1 ---@type integer
  local anchored = pattern:sub(1, 1) == "^" ---@type boolean

  while init <= #line + 1 do
    local from, to, sub_from, sub_to = line:find(pattern, init)
    if from == nil or to == nil or from > to then
      break
    end

    local match_from = sub_from or from ---@type integer
    local match_to = sub_to and sub_to - 1 or to ---@type integer
    matches[#matches + 1] = {
      full_match = line:sub(from, to),
      match = line:sub(match_from, match_to),
      coll = match_from - 1,
      colr = match_to,
    }

    if anchored then
      break
    end
    init = math.max(to + 1, from + 1)
  end

  return matches
end

return M
