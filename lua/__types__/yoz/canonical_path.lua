---@meta

---@module 'yoz.canonical_path'
---@class yoz.canonical_path
local M = {}

---@type '/'
M.SEP = "/"

---@param filepath                      string
---@return string
function M.basename(filepath) end

---@param filepath                      string
---@param keep_tailing_slash            boolean
---@return string
function M.dirname(filepath, keep_tailing_slash) end

---@param filepath                      string
---@return string
function M.extname(filepath) end

---@param os_path                       string OS path
---@param keep_trailing_slash           boolean
---@return string                       canonical path
function M.from_os_path(os_path, keep_trailing_slash) end

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
---@return string
function M.join(from, to, keep_trailing_slash) end

---@param from                          string
---@param to                            string
---@param keep_trailing_slash           boolean
---@return string
function M.relative(from, to, keep_trailing_slash) end

---@param from                          string
---@param to                            string
---@param keep_trailing_slash           boolean
---@return string
function M.resolve(from, to, keep_trailing_slash) end

---@return string
function M.get_cwd() end

---@param cwd                           string
---@return nil
function M.set_cwd(cwd) end

---@param filepath                      string
---@param keep_trailing_slash           boolean
---@return string
function M.normalize(filepath, keep_trailing_slash) end

---@param filepath                      string
---@param keep_trailing_slash           boolean
---@return string[]
function M.split(filepath, keep_trailing_slash) end

---@param filepath                      string canonical path
---@return string                       OS path
function M.to_os_path(filepath) end

return M
