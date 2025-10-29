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

---@param text                                  string
---@param offsets                               integer[]
---@return std.t.IMatchLocation[]
function M.get_locations(text, offsets) end

---@param pattern                               string
---@return integer[]
function M.kmp_calc_fails(pattern) end

---@param text                                  string
---@param pattern                               string
---@return integer[]
function M.kmp_find_all_matched_points(text, pattern) end

---@param text                                  string
---@param pattern                               string
---@return integer|nil
function M.kmp_find_first_matched_point(text, pattern) end

return M
