---@meta

---@module 'yoz.find'
---@class yoz.find
local M = {}

---@class yoz.find.IFindFilesOptions
---@field public cwd                    string
---@field public flag_case_sensitive    boolean
---@field public flag_gitignore         boolean
---@field public flag_regex             boolean
---@field public search_pattern         string
---@field public search_paths           string
---@field public exclude_patterns       string

---@class yoz.find.IFindFilesSucceedResult
---@field public filepaths              string[]

---@class yoz.find.IFindFilesFailedResult
---@field public error                  string

---@param options                       yoz.find.IFindFilesOptions
---@return yoz.find.IFindFilesSucceedResult|nil
---@return yoz.find.IFindFilesFailedResult|nil
function M.find_files(options) end

return M
