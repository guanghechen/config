---@class fc.std.oxi
local M = require("fc.std.oxi.mod")

---@class fc.std.oxi.find.IParams
---@field public workspace              string
---@field public cwd                    string
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public search_paths           string
---@field public exclude_patterns       string

---@class fc.std.oxi.find.IResult
---@field public filepaths              string[]

---@param params                        fc.std.oxi.find.IParams
---@return string[]
function M.find(params)
  local options_stringified = M.json.stringify(params)
  local result_str = M.nvim_tools.find(options_stringified)
  local ok, data = M.resolve_cmd_result("fc.std.oxi.find", result_str)
  if ok and data ~= nil then
    ---@cast data fc.std.oxi.find.IResult
    return data.filepaths
  end
  return {}
end
