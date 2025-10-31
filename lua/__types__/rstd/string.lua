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
---@param text                                  string
---@param widths                                integer[]|nil
---@return string[]
function M.parse_lines(text, widths) end

return M
