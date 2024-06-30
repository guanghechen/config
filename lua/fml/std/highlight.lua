---@class fml.std.highlight
local M = {}

---@param fg_hlname                     string
---@param bg_hlname                     string
---@return string
function M.blend_color(fg_hlname, bg_hlname)
  local fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(fg_hlname)), "fg#")
  local bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(bg_hlname)), "bg#")
  local new_hlname = bg_hlname .. "__" .. fg_hlname
  vim.api.nvim_set_hl(0, new_hlname, { fg = fg, bg = bg })
  return new_hlname
end

return M
