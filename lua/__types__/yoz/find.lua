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
---@field public include_patterns       string Comma-separated globs a file must match one of; empty lists every file.
---@field public exclude_patterns       string

---@class yoz.find.IFindFilesSucceedResult
---@field public filepaths              string[] Sorted paths relative to cwd.

---@class yoz.find.FindFilesJob
local Job = {}

---@return "running"|"completed"|"cancelled"|"failed"
---@return yoz.find.IFindFilesSucceedResult|nil
---@return string|nil
function Job:poll() end

---@return nil
function Job:cancel() end

---@return nil
function Job:dispose() end

---Walk on a worker thread; an invalid pattern raises at once.
---@param options                       yoz.find.IFindFilesOptions
---@return yoz.find.FindFilesJob
function M.start_find_files(options) end

return M
