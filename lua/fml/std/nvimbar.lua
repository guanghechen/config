local G = require("fml.std.G")

---@class fml.std.nvimbar
local M = {}

---@param text                          string
---@param hlname                        string
---@return string
function M.add_highlight(text, hlname)
  return "%#" .. hlname .. "#" .. text
end

---@param text                          string
---@param g_callback_fn                 string
function M.add_callback(text, g_callback_fn)
  return "%@:lua._G.fml.G." .. g_callback_fn .. "@" .. text .. "%@"
end

return M
