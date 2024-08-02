local sep = "  "

---@type string
local fn_goto_lsp_pos = fml.G.register_anonymous_fn(function(num)
  local args = fml.nvimbar.decode_btn_args(tostring(num)) ---@type integer[]
  if #args == 3 then
    local winnr = args[1] ---@type integer|nil
    local row = args[2] ---@type integer|nil
    local col = args[3] ---@type integer|nil

    if type(winnr) == "number" and type(row) == "number" and type(col) == "number" then
      if vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_win_set_cursor(winnr, { row, col })
      end
    end
  end
end) or ""

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "lsp",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local winnr = context.winnr ---@type integer
    local win = fml.api.state.wins[winnr] ---@type fml.types.api.state.IWinItem|nil
    if win == nil then
      return "", 0
    end

    local symbols = win.lsp_symbols ---@type fml.types.api.state.ILspSymbol[]|nil
    if symbols == nil or #symbols < 1 then
      return "", 0
    end

    local hl_text = "" ---@type string
    local width = 0 ---@type integer
    for _, symbol in ipairs(symbols) do
      local title = symbol.name or "" ---@type string
      local icon = (fml.ui.icons.kind[symbol.kind] or "") .. " " ---@type string
      local next_width = width + vim.fn.strwidth(sep .. icon .. title) ---@type integer
      if next_width > remain_width then
        break
      end

      width = next_width
      local hl_lsp_piece = fml.nvimbar.txt(sep, "f_wl_lsp_sep")
        .. fml.nvimbar.txt(icon, symbol.kind and "f_wl_lsp_icon_" .. symbol.kind or "f_wl_lsp_icon")
        .. fml.nvimbar.txt(title, "f_wl_lsp_text")
      hl_text = hl_text .. fml.nvimbar.btn(hl_lsp_piece, fn_goto_lsp_pos, { winnr, symbol.row, symbol.col })
    end
    return hl_text, width
  end,
}

return M
