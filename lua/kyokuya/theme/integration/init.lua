local integrate_theme_replacer = require("kyokuya.theme.integration.replacer")

---@class kyokuya.theme.integration
local M = {}

---@param highlighter kyokuya.theme.Highlighter
function M.load_integrations(highlighter)
  integrate_theme_replacer(highlighter)
end

return M
