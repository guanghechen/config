---@class guanghechen.replace.ReplacePane
local ReplacePane = {}
ReplacePane.__index = ReplacePane

---@return guanghechen.replace.ReplacePane
function ReplacePane.new()
  local self = setmetatable({}, ReplacePane)
  self._replace = ""
  self._replaceWith = ""
  return self
end
