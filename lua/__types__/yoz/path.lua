---@meta

---@module 'yoz.path'
---@class yoz.path
local M = {}

---@type string
M.SEP = ""

---@param filepath                      string
---@return string
function M.basename(filepath) end

---@param filepath                      string
---@param keep_tailing_slash            boolean
---@param sep                           string
---@return string
function M.dirname(filepath, keep_tailing_slash, sep) end

---@param filepath                      string
---@return string
function M.extname(filepath) end

---@param filepath                      string
---@return boolean
function M.is_absolute(filepath) end

---@param from                          string
---@param to                            string
---@return boolean
function M.is_descendant(from, to) end

---@param filepath                      string
---@return boolean
function M.is_dirpath(filepath) end

---@param from                          string
---@param to                            string
---@param keep_trailing_slash           boolean
---@param sep                           string
---@return string
function M.join(from, to, keep_trailing_slash, sep) end

---@param from                          string
---@param to                            string
---@param keep_trailing_slash           boolean
---@param sep                           string
---@return string
function M.relative(from, to, keep_trailing_slash, sep) end

---@param from                          string
---@param to                            string
---@param keep_trailing_slash           boolean
---@param sep                           string
---@return string
function M.resolve(from, to, keep_trailing_slash, sep) end

---@return string
function M.get_cwd() end

---@param cwd                           string
---@return nil
function M.set_cwd(cwd) end

---@param filepath                      string
---@param keep_trailing_slash           boolean
---@param sep                           string
---@return string
function M.normalize(filepath, keep_trailing_slash, sep) end

---@param filepath                      string
---@param keep_trailing_slash           boolean
---@return string[]
function M.split(filepath, keep_trailing_slash) end

---@param filepath                      string
---@return boolean
function M.is_exist(filepath) end

---@param dirpath                       string
---@return boolean
function M.is_exist_directory(dirpath) end

---@param filepath                      string
---@return boolean
function M.is_exist_file(filepath) end

---@param dirpath                       string
---@return nil
function M.mkdirs(dirpath) end

---@param start_dirpath                 string
---@param filenames                     string[]
---@return string|nil
function M.locate_nearest(start_dirpath, filenames) end

return M
