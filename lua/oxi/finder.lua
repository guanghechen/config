---@class oxi.finder.IFindFilesParams
---@field public workspace              string
---@field public cwd                    string
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public search_paths           string
---@field public exclude_patterns       string

---@class oxi.finder.IFindFilesResult
---@field public filepaths              string[]

---@class oxi.finder
local M = {}

---@param params                        oxi.finder.IFindFilesParams
---@return string[]
function M.find_files(params)
  local options_stringified = std.json.stringify(params)

  local nvim_tools = require("nvim_tools")
  local result_str = nvim_tools.find_files(options_stringified)
  local ok, data = oxi.fn.resolve_cmd_result("find_files", result_str)
  if ok and data ~= nil then
    ---@cast data                       oxi.finder.IFindFilesResult
    return data.filepaths
  end
  return {}
end

return M
