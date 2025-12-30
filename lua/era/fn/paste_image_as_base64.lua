---@return string|nil
local function paste_image_as_base64()
  if not era.m.clipboard.has_image() then
    return nil
  end
  return era.m.clipboard.get_image_as_base64()
end

return paste_image_as_base64
