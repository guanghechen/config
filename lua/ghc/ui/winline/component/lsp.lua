---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "lsp",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local winnr = context.winnr ---@type integer
    local win = fml.api.state.wins[winnr] ---@type fml.api.state.IWinItem|nil
    if win == nil then
      return "", 0
    end

    local symbols = win.lsp_symbols ---@type fml.api.state.ILspSymbol[]
    if symbols == nil or #symbols < 1 then
      return "", 0
    end

    local text_hl = "" ---@type string
    local width = 0
    for _, symbol in ipairs(symbols) do
      local title = symbol.name or "" ---@type string
      local icon = (fml.ui.icons.kind[symbol.kind] or "") .. " " ---@type string
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
