---@class fml.std.oxi
local M = require("fml.std.oxi.mod")

---@class fml.std.oxi.find.IParams
---@field public workspace              string
---@field public cwd                    string
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public search_paths           string
---@field public exclude_patterns       string

---@class fml.std.oxi.find.IResult
---@field public filepaths              string[]

---@param params                        fml.std.oxi.find.IParams
---@return string[]
function M.find(params)
  local options_stringified = M.json.stringify(params)
  local result_str = M.nvim_tools.find(options_stringified)
  local ok, data = M.resolve_cmd_result("fml.std.oxi.find", result_str)
  if ok and data ~= nil then
    ---@cast data fml.std.oxi.find.IResult
    return data.filepaths
  end
  return {}
end
