---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "lsp",
  condition = function()
    return not not package.loaded["nvim-navic"] and require("nvim-navic").is_available()
  end,
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local winnr = context.winnr ---@type integer
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local navic = require("nvim-navic")
    local nestings = navic.get_data(bufnr)
    if nestings == nil or vim.b[bufnr].navic_client_id == nil then
      return "", 0
    end

    local text_hl = "" ---@type string
    local width = 0
    for _, nesting in ipairs(nestings) do
      local title = nesting.name or "" ---@type string
      local icon = (nesting.icon or "") .. " " ---@type string
      local sep = "  "
      local t = sep .. icon .. " " .. title ---@type string
      local w = vim.fn.strwidth(t) ---@type integer

      if width + w > remain_width then
        break
      end

      width = width + w
      text_hl = text_hl
          .. fml.nvimbar.txt(sep, "f_wl_lsp_sep")
          .. fml.nvimbar.txt(icon, "f_wl_lsp_icon")
          .. fml.nvimbar.txt(title, "f_wl_lsp_text")
    end
    return text_hl, width
  end,
}

return M
