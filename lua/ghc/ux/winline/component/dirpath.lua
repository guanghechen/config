local env = require("eve.lib.env")

local sep = " " .. env.PATH_SEP .. " "

---@type fml.t.ux.nvimbar.IRawComponent
local M = {
  name = "dirpath",
  render = function(context)
    local winnr = context.winnr ---@type integer
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local meta = eve.buf.resolve(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
    if meta == nil then
      return "", 0
    end

    local winnr_cur = eve.locations.get_current_winnr() or 0 ---@type integer
    local activated = winnr_cur == winnr ---@type boolean
    local hln_text_piece = activated and "f_wla_dirpath_text" or "f_wl_dirpath_text" ---@type string
    local hln_text_sep = activated and "f_wla_dirpath_sep" or "f_wl_dirpath_sep" ---@type string

    local hl_text = "" ---@type string
    local width = 0 ---@type integer
    local N = #meta.relpath - 1 ---@type integer
    for i = 1, N, 1 do
      local piece = meta.relpath[i] ---@type string
      local hl_text_piece = eve.nvim.txt(piece, hln_text_piece) ---@type string
      local hl_text_sep = eve.nvim.txt(sep, hln_text_sep) ---@type string
      hl_text = hl_text .. hl_text_piece .. hl_text_sep
      width = width + vim.api.nvim_strwidth(piece .. sep)
    end
    return hl_text, width
  end,
}

return M
