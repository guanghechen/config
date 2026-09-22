---@return string|nil
local function paste_image_as_base64()
  local encoded = era.m.clipboard.get_image_as_base64() ---@type string|nil
  return encoded ~= "" and encoded or nil
end

return paste_image_as_base64
