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
---@param hlname                        ?string
function M.btn(text, callback, hlname)
  if hlname ~= nil then
    text = M.txt(text, hlname)
  end
  if callback.sub(callback, 1, 3) == "fml" then
    return "%@v:lua._G." .. callback .. "@" .. text .. "%X"
  end
  return "%@v:lua._G.fml.G." .. callback .. "@" .. text .. "%X"
end

return M
