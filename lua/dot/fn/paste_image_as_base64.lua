---@return string|nil
local function paste_image_as_base64()
  local clipboard = require("dot.module.clipboard")
  if not clipboard.has_image() then
    return nil
  end
  return clipboard.get_image_as_base64()
end

return paste_image_as_base64
