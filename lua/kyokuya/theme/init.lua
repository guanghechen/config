---@class kyokuya.theme
local M = {}

local scheme = require("kyokuya.theme.scheme") ---@type fml.api.highlight.Scheme

---@return fml.api.highlight.Scheme
function M.get_scheme()
  return scheme
end

---@param theme                        fml.enums.highlight.Theme
---@return nil
function M.toggle_theme(theme)
  local present, palette = pcall(require, "kyokuya.theme.palette." .. theme)
  if not present then
    fml.reporter.error({
      from = "kyokuya.theme",
      subject = "toggle_theme",
      message = "Cannot find palette",
      details = { theme = theme },
    })
    return
  end

  scheme:apply(0, palette)
end

return M
