---@meta

---@module 'rstd.string'
---@class rstd.string
local M = {}

---@param text                                  string
---@return integer[]
function M.calc_linewidths(text) end

---@param text                                  string
---@return integer
function M.count_lines(text) end

---@param text                                  string
---@return string[]
function M.parse_comma_list(text) end

return M
