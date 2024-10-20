local EDITING_PREFIX = eve.constants.EDITING_INPUT_PREFIX ---@type string

---@class fml.util
local M = {}

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
