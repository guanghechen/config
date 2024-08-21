---@class fml.ui.search
local M = {}

M.Input = require("fml.ui.search.input")
M.Main = require("fml.ui.search.main")
M.Preview = require("fml.ui.search.preview")
M.Search = require("fml.ui.search.search")
M.State = require("fml.ui.search.state")

---@return fml.types.ui.search.ISearch|nil
function M.get_current_instance()
  return M.Search.get_current_instance()
end

---@return string
---@return string|nil
function M.get_current_path()
  return M.Search.get_current_path()
end

---@return boolean
function M.resume()
  local instance = M.get_current_instance() ---@return fml.types.ui.search.ISearch|nil
  if instance ~= nil then
    instance:resume()
    return true
  else
    return false
  end
end

return M
