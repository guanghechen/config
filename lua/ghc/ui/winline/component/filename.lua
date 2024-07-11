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

    local icon, fileicon_hl = fml.fn.calc_fileicon(buf.filename)
    local text_icon = " " .. icon .. " " ---@type string
    local text_title = buf.filename ---@type string

    local title_hl = "f_wl_filename_text" ---@type string
    local icon_hl = fml.highlight.blend_color(fileicon_hl, title_hl)

    local hl_text_icon = fml.nvimbar.txt(text_icon, icon_hl) ---@type string
    local hl_text_title = fml.nvimbar.txt(text_title, title_hl) ---@type string

    local hl_text = hl_text_icon .. hl_text_title
    local width = vim.fn.strwidth(text_icon .. text_title) ---@type integer
    return hl_text, width
  end,
}

return M
