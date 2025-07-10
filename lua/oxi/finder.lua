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
---@return string|nil
function M.find_files(params)
  local data, cmd = oxi.fn.safe_execute("find_files", params)
  if data ~= nil and data.filepaths ~= nil then
    ---@cast data                       oxi.finder.IFindFilesResult
    return data.filepaths, cmd
  end
  return {}, cmd
end

return M
