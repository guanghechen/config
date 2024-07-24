---@type fml.types.ui.nvimbar.IRawComponent
local M = {
  name = "filename",
  ---@diagnostic disable-next-line: unused-local
  render = function(context, remain_width)
    local winnr = context.winnr ---@type integer
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local buf = fml.api.state.bufs[bufnr] ---@type fml.api.state.IBufItem|nil
    if buf == nil or buf.filename == nil then
      return "", 0
    end

    local icon, icon_hl = fml.util.calc_fileicon(buf.filename)
    local icon_text = " " .. icon .. " " ---@type string

    local title_hl = "f_wl_filename_text" ---@type string
    local title_text = buf.filename ---@type string

    local hl_icon_text = fml.nvimbar.txt(icon_text, icon_hl) ---@type string
    local hl_title_text = fml.nvimbar.txt(title_text, title_hl) ---@type string

    local hl_text = hl_icon_text .. hl_title_text
    local width = vim.fn.strwidth(icon_text .. title_text) ---@type integer
    return hl_text, width
  end,
}

return M
