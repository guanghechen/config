---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

local COMMA_LIST_ITEM_PATTERN = "([^,]+)" ---@type string

---@param cwd                           string
---@param exclude_patterns              string[]
---@return string[]
function M.collect_file_paths(cwd, exclude_patterns)
  local text = M.nvim_tools.collect_file_paths(cwd, table.concat(exclude_patterns, ",")) ---@type string
  local paths = {} ---@type string[]

  for piece in string.gmatch(text, COMMA_LIST_ITEM_PATTERN) do
    table.insert(paths, piece)
  end
  return paths
end
