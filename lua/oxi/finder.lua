---@class oxi.finder.IFindParams
---@field public workspace              string
---@field public cwd                    string
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public search_paths           string
---@field public exclude_patterns       string

---@class oxi.finder.IFindResult
---@field public filepaths              string[]

---@class oxi.finder
local M = {}

---@param params                        oxi.finder.IFindParams
---@return string[]
function M.find(params)
  local options_stringified = std.json.stringify(params)

  local nvim_tools = require("nvim_tools")
  local result_str = nvim_tools.find(options_stringified)
  local ok, data = oxi.fn.resolve_cmd_result("find", result_str)
  if ok and data ~= nil then
    ---@cast data                       oxi.finder.IFindResult
    return data.filepaths
  end
  return {}
end

return M
