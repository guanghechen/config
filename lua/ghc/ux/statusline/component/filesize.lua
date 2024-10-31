---@param context                       t.fml.ux.nvimbar.IContext
---@return string
local function get_filesize(context)
  local filepath = context.filepath ---@type string
  return eve.oxi.get_filesize(filepath) or ""
end

---@type t.fml.ux.nvimbar.IRawComponent
local M = {
  name = "filesize",
  render = function(context)
    local text = get_filesize(context) ---@type string
    local hl_text = eve.nvimbar.txt(text, "f_sl_text")
    local width = vim.api.nvim_strwidth(text)
    return hl_text, width
  end,
}

return M
