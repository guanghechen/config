---@class fml.std.nvimbar
local M = {}

---@param text                          string
---@param hlname                        string
---@return string
function M.txt(text, hlname)
  return "%#" .. hlname .. "#" .. text
end

---@param text                          string
---@param callback                      string
---@param args                          ?string
function M.btn(text, callback, args)
  args = args or ""
  if callback.sub(callback, 1, 3) == "fml" then
    return "%" .. args .. "@v:lua." .. callback .. "@" .. text .. "%X"
  end
  return "%" .. args .. "@v:lua.fml.G." .. callback .. "@" .. text .. "%X"
end

return M
