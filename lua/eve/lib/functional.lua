local setting = require("eve.constant.setting")
local EDITING_PREFIX = setting.EDITING_INPUT_PREFIX ---@type string

---@class eve.lib.functional
local M = {}

---@param ...                           any[]
---@return any
function M.noop(...) end

---@param text                          string
---@return boolean
function M.is_editing_text(text)
  return #text >= #EDITING_PREFIX and text:sub(1, #EDITING_PREFIX) == EDITING_PREFIX
end

---@param text                          string
---@return string
function M.unwrap_editing_prefix(text)
  return M.is_editing_text(text) and text:sub(#EDITING_PREFIX + 1) or text
end

return M
