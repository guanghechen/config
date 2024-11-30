---@type fml.t.ux.nvimbar.IRawComponent
local M = {
  name = "filename",
  render = function(context)
    local winnr = context.winnr ---@type integer
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    local meta = eve.buf.resolve(bufnr) ---@type eve.t.state.state.buf.IMeta|nil
    if meta == nil then
      local text = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local width = vim.api.nvim_strwidth(text) ---@type integer
      local hl_text = eve.nvim.txt(text, "f_wl_filename_text")
      return hl_text, width
    end

    local winnr_cur = eve.locations.get_current_winnr() or 0 ---@type integer
    local activated = winnr_cur == winnr ---@type boolean
    local hln_icon = activated and (meta.fileicon_hl .. "_wla") or (meta.fileicon_hl .. "_wl") ---@type string
    local hln_text = activated and "f_wla_filename_text" or "f_wl_filename_text" ---@type string

    local text_icon = meta.fileicon .. " " ---@type string
    local text_filename = meta.filename ---@type string
    local hl_text_icon = eve.nvim.txt(text_icon, hln_icon) ---@type string
    local hl_text_title = eve.nvim.txt(text_filename, hln_text) ---@type string

    local hl_text = hl_text_icon .. hl_text_title
    local width = vim.api.nvim_strwidth(text_icon .. text_filename) ---@type integer
    return hl_text, width
  end,
}

return M
