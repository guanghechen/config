local oxi = require("eve.lib.oxi")

---@param context                       fml.t.ux.nvimbar.IContext
---@return string
local function get_filesize(context)
  local filepath = context.filepath ---@type string
  return oxi.get_filesize(filepath) or ""
end

---@type fml.t.ux.nvimbar.IRawComponent
local M = {
  name = "filesize",
  render = function(context)
    local text = get_filesize(context) ---@type string
    local hl_text = eve.nvim.txt(text, "f_sl_text")
    local width = vim.api.nvim_strwidth(text)
    return hl_text, width
  end,
}

return M
