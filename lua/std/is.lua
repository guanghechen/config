---@class std.is
local M = {}

---@param value                         unknown
---@return boolean
function M.dict(value)
  return type(value) == "table" and (vim.tbl_isempty(value) or not value[1])
end

---@param value                         unknown
---@return boolean
function M.dict_like(value)
  return type(value) == "table" and (vim.tbl_isempty(value) or not vim.islist(value))
end

---@param value                         unknown
---@return boolean
function M.disposable(value)
  return type(value) == "table" and type(value.isDisposable) == "function" and type(value.dispose) == "function"
end

---@param value                         unknown
---@return boolean
function M.observable(value)
  return type(value) == "table"
    and type(value.snapshot) == "function"
    and type(value.next) == "function"
    and type(value.subscribe) == "function"
end

return M