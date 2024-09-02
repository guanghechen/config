---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "filename",
  render = function(context)
    local winnr = context.winnr ---@type integer
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local buf = fml.api.state.bufs[bufnr] ---@type fml.types.api.state.IBufItem|nil
    if buf == nil then
      return "", 0
    end

    local text_icon = buf.fileicon .. " " ---@type string
    local text_filename = buf.filename ---@type string
    local hl_text_icon = eve.nvimbar.txt(text_icon, buf.fileicon_hl .. "_wl") ---@type string
    local hl_text_title = eve.nvimbar.txt(text_filename, "f_wl_filename_text") ---@type string

    local hl_text = hl_text_icon .. hl_text_title
    local width = vim.fn.strwidth(text_icon .. text_filename) ---@type integer
    return hl_text, width
  end,
}

return M
