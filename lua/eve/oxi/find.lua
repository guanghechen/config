local json = require("eve.std.json")

---@class eve.oxi
local M = require("eve.oxi.mod")

---@class eve.oxi.find.IParams
---@field public workspace              string
---@field public cwd                    string
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public search_paths           string
---@field public exclude_patterns       string

---@class eve.oxi.find.IResult
---@field public filepaths              string[]

---@param params                        eve.oxi.find.IParams
---@return string[]
function M.find(params)
  local options_stringified = json.stringify(params)
  local result_str = M.nvim_tools.find(options_stringified)
  local ok, data = M.resolve_cmd_result("eve.oxi.find", result_str)
  if ok and data ~= nil then
    ---@cast data eve.oxi.find.IResult
    return data.filepaths
  end
  return {}
end
