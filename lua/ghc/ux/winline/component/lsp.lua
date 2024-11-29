local sep = "  "

---@type string
local fn_goto_lsp_pos = eve.G.register_anonymous_fn(function(num)
  local args = eve.nvimbar.decode_btn_args(tostring(num)) ---@type integer[]
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

---@type fml.t.ux.nvimbar.IRawComponent
local M = {
  name = "lsp",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local winnr = context.winnr ---@type integer
    local win = eve.context.state.wins[winnr] ---@type eve.t.context.state.win.IItem|nil
    if win == nil then
      return "", 0
    end

    local symbols = win.lsp_symbols ---@type eve.t.context.state.lsp.ISymbol[]|nil
    if symbols == nil or #symbols < 1 then
      return "", 0
    end

    local winnr_cur = fml.api.tab.get_current_winnr() ---@type integer
    local activated = winnr_cur == winnr ---@type boolean

    local hln_sep = activated and "f_wla_lsp_sep" or "f_wl_lsp_sep" ---@type string
    local hln_text = activated and "f_wla_lsp_text" or "f_wl_lsp_text" ---@type string

    local hl_text = "" ---@type string
    local width = 0 ---@type integer
    for _, symbol in ipairs(symbols) do
      local title = symbol.name or "" ---@type string
      local icon = (eve.icons.kind[symbol.kind] or "") .. " " ---@type string
      local next_width = width + vim.api.nvim_strwidth(sep .. icon .. title) ---@type integer
      if next_width > remain_width then
        break
      end

      local hln_icon = activated and "f_wla_lsp_icon" or "f_wl_lsp_icon" ---@type string
      hln_icon = symbol.kind and hln_icon .. "_" .. symbol.kind or hln_icon

      width = next_width
      local hl_lsp_piece = eve.nvimbar.txt(sep, hln_sep)
        .. eve.nvimbar.txt(icon, hln_icon)
        .. eve.nvimbar.txt(title, hln_text)
      hl_text = hl_text .. eve.nvimbar.btn(hl_lsp_piece, fn_goto_lsp_pos, { winnr, symbol.row, symbol.col })
    end
    return hl_text, width
  end,
}

return M
