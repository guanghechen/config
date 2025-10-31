---@meta

---@module 'rstd.find'
---@class rstd.find
local M = {}

---@class rstd.find.IFindFilesOptions
---@field public cwd                    string
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public search_paths           string
---@field public exclude_patterns       string

---@class rstd.find.IFindFilesSucceedResult
---@field public filepaths              string[]

---@class rstd.find.IFindFilesFailedResult
---@field public error                  string

---@param options                       rstd.find.IFindFilesOptions
---@return rstd.find.IFindFilesSucceedResult|nil
---@return rstd.find.IFindFilesFailedResult|nil
function M.find_files(options) end

return M
