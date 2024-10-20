local sep = " " .. eve.path.SEP .. " "

---@type t.fml.ux.nvimbar.IRawComponent
local M = {
  name = "dirpath",
  render = function(context)
    local winnr = context.winnr ---@type integer
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local buf = eve.context.state.bufs[bufnr] ---@type t.eve.context.state.buf.IItem|nil
    if buf == nil then
      return "", 0
    end

    local hl_text = "" ---@type string
    local width = 0 ---@type integer
    local N = #buf.relpath - 1 ---@type integer
    for i = 1, N, 1 do
      local piece = buf.relpath[i] ---@type string
      local hl_text_piece = eve.nvimbar.txt(piece, "f_wl_dirpath_text") ---@type string
      local hl_text_sep = eve.nvimbar.txt(sep, "f_wl_dirpath_sep") ---@type string
      hl_text = hl_text .. hl_text_piece .. hl_text_sep
      width = width + vim.api.nvim_strwidth(piece .. sep)
    end
    return hl_text, width
  end,
}

return M
