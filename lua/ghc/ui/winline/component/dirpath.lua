local sep = " " .. eve.path.SEP .. " "

---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "dirpath",
  render = function(context)
    local winnr = context.winnr ---@type integer
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local buf = fml.api.state.bufs[bufnr] ---@type fml.types.api.state.IBufItem|nil
    if buf == nil then
      return "", 0
    end

    local hl_text = "" ---@type string
    local width = 0 ---@type integer
    local N = #buf.real_paths - 1 ---@type integer
    for i = 1, N, 1 do
      local piece = buf.real_paths[i] ---@type string
      local hl_text_piece = eve.nvimbar.txt(piece, "f_wl_dirpath_text") ---@type string
      local hl_text_sep = eve.nvimbar.txt(sep, "f_wl_dirpath_sep") ---@type string
      hl_text = hl_text .. hl_text_piece .. hl_text_sep
      width = width + vim.fn.strwidth(piece .. sep)
    end
    return hl_text, width
  end,
}

return M
